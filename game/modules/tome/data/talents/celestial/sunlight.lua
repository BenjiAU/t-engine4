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

local DamageType = require "engine.DamageType"

newTalent{
	name = "Searing Light",
	type = {"celestial/sunlight", 1},
	require = divi_req1,
	random_ego = "attack",
	points = 5,
	cooldown = 5,
	positive = -10,
	range = 7,
	radius = 1,
	tactical = { ATTACK = {LIGHT = 2} },
	direct_hit = true,
	reflectable = true,
	requires_target = true,
	getDamage = function(self, t) return self:combatTalentSpellDamage(t, 17, 200) end,
	getDamageOnSpot = function(self, t) return self:combatTalentSpellDamage(t, 17, 200)/2 end,
	action = function(self, t)
		local tg = {type="hit", range=self:getTalentRange(t), radius=1, talent=t}
		local x, y = self:getTarget(tg)
		if not x or not y then return nil end

		local dam = self:spellCrit(t.getDamage(self, t))
		self:project(tg, x, y, DamageType.LIGHT, dam, {type="light"})

		local _ _, x, y = self:canProject(tg, x, y)
		-- Add a lasting map effect
		game.level.map:addEffect(self,
			x, y, 4,
			DamageType.LIGHT, dam / 2,
			1,
			5, nil,
			{type="light_zone"},
			nil, self:spellFriendlyFire()
		)

		game:playSoundNear(self, "talents/flame")
		return true
	end,
	info = function(self, t)
		local damage = t.getDamage(self, t)
		local damageonspot = t.getDamageOnSpot(self, t)
		return ([[Calls the power of the Sun into a searing lance, doing %d damage to the target and leaving a spot on the ground for 4 turns that does %d light damage to anyone within it.
		The damage dealt will increase with your Spellpower.]]):
		format(damDesc(self, DamageType.LIGHT, damage), damDesc(self, DamageType.LIGHT, damageonspot))
	end,
}

-- High end Light damage nuke, synergy with Darkest Light via resists mid/late game
newTalent{
	name = "Sun Flare",
	type = {"celestial/sunlight", 2},
	require = divi_req2,
	points = 5,
	random_ego = "attack",
	cooldown = 12,
	positive = 30,
	tactical = { DISABLE = 2,
		ATTACKAREA = function(self, t, aitarget)
			if self:getTalentLevel(t) >= 3 then return {light = 1} end
		end, },
	direct_hit = true,
	range = 0,
	radius = function(self, t) return math.min(8, math.floor(self:combatTalentScale(t, 2.5, 4.5))) end,
	target = function(self, t)
		return {type="ball", range=self:getTalentRange(t), selffire=false, radius=self:getTalentRadius(t), talent=t}
	end,
	requires_target = true,
	getDamage = function(self, t) return self:combatTalentSpellDamage(t, 10, 250) end,
	getDuration = function(self, t) return 4 end,
	getRes = function(self, t) return self:combatTalentSpellDamage(t, 15, 50) end,
	getResDuration = function(self, t) return 4 end,

	action = function(self, t)
		local tg = self:getTalentTarget(t)
		-- Temporarily turn on "friendlyfire" to lite all tiles
		tg.selffire = true
		self:project(tg, self.x, self.y, DamageType.LITE, 1)
		tg.selffire = false
		local grids = self:project(tg, self.x, self.y, DamageType.BLIND, t.getDuration(self, t))
		self:project(tg, self.x, self.y, DamageType.LIGHT, self:spellCrit(t.getDamage(self, t)))
		if self:getTalentLevel(t) >= 3 then
			self:setEffect(self.EFF_SOLAR_INFUSION, t.getResDuration(self, t), {resist=t.getRes(self, t)})
		end
		game.level.map:particleEmitter(self.x, self.y, tg.radius, "sunburst", {radius=tg.radius, grids=grids, tx=self.x, ty=self.y, max_alpha=80})
		game:playSoundNear(self, "talents/flame")
		return true
	end,
	info = function(self, t)
		local radius = self:getTalentRadius(t)
		local damage = t.getDamage(self, t)
		local duration = t.getDuration(self, t)
		local res = t.getRes(self, t)
		local resdur = t.getResDuration(self, t)
		return ([[Invokes the Sun to cause a flare within radius %d, blinding your foes for %d turns and lighting up the area.
		All enemies effected will take %0.2f light damage.
		At talent level 3 you gain %d%% light, darkness, and fire resistance for %d turns.
		The damage done and resistances will increase with your Spellpower.]]):
		format(radius, duration, damDesc(self, DamageType.LIGHT, damage), res, resdur )
   end,
}

