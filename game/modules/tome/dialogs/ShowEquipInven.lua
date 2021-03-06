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
local Dialog = require "engine.ui.Dialog"
local Inventory = require "engine.ui.Inventory"
local Separator = require "engine.ui.Separator"
local EquipDoll = require "engine.ui.EquipDoll"
local Tab = require "engine.ui.Tab"

module(..., package.seeall, class.inherit(Dialog))

function _M:init(title, equip_actor, filter, action, on_select, inven_actor, force_equipdoll)
	self.force_equipdoll = force_equipdoll
	self.action = action
	self.filter = filter
	inven_actor = inven_actor or equip_actor
	self.equip_actor = equip_actor
	self.inven_actor = inven_actor
	game.tooltip.add_map_str = nil

	if not inven_actor:getInven("INVEN") then -- set up default inventory if missing
		print("[ShowEquipInven] initiating inventory INVEN_INVEN for", inven_actor.name, inven_actor.uid)
		inven_actor.inven[inven_actor.INVEN_INVEN] = {worn=false, id=inven_actor.INVEN_INVEN, name="INVEN", max = 10}
	end
	Dialog.init(self, title or _t"Inventory", math.max(800, game.w * 0.8), math.max(600, game.h * 0.8))

	self.c_main_set = Tab.new{title=_t"Main Set", default=not equip_actor.off_weapon_slots, fct=function() end, on_change=function(s) if s then self:switchSets("main") end end}
	self.c_off_set = Tab.new{title=_t"Off Set", default=equip_actor.off_weapon_slots, fct=function() end, on_change=function(s) if s then self:switchSets("off") end end}

	local vsep = Separator.new{dir="horizontal", size=self.ih - 10}

	-- Add tooltips
	self.on_select = function(item)
		if item.last_display_x and item.object then
			local x
			if self.focus_ui and self.focus_ui.ui == self.c_inven then x = self.c_inven._last_ox - game.tooltip.w end
			game:tooltipDisplayAtMap(x or item.last_display_x, item.last_display_y, item.object:getDesc({do_color=true}, self.equip_actor:getInven(item.object:wornInven()), nil, equip_actor))
		elseif item.last_display_x and item.data and item.data.desc then
			game:tooltipDisplayAtMap(item.last_display_x, item.last_display_y, item.data.desc, {up=true})
		end
	end

	self.c_doll = EquipDoll.new{
		equipdoll = self.force_equipdoll or nil,
		subobject=equip_actor:attr("can_tinker") and "getTinker" or nil,
		subobject_restrict_slots=equip_actor.tinker_restrict_slots,
		actor=equip_actor, drag_enable=true, filter=filter,
		fct = function(item, button, event) self:use(item, button, event) end,
		on_select = function(ui, inven, item, o) if ui.ui.last_display_x then self:select{last_display_x=ui.ui.last_display_x+ui.ui.w, last_display_y=ui.ui.last_display_y, object=o} end end,
		actorWear = function(ui, wear_inven, wear_item, wear_o)
			if wear_o.is_tinker then
				local base_inven, base_item = ui.inven, ui.item
				-- Find appropriate slot
				if not base_inven or not base_item then
					base_inven, base_item = self:findTinkerSpot(wear_o)
				end
				if base_inven and base_item then
					local base_o = base_inven[base_item]
					self.equip_actor:doWearTinker(wear_inven, wear_item, wear_o, base_inven, base_item, base_o, true)
				end
			else
				local inven = ui.inven and self.equip_actor:getInven(ui.inven)
				if inven and self.equip_actor:canWearObject(wear_o, inven.name) then
					-- Force inventory and item
					self.equip_actor:doWear(wear_inven, wear_item, wear_o, self.inven_actor, ui.inven, ui.item)
					ui:forceUpdate()
				else
					self.equip_actor:doWear(wear_inven, wear_item, wear_o, self.inven_actor)
				end
			end
			self.c_inven:generateList()
		end
	}
	self.c_inven = Inventory.new{actor=inven_actor, inven=inven_actor:getInven("INVEN") or {}, width=self.iw - vsep.w - self.c_doll.w, height=self.ih - 10, filter=filter,
		default_last_tabs = "all",
		fct=function(item, sel, button, event) self:use(item, button, event) end,
		select=function(item, sel) self:select(item) end,
		select_tab=function(item) self:select(item) end,
		on_drag=function(item) self:onDrag(item) end,
		on_drag_end=function() self:onDragTakeoff() end,
		special_bg=function(item) if item.object and item.object.__transmo then return colors.GOLD end end,
	}
	
	self.c_inven.c_inven.on_focus_change = function(ui_self, status) if status == true then self:select(ui_self.list[ui_self.sel], true) end end

	local uis = {
		{left=0, top=0, ui=self.c_main_set},
		{left=self.c_main_set, top=0, ui=self.c_off_set},
		{left=0, top=self.c_main_set, ui=self.c_doll},
		{right=0, top=0, ui=self.c_inven},
		{left=self.c_doll.w, top=5, ui=vsep},
	}

	self:triggerHook{"EquipInvenDialog:makeUI", uis=uis}

	self:loadUI(uis)
	self:setFocus(self.c_inven)
	self:setupUI()

	if not self.equip_actor.quickSwitchWeapons then
		self:toggleDisplay(self.c_main_set, false)
		self:toggleDisplay(self.c_off_set, false)
	end
	
	local lock_tooltip = function()
		if not game.tooltip.empty then
			game.tooltip.locked = not game.tooltip.locked
			game.tooltip.container.focused = game.tooltip.locked
			game.log("Tooltip %s", game.tooltip.locked and _t"locked" or _t"unlocked")
			if game.tooltip.locked then
				self.old_areas_name = self.mouse.areas_name
				self.old_areas = self.mouse.areas
				self.mouse:reset()
				local on_mouse = function(button, x, y, xrel, yrel, bx, by, event)
					if button == "wheelup" and event == "button" then
						game.tooltip.container.scroll_inertia = math.min(game.tooltip.container.scroll_inertia, 0) - 5
					elseif button == "wheeldown" and event == "button" then 
						game.tooltip.container.scroll_inertia = math.max(game.tooltip.container.scroll_inertia, 0) + 5
					end
					if button == "middle" then
						if not self.scroll_drag then
							self.scroll_drag = true
							self.scroll_drag_x_start = x
							self.scroll_drag_y_start = y
						else
							game.tooltip.container.scrollbar.pos = util.minBound(game.tooltip.container.scrollbar.pos + y - self.scroll_drag_y_start, 0, game.tooltip.container.scrollbar.max)
							self.scroll_drag_x_start = x
							self.scroll_drag_y_start = y
						end
					else
						self.scroll_drag = false
					end
				end
				self.mouse:registerZone(0, 0, self.w, self.h, on_mouse)
			else
				self.mouse.areas_name = self.old_areas_name
				self.mouse.areas = self.old_areas
			end
		end
	end

	self.key:reset()
	engine.interface.PlayerHotkeys:bindAllHotkeys(self.key, function(i) self:defineHotkey(i) end)
	self.key.any_key = function(sym)
		-- Control resets the tooltip
		if sym == self.key._LCTRL or sym == self.key._RCTRL then 
			local ctrl = core.key.modState("ctrl")
			if self.prev_ctrl ~= ctrl then self:select(self.cur_item, true) end
			self.prev_ctrl = ctrl
		end
	end
	
	self.key:addCommands{
		[{"_TAB","shift"}] = function() self:moveFocus(1) end,
	}
	self.key:addBinds{
		ACCEPT = function() if self.focus_ui and self.focus_ui.ui == self.c_inven then self:use(self.c_inven.c_inven.list[self.c_inven.c_inven.sel]) end end,
		EXIT = function()
			if self.c_inven.c_inven.scrollbar then
				self.equip_actor.inv_scroll = self.c_inven.c_inven.scrollbar.pos or 0
			end
			game.tooltip.locked = false
			game:unregisterDialog(self)
		end,
		MOVE_UP = function() game.log("up") if game.tooltip.locked then game.tooltip.container.scroll_inertia = math.min(game.tooltip.container.scroll_inertia, 0) - 5 end end,
		MOVE_DOWN = function() if game.tooltip.locked then game.tooltip.container.scroll_inertia = math.max(game.tooltip.container.scroll_inertia, 0) + 5 end end,
		LOCK_TOOLTIP = lock_tooltip,
		LOCK_TOOLTIP_COMPARE = lock_tooltip,
		SCREENSHOT = function() if type(game) == "table" and game.key then game.key:triggerVirtual("SCREENSHOT") end end,
	}
	if self.equip_actor.inv_scroll and self.c_inven.c_inven.scrollbar then
		self.c_inven.c_inven.scrollbar.pos = util.bound(self.equip_actor.inv_scroll, 0, self.c_inven.c_inven.scrollbar.max)
	end
