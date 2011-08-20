-- ToME - Tales of Maj'Eyal
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
local DamageType = require "engine.DamageType"
local Map = require "engine.Map"
local Chat = require "engine.Chat"
local Target = require "engine.Target"
local Talents = require "engine.interface.ActorTalents"

--- Interface to add ToME archery combat system
module(..., package.seeall, class.make)

--- Look for possible archery targets
-- Take care of removing enough ammo
function _M:archeryAcquireTargets(tg, params)
	local weapon, ammo = self:hasArcheryWeapon()
	if not weapon then
		game.logPlayer(self, "You must wield a bow or a sling (%s)!", ammo)
		return nil
	end
	params = params or {}

	print("[ARCHERY ACQUIRE TARGETS WITH]", weapon.name, ammo.name)
	local realweapon = weapon
	weapon = weapon.combat

	local tg = tg or {type="bolt"}

	if not tg.range then tg.range=weapon.range or 6 end
	tg.display = tg.display or {display='/'}
	tg.speed = (tg.speed or 20) * (ammo.travel_speed or 100) / 100
	local x, y = self:getTarget(tg)
	if not x or not y then return nil end

	-- Find targets to know how many ammo we use
	local targets = {}
	if params.one_shot then
		local a
		if not ammo.infinite then
			a = self:removeObject(self:getInven("QUIVER"), 1)
		else
			a = ammo
		end
		if a then
			targets = {{x=x, y=y, ammo=a.combat}}
		end
	else
		local limit_shots = params.limit_shots

		self:project(tg, x, y, function(tx, ty)
			local target = game.level.map(tx, ty, game.level.map.ACTOR)
			if not target then return end
			if tx == self.x and ty == self.y then return end

			if limit_shots then
				if limit_shots <= 0 then return end
				limit_shots = limit_shots - 1
			end

			for i = 1, params.multishots or 1 do
				local a
				if not ammo.infinite then
					a = self:removeObject(self:getInven("QUIVER"), 1)
				else
					a = ammo
				end
				if a then targets[#targets+1] = {x=tx, y=ty, ammo=a.combat}
				else break end
			end
		end)
	end

	if #targets > 0 then
		local sound = weapon.sound

		local speed = self:combatSpeed(weapon)
		print("[SHOOT] speed", speed or 1, "=>", game.energy_to_act * (speed or 1))
		self:useEnergy(game.energy_to_act * (speed or 1))

		if sound then game:playSoundNear(targets[1], sound) end

		if not ammo.infinite and (ammo:getNumber() < 10 or ammo:getNumber() == 50 or ammo:getNumber() == 40 or ammo:getNumber() == 25) then
			game.logPlayer(self, "You only have %s left!", ammo:getName{do_color=true})
		end

		return targets
	else
		return nil
	end
end

--- Archery projectile code
local function archery_projectile(tx, ty, tg, self)
	local DamageType = require "engine.DamageType"
	local weapon, ammo = tg.archery.weapon, tg.archery.ammo
	local talent = self:getTalentFromId(tg.talent_id)

	local target = game.level.map(tx, ty, game.level.map.ACTOR)
	if talent.archery_onreach then
		talent.archery_onreach(self, talent, tx, ty)
	end
	if not target then return end

	local damtype = tg.archery.damtype or ammo.damtype or DamageType.PHYSICAL
	local mult = tg.archery.mult or 1

	-- Does the blow connect? yes .. complex :/
	if tg.archery.use_psi_archery then self.use_psi_combat = true end
	local atk, def = self:combatAttack(weapon, ammo), target:combatDefenseRanged()
	local dam, apr, armor = self:combatDamage(ammo), self:combatAPR(ammo), target:combatArmor()
	atk = atk + (tg.archery.atk or 0)
	dam = dam + (tg.archery.dam or 0)
	print("[ATTACK ARCHERY] to ", target.name, " :: ", dam, apr, armor, "::", mult)
	if not self:canSee(target) then atk = atk / 3 end

	-- If hit is over 0 it connects, if it is 0 we still have 50% chance
	local hitted = false
	if self:checkHit(atk, def) then
		apr = apr + (tg.archery.apr or 0)
		print("[ATTACK ARCHERY] raw dam", dam, "versus", armor, "with APR", apr)

		local pres = util.bound(target:combatArmorHardiness() / 100, 0, 1)
		armor = math.max(0, armor - apr)
		dam = math.max(dam * pres - armor, 0) + (dam * (1 - pres))
		print("[ATTACK ARCHERY] after armor", dam)

		local damrange = self:combatDamageRange(ammo)
		dam = rng.range(dam, dam * damrange)
		print("[ATTACK ARCHERY] after range", dam)

		local crit
		if tg.archery.crit_chance then self.combat_physcrit = self.combat_physcrit + tg.archery.crit_chance end
		dam, crit = self:physicalCrit(dam, ammo, target)
		if tg.archery.crit_chance then self.combat_physcrit = self.combat_physcrit - tg.archery.crit_chance end
		print("[ATTACK ARCHERY] after crit", dam)

		dam = dam * mult
		print("[ATTACK ARCHERY] after mult", dam)

		if crit then game.logSeen(self, "#{bold}#%s performs a critical strike!#{normal}#", self.name:capitalize()) end
		DamageType:get(damtype).projector(self, target.x, target.y, damtype, math.max(0, dam))
		game.level.map:particleEmitter(target.x, target.y, 1, "archery")
		hitted = true

		if talent.archery_onhit then talent.archery_onhit(self, talent, target, target.x, target.y) end
	else
		local srcname = game.level.map.seens(self.x, self.y) and self.name:capitalize() or "Something"
		game.logSeen(target, "%s misses %s.", srcname, target.name)
	end

	-- Ranged project
	if hitted and not target.dead then for typ, dam in pairs(self.ranged_project) do
		if dam > 0 then
			DamageType:get(typ).projector(self, target.x, target.y, typ, dam)
		end
	end end

	-- Temporal cast
	if hitted and not target.dead and self:knowTalent(self.T_WEAPON_FOLDING) and self:isTalentActive(self.T_WEAPON_FOLDING) then
		local t = self:getTalentFromId(self.T_WEAPON_FOLDING)
		local dam = t.getDamage(self, t)
		DamageType:get(DamageType.TEMPORAL).projector(self, target.x, target.y, DamageType.TEMPORAL, dam)
	end

	-- Conduit (Psi)
	if hitted and not target.dead and self:knowTalent(self.T_CONDUIT) and self:isTalentActive(self.T_CONDUIT) and self.use_psi_combat then
		local t =  self:getTalentFromId(self.T_CONDUIT)
		--t.do_combat(self, t, target)
		local mult = 1 + 0.2*(self:getTalentLevel(t))
		local auras = self:isTalentActive(t.id)
		if auras.k_aura_on then
			local k_aura = self:getTalentFromId(self.T_KINETIC_AURA)
			local k_dam = mult * k_aura.getAuraStrength(self, k_aura)
			DamageType:get(DamageType.PHYSICAL).projector(self, target.x, target.y, DamageType.PHYSICAL, k_dam)
		end
		if auras.t_aura_on then
			local t_aura = self:getTalentFromId(self.T_THERMAL_AURA)
			local t_dam = mult * t_aura.getAuraStrength(self, t_aura)
			DamageType:get(DamageType.FIRE).projector(self, target.x, target.y, DamageType.FIRE, t_dam)
		end
		if auras.c_aura_on then
			local c_aura = self:getTalentFromId(self.T_CHARGED_AURA)
			local c_dam = mult * c_aura.getAuraStrength(self, c_aura)
			DamageType:get(DamageType.LIGHTNING).projector(self, target.x, target.y, DamageType.LIGHTNING, c_dam)
		end
	end


	-- Regen on being hit
	if hitted and not target.dead and target:attr("stamina_regen_on_hit") then target:incStamina(target.stamina_regen_on_hit) end
	if hitted and not target.dead and target:attr("mana_regen_on_hit") then target:incMana(target.mana_regen_on_hit) end
	if hitted and not target.dead and target:attr("equilibrium_regen_on_hit") then target:incEquilibrium(-target.equilibrium_regen_on_hit) end

	-- Ablative armor
	if hitted and not target.dead and target:attr("carbon_spikes") then
		if target.carbon_armor >= 1 then
			target.carbon_armor = target.carbon_armor - 1
		else
			-- Deactivate without loosing energy
			target:forceUseTalent(target.T_CARBON_SPIKES, {ignore_energy=true})
		end
	end

	-- Zero gravity
	if hitted and game.zone.zero_gravity and rng.percent(util.bound(dam, 0, 100)) then
		target:knockback(self.x, self.y, math.ceil(math.log(dam)))
	end

	self.use_psi_combat = false
end

--- Shoot at one target
function _M:archeryShoot(targets, talent, tg, params)
	local weapon, ammo = self:hasArcheryWeapon()
	if not weapon then
		game.logPlayer(self, "You must wield a bow or a sling (%s)!", ammo)
		return nil
	end
	if self:attr("disarmed") then
		game.logPlayer(self, "You are disarmed!")
		return nil
	end
	print("[SHOOT WITH]", weapon.name, ammo.name)
	local realweapon = weapon
	weapon = weapon.combat

	local tg = tg or {type="bolt"}
	tg.talent = tg.talent or talent

	if not tg.range then tg.range=weapon.range or 6 end
	tg.display = tg.display or {display=' ', particle="arrow", particle_args={tile="shockbolt/"..(ammo.proj_image or realweapon.proj_image):gsub("%.png$", "")}}
	tg.speed = (tg.speed or 20) * (ammo.travel_speed or 100) / 100
	tg.archery = params or {}
	tg.archery.weapon = weapon
	for i = 1, #targets do
		local tg = table.clone(tg)
		tg.archery.ammo = targets[i].ammo
		self:projectile(tg, targets[i].x, targets[i].y, archery_projectile)
	end
end

--- Check if the actor has a bow or sling and corresponding ammo
function _M:hasArcheryWeapon(type)
	if self:attr("disarmed") then
		return nil, "disarmed"
	end

	if not self:getInven("MAINHAND") then return nil, "no shooter" end
	if not self:getInven("QUIVER") then return nil, "no ammo" end
	local weapon = self:getInven("MAINHAND")[1]
	local ammo = self:getInven("QUIVER")[1]
	if self.inven[self.INVEN_PSIONIC_FOCUS] then
		local pf_weapon = self:getInven("PSIONIC_FOCUS")[1]
		if pf_weapon and pf_weapon.archery then
			weapon = pf_weapon
		end
	end
	if not weapon or not weapon.archery then
		return nil, "no shooter"
	end
	if not ammo then
		-- Launchers provide infinite basic ammo
		ammo = {name="default", infinite=true, combat=weapon.basic_ammo}
	else
		if not ammo.archery_ammo or weapon.archery ~= ammo.archery_ammo then
			return nil, "bad ammo"
		end
	end
	if type and weapon.archery ~= type then return nil, "bad type" end
	return weapon, ammo
end
