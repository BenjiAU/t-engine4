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

newTalent{
	name = "Bone Spear",
	type = {"corruption/bone", 1},
	require = corrs_req1,
	points = 5,
	vim = 13,
	cooldown = 8,
	range = 10,
	random_ego = "attack",
	tactical = { ATTACK = {PHYSICAL = 2} },
	direct_hit = true,
	requires_target = true,
	getDamage = function(self, t) return self:combatTalentSpellDamage(t, 20, 250) end,
	getBonus = function(self, t) return 0.3 end,
	target = function(self, t)
		return {type="beam", range=self:getTalentRange(t), talent=t}
	end,
	action = function(self, t)
		local tg = self:getTalentTarget(t)
		local x, y = self:getTarget(tg)
		if not x or not y then return nil end

		local dam = self:spellCrit(t.getDamage(self, t))

		self:project(tg, x, y, function(tx, ty)
			local target = game.level.map(tx, ty, Map.ACTOR)
			if not target then return end
			local damage = dam * (1 + t.getBonus(self, t) * #self:effectsFilter({status="detrimental", type="magical"}, 10))

			DamageType:get(DamageType.PHYSICAL).projector(self, tx, ty, DamageType.PHYSICAL, damage)
			end, dam)
		local _ _, _, _, x, y = self:canProject(tg, x, y)
		game.level.map:particleEmitter(self.x, self.y, tg.range, "bone_spear", {tx=x - self.x, ty=y - self.y})
		game:playSoundNear(self, "talents/arcane")

		return true
	end,
	info = function(self, t)
		return ([[Conjures up a spear of bones, doing %0.2f physical damage to all targets in a line.  Each target takes an additional %d%% damage for each magical debuff they are afflicted with.
		The damage will increase with your Spellpower.]]):format(damDesc(self, DamageType.PHYSICAL, t.getDamage(self, t)), damDesc(self, DamageType.PHYSICAL, t.getBonus(self, t)*100))
	end,
}

-- Finish me pls
newTalent{
	name = "Bone Grab",
	type = {"corruption/bone", 2},
	require = corrs_req2,
	points = 5,
	vim = 28,
	cooldown = 15,
	range = function(self, t) return math.floor(self:combatTalentLimit(t, 10, 4, 9)) end,
	tactical = { DISABLE = 1, CLOSEIN = 3 },
	requires_target = true,
	getDuration = function(self, t) return math.floor(self:combatTalentScale(t, 4, 8)) end,
	getDamage = function(self, t) return self:combatTalentSpellDamage(t, 5, 140) end,
	action = function(self, t)
		local tg = {type="bolt", range=self:getTalentRange(t), talent=t}
		local x, y = self:getTarget(tg)
		if not x or not y then return nil end

		local dam = self:spellCrit(t.getDamage(self, t))

		self:project(tg, x, y, function(px, py)
			local target = game.level.map(px, py, engine.Map.ACTOR)
			if not target then return end

			target:pull(self.x, self.y, tg.range)

			DamageType:get(DamageType.PHYSICAL).projector(self, target.x, target.y, DamageType.PHYSICAL, dam)
			if target:canBe("pin") then
				target:setEffect(target.EFF_BONE_GRAB, t.getDuration(self, t), {apply_power=self:combatSpellpower()})
			else
				game.logSeen(target, "%s resists the bone!", target.name:capitalize())
			end
		end)
		game:playSoundNear(self, "talents/arcane")

		return true
	end,
	info = function(self, t)
		return ([[Grab a target and teleport it to your side or if adjacent to a random location away from you, pinning it there with a bone rising from the ground for %d turns.
		The bone will also deal %0.2f physical damage.
		The damage will increase with your Spellpower.]]):
		format(t.getDuration(self, t), damDesc(self, DamageType.PHYSICAL, t.getDamage(self, t)))
	end,
}

newTalent{
	name = "Bone Spike",
	type = {"corruption/bone", 3},
	require = corrs_req3,
	image = "talents/bone_nova.png",
	points = 5,
	mode = "passive",
	getDamage = function(self, t) return self:combatTalentSpellDamage(t, 20, 90) end,
	radius = 10,
	target = function(self, t)
		return {type="ball", radius=self:getTalentRadius(t), selffire=false, friendlyfire=false, talent=t}
	end,
	callbackOnTalentPost = function(self, t, ab, ret, silent)
		if self.turn_procs.bone_spike then return end
		self.turn_procs.bone_spike = true
		game:onTickEnd(function()
			local tg = self:getTalentTarget(t)
			local dam = self:spellCrit(t.getDamage(self, t))

			self:project(tg, self.x, self.y, function(px, py)
				local target = game.level.map(px, py, engine.Map.ACTOR)
				if not target then return end
				local nb = #self:effectsFilter({status="detrimental", type="magical"})
				if nb and nb < 3 then return end
				self:project({type="beam", range=10, selffire=false, friendlyfire=false, talent=t}, target.x, target.y, DamageType.PHYSICAL, dam)
				local _ _, _, _, x, y = self:canProject(tg, x, y)
				game.level.map:particleEmitter(self.x, self.y, 10, "bone_spear", {tx=target.x - self.x, ty=target.y - self.y})
			end)
		end)
	end,
	info = function(self, t)
		return ([[At the end of any turn you used a talent you launch a spear of bone at all enemies afflicted by 3 or more magical detrimental effects dealing %d to all enemies it passes through.
		The damage will increase with your Spellpower.]]):format(damDesc(self, DamageType.PHYSICAL, t.getDamage(self, t)) )
	end,
}

newTalent{
	name = "Bone Shield",
	type = {"corruption/bone", 4},
	points = 5,
	mode = "sustained", no_sustain_autoreset = true,
	require = corrs_req4,
	cooldown = 15,
	sustain_vim = 50,
	tactical = { DEFEND = 4 },
	direct_hit = true,
	getNb = function(self, t) return math.floor(self:combatTalentScale(t, 1, 5)) end,
	getThreshold = function(self, t) return math.floor(self:combatStatScale(self:combatSpellpower(), 10, 120)) end,
	getRegen = function(self, t) return math.max(math.floor(30 / t.getNb(self, t)), 3) end,
	iconOverlay = function(self, t, p)
		local p = self.sustain_talents[t.id]
		if not p or not p.nb then return "" end
		return p.nb.."/"..t.getNb(self, t), "buff_font_smaller"
	end,
	callbackOnRest = function(self, t)
		local nb = t.getNb(self, t)
		local p = self.sustain_talents[t.id]
		if not p or p.nb < nb then return true end
	end,
	callbackOnActBase = function(self, t)
		local p = self.sustain_talents[t.id]
		p.next_regen = (p.next_regen or 1) - 1
		if p.next_regen <= 0 then
			p.next_regen = t.getRegen(self, t) or 10

			if p.nb < t.getNb(self, t) then
				p.nb = p.nb + 1
				if p.adv_gfx then
					if p.particles[1] and p.particles[1]._shader and p.particles[1]._shader.shad then
						p.particles[1]._shader.shad:resetClean()
						p.particles[1]._shader:setResetUniform("chargesCount", util.bound(p.nb, 0, 10))
						p.particles[1].shader.chargesCount = util.bound(p.nb, 0, 10)
					end
				else
					p.particles[#p.particles+1] = self:addParticles(Particles.new("bone_shield", 1))
				end
			end
		end
	end,
	callbackOnHit = function(self, t, cb, src, dt)
		local p = self.sustain_talents[t.id]
		if not p.nb or p.nb <= 0 then return end
		if not cb.value or cb.value < t.getThreshold(self, t) then return end
		p.nb = p.nb - 1
		if p.adv_gfx then
			if p.particles[1] and p.particles[1]._shader and p.particles[1]._shader.shad then
				p.particles[1]._shader.shad:resetClean()
				p.particles[1]._shader:setResetUniform("chargesCount", util.bound(p.nb, 0, 10))
				p.particles[1].shader.chargesCount = util.bound(p.nb, 0, 10)
			end
		else
			local pid = table.remove(p.particles)
			self:removeParticles(pid)
		end
		game:delayedLogDamage(src, self, 0, ("#SLATE#(%d to bones)#LAST#"):format(cb.value), false)
		cb.value = 0
		return true
	end,
	activate = function(self, t)
		local nb = t.getNb(self, t)

		local adv_gfx = core.shader.allow("adv") and true or false
		local ps = {}
		if adv_gfx then
			ps[1] = self:addParticles(Particles.new("shader_ring_rotating", 1, {toback=true, a=0.5, rotation=0, radius=1.5, img="bone_shield"}, {type="boneshield"}))
			ps[1]._shader.shad:resetClean()
			ps[1]._shader:setResetUniform("chargesCount", util.bound(nb, 0, 10))
			ps[1].shader.chargesCount = util.bound(nb, 0, 10)
		else
			for i = 1, nb do ps[#ps+1] = self:addParticles(Particles.new("bone_shield", 1)) end
		end

		game:playSoundNear(self, "talents/spell_generic2")
		return {
			adv_gfx = adv_gfx,
			particles = ps,
			nb = nb,
			next_regen = t.getRegen(self, t),
		}
	end,
	deactivate = function(self, t, p)
		for i, particle in ipairs(p.particles) do self:removeParticles(particle) end
		return true
	end,
	info = function(self, t)
		return ([[Bone shields start circling around you. They will each fully absorb one attack.
		%d shield(s) will be generated when first activated.
		Then every %d turns a new one will be created if not full.
		This will only trigger on hits over %d damage based on Spellpower.]]):
		format(t.getNb(self, t), t.getRegen(self, t), t.getThreshold(self, t))
	end,
}
