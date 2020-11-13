-- TE4 - T-Engine 4
-- Copyright (C) 2009 - 2018 Nicolas Casalini
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

--- Allows a setup'able UI container (like Dialog & LayoutContainer) to spawn controls with paddings, layout, ...
-- @classmod engine.ui.LayoutEngine
module(..., package.seeall, class.make)

function _M:getNUI(name)
	return self.nuis and self.nuis[name]
end

function _M:makeUIByLines(lines)
	self.uis = {}
	local uis = self.uis
	local linew = self.iw
	local y = 0
	self.nuis = {}
	for i, line in ipairs(lines) do
		local x = 0
		local max_h = 0
		line.padding = line.padding or 10
		if line.vpadding_up then y = y + line.vpadding_up end
		for j, ui in ipairs(line) do
			local forcew = nil
			local args = table.clone(ui[2], true)
			local use_w = 0
			if ui.w then
				local p1 = ((j > 1) and line[j-1].pos.ui.w or 0) + line.padding
				local p2 = ((j > 2) and line[j-2].pos.ui.w or 0) + line.padding
				local p3 = ((j > 3) and line[j-3].pos.ui.w or 0) + line.padding
				local p4 = ((j > 4) and line[j-4].pos.ui.w or 0) + line.padding
				local p5 = ((j > 5) and line[j-5].pos.ui.w or 0) + line.padding
				local s = "return function(p1,p2,p3,p4,p5) return "..ui.w:gsub('%%', '*'..self.iw.."/100").." end"
				s = loadstring(s)()
				args.width = s(p1,p2,p3,p4,p5)
				use_w = args.width
			end
			local class = ui[1]
			if not class:find("%.") then class = "engine.ui."..class end
			local c = require(class).new(args)

			if ui.x then
				local p1 = ((j > 1) and line[j-1].pos.ui.w or 0) + line.padding
				local p2 = ((j > 2) and line[j-2].pos.ui.w or 0) + line.padding
				local p3 = ((j > 3) and line[j-3].pos.ui.w or 0) + line.padding
				local p4 = ((j > 4) and line[j-4].pos.ui.w or 0) + line.padding
				local p5 = ((j > 5) and line[j-5].pos.ui.w or 0) + line.padding
				local w = c.w
				local s = "return function(p1,p2,p3,p4,p5,w,x) return "..ui.x:gsub('%%', '*'..self.iw.."/100").." end"
				s = loadstring(s)()
				x = s(p1,p2,p3,p4,p5,w,x)
			end

			ui.pos = {left = x, top = y, ui=c}
			uis[#uis+1] = ui.pos
			x = x + math.max(c.w, use_w) + line.padding
			max_h = math.max(max_h, c.h)
			if ui[3] then self.nuis[ui[3]] = c end
			if ui[4] then ui.pos.has_tooltip = ui[4] end
		end
		if line.vcenter then
			for j, ui in ipairs(line) do
				ui.pos.top = y + math.floor((max_h - ui.pos.ui.h) / 2)
			end
		end
		y = y + max_h + (line.vpadding or 3)
	end
	return self.nuis
end
