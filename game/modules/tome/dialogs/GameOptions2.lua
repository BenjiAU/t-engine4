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
local Button = require "engine.ui.Button"
local TreeList = require "engine.ui.TreeList"
local Dropdown = require "engine.ui.Dropdown"
local Textzone = require "engine.ui.Textzone"
local TextzoneList = require "engine.ui.TextzoneList"
local Separator = require "engine.ui.Separator"
local Header = require "engine.ui.Header"
package.loaded["engine.ui.LayoutContainer"] = nil
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
		{title=_t"Visual", kind="video"},
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

function _M:saveNumberValue(name, fct, subv, factor)
	return function(v)
		if subv then v = v[subv] end
		if factor then v = v * factor end
		loadstring(("config.settings.%s = %d"):format(name, v))()
		game:saveSettings(name, ("%s = %d\n"):format(name, v))
		if fct then fct(v) end
	end
end

function _M:saveFloatValue(name, fct, subv, factor)
	return function(v)
		if subv then v = v[subv] end
		if factor then v = v * factor end
		loadstring(("config.settings.%s = %d"):format(name, v))()
		game:saveSettings(name, ("%s = %d\n"):format(name, v))
		if fct then fct(v) end
	end
end

function _M:saveBoolValue(name, fct, subv)
	return function(v)
		if subv then v = v[subv] end
		loadstring(("config.settings.%s = %s"):format(name, v and "true" or "false"))()
		game:saveSettings(name, ("%s = %s\n"):format(name, v and "true" or "false"))
		if fct then fct(v) end
	end
end

function _M:saveArrayValue(name, fct, subv)
	return function(v)
		if subv then v = v[subv] end
		local f, s = self.save_array[name](v)
		loadstring(("config.settings.%s = %s"):format(f, s))()
		game:saveSettings(f, f.." = "..s.."\n")
		if fct then fct(v) end
	end
end

_M.save_array = {
	["tome.fonts.type"] = function(v) return "tome.fonts", ("{ type = %q, size = %q }"):format(v, "normal") end,
}

function _M:switchTo(kind)
	self['generateList'..kind:capitalize()](self)
	self:triggerHook{"GameOptions2:generateList", list=self.list, kind=kind}

	local uis = {}
	self.c_layout.uis = uis

	local modes = {
		{name=_t"Fullscreen", mode=" Fullscreen"},
		{name=_t"Borderless", mode=" Borderless"},
		{name=_t"Windowed", mode=" Windowed"},
	}
	local w, h, fullscreen, borderless = core.display.size()
	local default_mode = 3
	if borderless then default_mode = 2
	elseif fullscreen then default_mode = 1 end
	local resolutions, default_resolution = self:getResolutions()	

	local font_styles = FontPackage:list()
	local default_font_style = table.findValueSub(font_styles, config.settings.tome.fonts.type, "id")

	self.c_layout:makeUIByLines{
		{{"Header", {width=self.iw, text=_t"Display", color=colors.simple1(colors.GOLD)}}},
		{ vcenter = true,
			{            "Textzone", {auto_width=true, auto_height=true, text=_t"Mode: "}},
			{w="40%-p1", "Dropdown", {default=default_mode, list=modes}, "resolution_mode"},
			{            "Textzone", {auto_width=true, auto_height=true, text=_t"Resolution: "}},
			{w="40%-p1", "Dropdown", {default=default_resolution, list=resolutions}, "resolution_size"},
			{w="20%",    "Button",   {text="Apply", fct=function() self:changeResolution() end}},
		},
		{ vcenter = true,
			{w="50%",    "NumberSlider", {title=_t"Max FPS: ", max=60, min=5, value=config.settings.display_fps, step=1, on_change=self:saveNumberValue("display_fps", function(v) core.game.setFPS(v) end)}},
			{w="50%",    "NumberSlider", {title=_t"Gamma: ", max=300, min=50, value=config.settings.gamma_correction, step=5, on_change=self:saveNumberValue("gamma_correction", function(v) game:setGamma(v / 100) end)}},
		},
		{ vcenter = true,
			{w="50%",    "NumberSlider", {title=_t"Zoom: ", max=400, min=50, value=config.settings.screen_zoom*100, step=5, on_change=self:saveFloatValue("screen_zoom", nil, nil, 1/100)}},
		},

		{{"Header", {width=self.iw, text=_t"Shaders", color=colors.simple1(colors.GOLD)}}, vpadding_up=20},
		{ vcenter = true,
			{w="33%",    "Checkbox", {title=_t"Shaders: Advanced", default=config.settings.shaders_kind_adv, on_change=self:saveBoolValue("shaders_kind_adv")}},
			{w="33%",    "Checkbox", {title=_t"Shaders: Distortion", default=config.settings.shaders_kind_distort, on_change=self:saveBoolValue("shaders_kind_distort")}},
			{w="33%",    "Checkbox", {title=_t"Shaders: Volumetric", default=config.settings.shaders_kind_volumetric, on_change=self:saveBoolValue("shaders_kind_volumetric")}},
		},

		{{"Header", {width=self.iw, text=_t"Fonts", color=colors.simple1(colors.GOLD)}}, vpadding_up=20},
		{ vcenter = true,
			{            "Textzone", {auto_width=true, auto_height=true, text=_t"Style: "}},
			{w="50%-p1", "Dropdown", {default=default_font_style, list=font_styles, fct=self:saveArrayValue("tome.fonts.type", nil, "id")}},
			{w="50%",    "NumberSlider", {title=_t"Size: ", max=300, min=50, value=config.settings.font_scale, step=1, on_change=self:saveNumberValue("font_scale")}},
		},

		{{"Header", {width=self.iw, text=_t"Misc", color=colors.simple1(colors.GOLD)}}, vpadding_up=20},
		{ vcenter = true,
			{w="50%",    "NumberSlider", {title=_t"Particle effects density: ", max=100, min=0, value=config.settings.particles_density, step=1, on_change=self:saveNumberValue("particles_density")}},
		},
		{ vcenter = true,
			{w="50%",    "Checkbox", {title=_t"Custom mouse cursor", default=config.settings.mouse_cursor, on_change=self:saveBoolValue("mouse_cursor")}},
		},
	}

	self.c_layout:generate()
