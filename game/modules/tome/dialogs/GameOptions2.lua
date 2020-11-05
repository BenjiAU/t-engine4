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
local TreeList = require "engine.ui.TreeList"
local Dropdown = require "engine.ui.Dropdown"
local Textzone = require "engine.ui.Textzone"
local TextzoneList = require "engine.ui.TextzoneList"
local Separator = require "engine.ui.Separator"
local Header = require "engine.ui.Header"
local LayoutContainer = require "engine.ui.LayoutContainer"
local GetQuantity = require "engine.dialogs.GetQuantity"
local GetQuantitySlider = require "engine.dialogs.GetQuantitySlider"
local Tabs = require "engine.ui.Tabs"
local GraphicMode = require("mod.dialogs.GraphicMode")
local FontPackage = require "engine.FontPackage"

module(..., package.seeall, class.inherit(Dialog))

function _M:init()
	-- we can be called from the boot menu, so make sure to load initial settings in this case
	dofile("/mod/settings.lua")

	Dialog.init(self, _t"Options", game.w * 0.6, game.h * 0.8)

	self.vsep = Separator.new{dir="horizontal", size=self.ih - 10}
	self.c_desc = TextzoneList.new{width=math.floor((self.iw - self.vsep.w)/2), height=self.ih}

	local tabs = {
		{title=_t"Video", kind="video"},
		{title=_t"Audio", kind="audio"},
		{title=_t"UI", kind="ui"},
		{title=_t"Gameplay", kind="gameplay"},
		{title=_t"Online", kind="online"},
		{title=_t"Misc", kind="misc"}
	}
	self:triggerHook{"GameOptions2:tabs", tab=function(title, fct)
		local id = #tabs+1
		tabs[id] = {title=title, kind="hooktab"..id}
		self['generateListHooktab'..id] = fct
	end}

	self.c_tabs = Tabs.new{width=self.iw - 5, tabs=tabs, on_change=function(kind) self:switchTo(kind) end}

	self.c_layout = LayoutContainer.new{width=self.iw, height=self.ih - self.c_tabs.h, uis={}}

	self:loadUI{
		{left=0, top=0, ui=self.c_tabs},
		{left=0, top=self.c_tabs, ui=self.c_layout},
	}
	self:setupUI()

	self:switchTo("video")

	self.key:addBinds{
		EXIT = function() game:unregisterDialog(self) end,
	}
end

function _M:select(item)
	if item and self.uis[3] then
		self.c_desc:switchItem(item, item.zone)
	end
end

function _M:isTome()
	return game.__mod_info.short_name == "tome"
end

function _M:addOptionLine(...)
	local uis = self.c_layout.uis
	local add_uis = {...}
	local last_h = uis[#uis] and uis[#uis].h or 0
	for i, ui in ipairs(add_uis) do
		local prev = i > 1 and add_uis[i-1].w or 0
		uis[#uis+1] = {left=prev, top=last_h, ui=ui}
	end
end

function _M:switchTo(kind)
	self['generateList'..kind:capitalize()](self)
	self:triggerHook{"GameOptions2:generateList", list=self.list, kind=kind}

	local uis = {}
	self.c_layout.uis = uis

	uis[#uis+1] = {left=0, top=0, ui=Header.new{width=self.iw, text=_t"Resolution", color=colors.simple1(colors.GOLD)}}

	local modes = {
		{name=_t"Fullscreen", mode="fullscreen"},
		{name=_t"Borderless", mode="borderless"},
		{name=_t"Windowed", mode="windowed"},
	}
	self:addOptionLine(
		Textzone.new{auto_width=true, auto_height=true, text=_t"Mode: "},
		Dropdown.new{width=150, fct=function(item)  end, on_select=function(item) end, list=modes}
	)
	table.print(uis)

	self.c_layout:generate()
end

function _M:generateListVideo()

end

function _M:generateListUi()
end

function _M:generateListGameplay()
end

function _M:generateListOnline()
end

function _M:generateListMisc()
end
