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

local class= require "engine.class"
local Numberbox = require "engine.ui.Numberbox"
local Focusable = require "engine.ui.Focusable"
local WithTitle = require "engine.ui.WithTitle"

-- a slider with an integrated numberbox
-- @classmod engine.ui.NumberSlider
module(..., class.inherit(WithTitle, Focusable))

function _M:init(t)
	self.min = t.min or 0
	self.max = t.max or 9999
	self.value = t.value or self.min
	self.step = t.step or 10
	self.on_change = t.on_change
	self.formatter = t.formatter or function(v) return ("%d"):format(v) end
	self.fct = t.fct or function() end
	assert(t.size or t.w or t.width, "no numberspinner size")
	self.size = t.size
	self.w = t.w or t.width

	WithTitle.init(self, t)
end

function _M:generate()
	self.mouse:reset()
	self.key:reset()
	self.do_container:clear()

	local knob_t = self:getAtlasTexture("ui/scrollbar-sel.png")
	local minus_t = self:getAtlasTexture("ui/minus.png")
	local plus_t = self:getAtlasTexture("ui/plus.png")

	self.h = self.font:height()
	self:generateTitle(self.h)
	self.w = self.w or self.size + self.title_w
	self.size = self.w - self.title_w

	local frame_green = self:makeFrameDO("ui/selector-green", plus_t.w, plus_t.h)

	local frame = self:makeFrameDO("ui/selector", self.size, nil, nil, 0)
	self.backdrop = frame.container:translate(self.title_w, (self.h - frame.h) / 2)
	self.do_container:add(self.backdrop)

	local frame_sel = self:makeFrameDO("ui/selector-sel", self.size, nil, nil, 0)
	self.backdrop_sel = frame_sel.container:translate(self.title_w, (self.h - frame.h) / 2)
	self.do_container:add(self.backdrop_sel:color(1, 1, 1, 0))

	self.value_text = core.renderer.text(self.font):scale(0.8, 0.8, 1):outline(1):text(self.formatter(self.value)):center()
	self.do_container:add(self.value_text:translate(self.title_w + self.size / 2, self.h / 2))

	local scale = frame.h / plus_t.h
	local plus = core.renderer.fromTextureTable(plus_t, 0, -plus_t.h/2):scale(scale, scale, scale)
	self.do_container:add(frame_green.container:translate(self.w - plus_t.w))
	self.do_container:add(plus:translate(self.w - plus_t.w, self.h / 2))

	local scale = frame.h / plus_t.h
	local minus = core.renderer.fromTextureTable(minus_t, 0, -minus_t.h/2):scale(scale, scale, scale)
	local frame_green = self:makeFrameDO("ui/selector-green", nil, nil, 0, 0)
	self.do_container:add(frame_green.container:clone():translate(self.title_w))
	self.do_container:add(minus:translate(self.title_w, self.h / 2))
	
	self.start_w = self.title_w + minus_t.w + knob_t.w / 2
	self.size = self.w - self.title_w - plus_t.w - knob_t.w - minus_t.w

	local scale = frame.h / knob_t.h
	self.knob = core.renderer.fromTextureTable(knob_t, -knob_t.w/2, -knob_t.h/2):scale(scale, scale, scale)
	self.do_container:add(self.knob:translate(self.start_w + ((self.value - self.min) / (self.max - self.min)) * self.size, self.h / 2))

	self.key:addBind("ACCEPT", function() self:onChange() if self.fct then self.fct() end end)
	self.key:addCommands{
		_RIGHT = function() self:setValue(self.value + self.step, true) end,
		_LEFT = function() self:setValue(self.value - self.step, true) end,
		_UP = function() self:setValue(self.value + self.step, true) end,
		_DOWN = function() self:setValue(self.value - self.step, true) end,
		_PAGEUP = function() self:setValue(self.value + self.step * 5, true) end,
		_PAGEDOWN = function() self:setValue(self.value - self.step * 5, true) end,
	}

	-- precise click
	self.mouse:allowDownEvent(true)
	self.mouse:registerZone(self.start_w, 0, self.size, self.h, function(button, x, y, xrel, yrel, bx, by, event)
		if button == "left" then
			x = (x - self.start_w) / self.size
			self:setValue(math.round(x * (self.max - self.min) + self.min), true)
		elseif button == "wheeldown" then
			self:setValue(self.value - self.step, true)
		elseif button == "wheelup" then
			self:setValue(self.value + self.step, true)
		end
	end, {button=true, move=true}, "precise")
	self.mouse:registerZone(self.title_w, 0, minus_t.w, self.h, function(button, x, y, xrel, yrel, bx, by, event) if button == "left" then
		self:setValue(self.value - self.step)
	end end)
	self.mouse:registerZone(self.w - plus_t.w, 0, plus_t.w, self.h, function(button, x, y, xrel, yrel, bx, by, event) if button == "left" then
		self:setValue(self.value + self.step)
	end end)

	-- -- wheeeeeeee
	-- local wheelTable = {wheelup = 1 * self.step, wheeldown = -1 * self.step}
	-- self.mouse:registerZone(self.start_w, 0, self.size, self.h, function(button, x, y, xrel, yrel, bx, by, event)
	-- 	if event == "button-down" then return false end
	-- 	if event ~= "button" or not wheelTable[button] then return false end
	-- 	self:onChange()
	-- end, {button=true})

	-- -- clicking on arrows
	-- local stepTable = {left = self.step, right = 1}
	-- self.mouse:registerZone(self.start_w, 0, self.left_w, self.h, function(button, x, y, xrel, yrel, bx, by, event)
	-- 	if event == "button-down" then return false end
	-- 	if event ~= "button" or not stepTable[button] then return false end
	-- 	self:onChange()
	-- end, {button=true}, "left")
	-- self.mouse:registerZone(self.start_w + self.size - self.right_w, 0, self.right_w, self.h, function(button, x, y, xrel, yrel, bx, by, event)
	-- 	if event == "button-down" then return false end
	-- 	if event ~= "button" or not stepTable[button] then return false end
	-- 	self:onChange()
	-- end, {button=true}, "right")

	self:onChange()
end

function _M:on_focus(v)
	game:onTickEnd(function() self.key:unicodeInput(v) end)
	self.backdrop:tween(4, "a", nil, v and 0 or 1, "linear")
	self.backdrop_sel:tween(4, "a", nil, v and 1 or 0, "linear")
	self:onChange()
end

function _M:onChange()
	self.value = util.bound(self.value, self.min, self.max)
	if self.on_change then self.on_change(self.value) end
end

function _M:setValue(v, smooth)
	self.value = v
	self:onChange()
	local nx = self.start_w + ((self.value - self.min) / (self.max - self.min)) * self.size
	if smooth then
		self.knob:tween(7, "x", nil, nx, "outQuad")
	else
		self.knob:translate(nx, self.h / 2)
	end
	self.value_text:text(self.formatter(self.value)):center()
end
