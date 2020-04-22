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

newTalent{
	name = "Hiemal Shield",
	type = {"spell/glacial-waste",1},
	require = spells_req1,
	points = 5,
	mode = "sustained",
	mana = 30, -- Note a mistake, this is a casting cost
	soul = 1, 
	sustain_soul = 1,
	cooldown = 25,
	range = 10,
	tactical = { DEFEND = 2 },
	getDamage = function(self, t) return self:combatTalentSpellDamage(t, 10, 60) end,
	getMaxAbsorb = function(self, t) return self:combatTalentSpellDamage(t, 10, 450) end,
	getCritResist = function(self, t) return self:combatTalentScale(t, 10, 40, 0.75) end,
	iconOverlay = function(self, t, p)
		local val = p.shield
		if val <= 0 then return "" end
		local fnt = "buff_font_small"
		if val >= 1000 then fnt = "buff_font_smaller" end
		return tostring(math.ceil(val)), fnt
	end,
	callbackOnActBase = checkLifeThreshold(1, function(self, t)
		local p = self:isTalentActive(t.id)
		if not p then return end

		if self.life < 1 then
			if not p.crit_id then
				p.crit_id = self:addTemporaryValue("ignore_direct_crits", t:_getCritResist(self))
			end
		else
			if p.crit_id then
				self:removeTemporaryValue("ignore_direct_crits", p.crit_id)
				p.crit_id = nil
			end
		end
	end),
	callbackOnHit = function(self, t, cb, src, dt)
		local p = self:isTalentActive(t.id)
		if not p then return end
		if cb.value <= 0 then return end

		local reduce = 0
		if self:knowTalent(self.T_BLEAK_GUARD) then
			reduce = self:callTalent(self.T_BLEAK_GUARD, "getReduce")
		end
		reduce = (100 - reduce) / 100
		local rvalue = cb.value * reduce

		if rvalue <= p.shield then
			game:delayedLogDamage(src, self, 0, ("#SLATE#(%d absorbed)#LAST#"):tformat(cb.value), false)
			p.shield = p.shield - rvalue
			cb.value = 0

			if p.waste_counter then
				p.waste_counter = p.waste_counter + rvalue / p.original_shield
				if p.waste_counter >= p.waste_threshold / 100 and p.waste_triggers > 0 then
					p.waste_counter = 0
					p.waste_triggers = p.waste_triggers - 1
					self:callTalent(self.T_DESOLATE_WASTE, "spawn")
				end
			end
		else
			game:delayedLogDamage(src, self, 0, ("#SLATE#(%d absorbed)#LAST#"):tformat(p.shield), false)
			cb.value = (rvalue - p.shield) / reduce
			p.shield = 0
		end

		self.turn_procs.hiemal_shield = self.turn_procs.hiemal_shield or {}
		if src and src ~= self and src.x and src.y and not self.turn_procs.hiemal_shield[src] then
			self:projectile({type="bolt", range=self:getTalentRange(t), friendlyfire=false, talent=t, display={particle="arrow", particle_args={tile="particles_images/ice_shards"}}}, src.x, src.y, DamageType.HIEMAL_SHIELD, t:_getDamage(self), {type="freeze"})
			self.turn_procs.hiemal_shield[src] = true
		end

		if p.shield <= 0 then	
			-- Deactivate without losing energy
			self:forceUseTalent(t.id, {ignore_energy=true})
		end
		return true
	end,
	activate = function(self, t)
		local ret = { }
		ret.shield = t:_getMaxAbsorb(self)
		ret.original_shield = ret.shield
		if self:knowTalent(self.T_DESOLATE_WASTE) then
			ret.waste_threshold = self:callTalent(self.T_DESOLATE_WASTE, "getThreshold")
			ret.waste_triggers = math.floor(100 / ret.waste_threshold)
			ret.waste_counter = 0
		end

		if core.shader.active(4) then
			ret.particle = self:addParticles(Particles.new("shader_shield", 1, {size_factor=1.4, img="hiemal_aegis"}, {type="shield", ellipsoidalFactor=1, shieldIntensity=0.4, color={0.9, 0.9, 1.0}}))
		else
			ret.particle = self:addParticles(Particles.new("disruption_shield", 1))
		end

		game:playSoundNear(self, "talents/ice")
		return ret
	end,
	deactivate = function(self, t, p)
		self:removeParticles(p.particle)
		if p.crit_id then self:removeTemporaryValue("ignore_direct_crits", p.crit_id) end
		return true
	end,
	info = function(self, t)
		return ([[Conjure a shield of ice around you that can absorbs a total of %d damage.
		Anytime it does it retaliates by sending a bolt of ice at the attacker, dealing %0.2f cold damage (this can only happen once per turn per creature).
		When you are under 1 life it also reduces the damage of critical hits by %d%%.
		The shield strength will increase with your Spellpower.]]):
		tformat(t:_getMaxAbsorb(self), damDesc(self, DamageType.COLD, t:_getDamage(self)), t:_getCritResist(self))
	end,
}