end

function _M:switchSets(which)
	if not self.equip_actor.quickSwitchWeapons then return end
	if which == "main" and not self.equip_actor.off_weapon_slots then return end
	if which == "off" and self.equip_actor.off_weapon_slots then return end

	self.equip_actor:quickSwitchWeapons()

	self.c_main_set.selected = not self.equip_actor.off_weapon_slots
	self.c_off_set.selected = self.equip_actor.off_weapon_slots
end

function _M:firstDisplay()
	self.cur_item = nil
	self.c_inven.c_inven:onSelect(true)
end

function _M:on_register()
	if not self.inven_actor:getInven("INVEN") then
		Dialog:simplePopup(_t"No Inventory", ("%s Has no defined main inventory"):tformat(self.inven_actor:getName():capitalize()))
		game:unregisterDialog(self)
	else
		game:onTickEnd(function() self.key:unicodeInput(true) end)
	end
end

function _M:defineHotkey(id)
	if self.equip_actor ~= self.inven_actor then return end
	if not self.equip_actor or not self.equip_actor.hotkey then return end

	local item = nil
	if self.focus_ui and self.focus_ui.ui == self.c_inven then item = self.c_inven.c_inven.list[self.c_inven.c_inven.sel]
	elseif self.focus_ui and self.focus_ui.ui == self.c_doll then item = {object=self.c_doll:getItem()}
	end
	if not item or not item.object then return end

	self.equip_actor.hotkey[id] = {"inventory", item.object:getName{no_add_name=true, no_count=true}}
	self:simplePopup(("Hotkey %s assigned"):tformat(id), item.object:getName{no_add_name=true, no_count=true}:capitalize().." assigned to hotkey "..id)
	self.equip_actor.changed = true
