--[[

HTTP server implementation for LuCI - luci handler
(c) 2008 Steven Barth <steven@midlink.org>

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

        http://www.apache.org/licenses/LICENSE-2.0

$Id$

]]--

module("luci.httpd.handler.file", package.seeall)

require("luci.httpd.module")
require("luci.http.protocol.date")
require("luci.http.protocol.mime")
require("luci.fs")
require("ltn12")

Simple = luci.util.class(luci.httpd.module.Handler)
Response = luci.httpd.module.Response

function Simple.__init__(self, docroot, dirlist)
	luci.httpd.module.Handler.__init__(self)
	self.docroot = docroot
	self.dirlist = dirlist and true or false
	self.mime    = luci.http.protocol.mime
	self.date    = luci.http.protocol.date
end

function Simple.getfile(self, uri)
	local file = self.docroot .. uri:gsub("%.%./", "")
	local stat = luci.fs.stat(file)

	return file, stat
end


function Simple._mk_etag(self, stat)
	return string.format( "%x-%x-%x", stat.ino, stat.size, stat.mtime )
end

function Simple._cmp_etag(self, stat, etag)
	return ( self:_mk_etag(stat) == etag )
end


function Simple.handle_get(self, request, sourcein, sinkerr)
	local file, stat = self:getfile(request.env.PATH_INFO)

	if stat then
		if stat.type == "regular" then
			return Response(
				200, {
					["Date"]           = self.date.to_http( os.time() );
					["Last-Modified"]  = self.date.to_http( stat.mtime );
					["Content-Type"]   = self.mime.to_mime( file );
					["Content-Length"] = stat.size;
					["ETag"]           = self:_mk_etag( stat );
				}
			), ltn12.source.file(io.open(file))
		else
			return self:failure(403, "Unable to transmit " .. stat.type .. " " .. file)
		end
	else
		return self:failure(404, "No such file: " .. file)
	end
end

function Simple.handle_head(self, ...)
	local response, sourceout = self:handle_get(...)
	return response
end
