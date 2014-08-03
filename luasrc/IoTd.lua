#! /usr/bin/env lua

--[[

    IoT.lua - Lua Script to get message from UART port 
	and PUT the data to a RESTful Server
	user can also record data in a local file or handle the data via
	custom commands. 

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

local actREST = require ("dragino.actREST")
local uci = require("luci.model.uci")
uci = uci.cursor()

local sensor = uci:get_all("sensor")

local START = 'ss'		-- Leading string for incoming data	
local END = 'gg'		-- Trailing string for incoming data
local DATATYPEADD = '1'       --ADD a device
local DATATYPEDEL = '2'	   -- DELETE a device
local DATATYPEPOST = '3'	    -- POST datapoint

local DEBUG = sensor.main.debug
local ENABLE_IOT = sensor.IoT.EnableIoT
local ENABLE_RECORD = sensor.main.record
local LOCAL_RECORD_FILE = sensor.main.record_file
local RECORD_FILE_SIZE = tonumber(sensor.main.record_file_size)

function decode(d)            -- decode the raw_date to 2 field: type and content
	d = string.match(d,START.."(.+)" ..END)
	if nil == d then
		return nil
	end
	-- TODO: 1. Validate check 
	--	2. crccheck	
	return string.match(d,"(.+) "),string.match(d," (.+)")
end


function process_data_REST(d)		-- Process the data use RESTful protocol
	local datatype, dd = decode(d)
	if nil == dd then 			-- stop if the FRAME doesn't match
		return                     
	end
	data = {}
	local index = 1
	for k in string.gmatch(dd, "([%w\.]+)%p-") do        -- store the content in a table.
		data[index] = k
		index = index + 1
     	end

	if datatype == DATATYPEPOST then			 --Create Datapoint on IoT server
		local tmp  = (DEBUG == "1") and os.execute("logger DATATYPE is create new datapoint")
		actREST.create_datapoint(data)
	elseif datatype == DATATYPEDEL then		-- Delete the device from IoT server
		local tmp =(DEBUG == "1") and os.execute("logger DATATYPE is delete device")
		actREST.delete_node(data[1])
	elseif datatype == DATATYPEADD then 		-- ADD device to IoT server
		local tmp =(DEBUG == "1") and os.execute("logger DATATYPE is add device")
		actREST.create_node(data[1],data[2],data[3])
	else 
		os.execute("logger -s DATATYPE is error")
	end
end

function fsize (file)		     -- function to get file size
	local current = file:seek()     -- get current position
    	local size = file:seek("end")   -- get file size
    	file:seek("set", current)       -- restore position
    	return size
end

function process_data_custom(dta)		--process data via custom command
	local cc = sensor.main.custom_code
	if cc == nil then 
		os.execute("logger custom code is nil")
		return 
	end
	cc = string.gsub(cc,'%[RAW_DATA%]',dta)
	os.execute(cc)
end

function process_data_record_local(d)				--record in a local file. 
	local f = io.open(LOCAL_RECORD_FILE, "r")
	if f then
		if fsize(f) >= RECORD_FILE_SIZE then	--make sure the file is not too big
			f:close()
			os.execute("mv "..LOCAL_RECORD_FILE.." "..LOCAL_RECORD_FILE..".bak")	
		else
			f:close()
		end
	end
	os.execute("echo '"..d .. "' >> " .. LOCAL_RECORD_FILE)	
end

actREST.set_indicate_pin()    -- we send a high level to GPIO4 to say we are ready to accept data
serialin=io.open("/dev/ttyS0","rb")   --open serial port and prepare to read data from Arduino
local ServerName
local ServerDefine

if ENABLE_IOT == "1" then
	ServerName = sensor.IoT.IoTServer
	ServerDefine = uci:get_all("IoTServer",ServerName)
end

while true do
	while raw_data == nill do 
		serialin:flush()
		raw_data = serialin:read()
	end
	local tmp =(DEBUG == "1") and os.execute("logger raw data is: " .. raw_data)
	if ENABLE_IOT == "1" then
		if ServerDefine.servertype == "REST" then
				process_data_REST(raw_data)
		end
	end
	if sensor.main.enable_custom_code == "1" then
		process_data_custom(raw_data)
	end 		
	if ENABLE_RECORD == "1" then
		process_data_record_local(raw_data)
	end
	raw_data=nil	
end
serialin:close()

