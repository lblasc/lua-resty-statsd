local udp            = ngx.socket.udp
local log            = ngx.log
local ERR            = ngx.ERR
local new_timer      = ngx.timer.at
local insert         = table.insert
local concat         = table.concat
local pairs          = pairs
local worker_exiting = ngx.worker.exiting

local ok, clear = pcall(require, "table.clear")
if not ok then
  error("table clear required")
end

local ok, new_tab = pcall(require, "table.new")
if not ok or type(new_tab) ~= "function" then
  new_tab = function (narr, nrec) return {} end
end

local function errlog(...)
  log(ERR, "statsd: ", ...)
end

-- https://github.com/influxdata/telegraf/tree/master/plugins/inputs/statsd
local function form_telegraf_string(tags)
  local tg_str = ""

  for t, v in pairs(tags) do
    tg_str = tg_str..","..t.."="..v
  end

  return tg_str
end

local function send(msg, host, port)
  local sock, err = udp()
  if not sock then
      return nil, err
  end

  local ok, err = sock:setpeername(host, port)
  if not ok then
    return nil, err
  end

  local ok, err = sock:send(msg)
  if not ok then
    return nil, err
  end

  return sock:close()
end

local buffer = {}

local _M = new_tab(0, 9)
_M._VERSION = "1.0.0"
local mt = { __index = _M }

function _M.new(self, options)
  local o = {
    host        = options.host or "localhost",
    port        = options.port or 8125,
    prefix      = options.prefix or "",
    suffix      = options.suffix or "",
    global_tags = options.global_tags or {},
    batch       = options.batch or false,
    telegraf    = options.telegraf or false,
  }

  return setmetatable(o, mt)
end

function _M.dispatch_metric(self, stat, value, mtype, tags)
  local host        = self.host
  local port        = self.port
  local prefix      = self.prefix
  local suffix      = self.suffix
  local telegraf    = self.telegraf
  local merged_tags = self.global_tags
  local tags_str    = ""

  -- override global tags
  if type(tags) == "table" then
    for t, v in pairs(tags) do
      merged_tags[t] = v
    end
  end

  -- support only telegraf tags, TODO: datadog
  if telegraf then
    tags_str = form_telegraf_string(merged_tags)
  end

  local msg = prefix..stat..suffix..tags_str..":"..value.."|"..mtype

  if self.batch then
    -- metrics will be lost if they are buffered while
    -- worker process is exiting (timer not triggered)
    -- so send them directly
    local exiting = worker_exiting()
    if not exiting then
      insert(buffer, msg)
      return
    end
  end

  local ok, err = send(msg, host, port)
  if not ok then
    errlog("failed to send metric: ", err)
  end
end

function _M.count(self, stat, n, tags)
  return self:dispatch_metric(stat, n, "c", tags)
end

function _M.incr(self, stat, n, tags)
  if not n or (type(n) ~= "number") then
    n = 1
  end

  return self:count(stat, n, tags)
end

function _M.decr(self, stat, n, tags)
  if not n or (type(n) ~= "number") then
    n = 1
  end

  return self:count(stat, -1*n, tags)
end

function _M.timing(self, stat, time, tags)
  return self:dispatch_metric(stat, time, "ms", tags)
end

function _M.gauge(self, stat, value, tags)
  return self:dispatch_metric(stat, value, "g", tags)
end

local flush
flush = function (premature, ctx)
  if premature then
    return
  end

  if #buffer ~= 0 then
    local msg = concat(buffer, "\n")
    clear(buffer)
    local ok, err = send(msg, ctx.host, ctx.port)
    if not ok then
      errlog("failed to send metric: ", err)
    end
  end

  local ok, err = new_timer(ctx.interval, flush, ctx)
  if not ok then
    if err ~= "process exiting" then
      errlog("failed to create timer: ", err)
      return
    end
    return
  end
end

function _M.spawn_flusher(self, interval)
  if not interval then
    interval = 1
  else
    interval = interval / 1000
    if interval < 0.1 then
      interval = 0.1 -- shouldn't go below this
    end
  end

  self.interval = interval

  local ok, err = new_timer(0, flush, self)
  if not ok then
    return nil, "failed to create timer: "..err
  end
end

return _M