newTalent{
	name = "Desolate Waste",
	type = {"spell/glacial-waste",2},
	require = spells_req2,
	points = 5,
	mode = "passive",
	radius = function(self, t) return math.floor(self:combatTalentScale(t, 3, 6)) end,
	getRegen = function(self, t) return self:combatTalentScale(t, 2, 5) end,
	getThreshold = function(self, t) return 25 end,
	getDamage = function(self, t) return self:combatTalentSpellDamage(t, 10, 40) end,
	spawn = function(self, t)
		game.level.map:addEffect(self,
			self.x, self.y, 8,
			DamageType.DESOLATE_WASTE, t:_getDamage(self),
			self:getTalentRadius(t),
			5, nil,
			MapEffect.new{zdepth=3, color_br=255, color_bg=255, color_bb=255, effect_shader="shader_images/boneyard_ground_gfx_3.png"},
			nil,
			false, false
		)
	end,
	trigger = function(self, t)
		local p = self:isTalentActive(self.T_HIEMAL_SHIELD)
		if not p then return end
		p.shield = p.shield + math.ceil(p.original_shield * t:_getRegen(self) / 100)
	end,
	info = function(self, t)
		return ([[Everytime your shield looses %d%% of its original value an radius %d circle of desolate waste spawns under you that deals %0.2f cold damage per turn to all foes for 6 turns.
		If a creature is hit by your hiemal shield's retribution bolt while on the waste, the shield feeds of the wasteland to regenerate %0.1f%% of its original value.
		No more than %d desolate wastes can trigger per shield activation.
		The damage will increase with your Spellpower.]]):
		tformat(t:_getThreshold(self), self:getTalentRadius(t), damDesc(self, DamageType.COLD, t:_getDamage(self)), t:_getRegen(self), 100 / t:_getThreshold(self))
	end,
}

newTalent{
	name = "Crumbling Earth",
	type = {"spell/glacial-waste",3},
	require = spells_req3,
	points = 5,
	mode = "passive",
	getSpeed = function(self, t) return self:combatTalentLimit(t, 50, 15, 35) end,
	getDamage = function(self, t) return self:combatTalentSpellDamage(t, 30, 120) end,
	trigger = function(self, t, target)
		if not target:canBe("cut") then return end
		target:setEffect(target.EFF_FROST_CUT, 4, {power=t:_getDamage(self)/4, speed=t:_getSpeed(self)})
	end,
	info = function(self, t)
		return ([[Your desolate wastes are now rapidly crumbling.
		Any foe moving through them is likely to get cut, bleeding ice that deals %0.2f cold damage over 4 turns (stacking) and reducing its movement speed by %d%%.
		The damage will increase with your Spellpower.]]):
		tformat(t:_getDamage(self), t:_getSpeed(self))
	end,
}

newTalent{
	name = "Bleak Guard",
	type = {"spell/glacial-waste",4},
	require = spells_req4,
	points = 5,
	mode = "passive",
	getReduce = function(self, t) return self:combatTalentLimit(t, 50, 10, 25) end,
	info = function(self, t)
		return ([[Your hiemal shield is stronger, taking %d%% less damage from all attacks.
		When under 1 life this effect is increased to %d%%.]]):
		tformat(t:_getReduce(self), t:_getReduce(self) * 1.33)
	end,
}
