#! /usr/bin/env lua

--[[

    actREST.lua - Lua Script to implement action to a RESTful server 

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

local REST = require ("dragino.REST")
local uci = require("luci.model.uci")
local sys = require("luci.sys")

local print,tonumber,os,io,assert,string,pairs,ipairs = print,tonumber,os,io,assert,string,pairs,ipairs

module "dragino.actREST"

uci = uci.cursor()

local IOT = uci:get_all("sensor","IoT")

local SERVERNAME = IOT.IoTServer
local server_info =  uci:get_all("IoTServer", SERVERNAME)
local API_KEY = IOT.API_KEY
local DEBUG = uci:get("sensor","main", "debug")
local TITLE = IOT.title or sys.hostname()
local DIR = IOT.directory
local SENSOR_TABLE = DIR .. "/sensor_table"
local ACTUATOR_TABLE = DIR .. "/actuator_table"
local SENSOR_TABLE_INDEX =  {"SENSORID","NAME","VALUETYPE","UNITNAME","UNITSYMBOL","INTERFACE"}
local ACTUATOR_TABLE_INDEX =  {"ACTUATORID","NAME","INTERFACE"}

local INDICATE_PIN = '4'        -- use gpio4 as indication

function cloud_init()  -- initia Dragrove
end

function create_node(dev,sen,act)
	--check if this node already exist in dragino,
	local d = uci:get_all("sensor",dev)
	local seninfo = get_sensor_info(sen)
	sen = tonumber(sen)
	act = tonumber(act)
	local hassensor = ((sen ~= 0) or nil)     --sensorid == 0 means no sensor connected 
	local hasactuator = ((act ~= 0) or nil)   --actuator == 0 means no actuator connected
	local st = { 				-- local device section table
		sensor_id = sen, 
		actuator_id = act, 
		sensorname = hassensor and seninfo.NAME,
		actuatorname = hasactuator and get_actuator_info(act).NAME,
		valuetype =  hassensor and seninfo.VALUETYPE
			}
	local yd = { title = TITLE .. "_" .. dev}        -- REST Server device table
	local ys
	if SERVERNAME == "yeelink" then     -- Different Server have different data format. 
		ys = { type = value, title = st.sensorname, unit = {name = hassensor and seninfo.UNITNAME, symbol = hassensor and seninfo.UNITSYMBOL}}    -- REST Server sensor table
	elseif SERVERNAME == "xively" then
		local s = st.sensorname and string.gsub(st.sensorname,"%s+","") -- trim all whitespace from sensor name
		ys = {datastreams = { id = s ,unit = {symbol = hassensor and seninfo.UNITSYMBOL , label = hassensor and seninfo.UNITNAME }}}
	end
	if nil == d then    -- if not , create it
		-- create this node in REST Server
		local r, code = REST.create(server_info["API_link"]..server_info["devices"], yd, API_KEY)
		
		print (code)
		if code == 200 then
			st.server_device_id = r.device_id
		end 
		-- create the sensor in REST Server
		if sen ~= 0 and st.sensorname ~= nil then --we only create this sensor on server when sensor ID is define in SENSOR_TABLE
			local r, code = REST.create(server_info["API_link"]..server_info["device"]..r.device_id .. "/"..server_info["sensors"], ys, API_KEY)
			if code == 200 then
				st.server_sensor_id = r.sensor_id
			end
		end 
		if code == 200 then
			uci:section("sensor", "node", dev, st)
			uci:commit("sensor")
			os.execute("logger Add Device:" .. dev .. ", Sensor: " .. sen .. ", Actuator: " .. act )
			return code
		end
			os.execute("logger Fail to add device. Return Code " .. code) 
	else  -- device already exist
		if sen ~= tonumber(d.sensor_id) then     -- same device ID, different sensor ID, delete the old one, add new one 
			uci:delete("sensor",dev)
			uci:commit("sensor")
			create_node(dev,sen,act)
		else			 -- same device ID, same sensor ID exist, check if it was created in IoT server, if not create it. 
			if act ~= tonumber(d.actuator_id) then
				uci:set("sensor",dev,"actuator_id",act)
				uci:commit("sensor")
				os.execute("logger Update device to new actuator id: " .. act)	
			end
			if sen ~= 0 and st.sensorname ~= nil then  --we only create this sensor on server when sensor ID is define in SENSOR_TABLE
				local r, code = REST.get( server_info["API_link"]..server_info["device"].. d.server_device_id .. "/" .. server_info["sensor"] .. d.server_sensor_id, API_KEY)
				if code == 200 then  -- this device and sensor already exist in server, do nothing
					os.execute("logger Device " .. dev .. ", and Sensor " .. sen .. " already exist")
					return code
				elseif code == 403 then 	-- the device are in the server, but no such sensor, create the sensor 
					local r, code = REST.create(server_info["API_link"]..server_info["device"]..d.server_device_id .. "/"..server_info["sensors"], ys, API_KEY)
					if code == 200 then 
						uci:set("sensor",dev,"server_sensor_id",r.sensor_id)
						uci:commit("sensor")
						os.execute("logger Add Device:" .. dev .. ", Sensor: " .. sen .. ", Actuator: " .. act )
						return code
					end 
				elseif code == 406 then 	-- neither device or sensor exist in the server. re-create both. 
					uci:delete("sensor",dev)
					uci:commit("sensor")
					create_node(dev,sen,act)
				end 
			end
		end
	end		
end

function delete_node(dev)
	--check if this node already exist in dragino,
	local d = uci:get_all("sensor",dev)
	if nil == d then    -- if not , no need to delete
		os.execute("logger Can not find " .. dev .. " in local configuration file")
		return 200
	else		   -- exist , delete it from REST Server and then from dragino. 
		local r, code = REST.delete(server_info["API_link"]..server_info["device"] .. d.server_device_id, API_KEY)
		if code == 200 then
			os.execute("logger DELETE: Device " .. dev .. " is removed from IoT Server: " .. server_info["URL"] .. "." )
			uci:delete("sensor",dev)
			uci:commit("sensor")
			os.execute("logger DELETE: Remove " .. dev .. " from local configuration file")
		elseif code == 403 then
			os.execute("logger DELETE: Device " .. dev .. " is not exist in IoT Server: " .. server_info["URL"] .. "." )
			uci:delete("sensor",dev)
			uci:commit("sensor")
			os.execute("logger DELETE: Remove " .. dev .. " from local configuration file")
		elseif code == 401 then
			os.execute("logger DELETE:  IoT Server: " .. server_info["URL"] .. " return 401:Unauthorized" )
		end
		--os.execute("logger Remove sensor device: " .. dev )
		return code
	end

end 

function create_datapoint(d)
	 
	local dev
	local dta = {}   --store the value
	for k,v in ipairs (d) do		
		if k == 1 then 
			dev = d[k]
		else 
			dta[k-1] = d[k]	
		end
	end 	
	--check if this node already exist in dragino,
	local device = uci:get_all("sensor",dev)
	if nil == device then    -- if not , fail to post data
		os.execute("logger POST datapoint fail, device doesn't exist in Dragino, create first")
		return 0
	end 

	if device.sensorname == nil  then
		os.execute("logger POST datapoint fail, sensor doesn't exist in Dragino, create first")
		return 0
	end
	
	-- get ValueType and construct data according to different type
	local valuetype = device.valuetype
	local data = {}
	if valuetype == '1' then   -- a general value type 
		data[server_info["value"]] = dta[1]
	elseif valuetype == '2' then  -- a GPS type value
		--create GPS json
	elseif valuetype == '3' then -- image value
		-- Create Image Binary
	else 
		os.execute("logger POST datapoint fail. Value type " .. valuetype .. "undefined.")
	end
	

       -- node exist, POST it to REST Server
	local r, code = REST.create(server_info["API_link"]..server_info["device"].. device.server_device_id .. "/" .. server_info["sensor"] .. device.server_sensor_id .. "/" ..server_info["datapoints"], data, API_KEY)
	if DEBUG == "1" then 
		os.execute("logger POST data to Server, server return ".. code)
	end
	return code
end

--return sensor info table, table index refer SENSOR_TABLE_INDEX define
function get_sensor_info(senid)
	local f = assert(io.open(SENSOR_TABLE,r))
	local stable = {}    -- table to store the sensor info
	local line
	for line in f:lines() do 
		local l = string.match(line,senid .. ",",1)
		if l ~= nil then 
			local index = 1
			for k in string.gmatch(line, "([%w\-_%s]+),-") do
				stable[SENSOR_TABLE_INDEX[index]] = k:gsub("^%s*(.-)%s*$", "%1")    --trim leading and trailing white space
				index = index + 1	
     			end
			return stable		
		end
	end
	return stable
end

--return actuator info table, table index refer ACTUATOR_TABLE_INDEX define
function get_actuator_info(actid)
	local f = assert(io.open(ACTUATOR_TABLE,r))
	local atable = {}    -- table to store the sensor info
	local line
	for line in f:lines() do 
		local l = string.match(line,actid .. ",",1)
		if l ~= nil then 
			local index = 1
			for k in string.gmatch(line, "([%w\-_%s]+),-") do        --seperate the string in different parts
				atable[ACTUATOR_TABLE_INDEX[index]] = k:gsub("^%s*(.-)%s*$", "%1")    --trim white space
				index = index + 1	
     			end
			return atable		
		end
	end
	return atable
end

function set_indicate_pin()
	os.execute("gpioctl dirout " .. INDICATE_PIN)
	os.execute("gpioctl set " .. INDICATE_PIN)	
end

function clear_indicate_pin()
	os.execute("gpioctl dirout " .. INDICATE_PIN)
	os.execute("gpioctl clear " .. INDICATE_PIN)	
end
