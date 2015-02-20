-- TE4 - T-Engine 4
-- Copyright (C) 2009 - 2015 Nicolas Casalini
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
local Focusable = require "engine.ui.Focusable"

--- A generic UI button
module(..., package.seeall, class.inherit(Base, Focusable))

frame_ox1 = -5
frame_ox2 = 5
frame_oy1 = -5
frame_oy2 = 5

function _M:init(t)
	self.text = assert(t.text, "no button text")
	self.fct = assert(t.fct, "no button fct")
	self.on_select = t.on_select
	self.force_w = t.width
	if t.can_focus ~= nil then self.can_focus = t.can_focus end
	if t.can_focus_mouse ~= nil then self.can_focus_mouse = t.can_focus_mouse end
	self.alpha_unfocus = t.alpha_unfocus or 1

	Base.init(self, t)
end

function _M:generate()
	self.mouse:reset()
	self.key:reset()

	-- Draw UI
	self.font:setStyle("bold")
	local w, h = self.font:size(self.text)
	self.font:setStyle("normal")

	self.iw, self.ih = w, h
	if self.force_w then w = self.force_w end
	self.w, self.h = w - frame_ox1 + frame_ox2, h - frame_oy1 + frame_oy2

	-- Add UI controls
	self.mouse:registerZone(0, 0, self.w+6, self.h+6, function(button, x, y, xrel, yrel, bx, by, event)
		if self.hide then return end
		if self.on_select then self.on_select() end
		if button == "left" and event == "button" then self:sound("button") self.fct() end
	end)
	self.key:addBind("ACCEPT", function() self:sound("button") self.fct() end)

	self.bw, self.bh = self.w, self.h
	self.rw, self.rh = w, h

	-- Draw stuff
	self:setupVOs(true, true)
	self.font:drawVO(self.votext, self.text, {center=true, x=self.w/2, y=self.h/2})
	self.vo_id = self:makeFrameVO(self.vo, "ui/button", 0, 0, self.bw, self.bh)

	-- Add a bit of padding
	self.w = self.w + 6
	self.h = self.h + 6
end

function _M:on_focus_change(status)
	self:updateFrameTextureVO(self.vo, self.vo_id, status and "ui/button_sel" or "ui/button")
end

function _M:display(x, y, nb_keyframes, ox, oy)
	self.last_display_x = ox
	self.last_display_y = oy

	if self.hide then return end

	x = x + 3
	y = y + 3
	ox = ox + 3
	oy = oy + 3
	local mx, my, button = core.mouse.get()
	-- if self.focused then
	-- 	if button == 1 and mx > ox and mx < ox+self.w and my > oy and my < oy+self.h then
	-- 		self:updateFrameColorVO(self.vo, self.vo_id, true, 0, 1, 0, 1)
	-- 	elseif self.glow then
	-- 		local v = self.glow + (1 - self.glow) * (1 + math.cos(core.game.getTime() / 300)) / 2
	-- 		self:updateFrameColorVO(self.vo, self.vo_id, true, v * 0.8, v, 0, 1)
	-- 	end
	-- else
	-- 	if self.glow then
	-- 		local v = self.glow + (1 - self.glow) * (1 + math.cos(core.game.getTime() / 300)) / 2
	-- 		self:updateFrameColorVO(self.vo, self.vo_id, true, v*0.8, v, 0, self.alpha_unfocus)
	-- 	else
	-- 		if self.focus_decay then
	-- 			self:updateFrameColorVO(self.vo, self.vo_id, true, 1, 1, 1, self.alpha_unfocus * self.focus_decay / self.focus_decay_max_d)
	-- 			self.focus_decay = self.focus_decay - nb_keyframes
	-- 			if self.focus_decay <= 0 then self.focus_decay = nil end
	-- 		else
	-- 			self:updateFrameColorVO(self.vo, self.vo_id, true, 1, 1, 1, self.alpha_unfocus)
	-- 		end
	-- 	end
	-- end

	-- self.vo:toScreen(x, y)
	-- self.votext:toScreen(x, y)
	-- if self.text_shadow then self:textureToScreen(self.tex, x-frame_ox1+1, y-frame_oy1+1, 0, 0, 0, self.text_shadow * (self.focused and 1 or self.alpha_unfocus)) end
	-- self:textureToScreen(self.tex, x-frame_ox1, y-frame_oy1, 1, 1, 1, self.focused and 1 or self.alpha_unfocus)
end
