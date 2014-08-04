#! /usr/bin/env lua

--[[

    IoT.lua - Lua Script to get message from UART port 
	and PUT the data to a RESTful Server
	user can also record data in a local file or handle the data via
	custom commands. 

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

local actREST = require ("wrtiot.actREST")
local uci = require("luci.model.uci")
local Json = require("luci.json")
local host, port = "tcp.lewei50.com", 9960
local socket = require("socket")

uci = uci.cursor()

local IOT = uci:get_all("wrtiot","IOT")

local API_KEY = IOT.API_KEY

function process_data_REST(d)		-- Process the data use RESTful protocol
        data = {}
        data['dev'] = string.match(d,"(.+):")
        data['dat'] = string.match(d,":  (.+)")

	actREST.UpdateSensors(data)
end

serialin=io.open("/dev/ttyUSB0","rb")   --open serial port and prepare to read data from dongle

while true do
	--read command from lewei,keep alive through tcp
	if commandserver == nil then
		commandserver = socket.tcp()
		commandserver:settimeout(3)
		commandserver:connect(host, port)

		os.execute("logger TCP Connect")
		msg = {
			["method"] = "update",
			["gatewayNo"] = "01",
			["userkey"] = API_KEY
		}

		msg = Json.encode(msg)
		msg = msg .. "&^!"

		commandserver:send(msg)
	end

	lasttime = os.time()
	local s, status, partial = commandserver:receive('*a')
	if partial ~= "" then
		os.execute("logger recv command is: " .. string.match(partial, "(.+)&^!"))
		command = Json.decode(string.match(partial,"(.+)&^!"))
		os.execute("logger command fun is: " .. command['f'])
		resp = {
			["method"] = "response",
			["result"] = {["successful"] = true, ["message"] = "WRTIOT Resp!"}
		}
		resp = Json.encode(resp)
		resp = resp .. "&^!"
		commandserver:send(resp)
		os.execute("logger send resp is: " .. resp)
		partial = nil
	end

	if status == "closed" then
		commandserver:close()
		commandserver = nil
		os.execute("logger TCP Closed")
	end
	if os.time() - lasttime > 30 then
		lasttime = os.time()
		commandserver:send(msg)
		os.execute("logger send msg is: " .. msg)
	end

	--read data from dongle
	serialin:flush()
	raw_data = serialin:read()
	if raw_data ~= nill then
	os.execute("logger raw data is: " .. raw_data)
	process_data_REST(raw_data)
	raw_data = nill
	end

end
serialin:close()

