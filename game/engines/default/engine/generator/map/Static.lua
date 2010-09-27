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
local Map = require "engine.Map"
require "engine.Generator"
module(..., package.seeall, class.inherit(engine.Generator))

function _M:init(zone, map, level, data)
	engine.Generator.init(self, zone, map, level)
	self.grid_list = zone.grid_list
	self.subgen = {}
	self.spots = {}
	self.data = data

	if data.adjust_level then
		self.adjust_level = {base=zone.base_level, lev = self.level.level, min=data.adjust_level[1], max=data.adjust_level[2]}
	else
		self.adjust_level = {base=zone.base_level, lev = self.level.level, min=0, max=0}
	end

	self:loadMap(data.map)
end

function _M:loadMap(file)
	local t = {}

	print("Static generator using file", "/data/maps/"..file..".lua")
	local f, err = loadfile("/data/maps/"..file..".lua")
	if not f and err then error(err) end
	local g = {
		Map = require("engine.Map"),
		subGenerator = function(g)
			self.subgen[#self.subgen+1] = g
		end,
		defineTile = function(char, grid, obj, actor, trap, status, spot)
			t[char] = {grid=grid, object=obj, actor=actor, trap=trap, status=status, define_spot=spot}
		end,
		quickEntity = function(char, e, status, spot)
			if type(e) == "table" then
				local e = self.zone.grid_class.new(e)
				t[char] = {grid=e, status=status, define_spot=spot}
			else
				t[char] = t[e]
			end
		end,
		prepareEntitiesList = function(type, class, file)
			local list = require(class):loadList(file)
			self.level:setEntitiesList(type, list)
		end,
		setStatusAll = function(s) self.status_all = s end,
		addData = function(t)
			table.merge(self.level.data, t, true)
		end,
		getMap = function(t)
			return self.map
		end,
		checkConnectivity = function(dst, src, type, subtype)
			self.spots[#self.spots+1] = {x=dst[1], y=dst[2], check_connectivity=src, type=type or "static", subtype=subtype or "static"}
		end,
		addSpot = function(dst, type, subtype)
			self.spots[#self.spots+1] = {x=dst[1], y=dst[2], type=type or "static", subtype=subtype or "static"}
		end,
	}
	setfenv(f, setmetatable(g, {__index=_G}))
	local ret, err = f()
	if not ret and err then error(err) end
	if type(ret) == "string" then ret = ret:split("\n") end

	local m = { w=ret[1]:len(), h=#ret }

	-- Read the map
	local rotate = util.getval(g.rotates or "default")
	for j, line in ipairs(ret) do
		local i = 1
		for c in line:gmatch(".") do
			local ii, jj = i, j

			if rotate == "flipx" then ii, jj = m.w - i + 1, j
			elseif rotate == "flipy" then ii, jj = i, m.h - j + 1
			elseif rotate == "90" then ii, jj = j, m.w - i + 1
			elseif rotate == "180" then ii, jj = m.w - i + 1, m.h - j + 1
			elseif rotate == "270" then ii, jj = m.h - j + 1, i
			end

			m[ii] = m[ii] or {}
			m[ii][jj] = c
			i = i + 1
		end
	end

	m.startx = g.startx or math.floor(m.w / 2)
	m.starty = g.starty or math.floor(m.h / 2)
	m.endx = g.endx or math.floor(m.w / 2)
	m.endy = g.endy or math.floor(m.h / 2)

	if rotate == "flipx" then
		m.startx = m.w - m.startx + 1
		m.endx   = m.w - m.endx   + 1
	elseif rotate == "flipy" then
		m.starty = m.h - m.starty + 1
		m.endy   = m.h - m.endy   + 1
	elseif rotate == "90" then
		m.startx, m.starty = m.starty, m.w - m.startx + 1
		m.endx,   m.endy   = m.endy,   m.w - m.endx   + 1
		m.w, m.h = m.h, m.w
	elseif rotate == "180" then
		m.startx, m.starty = m.w - m.startx + 1, m.h - m.starty + 1
		m.endx,   m.endy   = m.w - m.endx   + 1, m.h - m.endy   + 1
	elseif rotate == "270" then
		m.startx, m.starty = m.h - m.starty + 1, m.startx
		m.endx,   m.endy   = m.h - m.endy   + 1, m.endx
		m.w, m.h = m.h, m.w
	end

	self.gen_map = m
	self.tiles = t

	self.map.w = m.w
	self.map.h = m.h
	print("[STATIC MAP] size", m.w, m.h)
end

function _M:resolve(typ, c)
	if not self.tiles[c] or not self.tiles[c][typ] then return end
	local res = self.tiles[c][typ]
	if type(res) == "function" then
		return self.grid_list[res()]
	elseif type(res) == "table" and res.__CLASSNAME then
		return res
	elseif type(res) == "table" then
		return self.grid_list[res[rng.range(1, #res)]]
	else
		return self.grid_list[res]
	end
end

function _M:generate(lev, old_lev)
	local spots = {}

	for i = 1, self.gen_map.w do for j = 1, self.gen_map.h do
		local c = self.gen_map[i][j]
		local g = self:resolve("grid", c)
		if g then
			if g.force_clone then g = g:clone() end
			g:resolve()
			g:resolve(nil, true)
			self.map(i-1, j-1, Map.TERRAIN, g)
		end

		if self.status_all then
			local s = table.clone(self.status_all)
			if s.lite then self.level.map.lites(i-1, j-1, true) s.lite = nil end
			if s.remember then self.level.map.remembers(i-1, j-1, true) s.remember = nil end
			if s.special then self.map.room_map[i-1][j-1].special = s.special s.special = nil end
			if s.room_map then for k, v in pairs(s.room_map) do self.map.room_map[i-1][j-1][k] = v end s.room_map = nil end
			if pairs(s) then for k, v in pairs(s) do self.level.map.attrs(i-1, j-1, k, v) end end
		end
	end end

	-- generate the rest after because they might need full map data to be correctly made
	for i = 1, self.gen_map.w do for j = 1, self.gen_map.h do
		local c = self.gen_map[i][j]
		local actor = self.tiles[c] and self.tiles[c].actor
		local trap = self.tiles[c] and self.tiles[c].trap
		local object = self.tiles[c] and self.tiles[c].object
		local status = self.tiles[c] and self.tiles[c].status
		local define_spot = self.tiles[c] and self.tiles[c].define_spot

		if object then
			local o
			if type(object) == "string" then o = self.zone:makeEntityByName(self.level, "object", object)
			elseif type(object) == "table" and object.random_filter then o = self.zone:makeEntity(self.level, "object", object.random_filter, nil, true)
			else o = self.zone:finishEntity(self.level, "object", object)
			end

			if o then self:roomMapAddEntity(i-1, j-1, "object", o) end
		end

		if trap then
			local t
			if type(trap) == "string" then t = self.zone:makeEntityByName(self.level, "trap", trap)
			elseif type(trap) == "table" and trap.random_filter then t = self.zone:makeEntity(self.level, "trap", trap.random_filter, nil, true)
			else t = self.zone:finishEntity(self.level, "trap", trap)
			end
			if t then self:roomMapAddEntity(i-1, j-1, "trap", t) end
		end

		if actor then
			local m
			if type(actor) == "string" then m = self.zone:makeEntityByName(self.level, "actor", actor)
			elseif type(actor) == "table" and actor.random_filter then m = self.zone:makeEntity(self.level, "actor", actor.random_filter, nil, true)
			else m = self.zone:finishEntity(self.level, "actor", actor)
			end
			if m then self:roomMapAddEntity(i-1, j-1, "actor", m) end
		end

		if status then
			local s = table.clone(status)
			if s.lite then self.level.map.lites(i-1, j-1, true) s.lite = nil end
			if s.remember then self.level.map.remembers(i-1, j-1, true) s.remember = nil end
			if s.special then self.map.room_map[i-1][j-1].special = s.special s.special = nil end
			if s.room_map then for k, v in pairs(s.room_map) do self.map.room_map[i-1][j-1][k] = v end s.room_map = nil end
			if pairs(s) then for k, v in pairs(s) do self.level.map.attrs(i-1, j-1, k, v) end end
		end

		if define_spot then
			define_spot = table.clone(define_spot)
			assert(define_spot.type, "defineTile auto spot without type field")
			assert(define_spot.subtype, "defineTile auto spot without subtype field")
			define_spot.x = i-1
			define_spot.y = j-1
			self.spots[#self.spots+1] = define_spot
		end
	end end

	for i = 1, #self.subgen do
		local g = self.subgen[i]
		local data = g.data
		if type(data) == "string" and data == "pass" then data = self.data end

		local map = self.zone.map_class.new(g.w, g.h)
		local generator = require(g.generator).new(
			self.zone,
			map,
			self.level,
			data
		)
		local ux, uy, dx, dy, subspots = generator:generate(lev, old_lev)

		self.map:import(map, g.x, g.y)
		map:close()

		table.append(self.spots, subspots)

		if g.define_up then self.gen_map.startx, self.gen_map.starty = ux + g.x, uy + g.y end
		if g.define_down then self.gen_map.endx, self.gen_map.endy = dx + g.x, dy + g.y end
	end

	if self.gen_map.startx and self.gen_map.starty then
		self.map.room_map[self.gen_map.startx][self.gen_map.starty].special = "exit"
	end
	if self.gen_map.startx and self.gen_map.starty then
		self.map.room_map[self.gen_map.endx][self.gen_map.endy].special = "exit"
	end
	return self.gen_map.startx, self.gen_map.starty, self.gen_map.endx, self.gen_map.endy, self.spots
end
