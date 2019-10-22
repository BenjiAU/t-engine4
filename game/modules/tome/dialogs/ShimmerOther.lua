-- ToME - Tales of Maj'Eyal
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
local Dialog = require "engine.ui.Dialog"
local Textzone = require "engine.ui.Textzone"
local ActorFrame = require "engine.ui.ActorFrame"
local List = require "engine.ui.List"

module(..., package.seeall, class.inherit(Dialog))

function _M:init(player, slot)
	self.slot = slot
	self.true_actor = player
	self.actor = player:cloneFull()
	self.actor.x, self.actor.y = nil, nil
	self.actor:removeAllMOs()

	Dialog.init(self, "Shimmer: "..self:getShimmerName(), 680, 500)

	self:generateList()

	self.c_list = List.new{scrollbar=true, width=300, height=self.ih - 5, list=self.list, fct=function(item) self:use(item) end, select=function(item) self:select(item) end}
	local donatortext = ""
	if not profile:isDonator(1) then donatortext = "\n#{italic}##CRIMSON#This cosmetic feature is only available to donators/buyers. You can only preview.#WHITE##{normal}#" end
	local help = Textzone.new{width=math.floor(self.iw - self.c_list.w - 20), height=self.ih, no_color_bleed=true, auto_height=true, text="You can alter your look.\n#{bold}#This is a purely cosmetic change.#{normal}#"..donatortext}
	local actorframe = ActorFrame.new{actor=self.actor, w=128, h=128}

	self:loadUI{
		{left=0, top=0, ui=self.c_list},
		{right=0, top=0, ui=help},
		{right=(help.w - actorframe.w) / 2, vcenter=0, ui=actorframe},
	}
	self:setupUI(false, true)

	self.key:addBinds{
		EXIT = function()
			game:unregisterDialog(self)
		end,
	}
end

function _M:getShimmerName()
	if self.slot == "SHIMMER_DOLL" then return "Character's Skin"
	elseif self.slot == "SHIMMER_HAIR" then return "Character's Hair"
	elseif self.slot == "SHIMMER_FACIAL" then return "Character's Facial Features"
	elseif self.slot == "SHIMMER_AURA" then return "Character's Aura"
	end
	return "unknown"
end

function _M:applyShimmer(actor, shimmer)
	if not shimmer then return self:resetShimmer(actor) end

	if self.slot == "SHIMMER_DOLL" then
		actor.moddable_tile_base_shimmer = shimmer.moddable_tile
	elseif self.slot == "SHIMMER_HAIR" then
		actor.moddable_tile_base_shimmer_hair = shimmer.moddable_tile
	elseif self.slot == "SHIMMER_FACIAL" then
		actor.moddable_tile_base_shimmer_facial = shimmer.moddable_tile
	elseif self.slot == "SHIMMER_AURA" then
		actor.moddable_tile_base_shimmer_aura = shimmer.moddable_tile
		actor.moddable_tile_base_shimmer_particle = shimmer.moddable_tile2
	end
end

function _M:resetShimmer(actor)
	if self.slot == "SHIMMER_DOLL" then
		actor.moddable_tile_base_shimmer = nil
	elseif self.slot == "SHIMMER_HAIR" then
		actor.moddable_tile_base_shimmer_hair = nil
	elseif self.slot == "SHIMMER_FACIAL" then
		actor.moddable_tile_base_shimmer_facial = nil
	elseif self.slot == "SHIMMER_AURA" then
		actor.moddable_tile_base_shimmer_aura = nil
		actor.moddable_tile_base_shimmer_particle = nil
	end
end

function _M:use(item)
	if not item then end
	game:unregisterDialog(self)

	if profile:isDonator(1) then
		self:applyShimmer(self.true_actor, item.moddables)
		self.true_actor:updateModdableTile()
	else
		Dialog:yesnoPopup("Donator Cosmetic Feature", "This cosmetic feature is only available to donators/buyers.", function(ret) if ret then
			game:registerDialog(require("mod.dialogs.Donation").new("shimmer ingame"))
		end end, "Donate", "Cancel")
	end
end

function _M:select(item)
	if not item then end
	self:applyShimmer(self.actor, item.moddables)
	self.actor:updateModdableTile()
end

function _M:generateList()
	local unlocked = world.unlocked_shimmers and world.unlocked_shimmers[self.slot] or {}
	local list = {}

	list[#list+1] = {
		moddables = nil,
		name = "#GREY#[Default]",
		sortname = "--",
	}

	for name, data in pairs(unlocked) do
		local d = {
			moddables = table.clone(data.moddables, true),
			name = name,
			sortname = name:removeColorCodes(),
		}
		d.moddables.name = name
		list[#list+1] = d
	end
	table.sort(list, "sortname")

	self.list = list
end
