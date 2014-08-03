#! /usr/bin/env lua

--[[

    spid.lua - Lua Script to send command and get feedback to/from shield via SPI.   

    Copyright (C) 2011 edwin chen <edwin@dragino.com>

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
local nixio = require 'nixio'

module "dragino.spid"

local SPI_MAX_CLK_SPEED_HZ	= 1e6		
local SPI_MIN_BYTE_DELAY_US	= 250
local SPI_TX_RX_DELAY_NS	= 2e7
local SPI_CT_DELAY_NS	= 5e8
local SPI_MAX_READ_BYTES = 1024
local END_OF_MESSAGE = '.'


local SPI_DEV			= '/dev/spidev0.0'

local O_RDWR_NONBLOCK		= nixio.open_flags('rdwr', 'nonblock')

local spidev = nixio.open(SPI_DEV, O_RDWR_NONBLOCK)
nixio.spi.setspeed(spidev, SPI_MAX_CLK_SPEED_HZ, SPI_MIN_BYTE_DELAY_US)     --Initial Dragino SPI interface. 
spidev:lock('lock') -- blocks until it can place a write lock on the spidev device


function CommandToMCU(message)
	message = message .. END_OF_MESSAGE
	local count =10
	spidev:write(message)                          	-- Write Message to the SPI interface	
	
	incoming_msg = spidev:read(SPI_MAX_READ_BYTES)   -- Read Message from SPI interface                   		
	while incoming_msg == '' and count > 0 do
		incoming_msg = spidev:read(SPI_MAX_READ_BYTES)
		count = count -1
	end
	return incoming_msg
end

