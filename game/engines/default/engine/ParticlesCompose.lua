-- TE4 - T-Engine 4
-- Copyright (C) 2009 - 2017 Nicolas Casalini
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
local PC = core.particlescompose

--- Handles a particles compose system
-- Used by engine.Map
-- @classmod engine.ParticlesCompose
module(..., package.seeall, class.make)

local __particles_gl = {}
setmetatable(__particles_gl, {__mode="v"})

--- Make a particle emitter
function _M:init(def, radius, args, shader)
	self.args = args or {}
	self.def = def
	self.radius = radius or 1
	self.shader = shader

	self:loaded()
end

--- Serialization
function _M:save()
	return class.save(self, {
		ps = true,
		_do = true,
		gl_texture = true,
		_shader = true,
	})
end

function _M:cloned()
	self:loaded()
end

function _M:loaded()
	local ok, f = pcall(loadfile, item.path)
	if not ok then print("Error loading particle file", f) return end
	setfenv(f, {math=math, colors_alphaf=colors_alphaf, PC=PC})
	local ok, data = pcall(f)
	if not ok then print("Error loading particle file", data) return end

	self.ps = PC.new(data)

end

--- Gets a DisplayObject representing this particle
-- Beware, do not keep a reference to the Particles afterwards unless needed; just keep one to the DO which will itself reference the Particles
function _M:getDO()
	if not self.ps then return end
	return self.ps:getDO(self)
end

function _M:setSub(def, radius, args, shader)
end

function _M:updateZoom()
end

function _M:checkDisplay()
	if self.ps then return end
	self:loaded()
end

function _M:onDie(fct)
	self.on_die = fct
end

function _M:dieDisplay(no_callback)
	if not self.ps then return end
	if not no_callback and self.on_die then self:on_die() end
	-- DGDGDGDG
	-- self.ps:die()
	self.ps = nil
end

function _M:shift(map, mo)
	local adx, ady = mo:getWorldPos()
	if self._adx then
		self.ps:shift(self._adx - adx, self._ady - ady)
	end					
	self._adx, self._ady = adx, ady
end

function _M:shiftCustom(dx, dy)
	self.ps:shift(dx, dy)
end