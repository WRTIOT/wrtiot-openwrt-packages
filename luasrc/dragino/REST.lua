#! /usr/bin/env lua
--[[

    REST.lua - REST protocol to communicate with a RESTful server 

    Copyright (C) 2013 edwin chen <edwin@dragino.com>

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

module "dragino.REST"

local debug=true

local api_head = { xively = "X-ApiKey", yeelink = "U-ApiKey" }

--Get resource info 
--Success Code: 200
function get(url,API_KEY)
	local chunks = {}
	local servername

	if string.find(url,"yeelink") ~= nil then   -- different servers have slightly different in RESTful API interface. 
		servername = "yeelink"
	elseif string.find(url,"xively") ~= nil then 
		servername = "xively"
	end

	ret, code, head = http.request(
		{ ['url'] = url,
			method = 'GET',
			headers = {
				[api_head[servername]] = API_KEY,
			},
			sink = ltn12.sink.table(chunks)
		}
	)
	if debug then 
		if chunks and chunks[1] then
			print('DEBUG: REST:get(): chunks[1]='..chunks[1])
		end
		if ret then print('DEBUG: REST:Get():  ret='..ret) end
		print('DEBUG: REST:get(): code='..code)
		print('DEBUG: REST:get(): head='..json.encode(head))
	end

	if nil~=chunks then
		return json.decode(chunks[1]), code, head
	else
		return nil, code, head
	end

end

-- Put into the resource, this object and returns the created object, with appropriate Ids.
-- If some field is missing, then database will use the defaults.
-- Returns: newly object, return code, 
-- Success: code=200(Yeelink) , 201(cosm)
function create(url, object, API_KEY)
	local body = json.encode(object)
	local servername
	if string.find(url,"yeelink") ~= nil then   -- different servers have slightly different in RESTful API interface. 
		servername = "yeelink"
	elseif string.find(url,"xively") ~= nil then 
		servername = "xively"
		if string.find(url,"datastreams") ~= nil then       --- create datastreams in xively
			body = string.gsub(body, ":{",":[{",1):gsub("}}}","}}]}")
		end
	end
	if debug then print("DEBUG: REST.create(): body="..body) end
	local chunks = {}
	local ret, code, head = http.request(
		{ ['url'] = url,
			method = 'POST',
			headers = {
				[api_head[servername]] = API_KEY,
				['content-length'] = body:len(),
			}, 
			source = ltn12.source.string(body), -- ltn12.source.table(chunks)
			sink = ltn12.sink.table(chunks)
		}
	)
	if debug then 
		if chunks and chunks[1] then
			print('DEBUG: REST.create(): chunks[1]='..chunks[1])
		end
		print('DEBUG: REST.create(): code='..code)
		print('DEBUG: REST.create(): head='..json.encode(head))
		print('DEBUG: REST.create():  ret='..(ret or "nil"))
	end
	
	if servername == "xively" then
		local resp = {}
		resp.device_id = head.location and string.match(head.location,"feeds/([%d]+)")
		resp.sensor_id = head.location and string.match(head.location,"datastreams/([%w-_]+)")
		code = (code == 201) and 200 or code
		return resp,code,head
	elseif servername == "yeelink" then
		if nil==chunks then 
			return nil, code, head
		else
			return json.decode(chunks[1]), code, head -- ret is always 1?
		end
	end
end

function put(url, object, API_KEY)
	local body = json.encode(object)
	local servername
	if string.find(url,"yeelink") ~= nil then   -- different servers have slightly different in RESTful API interface. 
		servername = "yeelink"
	elseif string.find(url,"xively") ~= nil then 
		servername = "xively"
	end
	if debug then print("DEBUG: REST:put(): body="..body) end
	local chunks = {}
	local ret, code, head = http.request(
		{ ['url'] = url,
			method = 'PUT',
			headers = {  
				[api_head[servername]] = API_KEY,
				['content-length'] = body:len(),
			}, 
			source = ltn12.source.string(body), -- ltn12.source.table(chunks)
			sink = ltn12.sink.table(chunks)
		}
	)
	if debug then 
		if chunks and chunks[1] then
			print('DEBUG: REST:put(): chunks[1]='..chunks[1])
		end
		print('DEBUG: REST:put(): code='..code)
		print('DEBUG: REST:put(): head='..json.encode(head))
		print('DEBUG: REST:put():  ret='..ret)
	end
	if nil==chunks then 
		return nil, code, head
	else
		return object, code, head -- ret is always 1?
	end
end

-- Deletes a resource. 
-- On success, 200 is returned
function delete(url, API_KEY)
		local chunks = {}
		if string.find(url,"yeelink") ~= nil then   -- different servers have slightly different in RESTful API interface. 
			servername = "yeelink"
		elseif string.find(url,"xively") ~= nil then 
			servername = "xively"
		end
		ret, code, head = http.request(
			{ ['url'] = url,
				method = 'DELETE',
				headers = {
					[api_head[servername]] = API_KEY,
				},
				sink = ltn12.sink.table(chunks)
			}
		)
		if debug then 
			print('DEBUG: REST:delete(): code='..code)
			print('DEBUG: REST:delete(): head='..json.encode(head))
			print('DEBUG: REST:delete():  ret='..json.encode(ret))
		end
		return {}, code, head
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
