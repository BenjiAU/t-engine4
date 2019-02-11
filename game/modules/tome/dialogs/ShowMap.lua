-- ToME - Tales of Maj'Eyal
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
local Dialog = require "engine.ui.Dialog"
local DisplayObject = require "engine.ui.DisplayObject"

module(..., package.seeall, class.inherit(Dialog))

function _M:init()
	self.title_shadow = false
	self.color = {r=0x3a, g=0x35, b=0x33}

	self.ui = "parchment"

	self.bsize = 10
	local map = game.level.map
	local mw, mh = map.w * self.bsize, map.h * self.bsize
	local Mw, Mh = math.floor(game.w * 0.9), math.floor(game.h * 0.9)

	while mw > Mw or mh > Mh do
		if self.bsize <= 5 then break end
		self.bsize = self.bsize - 1
		mw, mh = map.w * self.bsize, map.h * self.bsize
	end

	mw = math.min(mw, Mw)
	mh = math.min(mh, Mh)

	local t_per_w, t_per_h = math.floor(mw / self.bsize), math.floor(mh / self.bsize)

	Dialog.init(self, "Map: #0080FF#"..game.zone_name, 1, 1)

	local mmdo = game.level.map:getMinimapDO(true)
	local mc = DisplayObject.new{width=mw, height=mh, DO=mmdo}
	local uis = { {left=0, top=0, ui=mc} }

	local minimap_scroll_x = util.bound(game.minimap_scroll_x or 0, 0, math.max(0, map.w - t_per_w))
	local minimap_scroll_y = util.bound(game.minimap_scroll_y or 0, 0, math.max(0, map.h - t_per_h))

	mc.mouse:registerZone(0, 0, mc.w, mc.h, function(button, mx, my, xrel, yrel, bx, by, event)
		if event == "out" then game.tooltip_x, game.tooltip_y = 1, 1 return end

		game.tooltip_x, game.tooltip_y = 1, 1
		local basex, basey = math.floor(bx / self.bsize), math.floor(by / self.bsize)
		local dx, dy = minimap_scroll_x + basex, minimap_scroll_y + basey
		local ts = game.tooltip:getTooltipAtMap(dx, dy, dx, dy)
		if ts then game.tooltip:set(ts) game.tooltip:display() else game.tooltip:erase() end

		if button == "right" then
			minimap_scroll_x = dx - math.floor(t_per_w / 2)
			minimap_scroll_y = dy - math.floor(t_per_h / 2)

			minimap_scroll_x = util.bound(minimap_scroll_x, 0, math.max(0, map.w - t_per_w))
			minimap_scroll_y = util.bound(minimap_scroll_y, 0, math.max(0, map.h - t_per_h))
		elseif button == "left" and not xrel and not yrel and event == "button" then
			game.player:mouseMove(dx, dy)
		elseif xrel or yrel then
			game.level.map:moveViewSurround(dx, dy, 1000, 1000)
		elseif event == "button" and button == "middle" then
			self.key:triggerVirtual("SHOW_MAP")
		end

	end, nil, nil, true)

	self:loadUI(uis)
	self.key:addBind("EXIT", function() game:unregisterDialog(self) end)
	self.key:addBind("ACCEPT", function() game:unregisterDialog(self) end)
	self.key:addBind("SHOW_MAP", function() game:unregisterDialog(self) end)
	self:setupUI(true, true)
	self:setFocus(1)

	mmdo:scale(self.bsize, self.bsize, 1):setMinimapInfo(minimap_scroll_x, minimap_scroll_y, math.floor(self.iw / self.bsize), math.floor(self.ih / self.bsize), 0.85)

	game:playSound("actions/read")
end
