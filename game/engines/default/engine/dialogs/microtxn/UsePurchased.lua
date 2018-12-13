-- TE4 - T-Engine 4
-- Copyright (C) 2009 - 2017 Nicolas Casalini
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
local Entity = require "engine.Entity"
local Dialog = require "engine.ui.Dialog"
local Image = require "engine.ui.Image"
local Textzone = require "engine.ui.Textzone"
local ListColumns = require "engine.ui.ListColumns"
local Button = require "engine.ui.Button"

module(..., package.seeall, class.inherit(Dialog))

function _M:init(mode)
	if not mode then mode = core.steam and "steam" or "te4" end
	self.mode = mode

	self.cart = {}

	self.base_title_text = game.__mod_info.long_name.." #GOLD#Purchased Options#LAST#"
	Dialog.init(self, self.base_title_text, game.w * 0.8, game.h * 0.8)

	self.categories_icons = {
		pay2die = Entity.new{image="/data/gfx/mtx/ui/category_pay2die.png"},
		community = Entity.new{image="/data/gfx/mtx/ui/category_community.png"},
		cosmetic = Entity.new{image="/data/gfx/mtx/ui/category_cosmetic.png"},
		misc = Entity.new{image="/data/gfx/mtx/ui/category_misc.png"},
	}
	local in_cart_icon = Entity.new{image="/data/gfx/mtx/ui/in_cart.png"},

	self:generateList()

	self.c_waiter = Textzone.new{auto_width=1, auto_height=1, text="#YELLOW#-- connecting to server... --"}
	self.c_list = ListColumns.new{width=self.iw, height=self.ih, scrollbar=true, sortable=true, columns={
		{name="Name", width=80, display_prop="display_name"},
		{name="Available", width=20, display_prop="nb_available"},
	}, list=self.list, all_clicks=true, fct=function(item, _, button) self:use(item, button) end, select=function(item, sel) end}

	self:loadUI{
		{vcenter=0, hcenter=0, ui=self.c_waiter},
		{left=0, top=0, ui=self.c_list},
	}
	self:setupUI(false, false)
	self:toggleDisplay(self.c_list, false)

	self.key:addBinds{
		ACCEPT = "EXIT",
		EXIT = function()
			game:unregisterDialog(self)
			if on_exit then on_exit() end
		end,
	}
end

function _M:use(item, button)
	if not item then return end

	if item.once_per_character and game.state["has_"..item.effect] then
		Dialog:simplePopup(item.name, "This option may only be used once per character to prevent wasting it.")
		return
	end

	if (item.community_event or item.self_event) and not game.state:allowOnlineEvent() then
		Dialog:simpleLongPopup(item.name, [[This option requires you to accept to receive events from the server.
Either you have the option currently disabled or you are playing a campaign that can not support these kind of events (mainly the Arena).
Make sure you have #GOLD##{bold}#Allow online events#WHITE##{normal}# in the #GOLD##{bold}#Online#WHITE##{normal}# section of the game options set to "all". You can set it back to your own setting once you have received the event.
]], 600)
		return
	end

	Dialog:yesnoPopup(item.name, ("You are about to use a charge of this option. You currently have %d charges remaining."):format(item.nb_available), function(ret) if ret then
		local popup = Dialog:simplePopup(item.name, "Please wait while contacting the server...", nil, true)
		profile:registerTemporaryEventHandler("MicroTxnUseActionable", function(e)
			game:unregisterDialog(popup)
			game:unregisterDialog(self)

			if e.success then
				Dialog:simplePopup(item.name, "The option has been activated.")			
			else
				Dialog:simplePopup(item.name, "There was an error from the server: "..tostring(e.error))
			end
		end)
		core.profile.pushOrder(string.format("o='MicroTxn' suborder='use_actionable' module=%q id_purchasable=%d", game.__mod_info.short_name, item.id_purchasable))
	end end)
end

function _M:generateList()
	self.list = {}

	profile:registerTemporaryEventHandler("MicroTxnListActionables", function(e)
		if e.error then
			Dialog:simplePopup("Online Store", e.error:capitalize())
			game:unregisterDialog(self)
			return
		end
		if not e.list then return end
		e.list = e.list:unserialize()
		-- table.print(e.list)

		local list = {}
		for _, item in ipairs(e.list) do
			item.img = Entity.new{image=item.image}
			item.display_name = item.img:getDisplayString().." "..item.name
			list[#list+1] = item
		end
		self.list = list
		self.c_list:setList(list)
		self:toggleDisplay(self.c_list, true)
		self:toggleDisplay(self.c_waiter, false)
		self:setFocus(self.c_list)
	end)
	core.profile.pushOrder(string.format("o='MicroTxn' suborder='get_actionables' module=%q", game.__mod_info.short_name))
end
