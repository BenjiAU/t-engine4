-- ToME - Tales of Middle-Earth
-- Copyright (C) 2009, 2010, 2011 Nicolas Casalini
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
require "engine.GameEnergyBased"
require "engine.interface.GameSound"
require "engine.interface.GameMusic"
require "engine.interface.GameTargeting"
require "engine.KeyBind"

local Module = require "engine.Module"
local Dialog = require "engine.ui.Dialog"
local Tooltip = require "engine.Tooltip"
local MainMenu = require "mod.dialogs.MainMenu"

local Shader = require "engine.Shader"
local Zone = require "engine.Zone"
local Map = require "engine.Map"
local Level = require "engine.Level"
local FlyingText = require "engine.FlyingText"

local NicerTiles = require "mod.class.NicerTiles"
local Grid = require "mod.class.Grid"
local Actor = require "mod.class.Actor"
local Player = require "mod.class.Player"
local NPC = require "mod.class.NPC"

module(..., package.seeall, class.inherit(engine.GameEnergyBased, engine.interface.GameMusic, engine.interface.GameSound))

-- Tell the engine that we have a fullscreen shader that supports gamma correction
support_shader_gamma = true

function _M:init()
	engine.interface.GameMusic.init(self)
	engine.interface.GameSound.init(self)
	engine.GameEnergyBased.init(self, engine.KeyBind.new(), 100, 100)
	self.profile_font = core.display.newFont("/data/font/VeraIt.ttf", 14)
	self.background = core.display.loadImage("/data/gfx/background/back.jpg")
	if self.background then
		self.background, self.background_w, self.background_h = self.background:glTexture()
	end

	self.tooltip = Tooltip.new(nil, 14, nil, colors.DARK_GREY, 400)

--	self.refuse_threads = true
	self.normal_key = self.key
	self.stopped = config.settings.boot_menu_background
	if self.stopped then
		core.game.setRealtime(0)
	else
		core.game.setRealtime(8)
	end

	self:loaded()
	profile:currentCharacter("Main Menu", "Main Menu")
end

function _M:loaded()
	engine.GameEnergyBased.loaded(self)
	engine.interface.GameMusic.loaded(self)
	engine.interface.GameSound.loaded(self)
end

function _M:run()
	self.flyers = FlyingText.new()
	self:setFlyingText(self.flyers)
	self.log = function(style, ...) end
	self.logSeen = function(e, style, ...) end
	self.logPlayer = function(e, style, ...) end
	self.nicer_tiles = NicerTiles.new()

	-- Starting from here we create a new game
	self:newGame()

	-- Ok everything is good to go, activate the game in the engine!
	self:setCurrent()

	-- Setup display
	self:registerDialog(MainMenu.new())

	-- Run the current music if any
	self:playMusic("The saga begins.ogg")

	-- Get news
	if not self.news then
		self.news = {
			title = "Welcome to T-Engine and the Tales of Maj'Eyal",
			text = [[From this interface you can create new characters for the game modules you want to play.

#GOLD#"Tales of Maj'Eyal"#WHITE# is the default game module, you can also install more by selecting "Install a game module" or by going to http://te4.org/

When inside a module remember you can press Escape to bring up a menu to change keybindings, resolution and other module specific options.

Remember that in most roguelikes death is usually permanent so be careful!

Now go and have some fun!]]
		}

		self:serverNews()
		self:updateNews()
	end

--	self:installNewEngine()

	if not self.firstrunchecked then
		-- Check first time run for online profile
		self.firstrunchecked = true
		self:checkFirstTime()
	end

	if self.s_log then
		local w, h = self.s_log:getSize()
		self.mouse:registerZone(self.w - w, self.h - h, w, h, function(button)
			if button == "left" then util.browserOpenUrl(self.logged_url) end
		end, {button=true})
	end

	-- Setup FPS
	core.game.setFPS(config.settings.display_fps)
end

function _M:newGame()
	self.player = Player.new{name=self.player_name, game_ender=true}
	Map:setViewerActor(self.player)
	self:setupDisplayMode()
	self:setGamma(config.settings.gamma_correction / 100)

	self.player:resolve()
	self.player:resolve(nil, true)
	self.player.energy.value = self.energy_to_act

	Zone:setup{npc_class="mod.class.NPC", grid_class="mod.class.Grid", }
	self:changeLevel(rng.range(1, 3), "dungeon")
end

