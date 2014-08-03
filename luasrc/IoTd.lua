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

function process_data_REST(d)		-- Process the data use RESTful protocol
        data = {}
        data['dev'] = string.match(d,"(.+):")
        data['dat'] = string.match(d,":  (.+)")

	actREST.UpdateSensors(data)
end

serialin=io.open("/dev/ttyUSB0","rb")   --open serial port and prepare to read data from dongle

while true do
	while raw_data == nill do 
		serialin:flush()
		raw_data = serialin:read()
	end
	os.execute("logger raw data is: " .. raw_data)
	process_data_REST(raw_data)
	raw_data = nill
end
serialin:close()

