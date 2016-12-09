-- ToME - Tales of Maj'Eyal
-- Copyright (C) 2009 - 2016 Nicolas Casalini
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

newTalent{
	name = "Eldritch Blow",
	type = {"spell/eldritch-shield", 1},
	require = spells_req1,
	points = 5,
	equilibrium = 3,
	mana = 10,
	cooldown = 10,
	range = 1,
	tactical = { ATTACK = { ARCANE = 2 }, DISABLE = { stun = 2 } },
	requires_target = true,
	on_pre_use = function(self, t, silent) local shield = self:hasShield() if not shield then if not silent then game.logPlayer(self, "You cannot use Eldritch Blow without a shield!") end return false end return true end,
	getDuration = function(self, t) return math.floor(self:combatTalentScale(t, 2.5, 4.5)) end,
	action = function(self, t)
		local shield = self:hasShield()

		local tg = {type="hit", range=self:getTalentRange(t)}
		local x, y, target = self:getTarget(tg)
		if not x or not y or not target then return nil end
		if core.fov.distance(self.x, self.y, x, y) > 1 then return nil end

		-- First attack with both weapon & shield (since we have the Stoneshield talent)
		-- nerf this damage?
		local hit = self:attackTarget(target, DamageType.ARCANE, self:combatTalentWeaponDamage(t, 0.6, (100 + self:combatTalentSpellDamage(t, 50, 300)) / 100), true)

		-- Try to stun !
		if hit then
			if target:canBe("stun") then
				target:setEffect(target.EFF_STUNNED, t.getDuration(self, t), {apply_power=self:combatPhysicalpower(), apply_save="combatSpellResist"})
			else
				game.logSeen(target, "%s resists the stun!", target.name:capitalize())
			end
		end

		return true
	end,
	info = function(self, t)
		return ([[Channel eldritch forces into a melee attack, hitting the target with your weapon and shield for %d%% arcane damage.
		If either attack hits, the target will be stunned for %d turns.
		The chance for the attack to stun increases with your Physical Power, but it is considered a magical attack and thus is resisted with spell save, rather than physical save.
		Damage increases with Spellpower.]])
		:format(100 * self:combatTalentWeaponDamage(t, 0.6, (100 + self:combatTalentSpellDamage(t, 50, 300)) / 100), t.getDuration(self, t))
	end,
}

newTalent{
	name = "Eldritch Infusion",
	type = {"spell/eldritch-shield", 2},
	require = spells_req2,
	points = 5,
	mode = "sustained",
	sustain_equilibrium = 15,
	sustain_mana = 50,
	cooldown = 30,
	tactical = { ATTACK = 3, BUFF = 2 },
	getDamage = function(self, t) return self:combatTalentSpellDamage(t, 15, 40) end,
	on_pre_use = function(self, t, silent)
		if not self:hasShield() then if not silent then game.logPlayer(self, "You require a shield to use this talent.") end return false end
		return true
	end,
	activate = function(self, t)
		local dam = t.getDamage(self, t)
		return {
			proj = self:addTemporaryValue("melee_project", {[DamageType.ARCANE]=dam}),
			onhit = self:addTemporaryValue("on_melee_hit", {[DamageType.ARCANE]=dam * 0.7}),
		}
	end,
	deactivate = function(self, t, p)
		self:removeTemporaryValue("melee_project", p.proj)
		self:removeTemporaryValue("on_melee_hit", p.onhit)
		return true
	end,
	info = function(self, t)
		local dam = t.getDamage(self, t)
		return ([[Imbues your shields with arcane power, dealing %0.2f arcane damage with each melee strike and %0.2f arcane damage when hit.
		The damage will increase with Spellpower.]]):
		format(damDesc(self, DamageType.ARCANE, dam), damDesc(self, DamageType.ARCANE, dam * 0.7))
	end,
}

newTalent{
	name = "Eldritch Fury",
	type = {"spell/eldritch-shield", 3},
	require = spells_req3,
	points = 5,
	equilibrium = 20,
	mana = 30,
	cooldown = 12,
	requires_target = true,
	tactical = { ATTACK = { NATURE = 3 }, DISABLE = { stun = 1 } },
	range = 1,
	on_pre_use = function(self, t, silent) local shield = self:hasShield() if not shield then if not silent then game.logPlayer(self, "You cannot use Eldricth Fury without a shield!") end return false end return true end,
	getDuration = function(self, t) return math.floor(self:combatTalentScale(t, 4, 8)) end,
	action = function(self, t)
		local tg = {type="hit", range=self:getTalentRange(t)}
		local x, y, target = self:getTarget(tg)
		if not x or not y or not target then return nil end
		if core.fov.distance(self.x, self.y, x, y) > 1 then return nil end

		-- First attack with both weapon & shield (since we have the Stoneshield talent)
		local hit1 = self:attackTarget(target, DamageType.NATURE, self:combatTalentWeaponDamage(t, 0.6, 1.6), true)
		local hit2 = self:attackTarget(target, DamageType.NATURE, self:combatTalentWeaponDamage(t, 0.6, 1.6), true)
		local hit3 = self:attackTarget(target, DamageType.NATURE, self:combatTalentWeaponDamage(t, 0.6, 1.6), true)

		-- Try to daze !
		if hit1 or hit2 or hit3 then
			if target:canBe("stun") then
				target:setEffect(target.EFF_DAZED, t.getDuration(self, t), {apply_power=self:combatPhysicalpower(), apply_save="combatSpellResist"})
			else
				game.logSeen(target, "%s resists the dazing blows!", target.name:capitalize())
			end
		end

		return true
	end,
	info = function(self, t)
		return ([[Channel eldritch forces into a ferocious melee attack, hitting the target three times with your shields doing %d%% Nature damage.
		If any of the attacks hit, the target will be dazed for %d turns.
		The chance for the attack to daze increases with you Physical Power, but it is considered a magical attack and thus is resisted with spell save, rather than physical save.]])
		:format(100 * self:combatTalentWeaponDamage(t, 0.6, 1.6), t.getDuration(self, t))
	end,
}

newTalent{
	name = "Eldritch Slam",
	type = {"spell/eldritch-shield", 4},
	require = spells_req4,
	points = 5,
	equilibrium = 10,
	mana = 30,
	cooldown = 20,
	tactical = { ATTACKAREA = { PHYSICAL = 3 } },
	requires_target = true,
	range = 1,
	radius = function(self, t) return math.floor(self:combatTalentScale(t, 2, 6)) end,
	on_pre_use = function(self, t, silent) local shield = self:hasShield() if not shield then if not silent then game.logPlayer(self, "You cannot use Eldritch Slam without a shield!") end return false end return true end,
	action = function(self, t)
		local tg = {type="ball", radius=self:getTalentRadius(t)}
		self:project(tg, self.x, self.y, function(px, py)
			local target = game.level.map(px, py, Map.ACTOR)
			if not target or target == self then return end
			self:attackTarget(target, DamageType.ARCANE, self:combatTalentWeaponDamage(t, 1.3, 2.6), true)
		end)
		game.level.map:particleEmitter(self.x, self.y, tg.radius, "shieldstorm", {radius=tg.radius})
		game:playSoundNear(self, "talents/icestorm")

		return true
	end,
	info = function(self, t)
		return ([[Slam your shield on the ground creating a shockwave.
		You perform a melee attack for %d%% Arcane damage against everyone within radius %d.]])
		:format(100 * self:combatTalentWeaponDamage(t, 1.3, 2.6), self:getTalentRadius(t))
	end,
}

