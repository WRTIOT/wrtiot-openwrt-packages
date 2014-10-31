#! /usr/bin/env lua
--[[

    REST.lua - REST protocol to communicate with a RESTful server 

    Copyright (C) 2013 edwin chen <edwin@dragino.com>
    Copyright (C) 2014 Mikeqin <Fengling.Qin@gmail.com>

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.

]]--
 
local json = require 'luci.json'
local http = require 'socket.http'
local ltn12 = require 'ltn12'
local type, assert, pairs, string, print, io = type, assert, pairs, string, print, io

module "wrtiot.REST"

local debug=true

-- Post object to REST Server
-- Returns: newly object, return code, 
-- Success: code=200
function post(url, object, API_KEY)
	local body = json.encode(object)
	body = '[' .. body .. ']'
	if debug then print("DEBUG: REST.post(): body="..body) end
	local chunks = {}
	local ret, code, head = http.request(
		{ ['url'] = url,
			method = 'POST',
			headers = {
				['userkey'] = API_KEY,
				['content-length'] = body:len(),
			}, 
			source = ltn12.source.string(body), -- ltn12.source.table(chunks)
			sink = ltn12.sink.table(chunks)
		}
	)
	if debug then 
		if chunks and chunks[1] then
			print('DEBUG: REST.post(): chunks[1]='..chunks[1])
		end
		print('DEBUG: REST.post(): code='..code)
		print('DEBUG: REST.post(): head='..json.encode(head))
		print('DEBUG: REST.post():  ret='..(ret or "nil"))
	end
	
	if nil==chunks then 
		return nil, code, head
	else
		return json.decode(chunks[1]), code, head -- ret is always 1?
	end
end

--dump a lua table
function tabledump(t,indent)
	-- if nil==t then return end
	assert(type(t)=='table', "Wrong input type. Expected table, got "..type(t))
	local indent = indent or 0
	for k,v in pairs(t) do
		if type(v)=="table" then
			print(string.rep(" ",indent)..k.."=>")
			tabledump(v, indent+4)
		else
			print(string.rep(" ",indent) .. k  .. "=>", v)
		end
	end
end
