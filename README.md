Name
====

lua-resty-statsd - OpenResty statsd client

Table of Contents
=================

* [Name](#name)
* [Status](#status)
* [Synopsis](#synopsis)
* [Description](#description)
* [Methods](#methods)
    * [spawn_checker](#spawn_checker)
    * [status_page](#status_page)
* [Multiple Upstreams](#multiple-upstreams)
* [Installation](#installation)
* [TODO](#todo)
* [Community](#community)
    * [English Mailing List](#english-mailing-list)
    * [Chinese Mailing List](#chinese-mailing-list)
* [Bugs and Patches](#bugs-and-patches)
* [Author](#author)
* [Copyright and License](#copyright-and-license)
* [See Also](#see-also)

Status
======

This library is still under early development but is already production ready.

Synopsis
========

```nginx
http {
    lua_package_path "/path/to/lua-resty-statsd/lib/?.lua;;";

    init_by_lua_block {
        statsd = require "resty.statsd"
    }

    server {
        ...

        # status page for all the peers:
        location = /status {
            access_log off;
            allow 127.0.0.1;
            deny all;

            default_type text/plain;
            content_by_lua_block {
                local client = statsd:new()
								client:incr("test")
            }
        }
    }
}
```

Description
===========

This library implements Etsy statsd protocol with optional Telegraf tags extension.

[Back to TOC](#table-of-contents)

Methods
=======

spawn_flusher
-------------
**syntax:** `ok, err = client:spawn_checker(interval)`

**context:** *init_worker_by_lua&#42;*

Spawns background timer-based "light threads" to perform periodic buffer flushes only
when runing in batch mode.

The statsd does not need any client traffic to function. The flushes are performed actively and periodically.

This method call is asynchronous and returns immediately.

Returns true on success, or `nil` and a string describing an error otherwise.

[Back to TOC](#table-of-contents)

Batch Mode
==========

One can perform healchchecks on multiple `upstream` groups by calling the [spawn_checker](#spawn_checker) method
multiple times in the `init_worker_by_lua*` handler. For example,

```nginx
upstream foo {
    ...
}

upstream bar {
    ...
}

lua_shared_dict healthcheck 1m;

lua_socket_log_errors off;

init_worker_by_lua_block {
    init_worker_by_lua_block {
        local hc = require "resty.upstream.healthcheck"

        local ok, err = hc.spawn_checker{
            shm = "healthcheck",
            upstream = "foo",
            ...
        }

        ...

        ok, err = hc.spawn_checker{
            shm = "healthcheck",
            upstream = "bar",
            ...
        }
    }
}
```

Different upstreams' healthcheckers use different keys (by always prefixing the keys with the
upstream name), so sharing a single `lua_shared_dict` among multiple checkers should not have
any issues at all. But you need to compensate the size of the shared dict for multiple users (i.e., multiple checkers).
If you have many upstreams (thousands or even more), then it is more optimal to use separate shm zones
for each (group) of the upstreams.

[Back to TOC](#table-of-contents)

Installation
============

If you are using [OpenResty](http://openresty.org) 1.9.3.2 or later, then you should already have this library (and all of its dependencies) installed by default (and this is also the recommended way of using this library). Otherwise continue reading:

You need to compile both the [ngx_lua](https://github.com/openresty/lua-nginx-module) and [ngx_lua_upstream](https://github.com/openresty/lua-upstream-nginx-module) modules into your Nginx.

The latest git master branch of [ngx_lua](https://github.com/openresty/lua-nginx-module) is required.

You need to configure
the [lua_package_path](https://github.com/openresty/lua-nginx-module#lua_package_path) directive to
add the path of your `lua-resty-upstream-healthcheck` source tree to [ngx_lua](https://github.com/openresty/lua-nginx-module)'s Lua module search path, as in

```nginx
# nginx.conf
http {
    lua_package_path "/path/to/lua-resty-upstream-healthcheck/lib/?.lua;;";
    ...
}
```

[Back to TOC](#table-of-contents)

TODO
====

[Back to TOC](#table-of-contents)

Community
=========

[Back to TOC](#table-of-contents)

English Mailing List
--------------------

The [openresty-en](https://groups.google.com/group/openresty-en) mailing list is for English speakers.

[Back to TOC](#table-of-contents)

Chinese Mailing List
--------------------

The [openresty](https://groups.google.com/group/openresty) mailing list is for Chinese speakers.

[Back to TOC](#table-of-contents)

Bugs and Patches
================

Please report bugs or submit patches by

1. creating a ticket on the [GitHub Issue Tracker](http://github.com/openresty/lua-resty-upstream-healthcheck/issues),
1. or posting to the [OpenResty community](#community).

[Back to TOC](#table-of-contents)

Author
======

Yichun "agentzh" Zhang (章亦春) <agentzh@gmail.com>, CloudFlare Inc.

[Back to TOC](#table-of-contents)

Copyright and License
=====================

This module is licensed under the BSD license.

Copyright (C) 2014-2016, by Yichun "agentzh" Zhang, CloudFlare Inc.

All rights reserved.

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

* Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.

* Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

[Back to TOC](#table-of-contents)

See Also
========
* the ngx_lua module: https://github.com/openresty/lua-nginx-module
* the ngx_lua_upstream module: https://github.com/openresty/lua-upstream-nginx-module
* OpenResty: http://openresty.org

[Back to TOC](#table-of-contents)

