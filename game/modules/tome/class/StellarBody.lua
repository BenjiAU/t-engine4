-- ToME - Tales of Maj'Eyal
-- Copyright (C) 2009 - 2019 Nicolas Casalini
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
require "mod.class.Grid"
local Map = require "engine.Map"
local Shader = require "engine.Shader"

module(..., package.seeall, class.inherit(mod.class.Grid))

-- STATIC
function makeAtmosphere(size, light_angle, r, g, b, a)
	local size2 = size / 2
	size2 = size2 * 128 / 112
	local tex = core.loader.png("/data/gfx/shockbolt/stars/atmosphere.png")
	return core.renderer.vertexes():quad(
		-size2, -size2,   0, 0,
		 size2, -size2,   1, 0,
		 size2,  size2,   1, 1,
		-size2,  size2,   0, 1,
		r, g, b, a
	):texture(tex):rotate(math.pi, 0, light_angle)
end

-- STATIC
function makePlanet(planettex, cloudtex, atmosphere, size, args)
	args = args or {}

	local planet = core.renderer.container()

	-- Build the planet itself
	local planetshader = Shader.new("planet", args)
	local vectortex = core.loader.png("/data/gfx/shockbolt/stars/template.png")
	local size2 = size / 2
	planet:add(core.renderer.vertexes():quad(
		-size2, -size2,   0, 0,
		 size2, -size2,   1, 0,
		 size2,  size2,   1, 1,
		-size2,  size2,   0, 1,
		1, 1, 1, 1
	):texture(vectortex, 0):texture(planettex, 1):texture(cloudtex, 2):shader(planetshader))

	-- Add an atmosphere
	if atmosphere then
		planet:add(makeAtmosphere(size, args.light_angle or math.rad(180), unpack(atmosphere)))
	end

	return planet
end

function _M:init(t, no_default)
	t.sphere_map = t.sphere_map or "stars/eyal.png"
	t.sphere_size = t.sphere_size or 1
	t.x_rot = t.x_rot or 0
	t.y_rot = t.y_rot or 0

	mod.class.Grid.init(self, t, no_default)

	self.sphere_size = self.sphere_size * Map.tile_w
end

function _M:defineDisplayCallback()
	if not self._mo then return end

	local planettex = core.loader.png("/data/gfx/shockbolt/"..self.sphere_map)
	local cloudtex = core.loader.png("/data/gfx/shockbolt/stars/clouds.png")
	local planet = self.makePlanet(planettex, cloudtex, {160/255, 160/255, 200/255, 0.5}, self.sphere_size, {planet_time_scale=100000, clouds_time_scale=70000, rotate_angle=math.rad(22), light_angle=math.pi})
	local planet_renderer = core.renderer.renderer("static"):add(planet)

	self._mo:displayCallback(function(x, y, w, h, zoom, on_map, tlx, tly)
		if not game.level then return end
		print("---------", x, y)
		planet_renderer:toScreen(0, 0)

		-- local rot = (game.level.data.frames % self.rot_speed) * 360 / self.rot_speed

		-- core.display.glDepthTest(true)
		-- core.display.glMatrix(true)
		-- core.display.glTranslate(x + w / 2, y + h / 2, 0)
		-- core.display.glRotate(self.x_rot, 0, 1, 0)
		-- core.display.glRotate(self.y_rot, 1, 0, 0)
		-- core.display.glRotate(rot, 0, 0, 1)
		-- core.display.glColor(1, 1, 1, 1)

		-- tex:bind(0)
		-- self.world_sphere.q:sphere(self.sphere_size)

		-- core.display.glMatrix(false)
		-- core.display.glDepthTest(false)

		return true
	end)
end
