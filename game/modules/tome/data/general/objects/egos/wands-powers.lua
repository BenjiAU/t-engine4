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

--[[
Wands
*detection
*light
*trap destruction
*firewall
*lightning
*conjuration
]]

newEntity{
	name = " of clairvoyance", addon=true, instant_resolve=true,
	keywords = {clairvoyance=true},
	level_range = {1, 50},
	rarity = 20,

	charm_power_def = {add=8, max=10, floor=true},
	resolvers.charm(function(self, who)
		return ("reveal the area around you, dispelling darkness (radius %d, power %d based on Magic), and detect the presence of nearby creatures for 3 turns"):format(self.use_power.radius(self, who), self.use_power.litepower(self, who))
	end,
	6,
	function(self, who)
		local rad = self.use_power.radius(self, who)
		who:setEffect(who.EFF_SENSE, 3, {
			range = rad,
			actor = 1,
		})
		game.logSeen(who, "%s uses %s %s!", who.name:capitalize(), who:his_her(), self:getName({no_add_name = true, do_color = true}))
		who:project({type="ball", range=0, selffire=true, radius=rad}, who.x, who.y, engine.DamageType.LITE, self.use_power.litepower(self, who))

		return {id=true, used=true}
	end,
	"T_GLOBAL_CD",
	{no_npc_use=true,
	radius = function(self, who) return self:getCharmPower(who) end,
	litepower = function(self, who) return who:combatStatScale("mag", 25, 75) + self:getCharmPower(who) end}),
}

newEntity{
	name = " of lightning storm", addon=true, instant_resolve=true,
	keywords = {lightning_storm=true},
	level_range = {1, 50},
	rarity = 10,

	charm_power_def = {add=25, max=400, floor=true},
	resolvers.charm(function(self, who)
		local dam = who:damDesc(engine.DamageType.LIGHTNING, self.use_power.damage(self, who))
		local radius = self.use_power.radius
		local duration = 5
		return ("create a radius %d storm for %d turns. Each turn, enemies within take %d lightning damage and will be dazed for 1 turn"):format(radius, duration, math.floor(dam / duration))
	end,
	15,
	function(self, who)
		local tg = self.use_power.target(self, who)
		local x, y = who:getTarget(tg)
		if not x or not y then return nil end
		local dam = {dam = who:spellCrit(self.use_power.damage(self, who)) / 5, daze = 100, daze_duration = 1}
		game.logSeen(who, "%s conjures a lightning storm from %s %s!", who.name:capitalize(), who:his_her(), self:getName({no_add_name = true, do_color = true}))
		local DamageType = require "engine.DamageType"
		local MapEffect = require "engine.MapEffect"
		who:project(tg, x, y, function(px, py)
			game.level.map:addEffect(who, px, py, 5, DamageType.LIGHTNING_DAZE, dam, 0, 5, nil, 
				MapEffect.new{color_br=30, color_bg=150, color_bb=160, effect_shader="shader_images/retch_effect.png"}, nil, true)
			--overlay_particle={zdepth=6, only_one=true, type="circle", args={appear=8, oversize=0, img="moon_circle", radius=self:getTalentRadius(t)}}
		end)
		game:playSoundNear(who, "talents/lightning")
		return {id=true, used=true}
	end,
	"T_GLOBAL_CD",
	{
	range = 8,
	radius = 3,
	requires_target = true,
	no_npc_use = function(self, who) return self:restrictAIUseObject(who) end, -- don't let dumb ai hurt friends
	target = function(self, who) return {type="ball", range=self.use_power.range, radius=self.use_power.radius} end,
	tactical = {ATTACKAREA = {FIRE = 2}},
	damage = function(self, who) return self:getCharmPower(who) end
	}),
}

newEntity{
	name = " of conjuration", addon=true, instant_resolve=true,
	keywords = {conjure=true},
	level_range = {1, 50},
	rarity = 10,
	resolvers.genericlast(function(e)
		local DamageType = require "engine.DamageType"
		e.elem = rng.table{
			{DamageType.FIRE, "flame", "fire"},
			{DamageType.COLD, "freeze", "cold"},
			{DamageType.LIGHTNING, "lightning_explosion", "lightning"},
			{DamageType.ACID, "acid", "acid"},
		}
	end),

	charm_power_def = {add=50, max=700, floor=true},
	resolvers.charm(function(self, who)
			local dam = self.use_power.damage(self, who)
			return ("fire a magical bolt dealing %d %s damage"):format(dam, self.elem[3] )
		end,
		10,
		function(self, who)
			local tg = self.use_power.target(self, who)
			local x, y = who:getTarget(tg)
			if not x or not y then return nil end
			local dam = self.use_power.damage(self, who)
			local elem = self.elem
			game.logSeen(who, "%s activates %s %s!", who.name:capitalize(), who:his_her(), self:getName({no_add_name = true, do_color = true}))
			who:project(tg, x, y, elem[1], who:spellCrit(dam), {type=elem[2]})
			game:playSoundNear(who, "talents/fire")
			return {id=true, used=true}
		end,
		"T_GLOBAL_CD",
		{ range = 8,
		requires_target = true,
		target = function(self, who) return {type="bolt", range=self.use_power.range} end,
		damage = function(self, who) return self:getCharmPower(who) end,
		tactical = {ATTACK = 1}}
	),
}
