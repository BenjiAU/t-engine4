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
Torques
*psionic shield
*clear mind
*mind wave
]]

newEntity{
	name = " of psionic shield", addon=true, instant_resolve=true,
	keywords = {psionicshield=true},
	level_range = {1, 50},
	rarity = 15,
	charm_power_def = {add=3, max=200, floor=true},
	resolvers.charm("setup a psionic shield, reducing all damage taken %d for 5 turns", 25, function(self, who)
		who:setEffect(who.EFF_PSIONIC_SHIELD, 5, {kind="all", power=self:getCharmPower(who)})
		game.logSeen(who, "%s uses %s!", who.name:capitalize(), self:getName{no_add_name=true, do_color=true})
		return {id=true, used=true}
	end,
	"T_GLOBAL_CD",
	{on_pre_use = function(self, who)
		local shield = who:hasEffect(who.EFF_PSIONIC_SHIELD)
		return not (shield and shield.kind == "kinetic")
	end,
	tactical = { DEFEND = 2 }}),
}

newEntity{
	name = " of clear mind", addon=true, instant_resolve=true,
	keywords = {clearmind=true},
	level_range = {15, 50},
	rarity = 15,
	charm_power_def = {add=1, max=5, floor=true},
	resolvers.charm("absorb and nullify at most %d detrimental mental status effects in the next 10 turns", 10, function(self, who)
		who:setEffect(who.EFF_CLEAR_MIND, 10, {power=self:getCharmPower(who)})
		game.logSeen(who, "%s uses %s!", who.name:capitalize(), self:getName{no_add_name=true, do_color=true})
		return {id=true, used=true}
	end,
	"T_GLOBAL_CD",
	{tactical = {CURE = function(who, t, aitarget) -- if we're debuffed, try to prevent more
			if who:hasEffect(who.EFF_CLEAR_MIND) then return 0 end
			local nb = 0
			for eff_id, p in pairs(who.tmp) do
				local e = who.tempeffect_def[eff_id]
				if e.status == "detrimental" and e.type == "mental" then
					nb = nb + 1
				end
			end
			return math.ceil(nb/2)
		end,
		DEFEND = function(who, t, aitarget) -- if the target can debuff us with mental abilities, prepare
			if not aitarget or who:hasEffect(who.EFF_CLEAR_MIND) then return 0 end
			local count, nb = 0, 0
			for t_id, p in pairs(aitarget.talents) do
				count = count + 1
				local tal = aitarget.talents_def[t_id]
				if tal.is_mind then
					if type(tal.tactical) == "table" and tal.tactical.disable then
						nb = nb + 1
					end
				end
			end
			return math.min(5*(nb/count)^.5, 5)
		end}}
	),
}

newEntity{
	name = " of gale force", addon=true, instant_resolve=true,
	keywords = {galeforce=true},
	level_range = {1, 50},
	rarity = 10,
	charm_power_def = {add=15, max=800, floor=true},
	resolvers.charm(
		function(self, who)
			local dam = who:damDesc(engine.DamageType.Mind, self.use_power.damage(self, who))
			return ("project a gust of wind in a cone knocking enemies back %d spaces and dealing %d damage"):format(self.use_power.knockback(self, who), dam)
		end,
		15,
		function(self, who)
			local tg = self.use_power.target(self, who)
			local x, y = who:getTarget(tg)
			if not x or not y then return nil end
			local dam = who:mindCrit(self.use_power.damage(self, who))
			local kb = self.use_power.knockback(self, who)

			game.logSeen(who, "%s uses %s %s!", who.name:capitalize(), who:his_her(), self:getName{no_add_name=true, do_color=true})
			local DamageType = require "engine.DamageType"
			local state = {}
			who:project(tg, x, y, function(tx, ty)
				local target = game.level.map(tx, ty, engine.Map.ACTOR)
				if not target or target == who or state[target] then return end
				state[target] = true
				local DamageType = require "engine.DamageType"
				DamageType:get(DamageType.PHYSICAL).projector(who, tx, ty, DamageType.PHYSICAL, dam)
				if target:canBe("knockback") then
					target:knockback(who.x, who.y, kb)		
				end
			end, dam)
			return {id=true, used=true}
		end,
		"T_GLOBAL_CD",
		{
		damage = function(self, who) return self:getCharmPower(who) end,
		knockback = function(self, who) return math.floor(self:getCharmPower(who) / 50) + 5 end,
		target = function(self, who) return {type="cone", radius=6, range=0} end,
		requires_target = true,
		tactical = { attackarea = { physical = 2} }
		}
	),
}

newEntity{
	name = " of mindblast", addon=true, instant_resolve=true,
	keywords = {mindblast=true},
	level_range = {1, 50},
	rarity = 10,
	charm_power_def = {add=25, max=600, floor=true},
	resolvers.charm(function(self, who)
			local dam = self.use_power.damage(self, who)
			return ("blast the opponent's mind dealing %d mind damage and silencing them for 4 turns"):format(dam )
		end,
		15,
		function(self, who)
			local tg = self.use_power.target(self, who)
			local x, y = who:getTarget(tg)
			if not x or not y then return nil end
			local damage = who:mindCrit(self.use_power.damage(self, who))
			game.logSeen(who, "%s activates %s %s!", who.name:capitalize(), who:his_her(), self:getName({no_add_name = true, do_color = true}))
			if not x or not y then return nil end
			who:project(tg, x, y, function(tx, ty)
				local target = game.level.map(tx, ty, engine.Map.ACTOR)
				if not target then return end
				local DamageType = require "engine.DamageType"
				DamageType:get(DamageType.MIND).projector(who, tx, ty, DamageType.MIND, damage)
				if target:canBe("silence") then
					target:setEffect(target.EFF_SILENCED, 4, {apply_power = who:combatMindpower()})
				end
			end, dam, {type="mind"})
			game:playSoundNear(who, "talents/mind")
			return {id=true, used=true}
		end,
		"T_GLOBAL_CD",
		{ range = 10,
		requires_target = true,
		target = function(self, who) return {type="hit", range=self.use_power.range} end,
		damage = function(self, who) return self:getCharmPower(who) end,
		tactical = {ATTACK = 1}}
	),
}
