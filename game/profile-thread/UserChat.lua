-- TE4 - T-Engine 4
-- Copyright (C) 2009, 2010 Nicolas Casalini
--
-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with this program.  If not, see <http://www.gnu.org/licenses/>.
--
-- Nicolas Casalini "DarkGod"
-- darkgod@te4.org

require "engine.class"
local socket = require "socket"

module(..., package.seeall, class.make)

function _M:init(client)
	self.client = client
	self.channels = {}
	self.cjoined = {}
end

function _M:event(e)
	if e.e == "ChatTalk" then
		cprofile.pushEvent(string.format("e='Chat' se='Talk' channel=%q login=%q name=%q msg=%q", e.channel, e.login, e.name, e.msg))
		print("[USERCHAT] channel talk", e.login, e.channel, e.msg)
	elseif e.e == "ChatJoin" then
		self.channels[e.channel] = self.channels[e.channel] or {}
		self.channels[e.channel][e.login] = true
		cprofile.pushEvent(string.format("e='Chat' se='Join' channel=%q login=%q name=%q ", e.channel, e.login, e.name))
		print("[USERCHAT] channel join", e.login, e.channel)
	elseif e.e == "ChatPart" then
		self.channels[e.channel] = self.channels[e.channel] or {}
		self.channels[e.channel][e.login] = nil
		cprofile.pushEvent(string.format("e='Chat' se='Part' channel=%q login=%q name=%q ", e.channel, e.login, e.name))
		print("[USERCHAT] channel part", e.login, e.channel)
	end
end

function _M:joined(channel)
	self.cjoined[channel] = true
	print("[ONLINE PROFILE] connected to channel", channel)
end

function _M:parted(channel)
	self.cjoined[channel] = nil
	print("[ONLINE PROFILE] parted from channel", channel)
end

function _M:reconnect()
	-- Rejoin every channels
	print("[ONLINE PROFILE] reconnecting to channels")
	for chan, _ in pairs(self.cjoined) do
		print("[ONLINE PROFILE] reconnecting to channel", chan)
		self.client:orderChatJoin{channel=chan}
	end
end
