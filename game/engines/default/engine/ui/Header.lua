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
local Base = require "engine.ui.Base"
local FontPackage = require "engine.FontPackage"

--- A generic UI separator
-- @classmod engine.ui.Separator
module(..., package.seeall, class.inherit(Base))

function _M:init(t)
	self.w = assert(t.width, "no header size")
	self.color = t.color or {1, 1, 1, 1}
	self.text = t.text
	Base.init(self, t)
	self.font = FontPackage:get("header")
end

function _M:generate()
	self.do_container:clear()
	if not self.text then self.text = "L" self:hide() end

	local conf = self.ui_conf[self.ui]
	local compress = conf.header_compress or 0

	local left = self:getAtlasTexture("ui/border_hor_left.png")
	local middle = self:getAtlasTexture("ui/border_hor_middle.png")
	local right = self:getAtlasTexture("ui/border_hor_right.png")
	local point = self:getAtlasTexture("ui/scrollbar-sel.png")

	local topbar = core.renderer.container()
	topbar:add(core.renderer.fromTextureTable(left, 0, 0))
	topbar:add(core.renderer.fromTextureTable(middle, left.w, 0, self.w - left.w - right.w, middle.h, true))
	topbar:add(core.renderer.fromTextureTable(right, self.w - right.w, 0))
	topbar:add(core.renderer.fromTextureTable(point, self.w / 2 - point.w/4, middle.h / 2 - point.h/4, point.w/2, point.h/2):translate(0, 0, 1))

	self.do_container:add(topbar:translate(0, -compress))

	self.text_do = core.renderer.text(self.font):scale(1.2, 1.2, 1):smallCaps(true):textStyle("bold"):textColor(unpack(self.color)):text(self.text):center()
	local _, text_h = self.text_do:getStats() text_h = text_h * 1.2
	self.do_container:add(self:applyShadowOutline(self.text_do:translate(self.w / 2, - compress + middle.h - compress + text_h / 2)))

	self.do_container:add(topbar:clone():translate(0,  - compress + middle.h - compress + text_h - compress))

	self.h = - compress + middle.h - compress + text_h - compress + middle.h - compress

	self.do_container:add(core.renderer.colorQuad(0, -compress+middle.h/2, self.w, self.h - (-compress+middle.h/2) - compress, 0, 0, 0, 0.2))
end

function _M:hide()
	self.do_container:shown(false)
end

function _M:set(text)
	self.do_container:shown(true)
	self.text = text
	self.text_do:text(text):center()
end