end

function _M:changeResolution(item)
	local mode = self.c_layout:getNUI("resolution_mode").value.mode
	local r = self.c_layout:getNUI("resolution_size").value.r..mode
	local _, _, w, h = r:find("^([0-9]+)x([0-9]+)")
	
	-- See if we need a restart (confirm).
	if core.display.setWindowSizeRequiresRestart(w, h, mode == " Fullscreen", mode == " Borderless") then
		Dialog:yesnoPopup(_t"Engine Restart Required"
			, ("Continue? %s"):tformat(game.creating_player and "" or _t" (progress will be saved)")
			, function(restart)
				if restart then
					local resetPos = Dialog:yesnoPopup(_t"Reset Window Position?"
						, _t"Simply restart or restart+reset window position?"
						, function(simplyRestart)
							if not simplyRestart then
								core.display.setWindowPos(0, 0)
								game:onWindowMoved(0, 0)
							end
							game:setResolution(r, true)
							-- Save game and reboot
							if not game.creating_player then game:saveGame() end
							util.showMainMenu(false, nil, nil
								, game.__mod_info.short_name, game.save_name
								, false)
						end, _t"Restart", _t"Restart with reset")
				end
			end, _t"Yes", _t"No")
	else
		game:setResolution(r, true)
	end
	
	game:unregisterDialog(self)
end

function _M:getResolutions()
	local l = {}
	local seen = {}
	for r, d in pairs(game.available_resolutions) do
		seen[d[1]] = seen[d[1]] or {}
		if not seen[d[1]][d[2]] then 
			l[#l+1] = r
			seen[d[1]][d[2]] = true
		end
	end
	table.sort(l, function(a,b)
		if game.available_resolutions[a][2] == game.available_resolutions[b][2] then
			return (game.available_resolutions[a][3] and 1 or 0) < (game.available_resolutions[b][3] and 1 or 0)
		elseif game.available_resolutions[a][1] == game.available_resolutions[b][1] then
			return game.available_resolutions[a][2] < game.available_resolutions[b][2]
		else
			return game.available_resolutions[a][1] < game.available_resolutions[b][1]
		end
	end)

	-- Makes up the list
	local list = {}
	local i = 0
	for _, r in ipairs(l) do
		local _, _, w, h = r:find("^([0-9]+)x([0-9]+)")
		local r = w.."x"..h
		list[#list+1] = { name=r, r=r }
		i = i + 1
	end

	local _, _, curw, curh = config.settings.window.size:find("^([0-9]+)x([0-9]+)")
	local cur = curw.."x"..curh
	if not table.findValueSub(list, cur, "r") then table.insert(list, {name=cur, r=cur}) end

	return list, table.findValueSub(list, cur, "r")
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
