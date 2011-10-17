-- TE4 - T-Engine 4
-- Copyright (C) 2009, 2010, 2011 Nicolas Casalini
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
local Map = require "engine.Map"
local Target = require "engine.Target"
local DamageType = require "engine.DamageType"

--- Handles actors projecting damage to zones/targets
module(..., package.seeall, class.make)

_M.projectile_class = "engine.Projectile"

function _M:init(t)
end

--- Project damage to a distance
-- @param t a type table describing the attack, passed to engine.Target:getType() for interpretation
-- @param x target coords
-- @param y target coords
-- @param damtype a damage type ID from the DamageType class
-- @param dam damage to be done
-- @param particles particles effect configuration, or nil
function _M:project(t, x, y, damtype, dam, particles)
	if type(particles) ~= "table" then particles = nil end

	local mods = {}
	if game.level.map:checkAllEntities(x, y, "on_project_acquire", self, t, x, y, damtype, dam, particles, false, mods) then
		if mods.x then x = mods.x end
		if mods.y then y = mods.y end
	end

--	if type(dam) == "number" and dam < 0 then return end
	local typ = Target:getType(t)
	typ.source_actor = self

	local grids = {}
	local function addGrid(x, y)
		if not grids[x] then grids[x] = {} end
		grids[x][y] = true
	end

	local srcx, srcy = t.x or self.x, t.y or self.y

	-- Stop at range or on block
	local lx, ly, is_corner_blocked = x, y
	local stop_x, stop_y = srcx, srcy
	local stop_radius_x, stop_radius_y = srcx, srcy
	local l
	if typ.source_actor.lineFOV then
		l = typ.source_actor:lineFOV(x, y, nil, nil, srcx, srcy)
	else
		l = core.fov.line(srcx, srcy, x, y)
	end
	local block_corner = function(_, bx, by)
		if typ.block_path then
			local b, h, hr = typ:block_path(bx, by, true)
			return b and h and not hr
		else
			return false
		end
	end

	local lx, ly, is_corner_blocked = l:step(block_corner)
	while lx and ly do
		local block, hit, hit_radius = false, true, true
		if typ.block_path then
			block, hit, hit_radius = typ:block_path(lx, ly)
		end
		if is_corner_blocked then
			block = true
			hit_radius = false
		end
		if hit then
			if is_corner_blocked then
				stop_x, stop_y = stop_radius_x, stop_radius_y
			else
				stop_x, stop_y = lx, ly
			end
			-- Deal damage: beam
			if typ.line then addGrid(lx, ly) end
			-- WHAT DOES THIS DO AGAIN?
			-- Call the on project of the target grid if possible
			if not t.bypass and game.level.map:checkAllEntities(lx, ly, "on_project", self, t, lx, ly, damtype, dam, particles) then
				return
			end
		end
		if hit_radius then
			stop_radius_x, stop_radius_y = lx, ly
		end

		if block then break end
		lx, ly, is_corner_blocked = l:step(block_corner)
	end

	if typ.ball and typ.ball > 0 then
		core.fov.calc_circle(
			stop_radius_x,
			stop_radius_y,
			game.level.map.w,
			game.level.map.h,
			typ.ball,
			function(_, px, py)
				if typ.block_radius and typ:block_radius(px, py) then return true end
			end,
			function(_, px, py)
				-- Deal damage: ball
				addGrid(px, py)
			end,
		nil)
		addGrid(stop_x, stop_y)
	elseif typ.cone and typ.cone > 0 then
		--local dir_angle = math.deg(math.atan2(y - self.y, x - self.x))
		core.fov.calc_beam_any_angle(
			stop_radius_x,
			stop_radius_y,
			game.level.map.w,
			game.level.map.h,
			typ.cone,
			x - self.x,
			y - self.y,
			typ.cone_angle,
			function(_, px, py)
				if typ.block_radius and typ:block_radius(px, py) then return true end
			end,
			function(_, px, py)
				addGrid(px, py)
			end,
		nil)
		addGrid(stop_x, stop_y)
	else
		-- Deal damage: single
		addGrid(stop_x, stop_y)
	end

	-- Check for minimum range
	if typ.min_range and core.fov.distance(self.x, self.y, stop_x, stop_y) < typ.min_range then
		return
	end

	self:check("on_project_grids", grids)

	-- Now project on each grid, one type
	local tmp = {}
	local stop = false
	DamageType:projectingFor(self, {project_type=typ})
	for px, ys in pairs(grids) do
		for py, _ in pairs(ys) do
			-- Call the projected method of the target grid if possible
			if not game.level.map:checkAllEntities(px, py, "projected", self, t, px, py, damtype, dam, particles) then
				-- Check self- and friendly-fire, and if the projection "misses"
				local act = game.level.map(px, py, engine.Map.ACTOR)
				if act and act == self and not ((type(typ.selffire) == "number" and rng.percent(typ.selffire)) or (type(typ.selffire) ~= "number" and typ.selffire)) then
				elseif act and self.reactionToward and (self:reactionToward(act) >= 0) and not ((type(typ.friendlyfire) == "number" and rng.percent(typ.friendlyfire)) or (type(typ.friendlyfire) ~= "number" and typ.friendlyfire)) then
				-- Otherwise hit
				else
					if type(damtype) == "function" then if damtype(px, py, tg, self) then stop=true break end
					else DamageType:get(damtype).projector(self, px, py, damtype, dam, tmp, nil) end
					if particles then
						game.level.map:particleEmitter(px, py, 1, particles.type, particles.args)
					end
				end
			end
		end
		if stop then break end
	end
	DamageType:projectingFor(self, nil)
	return grids
