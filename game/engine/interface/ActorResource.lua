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

--- Handles actors life and death
module(..., package.seeall, class.make)

_M.resources_def = {}

--- Defines resource
-- Static!
-- All actors will now have :getResourcename() and :incResourcename() methods as well as a .max_resourcename and .resourcename
-- properties. It is advised to NOT access .resourcename directly and use the get/inc methods. They handle talent
-- dependencies
function _M:defineResource(name, short_name, talent, regen_prop, desc)
	assert(name, "no resource name")
	assert(short_name, "no resource short_name")
	table.insert(self.resources_def, {
		name = name,
		short_name = short_name,
		talent = talent,
		regen_prop = regen_prop,
		description = desc,
		maxname = "max_"..short_name,
	})
	self.resources_def[#self.resources_def].id = #self.resources_def
	self.resources_def[short_name] = self.resources_def[#self.resources_def]
	self["RS_"..short_name:upper()] = #self.resources_def
	local maxname = "max_"..short_name
	self["inc"..short_name:lower():capitalize()] = function(self, v)
		self[short_name] = util.bound(self[short_name] + v, 0, self[maxname])
	end
	self["incMax"..short_name:lower():capitalize()] = function(self, v)
		self[maxname] = self[maxname] + v
	end
	if talent then
		-- if there is an associated talent, check for it
		self["get"..short_name:lower():capitalize()] = function(self)
			if self:knowTalent(talent) then
				return self[short_name]
			else
				return 0
			end
		end
		-- if there is an associated talent, check for it
		self["getMax"..short_name:lower():capitalize()] = function(self)
			if self:knowTalent(talent) then
				return self[maxname]
			else
				return 0
			end
		end
	else
		self["get"..short_name:lower():capitalize()] = function(self)
			return self[short_name]
		end
		self["getMax"..short_name:lower():capitalize()] = function(self)
			return self[maxname]
		end
	end
end

function _M:init(t)
	for i, r in ipairs(_M.resources_def) do
		self["max_"..r.short_name] = t["max_"..r.short_name] or 100
		self[r.short_name] = t[r.short_name] or self["max_"..r.short_name]
		if r.regen_prop then
			self[r.regen_prop] = t[r.regen_prop] or 0
		end
	end
end

--- Regen resources, shout be called in your actor's act() method
function _M:regenResources()
	for i, r in ipairs(_M.resources_def) do
		if r.regen_prop then
			self[r.short_name] = util.bound(self[r.short_name] + self[r.regen_prop], 0, self[r.maxname])
		end
	end
end
