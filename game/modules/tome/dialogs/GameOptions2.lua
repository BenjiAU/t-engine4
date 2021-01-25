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
	self.c_reload = Button.new{text=_t"Apply & Reload", fct=function() self:applyReload() end, hide=true}
	self.c_reload.do_container:color(1, 0.5, 0.2, 1)

	local tabs = {
		{title=_t"Visual", kind="video"},
		{title=_t"Audio", kind="audio"},
		{title=_t"Map", kind="map"},
		{title=_t"UI", kind="ui"},
		{title=_t"Gameplay", kind="gameplay"},
		{title=_t"Online", kind="online"},
	}
	self:triggerHook{"GameOptions2:tabs", tab=function(title, fct)
		local id = #tabs+1
		tabs[id] = {title=title, kind="hooktab"..id}
		self['generateListHooktab'..id] = fct
	end}

	self.c_tabs = Tabs.new{width=self.iw - 5 - self.c_reload.w, tabs=tabs, on_change=function(kind) self:switchTo(kind) end}

	self.c_layout = LayoutContainer.new{width=self.iw, height=self.ih - self.c_tabs.h, allow_scroll=true, uis={}}

	self:loadUI{
		{left=0, top=0, ui=self.c_tabs},
		{right=0, top=0, ui=self.c_reload},
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

function _M:applyReload()
	game:saveGame()
	util.showMainMenu(false, nil, nil, game.__mod_info.short_name, game.save_name, false)	
end

function _M:saveNumberValue(name, fct, restart, subv, factor)
	return function(v)
		local dv
		if subv then
			v = v[subv]
			dv = loadstring("return config.settings."..name.."['"..subv.."']")()
		else
			dv = loadstring("return config.settings."..name)()
		end
		if factor then v = v * factor end
		if v == dv then return end
		loadstring(("config.settings.%s = %d"):format(name, v))()
		game:saveSettings(name, ("%s = %d\n"):format(name, v))
		if fct then fct(v) end
		if restart then self:needApply() end
	end
end

function _M:saveFloatValue(name, fct, restart, subv, factor)
	return function(v)
		local dv
		if subv then
			v = v[subv]
			dv = loadstring("return config.settings."..name.."['"..subv.."']")()
		else
			dv = loadstring("return config.settings."..name)()
		end
		if factor then v = v * factor end
		if v == dv then return end
		loadstring(("config.settings.%s = %d"):format(name, v))()
		game:saveSettings(name, ("%s = %d\n"):format(name, v))
		if fct then fct(v) end
		if restart then self:needApply() end
	end
end

function _M:saveBoolValue(name, fct, restart, subv, invert)
	return function(v)
		local dv
		if subv then
			v = v[subv]
			dv = loadstring("return config.settings."..name.."['"..subv.."']")()
		else
			dv = loadstring("return config.settings."..name)()
		end
		if invert then v = not v end
		if v == dv then return end
		loadstring(("config.settings.%s = %s"):format(name, v and "true" or "false"))()
		game:saveSettings(name, ("%s = %s\n"):format(name, v and "true" or "false"))
		if fct then fct(v) end
		if restart then self:needApply() end
	end
end

function _M:saveArrayValue(name, fct, restart, subv)
	return function(v)
		if subv then v = v[subv] end
		local f, s = self.save_array[name](v)
		loadstring(("config.settings.%s = %s"):format(f, s))()
		game:saveSettings(f, f.." = "..s.."\n")
		if fct then fct(v) end
		if restart then self:needApply() end
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

function _M:defineOption(id, pos, widget, widget_args, tooltip, restart)
	local d = pos or {}
	widget_args = widget_args or {}
	widget_args.__reload__ = restart
	d[1] = widget
	d[2] = widget_args
	d[3] = id
	if restart then
		local desc = _t"Game needs to restart to apply this change."
		if tooltip then	tooltip = tooltip.."\n---\n"..desc
		else tooltip = desc end
	end
	d[4] = tooltip
	self.cur_ui_defs.cur_line[#self.cur_ui_defs.cur_line+1] = d
end

function _M:needApply()
	self.c_reload.hide = false
end

function _M:defineLabel(text, pos, id)
	self:defineOption(id, pos, "Textzone", {auto_width=true, auto_height=true, text=text})
end

function _M:defineCheckbox(id, pos, title, fct, tooltip, restart)
	local dv = loadstring("return config.settings."..id)()
	if pos.invert_value then dv = not dv end
	self:defineOption(id, pos,
		"Checkbox", {title=title, default=dv, on_change=self:saveBoolValue(id, fct, restart, nil, pos.invert_value)},
		tooltip, restart
	)
end

function _M:defineSlider(id, pos, title, min, max, step, format, fct, tooltip, restart)
	local dv = loadstring("return config.settings."..id)()
	local formatter
	if type(format) == "string" then
		formatter = function(v) return (format):tformat(v) end
	else
		formatter = format
	end
	self:defineOption(id, pos,
		"NumberSlider", {title=title, max=max, min=min, value=dv, formatter=formatter, step=step, on_change=self:saveNumberValue(id, fct, restart)},
		tooltip, restart
	)
end

function _M:switchTo(kind)
	local uis = {}
	self.c_layout.uis = uis

	self.cur_ui_defs = {uis={}}

	self['generateList'..kind:capitalize()](self)
	self:triggerHook{"GameOptions2:generateList", list=self.list, kind=kind}

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
		"Button", {text=_t"Apply", fct=function() self:changeResolution() end, hide=true}
	)

	self:defineNextLine()
	self:defineSlider("display_fps", {w="50%"}, _t"Max FPS: ",
		5, 60, 1, "%d", function(v) core.game.setFPS(v) end
	)
	self:defineSlider("gamma_correction", {w="50%"}, _t"Gamma: ",
		50, 300, 5, "%d%%", function(v) game:setGamma(v / 100) end,
		_t"Gamma correction setting.\nIncrease this to get a brighter display.#WHITE#"
	)

	-- self:defineNextLine()
	-- self:defineOption(nil, {w="50%"},
	-- 	"NumberSlider", {title=_t"Zoom: ", max=400, min=50, value=config.settings.screen_zoom*100, step=5, on_change=self:saveFloatValue("screen_zoom", nil, true, nil, 1/100)}, 
	-- 	_t"If you have a very high DPI screen you may want to raise this value. Requires a restart to take effect.#WHITE#"
	-- )

	-------------------------------------------------------------------------------------------
	self:defineSection(_t"Fonts") -----------------------------------------------------------

	self:defineLabel(_t"Style: ")
	self:defineOption("resolution_size", {w="50%-p1"},
		"Dropdown", {default=default_font_style, list=font_styles, fct=self:saveArrayValue("tome.fonts.type", nil, true, "id")},
		nil, true
	)
	self:defineSlider("font_scale", {w="50%"}, _t"Size: ",
		50, 300, 5, "%d%%", nil, nil, true
	)

	-------------------------------------------------------------------------------------------
	self:defineSection(_t"Visual Effects") -----------------------------------------------------------

	self:defineCheckbox("shaders_kind_adv", {w="33%"}, _t"Shaders: Advanced", nil,
		_t"Activates advanced shaders.\nThis option allows for advanced effects (like water surfaces, ...). Disabling it can improve performance.",
		true
	)
	self:defineCheckbox("shaders_kind_distort", {w="33%"}, _t"Shaders: Distortion", nil,
		_t"Activates distorting shaders.\nThis option allows for distortion effects (like spell effects doing a visual distortion, ...). Disabling it can improve performance.",
		true
	)
	self:defineCheckbox("shaders_kind_volumetric", {w="33%"}, _t"Shaders: Volumetric", nil,
		_t"Activates volumetric shaders.\nThis option allows for volumetricion effects (like deep starfields). Enabling it will severely reduce performance when shaders are displayed.",
		true
	)

	self:defineNextLine()
	self:defineCheckbox("mouse_cursor", {w="33%"}, _t"Custom mouse cursor", nil,
		_t"Use the custom cursor.\nDisabling it will use your normal operating system cursor. A full exit and restart of the game may be needed to apply change.",
		true
	)
	self:defineCheckbox("tome.smooth_fov", {w="33%"}, _t"Smooth unseen fog", nil,
		_t"Enables smooth fog-of-war.\nDisabling it will make the fog of war look 'blocky' but might gain an extremely slight performance increase."
	)

	self:defineNextLine()
	self:defineSlider("tome.sharpen_display", {w="100%"}, _t"Sharpen visuals: ",
		0, 10, 1, function(v) return (v == 0) and "Disabled" or ("Level %d"):tformat(v) end, function() if self:isTome() and game.player then game.player:updateMainShader() end end,
		_t"Sharpen the tileset of the map."
	)
end

function _M:generateListAudio()
	-------------------------------------------------------------------------------------------
	self:defineSection(_t"Global") -----------------------------------------------------------

	self:defineCheckbox("audio.enable", {w="100%"}, _t"Enabled", function(v) core.sound.enable(v) end)

	-------------------------------------------------------------------------------------------
	self:defineSection(_t"Volumes") -----------------------------------------------------------

	self:defineSlider("audio.music_volume", {w="100%"}, _t"Music: ",
		0, 100, 1, "%d%%", function(v) if game.volumeMusic then game:volumeMusic(v) end end
	)

	self:defineNextLine()
	self:defineSlider("audio.effects_volume", {w="100%"}, _t"Effects: ",
		0, 100, 1, "%d%%", function(v) if game.volumeSoundEffects then game:volumeSoundEffects(v) end end
	)
end

function _M:generateListMap()
	---------------------------------------------------------------------------------------
	self:defineSection(_t"Map") -----------------------------------------------------------

	local function get_tile_style()
		local cur_tile_style = "???"
		if GraphicMode.tiles_packs[config.settings.tome.gfx.tiles] then cur_tile_style = GraphicMode.tiles_packs[config.settings.tome.gfx.tiles].name end
		return ("Map tiles style: #{underline}##GREY#%s %s#{normal}#"):tformat(cur_tile_style, config.settings.tome.gfx.size)
	end
	self:defineLabel(get_tile_style(), nil, "cur_tile_style")
	self:defineOption(nil, nil,
		"Button", {text="Change", fct=function() game:registerDialog(GraphicMode.new(function()
			self.c_layout:getNUI("cur_tile_style"):setText(get_tile_style())
			self:needApply()
		end)) end},
		_t"Select the graphical mode to display the world.\nDefault is 'Modern'.\nWhen you change it, make a new character or it may look strange.",
		true
	)
	self:defineCheckbox("tome.show_grid_lines", {w="33%",x="66%"}, _t"Visible grid lines", function() if self:isTome() then game:createMapGridLines() end end,
		_t"Draw faint lines to separate each grid, making visual positioning easier to see."
	)

	self:defineNextLine()
	self:defineSlider("tome.scroll_dist", {w="100%"}, _t"Scroll when close to map edges: ",
		1, 50, 1, nil, nil,
		_t"Defines the distance from the screen edge at which scrolling will start. If set high enough the game will always center on the player."
	)

	---------------------------------------------------------------------------------------
	self:defineSection(_t"Animations") -----------------------------------------------------------

	self:defineSlider("tome.smooth_move", {w="100%"}, _t"Creatures visual movement speed: ",
		0, 60, 1, function(v) return ("%0.2fs"):tformat(v / 30) end, function(v) if self:isTome() then engine.Map.smooth_scroll = v end end,
		_t"Make the movement of creatures and projectiles 'smooth'. When set to 0 movement will be instantaneous.\nThis is the time it takes for actors to visualy move to their new position.\n\nNote: This does not affect the turn-based idea of the game. You can move again while your character is still moving, and it will correctly update and compute a new animation."
	)

	self:defineNextLine()
	self:defineCheckbox("tome.twitch_move", {w="33%"}, _t"Creatures move & attack animations", nil,
		_t"Enables or disables 'twitch' movement.\nWhen enabled creatures will do small bumps when moving and attacking."
	)

	---------------------------------------------------------------------------------------
	self:defineSection(_t"Combat messages") -----------------------------------------------------------

	self:defineSlider("tome.flyers_fade_time", {w="100%"}, _t"Map combat messages fading speed: ",
		1, 30, 1, function(v) return ("%d%%"):tformat(v * 10) end, nil,
		_t"How long will flying text messages be visible on screen."
	)

	self:defineNextLine()
	self:defineCheckbox("tome.talents_flyers", {w="33%"}, _t"Talents activations feedback", nil,
		_t"When the player or an NPC uses a talent shows a quick popup with the talent's icon and name over its head."
	)

	---------------------------------------------------------------------------------------
	self:defineSection(_t"Tactical infos") ------------------------------------------------

	local modes = {
		{name=_t"Combined Small", mode=true, vs="true"},
		{name=_t"Combined Big", mode="old", vs="'old'"},
		{name=_t"Only Healthbars", mode="health", vs="'health'"},
		{name=_t"Nothing", mode=nil, vs="nil"},
	}
	local default_mode = table.findValueSub(modes, config.settings.tome.tactical_mode, "mode")
	if not config.settings.tome.tactical_mode_set or not default_mode then default_mode = 1 end

	self:defineLabel(_t"Mode: ")
	self:defineOption("tactical_mode", {w="50%-p1"},
		"Dropdown", {default=default_mode, list=modes, fct=function(item)
			if self:isTome() then
				game:setTacticalMode(item.mode)
			else
				config.settings.tome.tactical_mode = item.mode
				config.settings.tome.tactical_mode_set = true
				game:saveSettings("tome.tactical_mode", ("tome.tactical_mode = %s\ntome.tactical_mode_set = true\n"):format(item.vs))
			end
		end},
		_t[[Toggles between various tactical information display:
- Combined healthbar and small tactical frame
- Combined healthbar and big tactical frame
- Only healthbar
- No tactical information at all

#{italic}#You can also change this directly ingame by pressing shift+T.#{normal}#]], true
	)

	self:defineNextLine()
	self:defineCheckbox("tome.flagpost_tactical", {w="50%"}, _t"Flagpost tactical bars", nil,
		_t"Toggles between a normal or flagpost tactical bars."
	)
	self:defineCheckbox("tome.small_frame_side", {w="50%"}, _t"Healthbars position", nil,
		_t"Toggles between a bottom or side display for tactial healthbars."
	)

	---------------------------------------------------------------------------------------
	self:defineSection(_t"Visuals") ------------------------------------------------

	self:defineCheckbox("tome.weather_effects", {w="50%"}, _t"Weather effects", nil,
		_t"Enables or disables weather effects in some zones.\nDisabling it can gain some very slight performance. It will not affect previously visited zones."
	)
	self:defineCheckbox("tome.daynight", {w="50%"}, _t"Day/night light cycle", nil,
		_t"Enables or disables day/night light variations effects."
	)

	self:defineNextLine()
	self:defineCheckbox("tome.actors_seethrough", {w="50%"}, _t"Semi-transparent UI and terrains over actors", function(v) if self:isTome() then
			game.uiset:updateSeethrough()
		end end,
		_t"Enables or disables the fading of UI elements and high ground/trees/... when they would obscure the player or npcs."
	)
end

function _M:generateListUi()
	---------------------------------------------------------------------------------------
	self:defineSection(_t"Interface") ------------------------------------------------

	local uis = {{name=_t"Dark", ui="dark"}, {name=_t"Metal", ui="metal"}, {name=_t"Stone", ui="stone"}, {name=_t"Simple", ui="simple"}}
	self:triggerHook{"GameOptions:UIs", uis=uis}
	local default_ui = table.findValueSub(uis, config.settings.tome.ui_theme3, "ui")
	if not default_ui then default_ui = 1 end

	self:defineLabel(_t"Style: ")
	self:defineOption("tome.ui_theme3", {w="50%-p1"},
		"Dropdown", {default=default_ui, list=uis, fct=function(item)
			config.settings.tome.ui_theme3 = item.ui
			game:saveSettings("tome.ui_theme3", ("tome.ui_theme3 = %q\n"):format(item.ui))
			self:needApply()
		end},
		_t"Select the interface look. Dark is the default one. Simple is basic but takes less screen space.\nYou must restart the game for the change to take effect.",
		true
	)

	self:defineNextLine()
	self:defineSlider("tome.log_fade", {w="100%"}, _t"Log/chat fade time: ",
		0, 20, 1, function(v) return (v == 0) and "Disabled" or ("%ds"):tformat(v) end, nil,
		_t"How many seconds before log and chat lines begin to fade away.\nIf set to 0 the logs will never fade away."
	)

	---------------------------------------------------------------------------------------
	self:defineSection(_t"Fullscreen effects") ------------------------------------------------

	self:defineCheckbox("tome.fullscreen_stun", {w="50%"}, _t"Stun notification", function() if self:isTome() then if game.player.updateMainShader then game.player:updateMainShader() end end end,
		_t"If disabled you will not get a fullscreen notification of stun/daze effects. Beware."
	)
	self:defineCheckbox("tome.fullscreen_confusion", {w="50%"}, _t"Confusion notification", function() if self:isTome() then if game.player.updateMainShader then game.player:updateMainShader() end end end,
		_t"If disabled you will not get a fullscreen notification of confusion effects. Beware."
	)

	---------------------------------------------------------------------------------------
	self:defineSection(_t"Advanced display") ------------------------------------------------

	self:defineCheckbox("tome.display_glove_stats", {w="50%"}, _t"Always show glove combat properties", nil,
		_t"Always display the combat properties of gloves even if you don't know unarmed attack talents."
	)
	self:defineCheckbox("tome.display_shield_stats", {w="50%"}, _t"Always show shield combat properties", nil,
		_t"Always display combat properties of shields even if you don't know shield attack talents."
	)

	self:defineNextLine()
	self:defineCheckbox("tome.advanced_weapon_stats", {w="50%"}, _t"Advanced Weapon Statistics", nil,
		_t"Toggles advanced weapon statistics display."
	)

	---------------------------------------------------------------------------------------
	self:defineSection(_t"Miscellaneous") ------------------------------------------------

	self:defineCheckbox("tome.lore_popup", {w="50%"}, _t"Always show lore popup", nil,
		_t"If disabled lore popups will only appear the first time you see the lore on your profile.\nIf enabled it will appear the first time you see it with each character."
	)
	self:defineCheckbox("tome.quest_popup", {w="50%"}, _t"Big Quest Popups", nil,
		_t"If enabled new quests and quests updates will display a big popup, if not a simple line of text will fly on the screen."
	)
	
	self:defineNextLine()
	self:defineCheckbox("tome.visual_hotkeys", {w="50%"}, _t"Visual hotkeys feedback", nil,
		_t"When you activate a hotkey, either by keyboard or click a visual feedback will appear over it in the hotkeys bar."
	)

	self:defineNextLine()
	self:defineCheckbox("tome.auto_hotkey_object", {w="50%"}, _t"Always add objects to hotkeys", nil,
		_t"If disabled items with activations will not be auto-added to your hotkeys, you will need to manualty drag them from the inventory screen."
	)

	self:defineNextLine()
	self:defineCheckbox("tome.hide_gestures", {w="50%", invert_value=true}, _t"Display mouse gesture trails", nil,
		_t"When you do a mouse gesture (right click + drag) a color coded trail is displayed."
	)

	self:defineNextLine()
	self:defineCheckbox("tome.show_cloak_hoods", {w="50%"}, _t"Show cloak hoods", function()
			if self:isTome() and game.level then
				for uid, e in pairs(game.level.entities) do
					if e.updateModdableTile then e:updateModdableTile() end
				end
			end
		end,
		_t"Replace headwear images by cloak hoods if a cloak is worn."
	)

	self:defineNextLine()
	self:defineCheckbox("censor_boot", {w="50%"}, _t"Censor boot", nil,
		_t"Disallow boot images that could be found 'offensive'."
	)
end

function _M:generateListGameplay()
	---------------------------------------------------------------------------------------
	self:defineSection(_t"Movement & Targeting") ------------------------------------------------

	self:defineCheckbox("tome.use_wasd", {w="50%"}, _t"Enable WASD movement keys", function() if self:isTome() then game:setupWASD() end end,
		_t"Enable the WASD movement keys. Can be used to move diagonaly by pressing two directions at once."
	)

	self:defineNextLine()
	self:defineCheckbox("tome.mouse_move", {w="50%"}, _t"Move by mouse-clicks", nil,
		_t"Enables easy movement using the mouse by left-clicking on the map."
	)
	self:defineCheckbox("tome.disable_mouse_targeting", {w="50%", invert_value=true}, _t"Mouse targeting", nil,
		_t"Enables mouse targeting. If disabled mouse movements will not change the target when casting a spell or using a talent."
	)

	self:defineNextLine()
	self:defineCheckbox("tome.immediate_melee_keys", {w="50%"}, _t"Quick melee targeting", nil,
		_t"Enables quick melee targeting.\nTalents that require a melee target will automatically target when pressing a direction key instead of requiring a confirmation."
	)
	self:defineCheckbox("tome.immediate_melee_keys_auto", {w="50%"}, _t"Quick melee targeting auto attack", nil,
		_t"Enables quick melee targeting auto attacking.\nTalents that require a melee target will automatically target and confirm if there is only one hostile creatue around."
	)

	self:defineNextLine()
	self:defineCheckbox("tome.auto_accept_target", {w="50%"}, _t"Auto-accept targets", nil,
		_t"Auto-validate targets. If you fire an arrow/talent/... it will automatically use the default target without asking\n#LIGHT_RED#This is dangerous. Do not enable unless you know exactly what you are doing.#WHITE#\n\nDefault target is always either one of:\n - The last creature hovered by the mouse\n - The last attacked creature\n - The closest creature"
	)

	---------------------------------------------------------------------------------------
	self:defineSection(_t"Warnings") ------------------------------------------------

	self:defineSlider("tome.life_lost_warning", {w="100%"}, _t"Life Lost Warning: ",
		1, 100, 10, function(v) return (v == 100) and "Disabled" or ("< %d%%"):tformat(v) end, nil,
		_t"If you loose more than this percentage of life in a turn, a warning will display and all key/mouse input will be ignored for 2 seconds to prevent mistakes."
	)

	---------------------------------------------------------------------------------------
	self:defineSection(_t"Miscellaneous") ------------------------------------------------

	self:defineCheckbox("tome.autoassign_talents_on_birth", {w="50%"}, _t"Auto-assign talent points at birth", nil,
		_t"New games begin with some talent points auto-assigned."
	)

	self:defineNextLine()
	self:defineCheckbox("tome.rest_before_explore", {w="50%"}, _t"Rest before auto-explore", nil,
		_t"Always rest to full before auto-exploring."
	)

	self:defineNextLine()
	self:defineCheckbox("tome.tinker_auto_switch", {w="50%"}, _t"Swap tinkers", nil,
		_t"When swaping an item with a tinker attached, swap the tinker to the newly worn item automatically."
	)

	---------------------------------------------------------------------------------------
	self:defineSection(_t"Saving") ------------------------------------------------

	self:defineCheckbox("background_saves", {w="50%"}, _t"Save in the background", nil,
		_t"Saves in the background, allowing you to continue playing.\n#LIGHT_RED#Disabling it is not recommended."
	)
	self:defineCheckbox("tome.save_zone_levels", {w="50%"}, _t"Zone save per level", nil,
		_t"Forces the game to save each level instead of each zone.\nThis makes it save more often but the game will use less memory when deep in a dungeon.\n\n#LIGHT_RED#Changing this option will not affect already visited zones.\n*THIS DOES NOT MAKE A FULL SAVE EACH LEVEL*.\n#LIGHT_RED#Enabling it is not recommended"
	)
end

function _M:generateListOnline()
	---------------------------------------------------------------------------------------
	self:defineSection(_t"Online") ------------------------------------------------

	self:defineCheckbox("disable_all_connectivity", {w="100%"}, _t"#CRIMSON#Disable all connectivity", nil,
		_t[[Disables all connectivity to the network.
This includes, but is not limited to:
- Player profiles: You will not be able to login, register
- Characters vault: You will not be able to upload any character to the online vault to show your glory
- Item's Vault: You will not be able to access the online item's vault, this includes both storing and retrieving items.
- Ingame chat: The ingame chat requires to connect to the server to talk to other players, this will not be possible.
- Purchaser / Donator benefits: The base game being free, the only way to give donators their bonuses fairly is to check their online profile. This will thus be disabled.
- Easy addons downloading & installation: You will not be able to see ingame the list of available addons, nor to one-click install them. You may still do so manually.
- Version checks: Addons will not be checked for new versions.
- Discord: If you use Discord Rich Presence integration this will also be disabled by this setting.
- Ingame game news: The main menu will stop showing you info about new updates to the game.

Note that this setting only affects the game itself. If you use the game launcher, whose sole purpose is to make sure the game is up to date, it will still do so.
If you do not want that, simply run the game directly: the #{bold}#only#{normal}# use of the launcher is to update the game.

#{bold}##CRIMSON#This is an extremely restrictive setting. It is recommended you only activate it if you have no other choice as it will remove many fun and acclaimed features.
A full exit and restart of the game is neccessary to apply this setting.#{normal}#]]
	)

	---------------------------------------------------------------------------------------
	self:defineSection(_t"Ingame Chat") ------------------------------------------------

	self:defineOption("chat_filter", nil,
		"Button", {text=_t"Messages filters", fct=function()
		game:registerDialog(require("engine.dialogs.ChatFilter").new({
			{name=_t"Deaths", kind="death"},
			{name=_t"Object & Creatures links", kind="link"},
		}))
		end}
	)
	self:defineNextLine()
	self:defineOption("chat_channels", nil,
		"Button", {text=_t"Channels", fct=function() game:registerDialog(require("engine.dialogs.ChatChannels").new()) end}
	)
	self:defineNextLine()
	self:defineOption("chat_ignores", nil,
		"Button", {text=_t"Ignores list", fct=function() game:registerDialog(require("engine.dialogs.ChatIgnores").new()) end}
	)


	---------------------------------------------------------------------------------------
	self:defineSection(_t"Character Sheets") ------------------------------------------------

	self:defineCheckbox("upload_charsheet", {w="100%"}, _t"Upload characters sheets to the online vault", nil,
		_t"Keep a copy of your character sheets (not the whole savefile) on the online vault at te4.org.\nFor each character you will be given a link to this online character sheet so that you can brag about your heroic deeds or sad deaths to your friends or the whole community."
	)

	if core.discord then
		---------------------------------------------------------------------------------------
		self:defineSection(_t"Discord") ------------------------------------------------

		self:defineCheckbox("disable_discord", {w="100%", invert_value=true}, _t"Discord's Rich Presence", nil,
			_t"Enable Discord's Rich Presence integration to show your current character on your currently playing profile on Discord (restart the game to apply).\n#ANTIQUE_WHITE#If you do not use Discord this option doesn't do anything in either state.",
			true
		)
	end

	---------------------------------------------------------------------------------------
	self:defineSection(_t"Miscellaneous") ------------------------------------------------

	local online_modes = {
		{name=_t"All", mode=true, vs="true"},
		{name=_t"Only for tech support help", mode="limited", vs="'limited'"},
		{name=_t"Disabled", mode=false, vs="false"},
	}
	local default_online_mode = table.findValueSub(online_modes, config.settings.allow_online_events, "mode")
	if not default_online_mode then default_online_mode = 1 end

	self:defineLabel(_t"Online Events: ")
	self:defineOption("allow_online_events", {w="50%-p1"},
		"Dropdown", {default=default_online_mode, list=online_modes, fct=function(item)
			config.settings.allow_online_events = item.mode
			game:saveSettings("allow_online_events", ("allow_online_events = %s\n"):format(item.vs))
		end},
		_t"Allow various events that are pushed by the server when playing online\n#{bold}#All#{normal}#: Allow all server events (bonus zones, random events, ...)\n#{bold}#Technical help only#{normal}#: Allow administrator to help in case of bugs or weirdness and allows website services (data reset, steam achievements push, ...) to work.\n#{bold}#Disabled#{normal}#: Disallow all.",
		true
	)

	self:defineNextLine()
	self:defineCheckbox("open_links_external", {w="100%"}, _t"Open links in external browser", nil,
		_t"Open links in external browser instead of the embedded one.\nThis does not affect addons browse and installation which always stays ingame."
	)
end