end

--- Can we project to this grid ?
-- This function can be used for either just the boolean, or to tell you where the projection stops.
-- Two sets of coordinates will be returned, one for where the projection stops (stop_x, stop_y) and
-- one for where any radius effect should start from (radius_x, radius_y).  The distinction is made
-- because a projection should hit the wall, but explosions should start one tile back to avoid
-- "leaking" through a one tile thick wall.
-- @param t a type table describing the attack, passed to engine.Target:getType() for interpretation
-- @param x target coords
-- @param y target coords
-- @return can_project, stop_x, stop_y, radius_x, radius_y.
function _M:canProject(t, x, y)
	local typ = Target:getType(t)
	typ.source_actor = self
	typ.start_x = self.x
	typ.start_y = self.y

	-- Stop at range or on block
	local lx, ly, is_corner_blocked = x, y
	local stop_x, stop_y = self.x, self.y
	local stop_radius_x, stop_radius_y = self.x, self.y
	local l
	if typ.source_actor.lineFOV then
		l = typ.source_actor:lineFOV(x, y)
	else
		l = core.fov.line(self.x, self.y, x, y)
	end
	local block_corner = function(_, bx, by)
		if typ.block_path then
			local b, h, hr = typ:block_path(bx, by, true)
			return b and h and not hr
		else
			return false
		end
	end

	local lx, ly, is_corner_blocked = l:step(block_corner)
	while lx and ly do
		local block, hit, hit_radius = false, true, true
		if typ.block_path then
			block, hit, hit_radius = typ:block_path(lx, ly)
		end
		if is_corner_blocked then
			block = true
			hit_radius = false
		end
		if hit then
			if is_corner_blocked then
				stop_x, stop_y = stop_radius_x, stop_radius_y
			else
				stop_x, stop_y = lx, ly
			end
		end
		if hit_radius then
			stop_radius_x, stop_radius_y = lx, ly
		end

		if block then break end
		lx, ly, is_corner_blocked = l:step(block_corner)
	end

	-- Check for minimum range
	if typ.min_range and core.fov.distance(self.x, self.y, stop_x, stop_y) < typ.min_range then
		return
	end

	if stop_x == x and stop_y == y then return true, stop_x, stop_y, stop_x, stop_y end
	return false, stop_x, stop_y, stop_radius_x, stop_radius_y
end

--- Project damage to a distance using a moving projectile
-- @param t a type table describing the attack, passed to engine.Target:getType() for interpretation
-- @param x target coords
-- @param y target coords
-- @param damtype a damage type ID from the DamageType class
-- @param dam damage to be done
-- @param particles particles effect configuration, or nil
function _M:projectile(t, x, y, damtype, dam, particles)
	if type(particles) ~= "function" and type(particles) ~= "table" then particles = nil end

	local mods = {}
	if game.level.map:checkAllEntities(x, y, "on_project_acquire", self, t, x, y, damtype, dam, particles, true, mods) then
		if mods.x then x = mods.x end
		if mods.y then y = mods.y end
	end

--	if type(dam) == "number" and dam < 0 then return end
	local typ = Target:getType(t)
	typ.source_actor = self
	typ.start_x = self.x
	typ.start_y = self.y
	if self.lineFOV then
		typ.line_function = self:lineFOV(x, y)
	else
		typ.line_function = core.fov.line(self.x, self.y, x, y)
	end

	local proj = require(self.projectile_class):makeProject(self, t.display, {x=x, y=y, start_x = t.x or self.x, start_y = t.y or self.y, damtype=damtype, tg=t, typ=typ, dam=dam, particles=particles})
	game.zone:addEntity(game.level, proj, "projectile", t.x or self.x, t.y or self.y)
end

