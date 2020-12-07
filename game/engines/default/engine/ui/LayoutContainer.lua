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
local LayoutEngine = require "engine.ui.LayoutEngine"
local Scrollbar = require "engine.ui.blocks.Scrollbar"
local KeyBind = require "engine.KeyBind"

--- A UI container that can host other UI elements and lay them out same as Dialog can
-- @classmod engine.ui.LayoutContainer
module(..., package.seeall, class.inherit(Base, Focusable, LayoutEngine))

function _M:init(t)
	if not t.uis then error("LayoutContainer needs uis") end
	self.w = t.width
	self.h = t.height
	self.allow_scroll = t.allow_scroll

	self.frame_id = t.frame_id
	if self.frame_id == false then self.frame_id = nil
	else self.frame_id = self.frame_id or "ui/textbox" end

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

	if self.allow_scroll then
		self.main_container = core.renderer.renderer()
		-- self.main_container = core.renderer.container()
	else
		self.main_container = core.renderer.container()
	end
	self.scroll_container = core.renderer:container()
	self.do_container:add(self.main_container)
	self.do_container:add(self.scroll_container)

	self.uis_container = core.renderer.renderer()

	self.frame = self:makeFrameDO(self.frame_id, self.w, self.h, nil, nil, false, true)
	self:setupUI(self.w == nil, self.h == nil)

	self.main_container:add(self.frame.container)

	if self.allow_scroll then
		self.outer_uis_container = core.renderer.renderer()
		self.outer_uis_container:cutoff(0, 0, self.iw, self.ih)		
		self.main_container:add(self.outer_uis_container)
		self.outer_uis_container:add(self.uis_container)
	else
		self.main_container:add(self.uis_container)
		self.uis_container:cutoff(0, 0, self.iw, self.ih)
	end

	self.mouse:registerZone(0, 0, self.w, self.h, function(...) self:mouseEvent(...) end, nil, nil, true)
	self.key.receiveKey = function(_, ...) self:keyEvent(...) end
end

function _M:positioned(x, y, sx, sy, dialog)
	self.display_x, self.display_y = sx, sy
	self.use_tooltip = dialog.use_tooltip
	self.useTooltip = function(self, ...) return dialog:useTooltip(...) end
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
	self.frame:resize(self.w, self.h)
	self.ix, self.iy = self.frame.ix, self.frame.iy
	self.iw, self.ih = self.frame.iw, self.frame.ih

	if self.allow_scroll then
		self.scrollbar = Scrollbar.new(nil, self.ih, self.ih)
		self.iw = self.iw - self.scrollbar.w
	end

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

	if self.allow_scroll then
		-- self.main_container:cutoff(0, 0, self.iw, self.ih)
		self.scrollbar:setMax(full_h - self.ih)
		self.scroll_inertia = 0
		local sx, sy = self.main_container:getTranslate()
		self.scroll_container:clear():add(self.scrollbar:get():translate(sx + self.iw, sy))
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
	if self.allow_scroll and self.scrollbar then
		y = y + self.scrollbar.pos
		by = by + self.scrollbar.pos

		if event == "button" and button == "wheelup" then
			self.scroll_inertia = math.min(self.scroll_inertia, 0) - 5
		elseif event == "button" and button == "wheeldown" then
			self.scroll_inertia = math.max(self.scroll_inertia, 0) + 5
		end
	end

	-- Look for focus
	self:useTooltip(false)
	for i = 1, #self.uis do
		local ui = self.uis[i]
		if ui.has_tooltip and bx >= ui.x and bx <= ui.x + ui.ui.w and by >= ui.y and by <= ui.y + ui.ui.h then
			self:useTooltip(true)
			if self.last_tooltip ~= ui then
				local dx, dy = ui.ui.do_container:getTranslate(true)
				self:useTooltip(dx, dy, ui.ui.h, ui.has_tooltip)
			end
			self.last_tooltip = ui
		end
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

function _M:setScroll(pos)
	self.scrollbar:setPos(pos)
	self.uis_container:translate(0, -self.scrollbar.pos)
end

function _M:display(x, y, nb_keyframes, ox, oy)
	if self.scrollbar then
		local oldpos = self.scrollbar.pos
		if self.scroll_inertia ~= 0 then self:setScroll(util.minBound(self.scrollbar.pos + self.scroll_inertia, 0, self.scrollbar.max)) end
		if self.scroll_inertia > 0 then self.scroll_inertia = math.max(self.scroll_inertia - nb_keyframes, 0)
		elseif self.scroll_inertia < 0 then self.scroll_inertia = math.min(self.scroll_inertia + nb_keyframes, 0)
		end
		if self.scrollbar.pos == 0 or self.scrollbar.pos == self.scrollbar.max then self.scroll_inertia = 0 end
	end
end
