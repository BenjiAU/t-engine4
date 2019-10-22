-- TE4 - T-Engine 4
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
local Tilemap = require "engine.tilemaps.Tilemap"
local Proxy = require "engine.tilemaps.Proxy"
local AlgoBSP = require "engine.algorithms.BSP"

--- Generate partitioned "building"
-- @classmod engine.tilemaps.BSP
module(..., package.seeall, class.inherit(Tilemap))

function _M:init(min_w, min_h, max_depth, inner_walls)
	Tilemap.init(self)
	self.a_min_w, self.a_min_h, self.a_max_depth = min_w, min_h, max_depth
	self.inner_walls = inner_walls
end

function _M:make(w, h, floor, wall)
	local bsp = AlgoBSP.new(w, h, self.a_min_w, self.a_min_h, self.a_max_depth)
	bsp:partition()

	self:setSize(w, h, ' ')

	self.rooms = {}

	for _, leaf in ipairs(bsp.leafs) do
		local from = self:point(leaf.rx + 1, leaf.ry + 1)
		local to = self:point(leaf.rx + 1 + leaf.w - 2, leaf.ry + 1 + leaf.h - 2)
		local center = from + (to - from) / 2

		if floor then
			self:carveArea(floor, from, to)
		end
		if wall then
			if self.inner_walls then
				for i = from.x, to.x do
					self:put(self:point(i, from.y), wall)
					self:put(self:point(i, to.y), wall)
				end
				for j = from.y, to.y do
					self:put(self:point(from.x, j), wall)
					self:put(self:point(to.x, j), wall)
				end
			else
				for i = from.x - 1, to.x + 1 do
					self:put(self:point(i, from.y - 1), wall)
					self:put(self:point(i, to.y + 1), wall)
				end
				for j = from.y - 1, to.y + 1 do
					self:put(self:point(from.x - 1, j), wall)
					self:put(self:point(to.x + 1, j), wall)
				end
			end
		end

		self.rooms[#self.rooms+1] = {
			from = from, 
			to = to, 
			center = center,
			map = Proxy.new(self, from, leaf.w - 1, leaf.h - 1),
		}
	end

	return self
end