function _M:onResolutionChange()
	local oldw, oldh = self.w, self.h
	engine.Game.onResolutionChange(self)
	if oldw == self.w and oldh == self.h then return end
	print("[RESOLUTION] changed to ", self.w, self.h)
	if not self.change_res_dialog then
		self.change_res_dialog = Dialog:yesnoPopup("Resolution changed", "Accept the new resolution?", function(ret)
			self.change_res_dialog = nil
			if ret then
				util.showMainMenu(false, nil, nil, "boot", "boot", false)
			else
				self:setResolution(oldw.."x"..oldh, true)
			end
		end, "Accept", "Revert")
	end
end

function _M:setupDisplayMode()
	Map:setViewPort(0, 0, self.w, self.h, 32, 32, nil, 22, true, true)
	Map:resetTiles()
	Map.tiles.use_images = true

	-- Create the framebuffer
	self.fbo = core.display.newFBO(game.w, game.h)
	if self.fbo then
		self.fbo_shader = Shader.new("main_fbo")
		if not self.fbo_shader.shad then
			self.fbo = nil self.fbo_shader = nil
		else
			self.fbo_shader:setUniform("colorize", {1,1,1,0.9})
		end
	end

	self.full_fbo = core.display.newFBO(self.w, self.h)
	if self.full_fbo then self.full_fbo_shader = Shader.new("full_fbo") if not self.full_fbo_shader.shad then self.full_fbo = nil self.full_fbo_shader = nil end end
end

function _M:changeLevel(lev, zone)
	local old_lev = (self.level and not zone) and self.level.level or -1000
	if zone then
		if self.zone then
			self.zone:leaveLevel(false, lev, old_lev)
			self.zone:leave()
		end
		if type(zone) == "string" then
			self.zone = Zone.new(zone)
		else
			self.zone = zone
		end
	end
	self.zone:getLevel(self, lev, old_lev)
	self.nicer_tiles:postProcessLevelTiles(self.level)

	if lev > old_lev then
		self.player:move(self.level.default_up.x, self.level.default_up.y, true)
	else
		self.player:move(self.level.default_down.x, self.level.default_down.y, true)
	end
	self.level:addEntity(self.player)
end

function _M:getPlayer()
	return self.player
end

function _M:updateNews()
	if self.news.link then
		self.tooltip:set("#AQUAMARINE#%s#WHITE#\n---\n%s\n---\n#LIGHT_BLUE##{underline}#%s#LAST##{normal}#", self.news.title, self.news.text, self.news.link)
	else
		self.tooltip:set("#AQUAMARINE#%s#WHITE#\n---\n%s", self.news.title, self.news.text)
	end

	if self.news.link then
		self.mouse:registerZone(5, self.tooltip.h - 30, self.tooltip.w, 30, function(button)
			if button == "left" then util.browserOpenUrl(self.news.link) end
		end, {button=true})
	end
end

