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
local Shader = require "engine.Shader"
local Dialog = require "engine.ui.Dialog"
local Textzone = require "engine.ui.Textzone"
local FontPackage = require "engine.FontPackage"
local Quest = require "engine.Quest"

module(..., package.seeall, class.inherit(Dialog))

local statuses = {
	[-1] = _t"#LIGHT_GREEN#New#LAST# Quest!",
	[Quest.PENDING] = _t"Quest #AQUAMARINE#Updated!",
	[Quest.COMPLETED] = _t"Quest #LIGHT_GREEN#Completed!",
	[Quest.DONE] = _t"Quest #LIGHT_GREEN#Done!",
	[Quest.FAILED] = _t"Quest #CIMSON#Failed!",
}

function _M:init(quest, status)
	local use_ui = "quest"
	if quest.use_ui then use_ui = quest.use_ui end
	if status == Quest.FAILED then use_ui = "quest-fail" end
	
	if status == Quest.DONE then
		if use_ui == "quest-escort" then
			if quest.to_zigur then self.dialog_h_middles_alter = {b8 = "ui/antimagic_complete_dialogframe_8_middle.png"}
			else self.dialog_h_middles_alter = {b8 = "ui/normal_complete_dialogframe_8_middle.png"} end
		elseif use_ui == "quest-idchallenge" then self.dialog_h_middles_alter = {b8 = "ui/complete_dialogframe_8_middle.png"}
		elseif use_ui == "quest-main" then self.dialog_h_middles_alter = {b8 = "ui/complete_dialogframe_8_middle.png"}
		elseif use_ui == "quest" then self.dialog_h_middles_alter = {b8 = "ui/complete_dialogframe_8_middle.png"}
		end
	end

	self.quest = quest
	self.ui = use_ui
	Dialog.init(self, "", 666, 150)

	local add = ''
	if quest.popup_text and quest.popup_text[status] then add = quest.popup_text[status].."\n" end

	local f, fs = FontPackage:getFont("bold")
	local quest = Textzone.new{auto_width=true, auto_height=true, text=("#ANTIQUE_WHITE#Quest: #AQUAMARINE#%s"):tformat(self.quest.name), font={f, math.ceil(fs * 2)}}
	quest:setTextShadow(3)

	local info = Textzone.new{auto_width=true, auto_height=true, text=add.._t'#ANTIQUE_WHITE#(See your Journal for further details or click here)', font={f, math.ceil(fs)}}
	info:setTextShadow(3)
	
	local status = Textzone.new{ui=use_ui, auto_width=true, auto_height=true, text="#cc9f33#"..(statuses[status] or "????"), has_box=true, font={FontPackage:getFont("bignews")}}
	status:setTextShadow(3)
   
	self:loadUI{
		{hcenter=0, top=0, ui=quest},
		{hcenter=0, bottom=quest.h, ui=info},
		{hcenter=0, top=self.h * 1, ignore_size=true, ui=status},
	}
	self:setupUI(false, true)

	self.key:addBinds{
		EXIT = function() game:unregisterDialog(self) end,
		ACCEPT = function() game:unregisterDialog(self) end,
	}
end

function _M:postGenerate()
	local cx, cy = self.frame.ox1, self.frame.oy1
	local blight_t = self:getUITexture("ui/dialogframe_backglow.png")
	local blight = core.renderer.fromTextureTable(blight_t)
	self.frame_container:add(blight:translate(cx, cy - blight_t.h / 2 + self.b8.h / 2, -10))
	local swap = false
	local function glow(blight) swap = not swap blight:tween(40, "a", nil, swap and 0.5 or 1, nil, glow) end
	glow(blight)
end

-- Any clicks inside will open the journal
function _M:mouseEvent(button, x, y, xrel, yrel, bx, by, event)
	if event ~= "button" or button ~= "left" then return end
	game:unregisterDialog(self)
	game:registerDialog(require("engine.dialogs.ShowQuests").new(game.party:findMember{main=true}, self.quest.id))
end