-- @param typ a target type table
-- @param tgtx the target's x-coordinate
-- @param tgty the target's y-coordinate
-- @param x the projectile's x-coordinate
-- @param y the projectile's x-coordinate
-- @param srcx the sources's x-coordinate
-- @param srcx the source's x-coordinate
-- @return lx x-coordinate the projectile travels to next
-- @return ly y-coordinate the projectile travels to next
-- @return act should we call projectDoAct (usually only for beam)
-- @return stop is this the last (blocking) tile?
function _M:projectDoMove(typ, tgtx, tgty, x, y, srcx, srcy)
	local block_corner = function(_, bx, by)
		if typ.block_path then
			local b, h, hr = typ:block_path(bx, by, true)
			return b and h and not hr
		else
			return false
		end
	end
	local lx, ly, is_corner_blocked = typ.line_function:step(block_corner)

	if lx and ly then
		local block, hit, hit_radius = false, true, true
		if typ.block_path then
			block, hit, hit_radius = typ:block_path(lx, ly)
		end
		if is_corner_blocked then
			block = true
			hit = false
			hit_radius = false
		end
		if block then
			if hit then
				return lx, ly, false, true
			-- If we don't hit the tile, pass back nils to stop on the current spot
			else
				return nil, nil, false, true
			end
		end

		-- End of the map
		if lx < 0 or lx >= game.level.map.w or ly < 0 or ly >= game.level.map.h then
			return nil, nil, false, true
		end

		-- Deal damage: beam
		if typ.line and (lx ~= tgtx or ly ~= tgty) then return lx, ly, true, false end
	end
	-- Ok if we are at the end
	if (not lx and not ly) then return lx, ly, false, true end
	return lx, ly, false, false
end


function _M:projectDoAct(typ, tg, damtype, dam, particles, px, py, tmp)
	-- Now project on each grid, one type
	-- Call the projected method of the target grid if possible
	if not game.level.map:checkAllEntities(px, py, "projected", self, typ, px, py, damtype, dam, particles) then
		-- Check self- and friendly-fire, and if the projection "misses"
		local act = game.level.map(px, py, engine.Map.ACTOR)
		if act and act == self and not ((type(typ.selffire) == "number" and rng.percent(typ.selffire)) or (type(typ.selffire) ~= "number" and typ.selffire)) then
		elseif act and self.reactionToward and (self:reactionToward(act) >= 0) and not ((type(typ.friendlyfire) == "number" and rng.percent(typ.friendlyfire)) or (type(typ.friendlyfire) ~= "number" and typ.friendlyfire)) then
		-- Otherwise hit
		else
			DamageType:projectingFor(self, {project_type=tg})
			if type(damtype) == "function" then if damtype(px, py, tg, self) then return true end
			else DamageType:get(damtype).projector(self, px, py, damtype, dam, tmp, nil, tg) end
			if particles and type(particles) == "table" then
				game.level.map:particleEmitter(px, py, 1, particles.type, particles.args)
			end
			DamageType:projectingFor(self, nil)
		end
	end
end

function _M:projectDoStop(typ, tg, damtype, dam, particles, lx, ly, tmp, rx, ry)
	local grids = {}
	local function addGrid(x, y)
		if not grids[x] then grids[x] = {} end
		grids[x][y] = true
	end

	if typ.ball and typ.ball > 0 then
		core.fov.calc_circle(
			rx,
			ry,
			game.level.map.w,
			game.level.map.h,
			typ.ball,
			function(_, px, py)
				if typ.block_radius and typ:block_radius(px, py) then return true end
			end,
			function(_, px, py)
				-- Deal damage: ball
				addGrid(px, py)
			end,
		nil)
		addGrid(rx, ry)
	elseif typ.cone and typ.cone > 0 then
		--local initial_dir = lx and util.getDir(lx, ly, x, y) or 5
		--local dir_angle = math.deg(math.atan2(ly - typ.source_actor.y, lx - typ.source_actor.x))
		core.fov.calc_beam_any_angle(
			rx,
			ry,
			game.level.map.w,
			game.level.map.h,
			typ.cone,
			lx - typ.source_actor.x,
			ly - typ.source_actor.y,
			typ.cone_angle,
			function(_, px, py)
				if typ.block_radius and typ:block_radius(px, py) then return true end
			end,
			function(_, px, py)
				-- Deal damage: cone
				addGrid(px, py)
			end,
		nil)
		addGrid(rx, ry)
	else
		-- Deal damage: single
		addGrid(lx, ly)
	end

	self:check("on_project_grids", grids)

	if typ.sound_stop then game:playSoundNear({x=lx,y=ly}, typ.sound_stop) end

	for px, ys in pairs(grids) do
		for py, _ in pairs(ys) do
			if self:projectDoAct(typ, tg, damtype, dam, particles, px, py, tmp) then break end
		end
	end
	if particles and type(particles) == "function" then
		if (typ.ball and typ.ball > 0) or (typ.cone and typ.cone > 0) then
			particles(self, tg, rx, ry, grids)
		else
			particles(self, tg, lx, ly, grids)
		end
	end
end
