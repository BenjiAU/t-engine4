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

	self.c_layout = LayoutContainer.new{width=self.iw, height=self.ih - self.c_tabs.h, allow_scroll=true, uis={}}

	self:loadUI{
		{left=0, top=0, ui=self.c_tabs},
		{left=0, top=self.c_tabs, ui=self.c_layout},
	}
	self:setupUI()

	self:switchTo("video")

	self.key:addCommands{
		_UP = function() end,
		_DOWN = function() end,
		_LEFT = function() end,
		_RIGHT = function() end,
	}

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

function _M:defineSection(title, color)
	if self.cur_ui_defs.cur_line then
		self.cur_ui_defs.uis[#self.cur_ui_defs.uis+1] = self.cur_ui_defs.cur_line
	end

	color = color or colors.simple1(colors.GOLD)
	self.cur_ui_defs.uis[#self.cur_ui_defs.uis+1] = {{w="100%", "Header", {text=title, color=color}}, vpadding_up=#self.cur_ui_defs.uis == 0 and 0 or 20}
	self.cur_ui_defs.cur_line = {vcenter=true}
end

function _M:defineNextLine()
	if self.cur_ui_defs.cur_line then
		self.cur_ui_defs.uis[#self.cur_ui_defs.uis+1] = self.cur_ui_defs.cur_line
	end
	self.cur_ui_defs.cur_line = {vcenter=true}
end

function _M:defineOption(id, pos, widget, widget_args, tooltip)
	local d = pos or {}
	d[1] = widget
	d[2] = widget_args
	d[3] = id
	d[4] = tooltip
	self.cur_ui_defs.cur_line[#self.cur_ui_defs.cur_line+1] = d
end

function _M:defineLabel(text, pos)
	self:defineOption(nil, pos, "Textzone", {auto_width=true, auto_height=true, text=text})
end

function _M:defineCheckbox(id, pos, title, fct, tooltip)
	local dv = loadstring("return config.settings."..id)()
	self:defineOption(id, pos,
		"Checkbox", {title=title, default=dv, on_change=self:saveBoolValue(id, fct)},
		tooltip
	)
end

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

	self.cur_ui_defs = {uis={}}

	-------------------------------------------------------------------------------------------
	self:defineSection(_t"Display") -----------------------------------------------------------

	self:defineLabel(_t"Mode: ")
	self:defineOption("resolution_mode", {w="30%-p1"},
		"Dropdown", {default=default_mode, list=modes, fct=function() self.c_layout:getNUI("resolution_apply").hide = false end}
	)
	self:defineLabel(_t"Resolution: ")
	self:defineOption("resolution_size", {w="30%-p1"},
		"Dropdown", {default=default_resolution, list=resolutions, fct=function() self.c_layout:getNUI("resolution_apply").hide = false end}
	)
	self:defineOption("resolution_apply", {x="100%-w-10"},
		"Button", {text="Apply", fct=function() self:changeResolution() end, hide=true}
	)

	self:defineNextLine()
	self:defineOption(nil, {w="50%"},
		"NumberSlider", {title=_t"Max FPS: ", max=60, min=5, value=config.settings.display_fps, step=1, on_change=self:saveNumberValue("display_fps", function(v) core.game.setFPS(v) end)}
	)
	self:defineOption(nil, {w="50%"},
		"NumberSlider", {title=_t"Gamma: ", max=300, min=50, value=config.settings.gamma_correction, formatter=function(v) return ("%d%%"):tformat(v) end, step=5, on_change=self:saveNumberValue("gamma_correction", function(v) game:setGamma(v / 100) end)},
		_t"Gamma correction setting.\nIncrease this to get a brighter display.#WHITE#"
	)

	-- self:defineNextLine()
	-- self:defineOption(nil, {w="50%"},
	-- 	"NumberSlider", {title=_t"Zoom: ", max=400, min=50, value=config.settings.screen_zoom*100, step=5, on_change=self:saveFloatValue("screen_zoom", nil, nil, 1/100)}, 
	-- 	_t"If you have a very high DPI screen you may want to raise this value. Requires a restart to take effect.#WHITE#"
	-- )

	-------------------------------------------------------------------------------------------
	self:defineSection(_t"Fonts") -----------------------------------------------------------

	self:defineLabel(_t"Style: ")
	self:defineOption("resolution_size", {w="50%-p1"},
		"Dropdown", {default=default_font_style, list=font_styles, fct=self:saveArrayValue("tome.fonts.type", nil, "id")}
	)
	self:defineOption(nil, {w="50%"},
		"NumberSlider", {title=_t"Size: ", max=300, min=50, step=5, value=config.settings.font_scale, formatter=function(v) return ("%d%%"):tformat(v) end, on_change=self:saveNumberValue("font_scale")}
	)

	-------------------------------------------------------------------------------------------
	self:defineSection(_t"Visual Effects") -----------------------------------------------------------

	self:defineCheckbox("shaders_kind_adv", {w="33%"}, _t"Shaders: Advanced", nil,
		_t"Activates advanced shaders.\nThis option allows for advanced effects (like water surfaces, ...). Disabling it can improve performance.\n\n#LIGHT_RED#You must restart the game for it to take effect.#WHITE#"
	)
	self:defineCheckbox("shaders_kind_distort", {w="33%"}, _t"Shaders: Distortion", nil,
		_t"Activates distorting shaders.\nThis option allows for distortion effects (like spell effects doing a visual distortion, ...). Disabling it can improve performance.\n\n#LIGHT_RED#You must restart the game for it to take effect.#WHITE#"
	)
	self:defineCheckbox("shaders_kind_volumetric", {w="33%"}, _t"Shaders: Volumetric", nil,
		_t"Activates volumetric shaders.\nThis option allows for volumetricion effects (like deep starfields). Enabling it will severely reduce performance when shaders are displayed.\n\n#LIGHT_RED#You must restart the game for it to take effect.#WHITE#"
	)

	self:defineNextLine()
	self:defineCheckbox("mouse_cursor", {w="33%"}, _t"Custom mouse cursor", nil,
		_t"Use the custom cursor.\nDisabling it will use your normal operating system cursor.#WHITE#"
	)
	self:defineCheckbox("tome.smooth_fov", {w="33%"}, _t"Smooth unseen fog", nil,
		_t"Enables smooth fog-of-war.\nDisabling it will make the fog of war look 'blocky' but might gain an extremely slight performance increase."
	)

	-------------------------------------------------------------------------------------------
	self:defineSection(_t"Map") -----------------------------------------------------------

	self:defineOption(nil, {w="100%"},
		"NumberSlider", {title=_t"Creatures visual movement speed: ", max=60, min=0, value=config.settings.tome.smooth_move, formatter=function(v) return ("%0.2fs"):tformat(v / 30) end, step=1, on_change=self:saveNumberValue("tome.smooth_move", function(v) if self:isTome() then engine.Map.smooth_scroll = v end end)},
		_t"Make the movement of creatures and projectiles 'smooth'. When set to 0 movement will be instantaneous.\nThis is the time it takes for actors to visualy move to their new position.\n\nNote: This does not affect the turn-based idea of the game. You can move again while your character is still moving, and it will correctly update and compute a new animation."
	)

	self:defineNextLine()
	self:defineCheckbox("tome.twitch_move", {w="33%"}, _t"Creatures move & attack animations", nil,
		_t"Enables or disables 'twitch' movement.\nWhen enabled creatures will do small bumps when moving and attacking."
	)
	self:defineCheckbox("tome.show_grid_lines", {w="33%"}, _t"Visible grid lines", function() if self:isTome() then game:createMapGridLines() end end,
		_t"Draw faint lines to separate each grid, making visual positioning easier to see."
	)


	self:defineNextLine()
	self.c_layout:makeUIByLines(self.cur_ui_defs.uis)
	self.cur_uis = nil

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
