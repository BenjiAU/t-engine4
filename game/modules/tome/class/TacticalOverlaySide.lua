-- ToME - Tales of Maj'Eyal
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
local Map = require "engine.Map"
local Tiles = require "engine.Tiles"
local Faction = require "engine.Faction"
local TacticalOverlay = require "mod.class.TacticalOverlay"

module(..., package.seeall, class.inherit(TacticalOverlay))

local BASE_W, BASE_H = 64, 64

local b_self
local b_powerful
local b_danger2
local b_danger1
local b_friend
local b_enemy
local b_neutral
local b_lifebar

function _M:setup()
	if self.setuped then return end
	self.setuped = true
	local tactic_tiles = Tiles.new(BASE_W, BASE_H, nil, nil, true, false)
	local assf_self = core.renderer.textureTile(tactic_tiles:get(nil, 0,0,0, 0,0,0, "alt_side_"..Map.faction_self, nil, nil, true))
	local assf_powerful = core.renderer.textureTile(tactic_tiles:get(nil, 0,0,0, 0,0,0, "alt_side_"..Map.faction_powerful, nil, nil, true))
	local assf_danger2 = core.renderer.textureTile(tactic_tiles:get(nil, 0,0,0, 0,0,0, "alt_side_"..Map.faction_danger2, nil, nil, true))
	local assf_danger1 = core.renderer.textureTile(tactic_tiles:get(nil, 0,0,0, 0,0,0, "alt_side_"..Map.faction_danger1, nil, nil, true))
	local assf_friend = core.renderer.textureTile(tactic_tiles:get(nil, 0,0,0, 0,0,0, "alt_side_"..Map.faction_friend, nil, nil, true))
	local assf_enemy = core.renderer.textureTile(tactic_tiles:get(nil, 0,0,0, 0,0,0, "alt_side_"..Map.faction_enemy, nil, nil, true))
	local assf_neutral = core.renderer.textureTile(tactic_tiles:get(nil, 0,0,0, 0,0,0, "alt_side_"..Map.faction_neutral, nil, nil, true))
	local ssf_self = core.renderer.textureTile(tactic_tiles:get(nil, 0,0,0, 0,0,0, "side_"..Map.faction_self, nil, nil, true))
	local ssf_powerful = core.renderer.textureTile(tactic_tiles:get(nil, 0,0,0, 0,0,0, "side_"..Map.faction_powerful, nil, nil, true))
	local ssf_danger2 = core.renderer.textureTile(tactic_tiles:get(nil, 0,0,0, 0,0,0, "side_"..Map.faction_danger2, nil, nil, true))
	local ssf_danger1 = core.renderer.textureTile(tactic_tiles:get(nil, 0,0,0, 0,0,0, "side_"..Map.faction_danger1, nil, nil, true))
	local ssf_friend = core.renderer.textureTile(tactic_tiles:get(nil, 0,0,0, 0,0,0, "side_"..Map.faction_friend, nil, nil, true))
	local ssf_enemy = core.renderer.textureTile(tactic_tiles:get(nil, 0,0,0, 0,0,0, "side_"..Map.faction_enemy, nil, nil, true))
	local ssf_neutral = core.renderer.textureTile(tactic_tiles:get(nil, 0,0,0, 0,0,0, "side_"..Map.faction_neutral, nil, nil, true))
	b_lifebar = core.renderer.textureTile(tactic_tiles:get(nil, 0,0,0, 0,0,0, "lifebar.png", nil, nil, true))

	if config.settings.tome.flagpost_tactical then
		b_self = assf_self
		b_powerful = assf_powerful
		b_danger2 = assf_danger2
		b_danger1 = assf_danger1
		b_friend = assf_friend
		b_enemy = assf_enemy
		b_neutral = assf_neutral
	else
		b_self = ssf_self
		b_powerful = ssf_powerful
		b_danger2 = ssf_danger2
		b_danger1 = ssf_danger1
		b_friend = ssf_friend
		b_enemy = ssf_enemy
		b_neutral = ssf_neutral
	end

	TacticalOverlay.setup(self, tactic_tiles)
