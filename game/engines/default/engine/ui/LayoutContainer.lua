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
local Base = require "engine.ui.Base"
local Focusable = require "engine.ui.Focusable"
local KeyBind = require "engine.KeyBind"

--- A UI container that can host other UI elements and lay them out same as Dialog can
-- @classmod engine.ui.LayoutContainer
module(..., package.seeall, class.inherit(Base, Focusable))

function _M:init(t)
	if not t.uis then error("LayoutContainer needs uis") end
	self.w = t.width
	self.h = t.height
	self.frame_id = t.frame_id

	self.uis = {}
	self.ui_by_ui = {}
	for i, ui in ipairs(t.uis) do
		self.uis[#self.uis+1] = ui
		self.ui_by_ui[ui.ui] = ui

		if not t.focus_ui and ui.ui.can_focus then
			self:setSubFocus(i)
		elseif ui.ui.can_focus then
			ui.ui:setSubFocus(false)
		end
	end

	t.require_renderer = true
	Base.init(self, t)
end

function _M:generate()
	self.mouse:reset()
	self.key:reset()
	self.do_container:clear()
	self.uis_container = core.renderer.renderer()

	self:setupUI(self.w == nil, self.h == nil)

	self.frame = self:makeFrameDO(self.frame_id or "ui/textbox", self.w, self.h, nil, nil, false, true)
	self.do_container:add(self.frame.container)
	self.do_container:add(self.uis_container)

	self.uis_container:cutoff(0, 0, self.iw, self.ih)

	self.mouse:registerZone(0, 0, self.w, self.h, function(...) self:mouseEvent(...) end, nil, nil, true)
	self.key.receiveKey = function(_, ...) self:keyEvent(...) end
end

function _M:positioned(x, y, sx, sy, dialog)
	self.display_x, self.display_y = sx, sy
end

function _M:setupUI(resizex, resizey, on_resize, addmw, addmh)
	local mw, mh = nil, nil

	local padding = 3 -- to not glue stuff to each other

--	resizex, resizey = true, true
	local nw, nh
	if resizex or resizey then
		mw, mh = 0, 0
		local addw, addh = 0, 0

		for i, ui in ipairs(self.uis) do
			if ui.top and type(ui.top) == "table" then ui.top = self.ui_by_ui[ui.top].top + self.ui_by_ui[ui.top].ui.h + padding end
			if ui.bottom and type(ui.bottom) == "table" then ui.bottom = self.ui_by_ui[ui.bottom].bottom + self.ui_by_ui[ui.bottom].ui.h + padding end
			if ui.left and type(ui.left) == "table" then ui.left = self.ui_by_ui[ui.left].left + self.ui_by_ui[ui.left].ui.w + padding end
			if ui.right and type(ui.right) == "table" then ui.right = self.ui_by_ui[ui.right].right + self.ui_by_ui[ui.right].ui.w + padding end
			
			if not ui.ignore_size then
				if ui.top then mh = math.max(mh, ui.top + ui.ui.h + (ui.padding_h or 0))
				elseif ui.bottom then addh = math.max(addh, ui.bottom + ui.ui.h + (ui.padding_h or 0))
				end

				if ui.left then mw = math.max(mw, ui.left + ui.ui.w + (ui.padding_w or 0))
				elseif ui.right then addw = math.max(addw, ui.right + ui.ui.w + (ui.padding_w or 0))
				end
			end
		end
		mw = mw + addw + 5 * 2 + (addmw or 0) + padding

		local tw, th = 0, 0
		if self.title then tw, th = self.font_bold:size(self.title) end
		mw = math.max(tw + 6, mw)

		mh = mh + addh + 5 + 22 + 3 + (addmh or 0) + th + padding

		if on_resize then on_resize(resizex and mw or self.w, resizey and mh or self.h) end
		nw, nh = resizex and mw or self.w, resizey and mh or self.h
	else
		if on_resize then on_resize(self.w, self.h) end
		nw, nh = self.w, self.h
	end

	self.w, self.h = math.floor(nw), math.floor(nh)
	self.ix, self.iy = 5, 8
	self.iw, self.ih = self.w - 2 * 5, self.h - 8 - 8

	self.uis_container:clear()
	local actual_container = self.uis_container

	local full_h = 0
	for i, ui in ipairs(self.uis) do
		local ux, uy

		ux, uy = self.ix, self.iy

		-- At first, calculate ALL dependencies
		if ui.top and type(ui.top) == "table" then ui.top = self.ui_by_ui[ui.top].y - self.iy + ui.top.h + padding end
		if ui.bottom and type(ui.bottom) == "table" then
			local top = self.ui_by_ui[ui.bottom].y - self.iy  -- top of ui.bottom
			ui.bottom = self.ih - top + padding
		end
		if ui.vcenter and type(ui.vcenter) == "table" then
			local vcenter = self.ui_by_ui[ui.vcenter].y + ui.vcenter.h
			ui.vcenter = math.floor(vcenter - self.ih / 2)
		end

		if ui.left and type(ui.left) == "table" then ui.left = self.ui_by_ui[ui.left].x - self.ix + ui.left.w + padding end
		if ui.right and type(ui.right)== "table" then
			local left = self.ui_by_ui[ui.right].x - self.ix -- left of ui.right
			ui.right = self.iw - left + padding
		end
		if ui.hcenter and type(ui.hcenter) == "table" then
			local hcenter = self.ui_by_ui[ui.hcenter].x - self.ix + ui.hcenter.w / 2
			ui.hcenter = math.floor(hcenter - self.iw / 2)
		end
		if ui.hcenter_left and type(ui.hcenter_left) == "table" then  -- I still have no idea what that does
			ui.hcenter_left = self.ui_by_ui[ui.hcenter_left].x + ui.hcenter_left.w
		end

		local regenerate = false
		if ui.calc_width then
			if ui.left and ui.right then
				ui.ui.w = self.iw - (ui.right + ui.left)
			elseif ui.left and ui.hcenter then
				ui.ui.w = self.iw + 2 * (ui.hcenter - ui.left)
			elseif ui.hcenter and ui.right then
				ui.ui.w = self.iw + 2 * (-ui.hcenter - ui.right)
			end
			regenerate = true
		end
		if ui.calc_height then
			if ui.top and ui.bottom then
				ui.ui.h = self.ih - (ui.bottom + ui.top)
			elseif ui.top and ui.vcenter then
				ui.ui.h = self.ih + 2 * (ui.vcenter - ui.top)
			elseif ui.vcenter and ui.bottom then
				ui.ui.h = self.ih + 2 * (-ui.vcenter - ui.bottom)
			end
			regenerate = true
		end
		if regenerate then
			ui.ui:generate()
		end


		if ui.top then
			uy = uy + ui.top
		elseif ui.bottom then
			uy = uy + self.ih - ui.bottom - ui.ui.h
		elseif ui.vcenter then
			uy = uy + math.floor(self.ih / 2) + ui.vcenter - ui.ui.h / 2
		end

		if ui.left then 
			ux = ux + ui.left
		elseif ui.right then
			ux = ux + self.iw - ui.right - ui.ui.w
		elseif ui.hcenter then
			ux = ux + math.floor(self.iw / 2) + ui.hcenter - ui.ui.w / 2
		elseif ui.hcenter_left then
			ux = ux + math.floor(self.iw / 2) + ui.hcenter_left
		end

		ui.x = ux
		ui.y = uy
		ui.ui.mouse.delegate_offset_x = ux
		ui.ui.mouse.delegate_offset_y = uy
		ui.ui:positioned(ux, uy, ux, uy, self)
		if ui.ui.do_container then
			ui.ui.do_container:translate(ui.x, ui.y, 0)
			ui.ui.do_container:removeFromParent()
			actual_container:add(ui.ui.do_container)
		end
		full_h = math.max(full_h, uy + ui.ui.h)
	end
end


function _M:setSubFocus(id, how)
	if type(id) == "table" then
		for i = 1, #self.uis do
			if self.uis[i].ui == id then id = i break end
		end
		if type(id) == "table" then self:no_focus() return end
	end

	local ui = self.uis[id]
	if self.focus_ui == ui then return end
	if self.focus_ui and (self.focus_ui.ui.can_focus or (self.focus_ui.ui.can_focus_mouse and how=="mouse")) then self.focus_ui.ui:setFocus(false) end
	if not ui.ui.can_focus then self:no_focus() return end
	self.focus_ui = ui
	self.focus_ui_id = id
	ui.ui:setFocus(true)
	self:on_focus(id, ui)
end

function _M:moveSubFocus(v)
	local id = self.focus_ui_id
	if id == #self.uis then return false end
	local start = id or 1
	local cnt = 0
	id = util.boundWrap((id or 1) + v, 1, #self.uis)
	while start ~= id and cnt <= #self.uis do
		if self.uis[id] and self.uis[id].ui and self.uis[id].ui.can_focus and not self.uis[id].ui.no_keyboard_focus then
			self:setSubFocus(id)
			break
		end
		id = util.boundWrap(id + v, 1, #self.uis)
		cnt = cnt + 1
	end
	return true
end

function _M:on_subfocus(id, ui)
end
function _M:no_subfocus()
end

function _M:mouseEvent(button, x, y, xrel, yrel, bx, by, event)
	-- Look for focus
	for i = 1, #self.uis do
		local ui = self.uis[i]
		if (ui.ui.can_focus or ui.ui.can_focus_mouse) and bx >= ui.x and bx <= ui.x + ui.ui.w and by >= ui.y and by <= ui.y + ui.ui.h then
			self:setSubFocus(i, "mouse")

			-- Pass the event
			ui.ui.mouse:delegate(button, bx, by, xrel, yrel, bx, by, event)
			return true
		end
	end
	self:no_focus()
	return false
end

function _M:keyEvent(...)
	if not self.focus_ui or not self.focus_ui.ui.key:receiveKey(...) then
		KeyBind.receiveKey(self.key, ...)
	end
end

function _M:on_focus_change(status)
	if not status then
		for i = 1, #self.uis do
			local ui = self.uis[i]
			if (ui.ui.can_focus or ui.ui.can_focus_mouse) then
				ui.ui:setFocus(false)
			end
		end
		self.focus_ui = nil
		self.focus_ui_id = nil
	else
		self.focus_ui_id = 0 -- Hack
		self:moveSubFocus(1)
	end
end

function _M:getNUI(name)
	return self.nuis and self.nuis[name]
end

function _M:makeByLines(lines)
	local uis = self.uis
	local linew = self.iw
	local y = 0
	self.nuis = {}
	for i, line in ipairs(lines) do
		local x = 0
		local max_h = 0
		line.padding = line.padding or 3
		for j, ui in ipairs(line) do
			local forcew = nil
			local args = table.clone(ui[2], true)
			if ui.w then
				local p1 = ((j > 1) and line[j-1].pos.ui.w or 0) + line.padding
				local p2 = ((j > 2) and line[j-2].pos.ui.w or 0) + line.padding
				local p3 = ((j > 3) and line[j-3].pos.ui.w or 0) + line.padding
				local p4 = ((j > 4) and line[j-4].pos.ui.w or 0) + line.padding
				local p5 = ((j > 5) and line[j-5].pos.ui.w or 0) + line.padding
				local s = "return function(p1,p2,p3,p4,p5) return "..ui.w:gsub('%%', '*'..self.iw.."/100").." end"
				print(s)
				s = loadstring(s)()
				print(" => ", s(p1,p2,p3,p4,p5), "with p1", p1)
				args.width = s(p1,p2,p3,p4,p5)
			end
			local class = ui[1]
			if not class:find("%.") then class = "engine.ui."..class end
			local c = require(class).new(args)
			ui.pos = {left = x, top = y, ui=c}
			uis[#uis+1] = ui.pos
			x = x + c.w + line.padding
			max_h = math.max(max_h, c.h)
			if ui[3] then self.nuis[ui[3]] = c end
		end
		if line.vcenter then
			for j, ui in ipairs(line) do
				ui.pos.top = y + math.floor((max_h - ui.pos.ui.h) / 2)
			end
		end
		y = y + max_h + (line.vpadding or 3)
	end
end