end

function _M:select(item, force)
	--if self.cur_item == item and not force then return end
	if item then self.on_select(item) end
	self.cur_item = item
end

function _M:use(item, button, event)
	if self.c_inven.c_inven.scrollbar then
		self.equip_actor.inv_scroll = self.c_inven.c_inven.scrollbar.pos or 0
	end
	if item then
		if self.action(item.object, item.inven, item.item, button, event) then
			game:unregisterDialog(self)
		end
	end
end

function _M:unload()
	for inven_id = 1, #self.inven_actor.inven_def do if self.inven_actor.inven[inven_id] then for item, o in ipairs(self.inven_actor.inven[inven_id]) do o:forAllStack(function(so) so.__new_pickup = nil end) end end end
end

function _M:updateTitle(title)
	Dialog.updateTitle(self, title)

	local green = colors.LIGHT_GREEN
	local red = colors.LIGHT_RED

	local enc, max = self.equip_actor:getEncumbrance(), self.equip_actor:getMaxEncumbrance()
	local v = math.min(enc, max) / max
	self.title_fill = self.iw * v
	self.title_fill_color = {
		r = util.lerp(green.r, red.r, v),
		g = util.lerp(green.g, red.g, v),
		b = util.lerp(green.b, red.b, v),
	}
	if self.equip_actor.inv_scroll and self.c_inven.c_inven.scrollbar then
		self.c_inven.c_inven.scrollbar.pos = util.bound(self.equip_actor.inv_scroll, 0, self.c_inven.c_inven.scrollbar.max)
	end
end

function _M:onDrag(item)
	if item and item.object then
		local s = item.object:getEntityFinalSurface(nil, 64, 64)
		local x, y = core.mouse.get()
		game.mouse:startDrag(x, y, s, {kind="inventory", item_idx=item.item, inven=item.inven, object=item.object, id=item.object:getName{no_add_name=true, force_id=true, no_count=true}}, function(drag, used)
			if not used then
				local x, y = core.mouse.get()
				game.mouse:receiveMouse("drag-end", x, y, true, nil, {drag=drag})
			end
		end)
	end
end

function _M:onDragTakeoff()
	local drag = game.mouse.dragged.payload

	if drag.kind == "inventory" and drag.inven and self.equip_actor:getInven(drag.inven) and self.equip_actor:getInven(drag.inven).worn and drag.object.is_tinker then
		self.equip_actor:doTakeoffTinker(self.equip_actor:getInven(drag.inven)[drag.item_idx], drag.object)
		self.c_inven:generateList()
		game.mouse:usedDrag()
	elseif drag.kind == "inventory" and drag.inven and self.equip_actor:getInven(drag.inven) and self.equip_actor:getInven(drag.inven).worn then
		self.equip_actor:doTakeoff(drag.inven, drag.item_idx, drag.object, nil, self.inven_actor)
		self.c_inven:generateList()
		game.mouse:usedDrag()
	end
end

function _M:drawFrame(x, y, r, g, b, a)
	Dialog.drawFrame(self, x, y, r, g, b, a)
	if r == 0 then return end -- Drawing the shadow
	if self.ui ~= "metal" then return end
	if not self.title_fill then return end

	core.display.drawQuad(x + self.frame.title_x, y + self.frame.title_y, self.title_fill, self.frame.title_h, self.title_fill_color.r, self.title_fill_color.g, self.title_fill_color.b, 60)
end

function _M:generateList()
	self.c_inven:generateList()
end

function _M:findTinkerSpot(tinker)
	return self.equip_actor:findTinkerSpot(tinker)
end