end

function _M:init(actor)
	_M:setup()
	self.actor = actor
	self.DO = core.renderer.renderer():setRendererName("Tactical:UID:"..self.actor.uid)

	self.DO_life = core.renderer.fromTextureTable(b_lifebar, 0, 0, 1, 1, false, 1, 1, 1, 1, nil, 0)
	self.DO_life_missing = core.renderer.fromTextureTable(b_lifebar, 0, 0, 1, 1, false, 1, 1, 1, 1, nil, 0)
	self.CO_life = core.renderer.container()
	self.CO_life:add(self.DO_life)
	self.CO_life:add(self.DO_life_missing)
	self.DO:add(self.CO_life)

	self.DO_tactical = core.renderer.vertexes()
	self.DO:add(self.DO_tactical)

	TacticalOverlay.init(self)
end

function _M:update()
	TacticalOverlay.update(self)

	local w, h = Map.tile_w, Map.tile_h
	local map = game.level and game.level.map
	local friend = -100
	local lp = math.min(1, math.max(0, (tonumber(self.actor.life) or 10)) / (tonumber(self.actor.max_life) or 10) + 0.0001)
	if self.actor.faction and map then
		if not map.actor_player then friend = Faction:factionReaction(map.view_faction, self.actor.faction)
		else friend = map.actor_player:reactionToward(self.actor) end
	end

	if self.old_friend ~= friend or self.old_life ~= lp then
		local sx = w * .015625
		local dx = w * .0625 - sx
		local sy = h * .03125
		local dy = h * .953125 - sy
		if friend < 0 then sx = w * .9375 end
		local color, color_missing
		if lp > .75 then -- green
			color_missing = {0.5058, 0.7058, 0.2235}
			color = {0.1916, 0.8627, 0.3019}
		elseif lp > .5 then -- yellow
			color_missing = {0.6862, 0.6862, 0.0392}
			color = {0.9411, 0.9882, 0.1372}
		elseif lp > .25 then -- orange
			color_missing = {0.7254, 0.6450, 0}
			color = {0, 0.6117, 0.0823}
		else -- red
			color_missing = {0.6549, 0.2156, 0.1529}
			color = {0.9215, 0, 0}
		end
		if not self.old_life then
			self.CO_life:translate(sx, sy)
			self.DO_life_missing:translate(0, 0):scale(dx, dy, 1):color(1, 1, 1, 0.5)
			self.DO_life:translate(0, dy):scale(dx, 1, 1):color(1, 1, 1, 1)
		end
		self.DO_life:tween(7, "scale_y", nil, -dy * lp, "inQuad"):tween(7, "r", nil, color[1], "inQuad"):tween(7, "g", nil, color[2], "inQuad"):tween(7, "b", nil, color[3], "inQuad")
		self.DO_life_missing:tween(7, "r", nil, color_missing[1], "inQuad"):tween(7, "g", nil, color_missing[2], "inQuad"):tween(7, "b", nil, color_missing[3], "inQuad")
	end

	local tactical_texture
	if self.actor.faction and map then
		if self.actor == map.actor_player then
			tactical_texture = b_self
		elseif map:faction_danger_check(self.actor) then
			if friend >= 0 then tactical_texture = b_powerful
			else
				if map:faction_danger_check(self.actor, true) then
					tactical_texture = b_danger2
				else
					tactical_texture = b_danger1
				end
			end
		elseif friend > 0 then
			tactical_texture = b_friend
		elseif friend < 0 then
			tactical_texture = b_enemy
		else
			tactical_texture = b_neutral
		end
	end
	if tactical_texture and self.old_tactical ~= tactical_texture then
		self.DO_tactical:clear()
		core.renderer.fromTextureTable(tactical_texture, 0, 0, w, h, false, 1, 1, 1, 1, self.DO_tactical)
	end

	self.old_friend = friend
	self.old_life = lp
	self.old_tactical = tactical_texture
end