function _M:tick()
	if self.stopped then engine.Game.tick(self) return true end
	if self.level then
		engine.GameEnergyBased.tick(self)
		-- Fun stuff: this can make the game realtime, although calling it in display() will make it work better
		-- (since display is on a set FPS while tick() ticks as much as possible
		-- engine.GameEnergyBased.tick(self)
	end
	return false
end

--- Called every game turns
-- Does nothing, you can override it
function _M:onTurn()
	if self.turn % 600 == 0 then self:changeLevel(util.boundWrap(self.level.level + 1, 1, 3)) end

	-- The following happens only every 10 game turns (once for every turn of 1 mod speed actors)
	if self.turn % 10 ~= 0 then return end

	-- Process overlay effects
	self.level.map:processEffects()
end

function _M:display(nb_keyframes)
	-- If switching resolution, blank everything but the dialog
	if self.change_res_dialog then engine.GameEnergyBased.display(self, nb_keyframes) return end

	if self.full_fbo then self.full_fbo:use(true) end

	-- If background anim is stopped, things are greatly simplified
	if self.stopped then
		if self.background then self.background:toScreenFull(0, 0, self.w, self.h, self.background_w, self.background_h) end
		self.tooltip:display()
		self.tooltip:toScreen(5, 5)
		engine.GameEnergyBased.display(self, nb_keyframes)
		if self.full_fbo then self.full_fbo:use(false) self.full_fbo:toScreen(0, 0, self.w, self.h, self.full_fbo_shader.shad) end
		return
	end

	-- Display using Framebuffer, so that we can use shaders and all
	if self.fbo then self.fbo:use(true) end

	-- Now the map, if any
	if self.level and self.level.map and self.level.map.finished then
		-- Display the map and compute FOV for the player if needed
		if self.level.map.changed then
			self.player:playerFOV()
		end

		self.level.map:display(nil, nil, nb_keyframes, true)
		self.level.map._map:drawSeensTexture(0, 0, nb_keyframes)
	end

	-- Draw it here, inside the FBO
	if self.flyers then self.flyers:display(nb_keyframes) end

	-- Display using Framebuffer, so that we can use shaders and all
	if self.fbo then
		self.fbo:use(false, self.full_fbo)
		_2DNoise:bind(1, false)
		self.fbo:toScreen(
			self.level.map.display_x, self.level.map.display_y,
			self.level.map.viewport.width, self.level.map.viewport.height,
			self.fbo_shader.shad
		)
	else
--		core.display.drawQuad(0, 0, game.w, game.h, 128, 128, 128, 128)
	end

	self.tooltip:display()
	self.tooltip:toScreen(5, 5)

	local old = self.flyers
	self.flyers = nil
	engine.GameEnergyBased.display(self, nb_keyframes)
	self.flyers = old

	if self.full_fbo then self.full_fbo:use(false) self.full_fbo:toScreen(0, 0, self.w, self.h, self.full_fbo_shader.shad) end
end

--- Ask if we really want to close, if so, save the game first
function _M:onQuit()
	if self.is_quitting then return end
	self.is_quitting = Dialog:yesnoPopup("Quit", "Really exit T-Engine/ToME?", function(ok)
		self.is_quitting = false
		if ok then os.exit() end
	end, "Quit", "Continue")
end

profile_help_text = [[#LIGHT_GREEN#T-Engine4#LAST# allows you to sync your player profile with the website #LIGHT_BLUE#http://te4.org/#LAST#

This allows you to:
* Play from several computers without having to copy unlocks and achievements.
* Keep track of your modules progression, kill count, ...
* Cool statistics for each module to help sharpen your gameplay style
* Help the game developers balance and refine the game

You will also have a user page on http://te4.org/ where you can show off your achievements to your friends.
This is all optional, you are not forced to use this feature at all, but the developers would thank you if you did as it will
make balancing easier.
Online profile requires an internet connection, if not available it will wait and sync when it finds one.]]

function _M:checkFirstTime()
	if not profile.generic.firstrun then
		profile:checkFirstRun()
		local text = "Thanks for downloading T-Engine/ToME.\n\n"..profile_help_text
		Dialog:yesnoLongPopup("Welcome to T-Engine", text, 400, function(ret)
			if ret then
				self:registerDialog(require("mod.dialogs.Profile").new())
			end
		end, "Register now", "Maybe later")
	end
end

function _M:createProfile(loginItem)
	if not loginItem.create then
		self.auth_tried = nil
		profile:performlogin(loginItem.login, loginItem.pass)
		profile:waitFirstAuth()
		if profile.auth then
			Dialog:simplePopup("Profile logged in!", "Your online profile is active now...", function() end )
		else
			Dialog:simplePopup("Login failed!", "Check your login and password or try again in in a few moments.", function() end )
		end
		return
	else
		self.auth_tried = nil
		profile:newProfile(loginItem.login, loginItem.name, loginItem.pass, loginItem.email)
		profile:waitFirstAuth()
		if profile.auth then
			Dialog:simplePopup(self.justlogin and "Logged in!" or "Profile created!", "Your online profile is active now...", function() end )
		else
			Dialog:simplePopup("Profile creation failed!", "Try again in in a few moments, or try online at http://te4.org/", function() end )
		end
	end
end

function _M:serverNews()
	local co = coroutine.create(function()
		local stop = false
		profile:getNews(function(news)
			stop = true
			if news and news.body then
				local title = news.title
				news = news.body:unserialize()
				news.title = title
				self.news = news
				self:updateNews()
			end
		end)

		while not stop do coroutine.yield() end
	end)
	game:registerCoroutine("getnews", co)
end

--- Receives a profile event
-- Overloads to detect auth
function _M:handleProfileEvent(evt)
	evt = engine.GameEnergyBased.handleProfileEvent(self, evt)
	if evt.e == "Auth" then
		local d = self.dialogs[#self.dialogs]
		if d and d.__CLASSNAME == "mod.dialogs.MainMenu" then
			d:on_recover_focus()
		end
	end
	return evt
end