-- Some anti-synergy/potentially unexpected behavior with cooldown reduction, ideally we should distinguish between manual activation
newTalent{
	name = "Firebeam",
	type = {"celestial/sunlight",3},
	require = divi_req3,
	points = 5,
	random_ego = "attack",
	cooldown = 12,
	positive = 30,
	tactical = { ATTACK = {FIRE = 2}  },
	range = 10,
	direct_hit = true,
	requires_target = true,
	target = function(self, t)
		return {type="ball", radius=self:getTalentRange(t), friendlyfire=false, talent=t}
	end,
	getDamage = function(self, t) return self:combatTalentSpellDamage(t, 1, 50) end,
	callbackOnLevelChange = function(self, eff)
		self.firebeam_turns_remaining = nil
	end,
	callbackOnAct = function(self, t)
		if not self.firebeam_turns_remaining then return end
		if self.firebeam_turns_remaining <= 0 then self.firebeam_turns_remaining = nil return end

		if self.firebeam_turns_remaining % 2 ~= 0 then
			self:forceUseTalent(self.T_FIREBEAM, {ignore_cd=true, ignore_energy=true, ignore_ressources=true})
		end

		self.firebeam_turns_remaining = self.firebeam_turns_remaining - 1
	end,
	action = function(self, t)
		local tg = self:getTalentTarget(t)

		local tgts = {}
		self:project(tg, self.x, self.y, function(px, py)
			local target = game.level.map(px, py, engine.Map.ACTOR)
			if not target then return end
			tgts[#tgts+1] = {tgt=target, distance=core.fov.distance(self.x, self.y, target.x, target.y)}
		end)

		if #tgts > 0 then table.sort(tgts, "distance") else return end
		
		local tgt, x, y = tgts[#tgts].tgt, tgts[#tgts].tgt.x, tgts[#tgts].tgt.y
		local dam = self:spellCrit(t.getDamage(self, t))
		self:project({type="beam", friendlyfire=false, selffire=false, talent=t, self.x, self.y}, x, y, DamageType.FIRE, dam)

		local _ _, x, y = self:canProject(tg, x, y)
		game.level.map:particleEmitter(self.x, self.y, math.max(math.abs(x-self.x), math.abs(y-self.y)), "light_beam", {tx=x-self.x, ty=y-self.y})

		game:playSoundNear(self, "talents/flame")
		if not self.firebeam_turns_remaining then self.firebeam_turns_remaining = 4 end
		return true
	end,
	info = function(self, t)
		local damage = t.getDamage(self, t)
		return ([[Call forth the Sun to summon a fiery beam that pierces to the farthest enemy dealing %d fire damage to all enemies hit.
		This spell will automatically cast again at the start of every other one of your turns up to twice.
		The damage done will increase with your Spellpower.]]):
		format(damDesc(self, DamageType.FIRE, damage))
	end,
}

newTalent{
	name = "Sunburst",
	type = {"celestial/sunlight", 4},
	require = divi_req4,
	points = 5,
	random_ego = "attack",
	cooldown = 15,
	positive = 30,
	tactical = { ATTACKAREA = {LIGHT = 2} },
	radius = 10,
	direct_hit = true,
	target = function(self, t)
		return {type="ball", radius=self:getTalentRadius(t), friendlyfire=false, talent=t}
	end,
	getDamage = function(self, t) return self:combatTalentSpellDamage(t, 10, 250) end,
	getDuration = function(self, t) return 4 end,
	getPower = function(self, t) return self:combatTalentLimit(t, 1, 0.2, 0.7) end,
	getTargetCount = function(self, t) return math.floor(self:combatTalentScale(t, 1, 5)) end,
	action = function(self, t)
		local damInc = (self:combatGetDamageIncrease(DamageType.DARKNESS, true)) * t.getPower(self, t)
		self:setEffect(self.EFF_SUNBURST, t.getDuration(self, t), {damInc=damInc})

		--do cool lasers
		local tgts = {}
		local grids = core.fov.circle_grids(self.x, self.y, self:getTalentRadius(t), true)
		for x, yy in pairs(grids) do for y, _ in pairs(grids[x]) do
			local a = game.level.map(x, y, Map.ACTOR)
			if a and self:reactionToward(a) < 0 then
				tgts[#tgts+1] = a
			end
		end end

		if #tgts <= 0 then return true end

		local dam = self:spellCrit(t.getDamage(self, t))

		-- Randomly take targets
		local tg = {type="hit", range=self:getTalentRadius(t), talent=t}
		for i = 1, t.getTargetCount(self, t) do
			if #tgts <= 0 then break end
			local a, id = rng.table(tgts)
			table.remove(tgts, id)

			self:project(tg, a.x, a.y, DamageType.LIGHT, dam)
			game.level.map:particleEmitter(self.x, self.y, math.max(math.abs(a.x-self.x), math.abs(a.y-self.y)), "light_beam", {tx=a.x-self.x, ty=a.y-self.y})

			game:playSoundNear(self, "talents/spell_generic")
		end

		return true
	end,
	info = function(self, t)
		return ([[Release a furious burst of sunlight, increasing your bonus light damage by %d%% of your bonus darkness damage for %d turns and dealing %0.2f light damage to %d random foes in radius %d.]]):
			format(t.getPower(self, t)*100, t.getDuration(self, t), damDesc(self, DamageType.LIGHT, t.getDamage(self, t)), t.getTargetCount(self, t), self:getTalentRadius(t))
	end,
}
