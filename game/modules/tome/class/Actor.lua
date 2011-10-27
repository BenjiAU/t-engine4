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
require "engine.Actor"
require "engine.Autolevel"
require "engine.interface.ActorInventory"
require "engine.interface.ActorTemporaryEffects"
require "engine.interface.ActorLife"
require "engine.interface.ActorProject"
require "engine.interface.ActorLevel"
require "engine.interface.ActorStats"
require "engine.interface.ActorTalents"
require "engine.interface.ActorResource"
require "engine.interface.BloodyDeath"
require "engine.interface.ActorFOV"
require "mod.class.interface.ActorPartyQuest"
require "mod.class.interface.Combat"
require "mod.class.interface.Archery"
require "mod.class.interface.ActorInscriptions"
local Faction = require "engine.Faction"
local Dialog = require "engine.ui.Dialog"
local Map = require "engine.Map"
local DamageType = require "engine.DamageType"

module(..., package.seeall, class.inherit(
	-- a ToME actor is a complex beast it uses may interfaces
	engine.Actor,
	engine.interface.ActorInventory,
	engine.interface.ActorTemporaryEffects,
	engine.interface.ActorLife,
	engine.interface.ActorProject,
	engine.interface.ActorLevel,
	engine.interface.ActorStats,
	engine.interface.ActorTalents,
	engine.interface.ActorResource,
	engine.interface.BloodyDeath,
	engine.interface.ActorFOV,
	mod.class.interface.ActorPartyQuest,
	mod.class.interface.ActorInscriptions,
	mod.class.interface.Combat,
	mod.class.interface.Archery
))

-- Dont save the can_see_cache
_M._no_save_fields.can_see_cache = true

-- Use distance maps
_M.__do_distance_map = true

_M.__is_actor = true

_M.stats_per_level = 3

-- Speeds are multiplicative, not additive
_M.temporary_values_conf.movement_speed = "mult0"
_M.temporary_values_conf.combat_physspeed = "mult0"
_M.temporary_values_conf.combat_spellspeed = "mult0"

function _M:init(t, no_default)
	-- Define some basic combat stats
	self.energyBase = 0

	self.combat_def = 0
	self.combat_armor = 0
	self.combat_armor_hardiness = 0
	self.combat_atk = 0
	self.combat_apr = 0
	self.combat_dam = 0
	self.global_speed = 1
	self.global_speed_base = 1
	self.global_speed_add = 0
	self.movement_speed = 1
	self.combat_physcrit = 0
	self.combat_physspeed = 1
	self.combat_spellspeed = 1
	self.combat_spellcrit = 0
	self.combat_spellpower = 0
	self.combat_mindpower = 0
	self.combat_mindcrit = 0

	self.combat_physresist = 0
	self.combat_spellresist = 0
	self.combat_mentalresist = 0

	self.fatigue = 0

	self.spell_cooldown_reduction = 0

	self.unused_stats = self.unused_stats or 3
	self.unused_talents = self.unused_talents or 2
	self.unused_generics = self.unused_generics or 1
	self.unused_talents_types = self.unused_talents_types or 0

	t.healing_factor = t.healing_factor or 1

	t.sight = t.sight or 10

	t.resource_pool_refs = t.resource_pool_refs or {}

	t.lite = t.lite or 0

	t.size_category = t.size_category or 3
	t.rank = t.rank or 2

	t.life_rating = t.life_rating or 10
	t.mana_rating = t.mana_rating or 4
	t.vim_rating = t.vim_rating or 4
	t.stamina_rating = t.stamina_rating or 3
	t.positive_negative_rating = t.positive_negative_rating or 3
	t.psi_rating = t.psi_rating or 0

	t.esp = t.esp or {}
	t.esp_range = t.esp_range or 10

	t.talent_cd_reduction = t.talent_cd_reduction or {}

	t.on_melee_hit = t.on_melee_hit or {}
	t.melee_project = t.melee_project or {}
	t.ranged_project = t.ranged_project or {}
	t.can_pass = t.can_pass or {}
	t.move_project = t.move_project or {}
	t.can_breath = t.can_breath or {}

	t.ai_tactic = t.ai_tactic or {}

	-- Resistances
	t.resists = t.resists or {}
	t.resists_cap = t.resists_cap or { all = 100 }
	t.resists_pen = t.resists_pen or {}
	t.resists_actor_type = t.resists_actor_type or {}
	t.resists_cap_actor_type = 70

	-- Absorbs a percentage of damage
	t.damage_affinity = t.damage_affinity or {}

	-- % Increase damage
	t.inc_damage = t.inc_damage or {}
	t.inc_damage_actor_type = t.inc_damage_actor_type or {}

	-- Default regen
	t.air_regen = t.air_regen or 3
	t.mana_regen = t.mana_regen or 0.5
	t.stamina_regen = t.stamina_regen or 0.3 -- Stamina regens slower than mana
	t.life_regen = t.life_regen or 0.25 -- Life regen real slow
	t.equilibrium_regen = t.equilibrium_regen or 0 -- Equilibrium does not regen
	t.vim_regen = t.vim_regen or 0 -- Vim does not regen
	t.positive_regen = t.positive_regen or -0.2 -- Positive energy slowly decays
	t.negative_regen = t.negative_regen or -0.2 -- Positive energy slowly decays
	t.paradox_regen = t.paradox_regen or 0 -- Paradox does not regen
	t.psi_regen = t.psi_regen or 0.2 -- Energy regens slowly

	t.max_positive = t.max_positive or 50
	t.max_negative = t.max_negative or 50
	t.positive = t.positive or 0
	t.negative = t.negative or 0

	t.hate_rating = t.hate_rating or 0.2
	t.hate_regen = t.hate_regen or 0
	t.max_hate = t.max_hate or 10
	t.absolute_max_hate = t.absolute_max_hate or 14
	t.hate = t.hate or 10
	t.hate_per_kill = t.hate_per_kill or 0.8

	t.equilibrium = t.equilibrium or 0

	t.paradox = t.paradox or 150

	t.money = t.money or 0

	engine.Actor.init(self, t, no_default)
	engine.interface.ActorInventory.init(self, t)
	engine.interface.ActorTemporaryEffects.init(self, t)
	engine.interface.ActorLife.init(self, t)
	engine.interface.ActorProject.init(self, t)
	engine.interface.ActorTalents.init(self, t)
	engine.interface.ActorResource.init(self, t)
	engine.interface.ActorStats.init(self, t)
	engine.interface.ActorLevel.init(self, t)
	engine.interface.ActorFOV.init(self, t)
	mod.class.interface.ActorInscriptions.init(self, t)

	-- Default melee barehanded damage
	self.combat = self.combat or {
		dam=1,
		atk=1, apr=0,
		physcrit=0,
		physspeed =1,
		dammod = { str=1 },
		damrange=1.1,
		talented = "unarmed",
	}
	-- Insures we have certain values for gloves to modify
	self.combat.damrange = self.combat.damrange or 1.1
	self.combat.physspeed = self.combat.physspeed or 1
	self.combat.dammod = self.combat.dammod or {str=0.6}

	self.talents[self.T_ATTACK] = self.talents[self.T_ATTACK] or 1

	self:resetCanSeeCache()
	self:recomputeGlobalSpeed()
end

function _M:useEnergy(val)
	engine.Actor.useEnergy(self, val)

	-- handle stalking
	local effStalker = self:hasEffect(self.EFF_STALKER)
	if effStalker then
		if effStalker.hit then
			-- consecutive hit on stalkee..add hate then bonus
			local t = self:getTalentFromId(self.T_STALK)
			self:incHate(t.getHitHateChange(self, t, effStalker.bonus))
			effStalker.bonus = math.min(3, (effStalker.bonus or 1) + 1)
			effStalker.hit = false
		else
			 -- no consecutive hit on stalkee..remove bonus
			effStalker.bonus = math.max(1, (effStalker.bonus or 1) - 1)
		end
	elseif self:isTalentActive(self.T_STALK) then
		local stalk = self:isTalentActive(self.T_STALK)
		if stalk.hit and stalk.hit_target and not stalk.hit_target.dead then
			stalk.hit_turns = (stalk.hit_turns or 0) + 1
			stalk.hit = false

			if stalk.hit_turns > 1 then
				-- multiple hits begin stalking
				local t = self:getTalentFromId(self.T_STALK)
				t.doStalk(self, t, stalk.hit_target)
				stalk.hit_turns = 0
				stalk.hit_target = nil
			end
		else
			stalk.hit = false
			stalk.hit_target = nil
			stalk.hit_turns = 0
		end
	end

	-- Curse of Shrouds: turn shroud of passing on or off
	local eff = self:hasEffect(self.EFF_CURSE_OF_SHROUDS)
	if eff then self.tempeffect_def[self.EFF_CURSE_OF_SHROUDS].doShroudOfPassing(self, eff) end

	-- Do not fire those talents if this is not turn's end
	if self:enoughEnergy() or game.zone.wilderness then return end
	if self:isTalentActive(self.T_KINETIC_AURA) then
		local t = self:getTalentFromId(self.T_KINETIC_AURA)
		t.do_kineticaura(self, t)
	end
	if self:isTalentActive(self.T_THERMAL_AURA) then
		local t = self:getTalentFromId(self.T_THERMAL_AURA)
		t.do_thermalaura(self, t)
	end
	if self:isTalentActive(self.T_CHARGED_AURA) then
		local t = self:getTalentFromId(self.T_CHARGED_AURA)
		t.do_chargedaura(self, t)
	end
	if self:isTalentActive(self.T_BEYOND_THE_FLESH) then
		local t = self:getTalentFromId(self.T_BEYOND_THE_FLESH)
		t.do_tkautoattack(self, t)
	end
	if self:hasEffect(self.EFF_MASTERFUL_TELEKINETIC_ARCHERY) then
		local t = self:getTalentFromId(self.T_MASTERFUL_TELEKINETIC_ARCHERY)
		t.do_tkautoshoot(self, t)
	end
end

function _M:actBase()
	self.energyBase = self.energyBase - game.energy_to_act

	if self:attr("no_timeflow") then return end

	if self:isTalentActive (self.T_DARKEST_LIGHT) and self.positive > self.negative then
		self:forceUseTalent(self.T_DARKEST_LIGHT, {ignore_energy=true})
		game.logSeen(self, "%s's darkness can no longer hold back the light!", self.name:capitalize())
	end

	-- Cooldown talents
	if not self:attr("no_talents_cooldown") then self:cooldownTalents() end
	-- Regen resources
	self:regenLife()
	if self:knowTalent(self.T_UNNATURAL_BODY) then
		local t = self:getTalentFromId(self.T_UNNATURAL_BODY)
		t.do_regenLife(self, t)
	end
	self:regenResources()
	-- Hate decay
	if self:knowTalent(self.T_HATE_POOL) then
		-- hate loss speeds up as hate increases
		local hateChange = -math.max(0.02, 0.07 * math.pow(self.hate / 10, 1.5))
		if self:knowTalent(self.T_SEETHE) then
			-- seethe prevents loss at low levels and gains some back and very low levels
			local t = self:getTalentFromId(self.T_SEETHE)
			local hateLossMinHate = t.getHateLossMinHate(self, t)
			local hateGainMaxHate = t.getHateGainMaxHate(self, t)

			if self.hate < hateGainMaxHate then
				hateChange = math.min(t.getHateGainChange(self, t), hateGainMaxHate - self.hate)
			elseif self.hate < hateLossMinHate then
				hateChange = 0
			elseif self.hate + hateChange <= hateLossMinHate then
				hateChange = hateLossMinHate - self.hate
			end
		end

		if hateChange ~= 0 then
			self:incHate(hateChange)
		end
	end

	-- Compute timed effects
	self:timedEffects()

	-- Handle thunderstorm, even if the actor is stunned or incapacitated it still works
	if not game.zone.wilderness then
		if self:isTalentActive(self.T_THUNDERSTORM) then
			local t = self:getTalentFromId(self.T_THUNDERSTORM)
			t.do_storm(self, t)
		end
		if self:isTalentActive(self.T_STONE_VINES) then
			local t = self:getTalentFromId(self.T_STONE_VINES)
			t.do_vines(self, t)
		end
		if self:isTalentActive(self.T_BODY_OF_FIRE) then
			local t = self:getTalentFromId(self.T_BODY_OF_FIRE)
			t.do_fire(self, t)
		end
		if self:isTalentActive(self.T_HYMN_OF_MOONLIGHT) then
			local t = self:getTalentFromId(self.T_HYMN_OF_MOONLIGHT)
			t.do_beams(self, t)
		end
		if self:isTalentActive(self.T_BLOOD_FRENZY) then
			local t = self:getTalentFromId(self.T_BLOOD_FRENZY)
			t.do_turn(self, t)
		end
		if self:isTalentActive(self.T_TRUE_GRIT) then
			local t = self:getTalentFromId(self.T_TRUE_GRIT)
			t.do_turn(self, t)
		end
		-- this handles cursed gloom turn based effects
		if self:isTalentActive(self.T_GLOOM) then
			local t = self:getTalentFromId(self.T_GLOOM)
			t.do_gloom(self, t)
		end
		-- this handles cursed call shadows turn based effects
		if self:isTalentActive(self.T_CALL_SHADOWS) then
			local t = self:getTalentFromId(self.T_CALL_SHADOWS)
			t.do_callShadows(self, t)
		end
		-- this handles cursed deflection turn based effects
		if self:isTalentActive(self.T_DEFLECTION) then
			local t = self:getTalentFromId(self.T_DEFLECTION)
			t.do_act(self, t, self:isTalentActive(self.T_DEFLECTION))
		end
		-- this handles doomed unseen force turn based effects
		if self.unseenForce then
			local t = self:getTalentFromId(self.T_UNSEEN_FORCE)
			t.do_unseenForce(self, t)
		end
		-- this handles doomed arcane bolts turn based effects
		if self.arcaneBolts then
			local t = self:getTalentFromId(self.T_ARCANE_BOLTS)
			t.do_arcaneBolts(self, t)
		end
		-- Curse of Nightmares: Nightmare
		if not self.dead and self:hasEffect(self.EFF_CURSE_OF_NIGHTMARES) then
			local eff = self:hasEffect(self.EFF_CURSE_OF_NIGHTMARES)
			if eff.isHit then
				eff.isHit = false
				self.tempeffect_def[self.EFF_CURSE_OF_NIGHTMARES].doNightmare(self, eff)
			end
		end
		-- this handles Door to the Past random anomalies
		if self:isTalentActive(self.T_DOOR_TO_THE_PAST) then
			local t = self:getTalentFromId(self.T_DOOR_TO_THE_PAST)
			t.do_anomalyCount(self, t)
		end
		-- this handles Carbon Spike regrowth
		if self:isTalentActive(self.T_CARBON_SPIKES) then
			local t = self:getTalentFromId(self.T_CARBON_SPIKES)
			t.do_carbonRegrowth(self, t)
		end
		if self:knowTalent(self.T_UNFLINCHING_RESOLVE) then
			local t = self:getTalentFromId(self.T_UNFLINCHING_RESOLVE)
			t.do_unflinching_resolve(self, t)
		end
		if self:isTalentActive(self.T_DAUNTING_PRESENCE) then
			local t = self:getTalentFromId(self.T_DAUNTING_PRESENCE)
			if self.life < t.getMinimumLife(self, t) then
				self:forceUseTalent(self.T_DAUNTING_PRESENCE, {ignore_energy=true})
			end
		end
	end

	-- Suffocate ?
	local air_level, air_condition = game.level.map:checkEntity(self.x, self.y, Map.TERRAIN, "air_level"), game.level.map:checkEntity(self.x, self.y, Map.TERRAIN, "air_condition")
	if air_level then
		if not air_condition or not self.can_breath[air_condition] or self.can_breath[air_condition] <= 0 then
			self:suffocate(-air_level, self, air_condition == "water" and "drowned to death" or nil)
		end
	end
end

function _M:act()
	if not engine.Actor.act(self) then return end

	self.changed = true

	-- If resources are too low, disable sustains
	if self.mana < 1 or self.stamina < 1 or self.psi < 1 then
		for tid, _ in pairs(self.sustain_talents) do
			local t = self:getTalentFromId(tid)
			if (t.sustain_mana and self.mana < 1) or (t.sustain_stamina and self.stamina < 1 and not self:hasEffect(self.EFF_ADRENALINE_SURGE)) then
				self:forceUseTalent(tid, {ignore_energy=true})
			elseif (t.sustain_psi and self.psi < 1) and t.remove_on_zero then
				self:forceUseTalent(tid, {ignore_energy=true})
			end
		end
		-- clear grappling
		if self:hasEffect(self.EFF_GRAPPLING) and not self:hasEffect(self.EFF_ADRENALINE_SURGE) then
			self:removeEffect(self.EFF_GRAPPLING)
		end
	end

	-- Conduit talent prevents all auras from cooling down
	if self:isTalentActive(self.T_CONDUIT) then
		local auras = self:isTalentActive(self.T_CONDUIT)
		if auras.k_aura_on then
			local t_kinetic_aura = self:getTalentFromId(self.T_KINETIC_AURA)
			self.talents_cd[self.T_KINETIC_AURA] = t_kinetic_aura.cooldown(self, t)
		end
		if auras.t_aura_on then
			local t_thermal_aura = self:getTalentFromId(self.T_THERMAL_AURA)
			self.talents_cd[self.T_THERMAL_AURA] = t_thermal_aura.cooldown(self, t)
		end
		if auras.c_aura_on then
			local t_charged_aura = self:getTalentFromId(self.T_CHARGED_AURA)
			self.talents_cd[self.T_CHARGED_AURA] = t_charged_aura.cooldown(self, t)
		end
	end

	if self:attr("paralyzed") then
		self.paralyzed_counter = (self.paralyzed_counter or 0) + (self:attr("stun_immune") or 0) * 100
		if self.paralyzed_counter < 100 then
			self.energy.value = 0
		else
			-- We are saved for this turn
			self.paralyzed_counter = self.paralyzed_counter - 100
			game.logSeen(self, "%s temporarily fights the paralyzation.", self.name:capitalize())
		end
	end
	if self:attr("stoned") then self.energy.value = 0 end
	if self:attr("dazed") then self.energy.value = 0 end
	if self:attr("time_stun") then self.energy.value = 0 end
	if self:attr("time_prison") then self.energy.value = 0 end

	-- Regain natural balance?
	local equilibrium_level = game.level.map:checkEntity(self.x, self.y, Map.TERRAIN, "equilibrium_level")
	if equilibrium_level then self:incEquilibrium(equilibrium_level) end

	-- Do stuff to things standing in the fire
	game.level.map:checkEntity(self.x, self.y, Map.TERRAIN, "on_stand", self)

	-- Still enough energy to act ?
	if self.energy.value < game.energy_to_act then return false end

	-- Still not dead ?
	if self.dead then return false end

	-- Ok reset the seen cache
	self:resetCanSeeCache()

	if self.on_act then self:on_act() end

	if self.never_act then return false end

	if not game.zone.wilderness then self:automaticTalents() end

	-- Compute bonuses based on actors in FOV
	if self:knowTalent(self.T_MILITANT_MIND) and not self:hasEffect(self.EFF_MILITANT_MIND) then
		local nb_foes = 0
		local act
		for i = 1, #self.fov.actors_dist do
			act = self.fov.actors_dist[i]
			if act and self:reactionToward(act) < 0 and self:canSee(act) then nb_foes = nb_foes + 1 end
		end
		if nb_foes > 1 then
			nb_foes = math.min(nb_foes, self:getTalentLevel(self.T_MILITANT_MIND))
			self:setEffect(self.EFF_MILITANT_MIND, 4, {power=self:getTalentLevel(self.T_MILITANT_MIND) * nb_foes * 0.6})
		end
	end

	-- Still enough energy to act ?
	if self.energy.value < game.energy_to_act then return false end

	if self.sound_random and rng.chance(self.sound_random_chance or 15) then game:playSoundNear(self, self.sound_random) end

	return true
end

--- Setup minimap color for this entity
-- You may overload this method to customize your minimap
function _M:setupMinimapInfo(mo, map)
	if map.actor_player and not map.actor_player:canSee(self) then return end
	if self.rank > 3 then mo:minimap(0xC0, 0x00, 0xAF) return end
	local r = map.actor_player and map.actor_player:reactionToward(self) or -100
	if r < 0 then mo:minimap(240, 0, 0)
	elseif r > 0 then mo:minimap(0, 240, 0)
	else mo:minimap(0, 0, 240)
	end
end

--- Attach or remove a display callback
-- Defines particles to display
function _M:defineDisplayCallback()
	if not self._mo then return end

	local ps = self:getParticlesList()

	local f_self = nil
	local f_danger = nil
	local f_powerful = nil
	local f_friend = nil
	local f_enemy = nil
	local f_neutral = nil

	self._mo:displayCallback(function(x, y, w, h, zoom, on_map)
		-- Tactical info
		if game.level and game.always_target then
			-- Tactical life info
			if on_map then
				local dh = h * 0.1
				local lp = math.max(0, self.life) / self.max_life + 0.0001
				core.display.drawQuad(x + 3, y + h - dh, w - 6, dh, 129, 180, 57, 128)
				core.display.drawQuad(x + 3, y + h - dh, (w - 6) * lp, dh, 50, 220, 77, 255)
			end
		end

		-- Tactical info
		if game.level and game.level.map.view_faction then
			local map = game.level.map
			if on_map then
				if not f_self then
					f_self = game.level.map.tilesTactic:get(nil, 0,0,0, 0,0,0, map.faction_self)
					f_powerful = game.level.map.tilesTactic:get(nil, 0,0,0, 0,0,0, map.faction_powerful)
					f_danger = game.level.map.tilesTactic:get(nil, 0,0,0, 0,0,0, map.faction_danger)
					f_friend = game.level.map.tilesTactic:get(nil, 0,0,0, 0,0,0, map.faction_friend)
					f_enemy = game.level.map.tilesTactic:get(nil, 0,0,0, 0,0,0, map.faction_enemy)
					f_neutral = game.level.map.tilesTactic:get(nil, 0,0,0, 0,0,0, map.faction_neutral)
				end

				if self.faction then
					local friend
					if not map.actor_player then friend = Faction:factionReaction(map.view_faction, self.faction)
					else friend = map.actor_player:reactionToward(self) end

					if self == map.actor_player then
						f_self:toScreen(x, y, w, h)
					elseif map:faction_danger_check(self) then
						if friend >= 0 then f_powerful:toScreen(x, y, w, h)
						else f_danger:toScreen(x, y, w, h) end
					elseif friend > 0 then
						f_friend:toScreen(x, y, w, h)
					elseif friend < 0 then
						f_enemy:toScreen(x, y, w, h)
					else
						f_neutral:toScreen(x, y, w, h)
					end
				end
			end
		end

		local e
		for i = 1, #ps do
			e = ps[i]
			e:checkDisplay()
			if e.ps:isAlive() then e.ps:toScreen(x + w / 2, y + h / 2, true, w / (game.level and game.level.map.tile_w or w))
			else self:removeParticles(e)
			end
		end

		return true
	end)
end

function _M:move(x, y, force)
	local moved = false
	local ox, oy = self.x, self.y

	if force or self:enoughEnergy() then

		-- Confused ?
		if not force and self:attr("confused") then
			if rng.percent(self:attr("confused")) then
				x, y = self.x + rng.range(-1, 1), self.y + rng.range(-1, 1)
			end
		end

		-- Encased in ice, attack the ice
		if not force and self:attr("encased_in_ice") then
			self:attackTarget(self)
			moved = true
		-- Should we prob travel through walls ?
		elseif not force and self:attr("prob_travel") and game.level.map:checkEntity(x, y, Map.TERRAIN, "block_move", self) then
			moved = self:probabilityTravel(x, y, self:attr("prob_travel"))
		-- Never move but tries to attack ? ok
		elseif not force and self:attr("never_move") then
			-- A bit weird, but this simple asks the collision code to detect an attack
			if not game.level.map:checkAllEntities(x, y, "block_move", self, true) then
				game.logPlayer(self, "You are unable to move!")
			end
		else
			moved = engine.Actor.move(self, x, y, force)
		end
		if not force and moved and (self.x ~= ox or self.y ~= oy) and not self.did_energy then
			local eff = self:hasEffect(self.EFF_CURSE_OF_SHROUDS)
			if eff then eff.moved = true end

			self:useEnergy(game.energy_to_act * self:combatMovementSpeed())
		end
	end
	self.did_energy = nil

	-- Try to detect traps
	if self:knowTalent(self.T_TRAP_DETECTION) then
		local power = self:getTalentLevel(self.T_TRAP_DETECTION) * self:getCun(25, true)
		local grids = core.fov.circle_grids(self.x, self.y, 1, true)
		for x, yy in pairs(grids) do for y, _ in pairs(yy) do
			local trap = game.level.map(x, y, Map.TRAP)
			if trap and not trap:knownBy(self) and self:checkHit(power, trap.detect_power) then
				trap:setKnown(self, true)
				game.level.map:updateMap(x, y)
				game.logPlayer(self, "You have found a trap (%s)!", trap:getName())
			end
		end end
	end

	-- chooseCursedAuraTree allows you to get the Cursed Aura tree
	if moved and self.chooseCursedAuraTree then
		if self.player then
			-- function placed in defiling touch where cursing logic exists
			local t = self:getTalentFromId(self.T_DEFILING_TOUCH)
			t.chooseCursedAuraTree(self, t)
		end
	end

	if moved and self:knowTalent(self.T_DEFILING_TOUCH) then
		local t = self:getTalentFromId(self.T_DEFILING_TOUCH)
		t.curseFloor(self, t, x, y)
	end

	if moved and self:isTalentActive(self.T_BODY_OF_STONE) then
		self:forceUseTalent(self.T_BODY_OF_STONE, {ignore_energy=true})
	end

	if not forced and moved and ox and oy and (ox ~= self.x or oy ~= self.y) and self:knowTalent(self.T_LIGHT_OF_FOOT) then
		self:incStamina(self:getTalentLevelRaw(self.T_LIGHT_OF_FOOT) * 0.2)
	end

	if moved and not force and ox and oy and (ox ~= self.x or oy ~= self.y) and config.settings.tome.smooth_move > 0 then
		local blur = 0
		if game.level.data.zero_gravity or self:hasEffect(self.EFF_HASTE) then blur = 2 end
		if self:attr("lightning_speed") or self:attr("step_up") or self:attr("wild_speed") then blur = 3 end
		self:setMoveAnim(ox, oy, config.settings.tome.smooth_move, blur)
	end

	if moved and not force and self:knowTalent(self.T_HASTE) and self:hasEffect(self.EFF_HASTE) then
		local t = self:getTalentFromId(self.T_HASTE)
		t.do_haste_double(self, t, ox, oy)
	end

	return moved
end

--- Knock back the actor
-- Overloaded to add move anim
function _M:knockback(srcx, srcy, dist, recursive)
	local ox, oy = self.x, self.y
	engine.Actor.knockback(self, srcx, srcy, dist, recursive)
	if config.settings.tome.smooth_move > 0 then
		self:resetMoveAnim()
		self:setMoveAnim(ox, oy, 9, 5)
	end
end

--- Pull in the actor
-- Overloaded to add move anim
function _M:pull(srcx, srcy, dist, recursive)
	local ox, oy = self.x, self.y
	engine.Actor.pull(self, srcx, srcy, dist, recursive)
	if config.settings.tome.smooth_move > 0 then
		self:resetMoveAnim()
		self:setMoveAnim(ox, oy, 9, 5)
	end
end

--- Get the "path string" for this actor
-- See Map:addPathString() for more info
function _M:getPathString()
	local ps = self.open_door and "return {open_door=true,can_pass={" or "return {can_pass={"
	for what, check in pairs(self.can_pass) do
		ps = ps .. what.."="..check..","
	end
	ps = ps.."}}"
--	print("[PATH STRING] for", self.name, " :=: ", ps)
	return ps
end

--- Drop no-teleport items
function _M:dropNoTeleportObjects()
	for inven_id, inven in pairs(self.inven) do
		for item = #inven, 1, -1 do
			local o = inven[item]
			if o.no_teleport then
				self:dropFloor(inven, item, false, true)
				game.logPlayer(self, "#LIGHT_RED#Your %s is immune to the teleportation and drops to the floor!", o:getName{do_color=true})
			end
		end
	end
end

--- Blink through walls
function _M:probabilityTravel(x, y, dist)
	if game.zone.wilderness then return true end
	if self:attr("encased_in_ice") then return end

	local dirx, diry = x - self.x, y - self.y
	local tx, ty = x, y
	while game.level.map:isBound(tx, ty) and game.level.map:checkAllEntities(tx, ty, "block_move", self) and dist > 0 do
		if game.level.map.attrs(tx, ty, "no_teleport") then break end
		if game.level.map:checkAllEntities(tx, ty, "no_prob_travel", self) then break end
		tx = tx + dirx
		ty = ty + diry
		dist = dist - 1
	end
	if game.level.map:isBound(tx, ty) and not game.level.map:checkAllEntities(tx, ty, "block_move", self) and not game.level.map.attrs(tx, ty, "no_teleport") then
		self:dropNoTeleportObjects()
		return engine.Actor.move(self, tx, ty, false)
	end
	return true
end

--- Teleports randomly to a passable grid
-- This simply calls the default actor teleportRandom but first checks for space-time stability
-- @param x the coord of the teleportation
-- @param y the coord of the teleportation
-- @param dist the radius of the random effect, if set to 0 it is a precise teleport
-- @param min_dist the minimum radius of of the effect, will never teleport closer. Defaults to 0 if not set
-- @return true if the teleport worked
function _M:teleportRandom(x, y, dist, min_dist)
	if self:attr("encased_in_ice") then return end
	if game.level.data.no_teleport_south and y + dist > self.y then
		y = self.y - dist
	end
	local ox, oy = self.x, self.y
	local ret = engine.Actor.teleportRandom(self, x, y, dist, min_dist)
	if self.x ~= ox or self.y ~= oy then
		self.x, self.y, ox, oy = ox, oy, self.x, self.y
		self:dropNoTeleportObjects()
		self.x, self.y, ox, oy = ox, oy, self.x, self.y
	end
	return ret
end

--- Quake a zone
-- Moves randomly each grid to an other grid
function _M:doQuake(tg, x, y)
	local w = game.level.map.w
	local locs = {}
	local ms = {}
	self:project(tg, x, y, function(tx, ty)
		if not game.level.map.attrs(tx, ty, "no_teleport") then
			locs[#locs+1] = {x=tx,y=ty}
			ms[#ms+1] = {map=game.level.map.map[tx + ty * w], attrs=game.level.map.attrs[tx + ty * w]}
		end
	end)

	while #locs > 0 do
		local l = rng.tableRemove(locs)
		local m = rng.tableRemove(ms)

		game.level.map.map[l.x + l.y * w] = m.map
		game.level.map.attrs[l.x + l.y * w] = m.attrs
		for z, e in pairs(m.map or {}) do
			if e.move then
				e.x = nil e.y = nil e:move(l.x, l.y, true)
			end
			game.nicer_tiles:updateAround(game.level, l.x, l.y)
		end
	end
	game.level.map:cleanFOV()
	game.level.map.changed = true
	game.level.map:redisplay()
end

--- Reveals location surrounding the actor
function _M:magicMap(radius, x, y, checker)
	x = x or self.x
	y = y or self.y
	radius = math.floor(radius)

	local ox, oy

	self.x, self.y, ox, oy = x, y, self.x, self.y
	self:computeFOV(radius, "block_sense", function(x, y)
		if not checker or checker(x, y) then
			game.level.map.remembers(x, y, true)
			game.level.map.has_seens(x, y, true)
		end
	end, true, true, true)

	self.x, self.y = ox, oy
end

--- What is our reaction toward the target
-- This can modify faction reaction using specific actor to actor reactions
function _M:reactionToward(target, no_reflection)
	if target == self and self:attr("encased_in_ice") then return -100 end

	-- If self or target is a summon bound to a master's will, use the master instead
	if self.summoner then return self.summoner:reactionToward(target, no_reflection) end
	if target.summoner then target = target.summoner end

	local v = engine.Actor.reactionToward(self, target)

	if self.reaction_actor and self.reaction_actor[target.unique or target.name] then v = v + self.reaction_actor[target.unique or target.name] end

	-- Take the lowest of the two just in case
	if not no_reflection and target.reactionToward then v = math.min(v, target:reactionToward(self, true)) end

	return util.bound(v, -100, 100)
end

function _M:incMoney(v)
	self.money = self.money + v
	if self.money < 0 then self.money = 0 end
	self.changed = true

	if self.player then
		world:gainAchievement("TREASURE_HUNTER", self)
		world:gainAchievement("TREASURE_HOARDER", self)
		world:gainAchievement("DRAGON_GREED", self)
		if v >= 0 then game:playSound("actions/coins")
		else game:playSound("actions/coins_less") end
	end
end

function _M:getRankStatAdjust()
	if self.rank == 1 then return -1
	elseif self.rank == 2 then return -0.5
	elseif self.rank == 3 then return 0
	elseif self.rank == 3.5 then return 1
	elseif self.rank == 4 then return 1
	elseif self.rank >= 5 then return 1
	else return 0
	end
end

function _M:getRankLevelAdjust()
	if self.rank == 1 then return -1
	elseif self.rank == 2 then return 0
	elseif self.rank == 3 then return 1
	elseif self.rank == 3.5 then return 2
	elseif self.rank == 4 then return 3
	elseif self.rank >= 5 then return 4
	else return 0
	end
end

function _M:getRankVimAdjust()
	if self.rank == 1 then return 0.7
	elseif self.rank == 2 then return 1
	elseif self.rank == 3 then return 1.2
	elseif self.rank == 3.5 then return 2.2
	elseif self.rank == 4 then return 2.6
	elseif self.rank >= 5 then return 2.8
	else return 0
	end
end

function _M:getRankLifeAdjust(value)
	local level_adjust = 1 + self.level / 40
	if self.rank == 1 then return value * (level_adjust - 0.2)
	elseif self.rank == 2 then return value * (level_adjust - 0.1)
	elseif self.rank == 3 then return value * (level_adjust + 0.1)
	elseif self.rank == 3.5 then return value * (level_adjust + 1)
	elseif self.rank == 4 then return value * (level_adjust + 2)
	elseif self.rank >= 5 then return value * (level_adjust + 3)
	else return 0
	end
end

function _M:getRankResistAdjust()
	if self.rank == 1 then return 0.4, 0.9
	elseif self.rank == 2 then return 0.5, 1.5
	elseif self.rank == 3 then return 0.8, 1.5
	elseif self.rank == 3.5 then return 0.9, 1.5
	elseif self.rank == 4 then return 0.9, 1.5
	elseif self.rank >= 5 then return 0.9, 1.5
	else return 0
	end
end

function _M:getRankSaveAdjust()
	if self.rank == 1 then return 0.6, 0.9
	elseif self.rank == 2 then return 1, 1.5
	elseif self.rank == 3 then return 1.3, 1.8
	elseif self.rank == 3.5 then return 1.5, 2
	elseif self.rank == 4 then return 1.7, 2.1
	elseif self.rank >= 5 then return 1.9, 2.3
	else return 0
	end
end

function _M:TextRank()
	local rank, color = "normal", "#ANTIQUE_WHITE#"
	if self.rank == 1 then rank, color = "critter", "#C0C0C0#"
	elseif self.rank == 2 then rank, color = "normal", "#ANTIQUE_WHITE#"
	elseif self.rank == 3 then rank, color = "elite", "#YELLOW#"
	elseif self.rank == 3.5 then rank, color = "unique", "#SANDY_BROWN#"
	elseif self.rank == 4 then rank, color = "boss", "#ORANGE#"
	elseif self.rank >= 5 then rank, color = "elite boss", "#GOLD#"
	end
	return rank, color
end

function _M:TextSizeCategory()
	local sizecat = "medium"
	if self.size_category <= 1 then sizecat = "tiny"
	elseif self.size_category == 2 then sizecat = "small"
	elseif self.size_category == 3 then sizecat = "medium"
	elseif self.size_category == 4 then sizecat = "big"
	elseif self.size_category == 5 then sizecat = "huge"
	elseif self.size_category >= 6 then sizecat = "gargantuan"
	end
	return sizecat
end

function _M:colorStats(stat)
	local score = 0
	if stat == "combatDefense" or stat == "combatPhysicalResist" or stat == "combatSpellResist" or stat == "combatMentalResist" then
		score = math.floor(self[stat](self, true))
	else
		score = math.floor(self[stat](self))
	end

	if score <= 9 then
		return "#B4B4B4# "..score
	elseif score <= 20 then
		return "#B4B4B4#"..score
	elseif score <= 40 then
		return "#FFFFFF#"..score
	elseif score <= 60 then
		return "#00FF80#"..score
	elseif score <= 80 then
		return "#0080FF#"..score
	elseif score <= 99 then
		return "#8d55ff#"..score
	elseif score == 100 then
		return "#8d55ff#**"
	end
end

function _M:tooltip(x, y, seen_by)
	if seen_by and not seen_by:canSee(self) then return end
	local factcolor, factstate, factlevel = "#ANTIQUE_WHITE#", "neutral", Faction:factionReaction(self.faction, game.player.faction)
	if factlevel < 0 then factcolor, factstate = "#LIGHT_RED#", "hostile"
	elseif factlevel > 0 then factcolor, factstate = "#LIGHT_GREEN#", "friendly"
	end

	-- Debug feature, mousing over with ctrl pressed will give detailed FOV info
	if config.settings.cheat and core.key.modState("ctrl") then
		print("============================================== SEEING from", self.name)
		for i, a in ipairs(self.fov.actors_dist) do
			local d = self.fov.actors[a]
			if d then
				print(("%3d : %-40s at %3dx%3d (see at %3dx%3d), diff %3dx%3d"):format(d.sqdist, a.name, a.x, a.y, d.x, d.y,d.dx,d.dy))
			end
		end
		print("==============================================")
	end

	local pfactcolor, pfactstate, pfactlevel = "#ANTIQUE_WHITE#", "neutral", self:reactionToward(game.player)
	if pfactlevel < 0 then pfactcolor, pfactstate = "#LIGHT_RED#", "hostile"
	elseif pfactlevel > 0 then pfactcolor, pfactstate = "#LIGHT_GREEN#", "friendly"
	end

	local rank, rank_color = self:TextRank()

	local resists = {}
	for t, v in pairs(self.resists) do
		if t ~= "all" then v = self:combatGetResist(t) end
		resists[#resists+1] = string.format("%d%% %s", v, t == "all" and "all" or DamageType:get(t).name)
	end

	local ts = tstring{}
	ts:add({"uid",self.uid}) ts:merge(rank_color:toTString()) ts:add(self.name, {"color", "WHITE"})
	if self.type == "humanoid" or self.type == "giant" then ts:add({"font","italic"}, "(", self.female and "female" or "male", ")", {"font","normal"}, true) else ts:add(true) end
	ts:add(self.type:capitalize(), " / ", self.subtype:capitalize(), true)
	ts:add("Rank: ") ts:merge(rank_color:toTString()) ts:add(rank, {"color", "WHITE"}, true)
	ts:add({"color", 0, 255, 255}, ("Level: %d"):format(self.level), {"color", "WHITE"}, true)
	ts:add({"color", 255, 0, 0}, ("HP: %d (%d%%)"):format(self.life, self.life * 100 / self.max_life), {"color", "WHITE"}, true)

	if self:attr("encased_in_ice") then
		local eff = self:hasEffect(self.EFF_FROZEN)
		ts:add({"color", 0, 255, 128}, ("Iceblock: %d"):format(eff.hp), {"color", "WHITE"}, true)
	end
	--ts:add(("Stats: %d / %d / %d / %d / %d / %d"):format(self:getStr(), self:getDex(), self:getCon(), self:getMag(), self:getWil(), self:getCun()), true)
	if #resists > 0 then ts:add("Resists: ", table.concat(resists, ','), true) end
	ts:add("Hardiness/Armour: ", tostring(math.floor(self:combatArmorHardiness())), '% / ', tostring(math.floor(self:combatArmor())), true)
	ts:add("Size: ", {"color", "ANTIQUE_WHITE"}, self:TextSizeCategory(), {"color", "WHITE"}, true)

	ts:add("#FFD700#Accuracy#FFFFFF#: ", self:colorStats("combatAttack"), "  ")
	ts:add("#0080FF#Defense#FFFFFF#:  ", self:colorStats("combatDefense"), true)
	ts:add("#FFD700#P. power#FFFFFF#: ", self:colorStats("combatPhysicalpower"), "  ")
	ts:add("#0080FF#P. save#FFFFFF#:  ", self:colorStats("combatPhysicalResist"), true)
	ts:add("#FFD700#S. power#FFFFFF#: ", self:colorStats("combatSpellpower"), "  ")
	ts:add("#0080FF#S. save#FFFFFF#:  ", self:colorStats("combatSpellResist"), true)
	ts:add("#FFD700#M. power#FFFFFF#: ", self:colorStats("combatMindpower"), "  ")
	ts:add("#0080FF#M. save#FFFFFF#:  ", self:colorStats("combatMentalResist"), true)
	ts:add({"color", "WHITE"})
	if self.summon_time then
		ts:add("Time left: ", {"color", "ANTIQUE_WHITE"}, ("%d"):format(self.summon_time), {"color", "WHITE"}, true)
	end
	if self.desc then ts:add(self.desc, true) end
	if self.faction and Faction.factions[self.faction] then ts:add("Faction: ") ts:merge(factcolor:toTString()) ts:add(("%s (%s, %d)"):format(Faction.factions[self.faction].name, factstate, factlevel), {"color", "WHITE"}, true) end
	if game.player ~= self then ts:add("Personal reaction: ") ts:merge(pfactcolor:toTString()) ts:add(("%s, %d"):format(pfactstate, pfactlevel), {"color", "WHITE"}, true) end

	for tid, act in pairs(self.sustain_talents) do
		if act then ts:add("- ", {"color", "LIGHT_GREEN"}, self:getTalentFromId(tid).name, {"color", "WHITE"}, true) end
	end
	for eff_id, p in pairs(self.tmp) do
		local e = self.tempeffect_def[eff_id]
		local dur = p.dur + 1
		if e.status == "detrimental" then
			if act then ts:add("- ", {"color", "LIGHT_RED"}, (e.decrease > 0) and ("%s(%d)"):format(e.desc,dur) or e.desc, {"color", "WHITE"}, true) end
		else
			if act then ts:add("- ", {"color", "LIGHT_GREEN"}, (e.decrease > 0) and ("%s(%d)"):format(e.desc,dur) or e.desc, {"color", "WHITE"}, true) end
		end
	end

	return ts
end

--- Regenerate life, call it from your actor class act() method
function _M:regenLife()
	if self.life_regen and not self:attr("no_life_regen") then
		self.life = util.bound(self.life + self.life_regen * util.bound((self.healing_factor or 1), 0, 2.5), self.die_at, self.max_life)
	end
end

--- Called before healing
function _M:onHeal(value, src)
	if self:hasEffect(self.EFF_UNSTOPPABLE) then return 0 end
	if self:attr("no_healing") then return 0 end

	value = value * util.bound((self.healing_factor or 1), 0, 2.5)

	if self:attr("stunned") then value = value / 2 end

	local eff = self:hasEffect(self.EFF_HEALING_NEXUS)
	if eff and value > 0 and not self.heal_leech_active then
		eff.src.heal_leech_active = true
		eff.src:heal(value * eff.pct, src)
		eff.src.heal_leech_active = nil
		eff.src:incEquilibrium(-eff.eq)
		if eff.src == self then
			game.logSeen(self, "%s heal is doubled!", self.name)
		else
			game.logSeen(self, "%s steals %s heal!", eff.src.name:capitalize(), self.name)
			return 0
		end
	end

	if self:attr("arcane_shield") and value > 0 and not self:hasEffect(self.EFF_DAMAGE_SHIELD) then
		self:setEffect(self.EFF_DAMAGE_SHIELD, 3, {power=value * self.arcane_shield / 100})
	end

	print("[HEALING]", self.uid, self.name, "for", value)
	if not self.resting and value >= 1 and game.level.map.seens(self.x, self.y) then
		local sx, sy = game.level.map:getTileToScreen(self.x, self.y)
		game.flyers:add(sx, sy, 30, rng.float(-3, -2), (rng.range(0,2)-1) * 0.5, tostring(math.ceil(value)), {255,255,0})
	end
	return value
end

--- Called before taking a hit, it's the chance to check for shields
function _M:onTakeHit(value, src)
	-- Un-daze
	if self:hasEffect(self.EFF_DAZED) then
		self:removeEffect(self.EFF_DAZED)
	end
	-- Un-meditate
	if self:hasEffect(self.EFF_MEDITATION) then
		self:removeEffect(self.EFF_MEDITATION)
	end
	if self:hasEffect(self.EFF_SPACETIME_TUNING) then
		self:removeEffect(self.EFF_SPACETIME_TUNING)
	end

	-- Remove domination hex
	if self:hasEffect(self.EFF_DOMINATION_HEX) and src and src == self:hasEffect(self.EFF_DOMINATION_HEX).src then
		self:removeEffect(self.EFF_DOMINATION_HEX)
	end

	if self:attr("invulnerable") then
		return 0
	end

	if self:attr("retribution") then
	-- Absorb damage into the retribution
		if value / 2 <= self.retribution_absorb then
			self.retribution_absorb = self.retribution_absorb - (value / 2)
			value = value / 2
		else
			value = value - self.retribution_absorb
			self.retribution_absorb = 0
			local dam = self.retribution_strike

			-- Deactivate without loosing energy
			self:forceUseTalent(self.T_RETRIBUTION, {ignore_energy=true})

			-- Explode!
			game.logSeen(self, "%s unleashes the stored damage in retribution!", self.name:capitalize())
			local tg = {type="ball", range=0, radius=self:getTalentRange(self:getTalentFromId(self.T_RETRIBUTION)), selffire=false, talent=t}
			local grids = self:project(tg, self.x, self.y, DamageType.LIGHT, dam)
			game.level.map:particleEmitter(self.x, self.y, tg.radius, "sunburst", {radius=tg.radius, grids=grids, tx=self.x, ty=self.y})
		end
	end

	if self:knowTalent(self.T_DISPLACE_DAMAGE) and self:isTalentActive(self.T_DISPLACE_DAMAGE) and rng.percent(5 + (self:getTalentLevel(self.T_DISPLACE_DAMAGE) * 5)) then
		-- find available targets
		local tgts = {}
		local grids = core.fov.circle_grids(self.x, self.y, self:getTalentLevelRaw(self.T_DISPLACE_DAMAGE) * 2, true)
		for x, yy in pairs(grids) do for y, _ in pairs(grids[x]) do
			local a = game.level.map(x, y, Map.ACTOR)
			if a and self:reactionToward(a) < 0 then
				tgts[#tgts+1] = a
			end
		end end

		local a = rng.table(tgts)
		if a then
			game.logSeen(self, "Some of the damage has been displaced onto %s!", a.name:capitalize())
			a:takeHit(value / 2, self)
			value = value / 2
		end

	end

	if self:attr("disruption_shield") then
		local mana = self:getMana()
		local mana_val = value * self:attr("disruption_shield")
		-- We have enough to absorb the full hit
		if mana_val <= mana then
			self:incMana(-mana_val)
			self.disruption_shield_absorb = self.disruption_shield_absorb + value
			return 0
		-- Or the shield collapses in a deadly arcane explosion
		else
			local dam = self.disruption_shield_absorb

			-- Deactivate without loosing energy
			self:forceUseTalent(self.T_DISRUPTION_SHIELD, {ignore_energy=true})

			-- Explode!
			game.logSeen(self, "%s's disruption shield collapses and then explodes in a powerful manastorm!", self.name:capitalize())
			local tg = {type="ball", radius=5}
			self:project(tg, self.x, self.y, DamageType.ARCANE, dam, {type="manathrust"})
		end
	end

	if self:attr("time_shield") then
		-- Absorb damage into the time shield
		self.time_shield_absorb = self.time_shield_absorb or 0
		if value <= self.time_shield_absorb then
			self.time_shield_absorb = self.time_shield_absorb - value
			value = 0
		else
			value = value - self.time_shield_absorb
			self.time_shield_absorb = 0
		end

		-- If we are at the end of the capacity, release the time shield damage
		if self.time_shield_absorb <= 0 then
			game.logPlayer(self, "Your time shield crumbles under the damage!")
			self:removeEffect(self.EFF_TIME_SHIELD)
		end
	end

	if self:attr("damage_shield") then
		-- Absorb damage into the shield
		self.damage_shield_absorb = self.damage_shield_absorb or 0
		if value <= self.damage_shield_absorb then
			self.damage_shield_absorb = self.damage_shield_absorb - value
			value = 0
		else
			value = value - self.damage_shield_absorb
			self.damage_shield_absorb = 0
		end

		-- If we are at the end of the capacity, release the time shield damage
		if self.damage_shield_absorb <= 0 then
			game.logPlayer(self, "Your shield crumbles under the damage!")
			self:removeEffect(self.EFF_DAMAGE_SHIELD)
		end
	end

	if self:attr("displacement_shield") then
		-- Absorb damage into the displacement shield
		if rng.percent(self.displacement_shield_chance) then
			if value <= self.displacement_shield then
				game.logSeen(self, "The displacement shield teleports the damage to %s!", self.displacement_shield_target.name)
				self.displacement_shield = self.displacement_shield - value
				self.displacement_shield_target:takeHit(value, src)
				value = 0
			else
				self:removeEffect(self.EFF_DISPLACEMENT_SHIELD)
			end
		end
	end

	if self:hasEffect(self.EFF_BONE_SHIELD) then
		local e = self.tempeffect_def[self.EFF_BONE_SHIELD]
		e.absorb(self, self.tmp[self.EFF_BONE_SHIELD])
		value = 0
	end

	if self:isTalentActive(self.T_BONE_SHIELD) then
		local t = self:getTalentFromId(self.T_BONE_SHIELD)
		t.absorb(self, t, self:isTalentActive(self.T_BONE_SHIELD))
		value = 0
	end

	if self:isTalentActive(self.T_DEFLECTION) then
		local t = self:getTalentFromId(self.T_DEFLECTION)
		value = t.do_onTakeHit(self, t, self:isTalentActive(self.T_DEFLECTION), value)
	end

	-- Achievements
	if not self.no_take_hit_achievements and src and src.resolveSource and src:resolveSource().player and value >= 600 then
		local rsrc = src:resolveSource()
		world:gainAchievement("SIZE_MATTERS", rsrc)
		if value >= 1500 then world:gainAchievement("DAMAGE_1500", rsrc) end
		if value >= 3000 then world:gainAchievement("DAMAGE_3000", rsrc) end
		if value >= 6000 then world:gainAchievement("DAMAGE_6000", rsrc) end
	end

	-- Stoned ? SHATTER !
	if self:attr("stoned") and value >= self.max_life * 0.3 then
		-- Make the damage high enough to kill it
		value = self.max_life + 1
		game.logSeen(self, "%s shatters into pieces!", self.name:capitalize())
	end

	-- Frozen: absorb some damage into the iceblock
	if self:attr("encased_in_ice") then
		local eff = self:hasEffect(self.EFF_FROZEN)
		eff.hp = eff.hp - value * 0.4
		value = value * 0.6
		if eff.hp < 0 and not eff.begone then game:onTickEnd(function() self:removeEffect(self.EFF_FROZEN) end) end
		eff.begone = true
	end

	-- Adds hate
	if self:knowTalent(self.T_HATE_POOL) then
		local hateGain = 0
		local hateMessage

		if value / self.max_life >= 0.15 then
			-- you take a big hit..adds 0.2 + 0.2 for each 5% over 15%
			hateGain = hateGain + 0.2 + (((value / self.max_life) - 0.15) * 10 * 0.5)
			hateMessage = "#F53CBE#You fight through the pain!"
		end

		if value / self.max_life >= 0.05 and (self.life - value) / self.max_life < 0.25 then
			-- you take a hit with low health
			hateGain = hateGain + 0.4
			hateMessage = "#F53CBE#Your rage grows even as your life fades!"
		end

		if hateGain >= 0.1 then
			self.hate = math.min(self.max_hate, self.hate + hateGain)
			if hateMessage then
				game.logPlayer(self, hateMessage.." (+%0.1f hate)", hateGain)
			end
		end
	end
	if src and (src.hate_per_powerful_hit or 0) > 0 and src.knowTalent and src:knowTalent(src.T_HATE_POOL) then
		local hateGain = 0
		local hateMessage

		if value / src.max_life > 0.33 then
			-- you deliver a big hit
			hateGain = hateGain + src.hate_per_powerful_hit
			hateMessage = "#F53CBE#Your powerful attack feeds your madness!"
		end

		if hateGain >= 0.1 then
			src.hate = math.min(src.max_hate, src.hate + hateGain)
			if hateMessage then
				game.logPlayer(src, hateMessage.." (+%0.1f hate)", hateGain)
			end
		end
	end

	-- Bloodlust!
	if src and src.knowTalent and src:knowTalent(src.T_BLOODLUST) then
		src:setEffect(src.EFF_BLOODLUST, 1, {})
	end

	if self:knowTalent(self.T_RAMPAGE) then
		local t = self:getTalentFromId(self.T_RAMPAGE)
		t:onTakeHit(self, value / self.max_life)
	end

	if self:hasEffect(self.EFF_UNSTOPPABLE) then
		if value > self.life then value = self.life - 1 end
	end

	-- Split ?
	if self.clone_on_hit and value >= self.clone_on_hit.min_dam_pct * self.max_life / 100 and rng.percent(self.clone_on_hit.chance) then
		-- Find space
		local x, y = util.findFreeGrid(self.x, self.y, 1, true, {[Map.ACTOR]=true})
		if x then
			-- Find a place around to clone
			local a = self:clone()
			a.life = math.max(1, a.life - value / 2)
			a.clone_on_hit.chance = math.ceil(a.clone_on_hit.chance / 2)
			a.energy.val = 0
			a.exp_worth = 0.1
			a.inven = {}
			a:removeAllMOs()
			a.x, a.y = nil, nil
			game.zone:addEntity(game.level, a, "actor", x, y)
			game.logSeen(self, "%s is split in two!", self.name:capitalize())
			value = value / 2
		end
	end

	if self.on_takehit then value = self:check("on_takehit", value, src) end

	-- VITALITY?
	if self:knowTalent(self.T_VITALITY) and self.life > self.max_life /2 and self.life - value <= self.max_life/2 then
		local t = self:getTalentFromId(self.T_VITALITY)
		t.do_vitality_recovery(self, t)
	end

	-- Daunting Presence?
	if self:isTalentActive(self.T_DAUNTING_PRESENCE) and value > (self.max_life / 20) then
		local t = self:getTalentFromId(self.T_DAUNTING_PRESENCE)
		t.do_daunting_presence(self, t)
	end

	-- Shield of Light
	if value > 0 and self:isTalentActive(self.T_SHIELD_OF_LIGHT) then
		if value <= 2 then
			drain = value
		else
			drain = 2
		end
		if self:getPositive() <= 0 then
			self:forceUseTalent(self.T_SHIELD_OF_LIGHT, {ignore_energy=true})
			game.logSeen(self, "%s's shield of light spell has crumbled under the attack!", self.name:capitalize())
		else
			self:incPositive(- drain)
			self:heal(self:combatTalentSpellDamage(self.T_SHIELD_OF_LIGHT, 5, 25), self)
		end
	end

	-- Second Life
	if self:isTalentActive(self.T_SECOND_LIFE) and value >= self.life then
		local sl = self.max_life * (0.05 + self:getTalentLevelRaw(self.T_SECOND_LIFE)/25)
		value = 0
		self.life = sl
		game.logSeen(self, "%s has been saved by a blast of positive energy!", self.name:capitalize())
		self:forceUseTalent(self.T_SECOND_LIFE, {ignore_energy=true})
	end

	-- Shade's reform
	if value >= self.life and self.ai_state and self.ai_state.can_reform then
		local t = self:getTalentFromId(self.T_SHADOW_REFORM)
		if rng.percent(t.getChance(self, t)) then
			value = 0
			self.life = self.max_life
			game.logSeen(self, "%s fades for a moment and then reforms whole again!", self.name:capitalize())
			game.level.map:particleEmitter(self.x, self.y, 1, "teleport_out")
			game:playSoundNear(self, "talents/heal")
			game.level.map:particleEmitter(self.x, self.y, 1, "teleport_in")
		end
	end

	-- Vim leech
	if self:knowTalent(self.T_LEECH) and src.hasEffect and src:hasEffect(src.EFF_VIMSENSE) then
		self:incVim(3 + self:getTalentLevel(self.T_LEECH) * 0.7)
		self:heal(5 + self:getTalentLevel(self.T_LEECH) * 3)
		game.logPlayer(self, "#AQUAMARINE#You leech a part of %s vim.", src.name:capitalize())
	end

	-- Invisible on hit
	if value >= self.max_life * 0.15 and self:attr("invis_on_hit") and rng.percent(self:attr("invis_on_hit")) then
		self:setEffect(self.EFF_INVISIBILITY, 5, {power=self:attr("invis_on_hit_power")})
		for tid, _ in pairs(self.invis_on_hit_disable) do self:forceUseTalent(tid, {ignore_energy=true}) end
	end

	-- Damage shield on hit
	if self:attr("contingency") and value >= self.max_life * self:attr("contingency") / 100 and not self:hasEffect(self.EFF_DAMAGE_SHIELD) then
		self:setEffect(self.EFF_DAMAGE_SHIELD, 3, {power=value * self:attr("contingency_shield") / 100})
		for tid, _ in pairs(self.contingency_disable) do self:forceUseTalent(tid, {ignore_energy=true}) end
	end

	-- Life leech
	if value > 0 and src and src:attr("life_leech_chance") and rng.percent(src.life_leech_chance) then
		local leech = math.min(value, self.life) * src.life_leech_value / 100
		if leech > 0 then
			src:heal(leech)
			game.logSeen(src, "#CRIMSON#%s leeches life from its victim!", src.name:capitalize())
		end
	end

	-- Resource leech
	if value > 0 and src and src:attr("resource_leech_chance") and rng.percent(src.resource_leech_chance) then
		local leech = src.resource_leech_value
		src:incMana(leech)
		src:incVim(leech * 0.5)
		src:incPositive(leech * 0.25)
		src:incNegative(leech * 0.25)
		src:incEquilibrium(-leech * 0.35)
		src:incStamina(leech * 0.65)
		src:incHate(leech * 0.05)
		src:incPsi(leech * 0.2)
		game.logSeen(src, "#CRIMSON#%s leeches energies from its victim!", src.name:capitalize())
	end

	return value
end

function _M:removeTimedEffectsOnClone()
	local todel = {}
	for eff, p in pairs(self.tmp) do
		if _M.tempeffect_def[eff].remove_on_clone then
			todel[#todel+1] = eff
		end
	end
	while #todel > 0 do self:removeEffect(table.remove(todel)) end
end

function _M:resolveSource()
	if self.summoner_gain_exp and self.summoner then
		return self.summoner:resolveSource()
	else
		return self
	end
end

function _M:die(src, death_note)
	if self.dead then self:disappear(src) self:deleteFromMap(game.level.map) return true end

	engine.interface.ActorLife.die(self, src, death_note)

	-- Gives the killer some exp for the kill
	local killer = nil
	if src and src.resolveSource and src:resolveSource().gainExp then
		killer = src:resolveSource()
		killer:gainExp(self:worthExp(killer))
	end

	-- Hack: even if the boss dies from something else, give the player exp
	if (not killer or not killer.player) and self.rank > 3 and not game.party:hasMember(self) then
		game.logPlayer(game.player, "You feel a surge of power as a powerful creature falls nearby.")
		killer = game.player:resolveSource()
		killer:gainExp(self:worthExp(killer))
	end

	-- Register bosses deaths
	if self.rank > 3 then
		game.state:bossKilled(self.rank)
	end
	if self.unique then game.state:registerUniqueDeath(self) end

	if self.on_death_lore then game.player:learnLore(self.on_death_lore) end

	-- Do we get a blooooooody death ?
	if rng.percent(33) then self:bloodyDeath() end

	-- Drop stuff
	if not self.keep_inven_on_death then
		if not self.no_drops then
			local invens = {}
			for inven_id, inven in pairs(self.inven) do invens[#invens+1] = inven end
			table.sort(invens, function(a,b) if a.id == 1 then return false elseif b.id == 1 then return true else return a.id < b.id end end)
			for _, inven in ipairs(invens) do
				for i = #inven, 1, -1 do
					local o = inven[i]

					-- Handle boss wielding artifacts
					if o.__special_boss_drop and rng.percent(o.__special_boss_drop.chance) then
						print("Refusing to drop "..self.name.." artifact "..o.name.." with chance "..o.__special_boss_drop.chance)

						-- Do not drop
						o.no_drop = true

						-- Drop a random artifact instead
						local ro = game.zone:makeEntity(game.level, "object", {no_tome_drops=true, unique=true, not_properties={"lore"}}, nil, true)
						if ro then game.zone:addEntity(game.level, ro, "object", self.x, self.y) end
					end

					if not o.no_drop then
						o.droppedBy = self.name
						self:removeObject(inven, i, true)
						game.level.map:addObject(self.x, self.y, o)
					else
						o:removed()
					end
				end
			end
		end
		self.inven = {}
	end

	-- Give stamina back
	if src and src.knowTalent and src:knowTalent(src.T_UNENDING_FRENZY) then
		src:incStamina(src:getTalentLevel(src.T_UNENDING_FRENZY) * 2)
	end

	-- Increases blood frenzy
	if src and src.knowTalent and src:knowTalent(src.T_BLOOD_FRENZY) and src:isTalentActive(src.T_BLOOD_FRENZY) then
		src.blood_frenzy = src.blood_frenzy + src:getTalentLevel(src.T_BLOOD_FRENZY) * 2
	end

	-- Increases necrotic aura count
	if src and src.resolveSource and src:resolveSource().isTalentActive and src:resolveSource():isTalentActive(src.T_NECROTIC_AURA) and not self.necrotic_minion and not self.no_necrotic_soul then
		local rsrc = src:resolveSource()
		local p = rsrc:isTalentActive(src.T_NECROTIC_AURA)
		if self.x and self.y and src.x and src.y and core.fov.distance(self.x, self.y, rsrc.x, rsrc.y) <= rsrc.necrotic_aura_radius then
			p.souls = math.min(p.souls + 1, p.souls_max)
			rsrc.changed = true
		end
	end

	-- Adds hate
	if src and src.knowTalent and src:knowTalent(src.T_HATE_POOL) then
		local hateGain = src.hate_per_kill
		local hateMessage

		if self.level - 2 > src.level then
			-- level bonus
			hateGain = hateGain + (self.level - 2 - src.level) * 0.2
			hateMessage = "#F53CBE#You have taken the life of an experienced foe!"
		end

		if self.rank >= 4 then
			-- boss bonus
			hateGain = hateGain * 4
			hateMessage = "#F53CBE#Your hate has conquered a great adversary!"
		elseif self.rank >= 3 then
			-- elite bonus
			hateGain = hateGain * 2
			hateMessage = "#F53CBE#An elite foe has fallen to your hate!"
		end
		hateGain = math.min(hateGain, 10)

		src.hate = math.min(src.max_hate, src.hate + hateGain)
		if hateMessage then
			game.logPlayer(src, hateMessage.." (+%0.1f hate)", hateGain - src.hate_per_kill)
		end
	end

	if src and src.summoner and src.summoner_hate_per_kill then
		if src.summoner.knowTalent and src.summoner:knowTalent(src.summoner.T_HATE_POOL) then
			src.summoner.hate = math.min(src.summoner.max_hate, src.summoner.hate + src.summoner_hate_per_kill)
			game.logPlayer(src.summoner, "%s feeds you hate from it's latest victim. (+%0.1f hate)", src.name:capitalize(), src.summoner_hate_per_kill)
		end
	end

	if src and src.knowTalent and src:knowTalent(src.T_UNNATURAL_BODY) then
		local t = src:getTalentFromId(src.T_UNNATURAL_BODY)
		t.on_kill(src, t, self)
	end

	if src and src.knowTalent and src:knowTalent(src.T_CRUEL_VIGOR) then
		local t = src:getTalentFromId(src.T_CRUEL_VIGOR)
		t.on_kill(src, t)
	end

	local effStalked = self:hasEffect(self.EFF_STALKED)
	if effStalked and not effStalked.source.dead and effStalked.source:hasEffect(self.EFF_STALKER) then
		local t = effStalked.source:getTalentFromId(effStalked.source.T_STALK)
		t.on_targetDied(effStalked.source, t, self)
	end

	if src and src.knowTalent and src:knowTalent(src.T_BLOODRAGE) then
		local t = src:getTalentFromId(src.T_BLOODRAGE)
		t.on_kill(src, t)
	end

	if src and src.isTalentActive and src:isTalentActive(src.T_FORAGE) then
		local t = src:getTalentFromId(src.T_FORAGE)
		t.on_kill(src, t, self)
	end

	if src and src.knowTalent and src:knowTalent(src.T_TOXIC_DEATH) then
		local t = src:getTalentFromId(src.T_TOXIC_DEATH)
		t.on_kill(src, t, self)
	end

	if src and src.hasEffect and src:hasEffect(self.EFF_UNSTOPPABLE) then
		local p = src:hasEffect(self.EFF_UNSTOPPABLE)
		p.kills = p.kills + 1
	end

	if src and src.knowTalent and src:knowTalent(src.T_STEP_UP) and rng.percent(src:getTalentLevelRaw(src.T_STEP_UP) * 20) then
		game:onTickEnd(function() src:setEffect(self.EFF_STEP_UP, 1, {}) end)
	end

	if self:hasEffect(self.EFF_CORROSIVE_WORM) then
		local p = self:hasEffect(self.EFF_CORROSIVE_WORM)
		p.src:project({type="ball", radius=4, x=self.x, y=self.y}, self.x, self.y, DamageType.ACID, p.explosion, {type="acid"})
	end

	if self:hasEffect(self.EFF_TEMPORAL_DESTABILIZATION) then
		local p = self:hasEffect(self.EFF_TEMPORAL_DESTABILIZATION)
		if self:hasEffect(self.EFF_CONTINUUM_DESTABILIZATION) then
			p.src:project({type="ball", radius=4, x=self.x, y=self.y}, self.x, self.y, DamageType.TEMPORAL, p.explosion, nil)
			game.level.map:particleEmitter(self.x, self.y, 4, "ball_temporal", {radius=4})
		else
			p.src:project({type="ball", radius=4, x=self.x, y=self.y}, self.x, self.y, DamageType.MATTER, p.explosion, nil)
			game.level.map:particleEmitter(self.x, self.y, 4, "ball_matter", {radius=4})
		end
		game:playSoundNear(self, "talents/breath")
	end

	if self:hasEffect(self.EFF_CEASE_TO_EXIST) then
		local kill = true
		game:onTickEnd(function()
			if game._chronoworlds == nil then
				game.logPlayer(game.player, "#LIGHT_RED#The cease to exist spell fizzles and cancels, leaving the timeline intact.")
				kill = false
				return
			end
			game:chronoRestore("cease_to_exist", true)
			-- check that the kill condition still applies
			if kill == true then
				local t = game.player:getTalentFromId(game.player.T_CEASE_TO_EXIST)
				t.do_instakill(game.player, t)
			end
		end)
	end

	-- Curse of Corpses: Corpselight
	-- Curse of Corpses: Reprieve from Death
	if src and src.hasEffect and src:hasEffect(src.EFF_CURSE_OF_CORPSES) then
		local eff = src:hasEffect(src.EFF_CURSE_OF_CORPSES)
		local def = src.tempeffect_def[src.EFF_CURSE_OF_CORPSES]
		if not def.doReprieveFromDeath(src, eff, self) then
			def.doCorpselight(src, eff, self)
		end
	end

	-- Curse of Shrouds: Shroud of Death
	if src and src.hasEffect and src:hasEffect(src.EFF_CURSE_OF_SHROUDS) then
		local eff = src:hasEffect(src.EFF_CURSE_OF_SHROUDS)
		local def = src.tempeffect_def[src.EFF_CURSE_OF_SHROUDS]
		def.doShroudOfDeath(src, eff)
	end

	-- Increase vim
	if src and src.knowTalent and src:knowTalent(src.T_VIM_POOL) then src:incVim(1 + src:getWil() / 10) end
	if src and src.attr and src:attr("vim_on_death") and not self:attr("undead") then src:incVim(src:attr("vim_on_death")) end
	if src and death_note and death_note.source_talent and death_note.source_talent.vim and src.last_vim_turn ~= game.turn then
		src.last_vim_turn = game.turn
		game:onTickEnd(function() -- Do it on tick end to make sure Vim is spent by the talent code before being refunded
			src:incVim(death_note.source_talent.vim)
		end)
	end

	if src and ((src.resolveSource and src:resolveSource().player) or src.player) then
		-- Achievements
		local p = game.party:findMember{main=true}
		if math.floor(p.life) <= 1 and not p.dead then world:gainAchievement("THAT_WAS_CLOSE", p) end
		world:gainAchievement("BOSS_REVENGE", p, self)
		world:gainAchievement("EMANCIPATION", p, self)
		world:gainAchievement("EXTERMINATOR", p, self)
		world:gainAchievement("PEST_CONTROL", p, self)
		world:gainAchievement("REAVER", p, self)

		if self.unique then
			game.player:registerUniqueKilled(self)
		end

		-- Record kills
		p.all_kills = p.all_kills or {}
		p.all_kills[self.name] = p.all_kills[self.name] or 0
		p.all_kills[self.name] = p.all_kills[self.name] + 1
	end

	if self.sound_die and (self.unique or rng.chance(5)) then game:playSoundNear(self, self.sound_die) end

	return true
end

function _M:learnStats(statorder)
	self.auto_stat_cnt = self.auto_stat_cnt or 1
	local nb = 0
	local max = 60

	-- Allow to go over a natural 60, up to 80 at level 50
	if not self.no_auto_high_stats then max = 60 + (self.level * 20 / 50) end

	while self.unused_stats > 0 do
		if self:getStat(statorder[self.auto_stat_cnt]) < max then
			self:incIncStat(statorder[self.auto_stat_cnt], 1)
			self.unused_stats = self.unused_stats - 1
		end
		self.auto_stat_cnt = util.boundWrap(self.auto_stat_cnt + 1, 1, #statorder)
		nb = nb + 1
		if nb >= #statorder then break end
	end
end

function _M:resetToFull()
	if self.dead then return end
	self.life = self.max_life
	self.mana = self.max_mana
	self.vim = self.max_vim
	self.stamina = self.max_stamina
	self.equilibrium = self.min_equilibrium
	self.air = self.max_air
	self.psi = self.max_psi
end

function _M:levelup()
	engine.interface.ActorLevel.levelup(self)
	engine.interface.ActorTalents.resolveLevelTalents(self)

	if not self.no_points_on_levelup then
		self.unused_stats = self.unused_stats + (self.stats_per_level or 3) + self:getRankStatAdjust()
		self.unused_talents = self.unused_talents + 1
		self.unused_generics = self.unused_generics + 1
		if self.level % 5 == 0 then self.unused_talents = self.unused_talents + 1 end
		if self.level % 5 == 0 then self.unused_generics = self.unused_generics - 1 end
		-- At levels 10, 20 and 30 we gain a new talent type
		if self.level == 10 or self.level == 20 or self.level == 30 then
			self.unused_talents_types = self.unused_talents_types + 1
		end
	elseif type(self.no_points_on_levelup) == "function" then
		self:no_points_on_levelup()
	end

	-- Gain some basic resistances
	if not self.no_auto_resists then
		-- Make up a random list of resists the first time
		if not self.auto_resists_list then
			local list = {
				DamageType.PHYSICAL,
				DamageType.FIRE, DamageType.COLD, DamageType.ACID, DamageType.LIGHTNING,
				DamageType.LIGHT, DamageType.DARKNESS,
				DamageType.NATURE, DamageType.BLIGHT,
				DamageType.TEMPORAL,
				DamageType.MIND,
			}
			self.auto_resists_list = {}
			for i = 1, rng.range(1, self.auto_resists_nb or 2) do
				local t = rng.tableRemove(list)
				-- Double the chance so that resist is more likely to happen
				if rng.percent(30) then self.auto_resists_list[#self.auto_resists_list+1] = t end
				self.auto_resists_list[#self.auto_resists_list+1] = t
			end
		end
		-- Provide one of our resists
		local t = rng.table(self.auto_resists_list)
		if (self.resists[t] or 0) < 50 then
			self.resists[t] = (self.resists[t] or 0) + rng.float(self:getRankResistAdjust())
		end

		-- Bosses have a right to get a general damage reduction
		if self.rank >= 4 then
			self.resists.all = (self.resists.all or 0) + rng.float(self:getRankResistAdjust()) / (self.rank == 4 and 3 or 2.5)
		end
	end

	-- Gain some saves
	if not self.no_auto_saves then
		self.combat_spellresist = self.combat_spellresist + rng.float(self:getRankSaveAdjust()) * (self:getMag() + self:getWil()) / 200
		self.combat_mentalresist = self.combat_mentalresist + rng.float(self:getRankSaveAdjust()) * (self:getCun() + self:getWil()) / 200
		self.combat_physresist = self.combat_physresist + rng.float(self:getRankSaveAdjust()) * (self:getStr() + self:getCon()) / 200
	end

	-- Gain life and resources and saves
	local rating = self.life_rating
	if not self.fixed_rating then
		rating = rng.range(math.floor(self.life_rating * 0.5), math.floor(self.life_rating * 1.5))
	end
	self.max_life = self.max_life + math.max(self:getRankLifeAdjust(rating), 1)

	self:incMaxVim(self.vim_rating)
	self:incMaxMana(self.mana_rating)
	self:incMaxStamina(self.stamina_rating)
	self:incMaxPositive(self.positive_negative_rating)
	self:incMaxNegative(self.positive_negative_rating)
	self:incMaxPsi(self.psi_rating)
	if self.max_hate < self.absolute_max_hate then
		local amount = math.min(self.hate_rating, self.absolute_max_hate - self.max_hate)
		self:incMaxHate(amount)
	end

	-- Heal up on new level
	self:resetToFull()

	-- Auto levelup ?
	if self.autolevel then
		engine.Autolevel:autoLevel(self)
	end

	-- Force levelup of the golem
	if self.alchemy_golem then self.alchemy_golem:forceLevelup(self.level) end

	-- Notify party levelups
	if self.x and self.y and game.party:hasMember(self) and not self.silent_levelup then
		local x, y = game.level.map:getTileToScreen(self.x, self.y)
		game.flyers:add(x, y, 80, 0.5, -2, "LEVEL UP!", {0,255,255})
		game.log("#00ffff#Welcome to level %d [%s].", self.level, self.name:capitalize())
		local more = "Press G to use them."
		if game.player ~= self then more = "Select "..self.name.. " in the party list and press G to use them." end
		local points = {}
		if self.unused_stats > 0 then points[#points+1] = ("%d stat point(s)"):format(self.unused_stats) end
		if self.unused_talents > 0 then points[#points+1] = ("%d class talent point(s)"):format(self.unused_talents) end
		if self.unused_generics > 0 then points[#points+1] = ("%d generic talent point(s)"):format(self.unused_generics) end
		if self.unused_talents_types > 0 then points[#points+1] = ("%d category point(s)"):format(self.unused_talents_types) end
		if #points > 0 then game.log("%s has %s to spend. %s", self.name:capitalize(), table.concat(points, ", "), more) end

		if self.level == 10 then world:gainAchievement("LEVEL_10", self) end
		if self.level == 20 then world:gainAchievement("LEVEL_20", self) end
		if self.level == 30 then world:gainAchievement("LEVEL_30", self) end
		if self.level == 40 then world:gainAchievement("LEVEL_40", self) end
		if self.level == 50 then world:gainAchievement("LEVEL_50", self) end

		if game.permadeath == game.PERMADEATH_MANY and (
			self.level == 2 or
			self.level == 5 or
			self.level == 7 or
			self.level == 14 or
			self.level == 24 or
			self.level == 35
			) then
			self.easy_mode_lifes = (self.easy_mode_lifes or 0) + 1
			game.logPlayer(self, "#AQUAMARINE#You have gained one more life (%d remaining).", self.easy_mode_lifes)
		end
		game:updateCurrentChar()

		if self == game.player then game:onTickEnd(function() game:playSound("actions/levelup") end, "levelupsound") end
	end
end

--- Notifies a change of stat value
function _M:onStatChange(stat, v)
	if stat == self.STAT_CON then
		self.max_life = self.max_life + 4 * v
	elseif stat == self.STAT_WIL then
		self:incMaxMana(5 * v)
		self:incMaxStamina(2.5 * v)
		self:incMaxPsi(1 * v)
	elseif stat == self.STAT_STR then
		self:checkEncumbrance()
	end
end

function _M:recomputeGlobalSpeed()
	if self.global_speed_add > 0 then self.global_speed = self.global_speed_base + self.global_speed_add
	else self.global_speed = self.global_speed_base * math.exp(self.global_speed_add)
	end
end

--- Called when a temporary value changes (added or deleted)
-- Takes care to call onStatChange when needed
-- @param prop the property changing
-- @param v the value of the change
-- @param base the base table of prop
function _M:onTemporaryValueChange(prop, v, base)
	if base == self.inc_stats then
		self:onStatChange(prop, v)
	elseif prop == "global_speed_add" then
		self:recomputeGlobalSpeed()
	end
end

function _M:attack(target, x, y)
	self:bumpInto(target, x, y)
end

function _M:getMaxEncumbrance()
	local add = 0
	return math.floor(40 + self:getStr() * 1.8 + (self.max_encumber or 0) + add)
end

function _M:getEncumbrance()
	local enc = 0

	local fct = function(so) enc = enc + so.encumber end

	-- Compute encumbrance
	for inven_id, inven in pairs(self.inven) do
		for item, o in ipairs(inven) do
			if not o.__transmo then
				o:forAllStack(fct)
			end
		end
	end
--	print("Total encumbrance", enc)
	return math.floor(enc)
end

function _M:checkEncumbrance()
	-- Compute encumbrance
	local enc, max = self:getEncumbrance(), self:getMaxEncumbrance()

	-- We are pinned to the ground if we carry too much
	if not self.encumbered and enc > max then
		game.logPlayer(self, "#FF0000#You carry too much--you are encumbered!")
		game.logPlayer(self, "#FF0000#Drop some of your items.")
		self.encumbered = self:addTemporaryValue("never_move", 1)
	elseif self.encumbered and enc <= max then
		self:removeTemporaryValue("never_move", self.encumbered)
		self.encumbered = nil
		game.logPlayer(self, "#00FF00#You are no longer encumbered.")
	end
end

--- Update tile for races that can handle it
function _M:updateModdableTile()
	if not self.moddable_tile or Map.tiles.no_moddable_tiles then return end
	self:removeAllMOs()

	local base = "player/"..self.moddable_tile:gsub("#sex#", self.female and "female" or "male").."/"

	self.image = base.."base_shadow_01.png"
	self.add_mos = {}
	local add = self.add_mos
	local i

	i = self.inven[self.INVEN_CLOAK]; if i and i[1] and i[1].moddable_tile then add[#add+1] = {image = base..(i[1].moddable_tile):format("behind")..".png", display_y=i[1].moddable_tile_big and -1 or 0, display_h=i[1].moddable_tile_big and 2 or 1} end
	add[#add+1] = {image = base..(self.moddable_tile_base or "base_01.png")}
	i = self.inven[self.INVEN_CLOAK]; if i and i[1] and i[1].moddable_tile then add[#add+1] = {image = base..(i[1].moddable_tile):format("shoulder")..".png", display_y=i[1].moddable_tile_big and -1 or 0, display_h=i[1].moddable_tile_big and 2 or 1} end
	i = self.inven[self.INVEN_BODY]; if i and i[1] and i[1].moddable_tile2 then add[#add+1] = {image = base..(i[1].moddable_tile2)..".png"}
	elseif not self.moddable_tile_nude then add[#add+1] = {image = base.."lower_body_01.png"} end
	i = self.inven[self.INVEN_BODY]; if i and i[1] and i[1].moddable_tile then add[#add+1] = {image = base..(i[1].moddable_tile)..".png", display_y=i[1].moddable_tile_big and -1 or 0, display_h=i[1].moddable_tile_big and 2 or 1}
	elseif not self.moddable_tile_nude then add[#add+1] = {image = base.."upper_body_01.png"} end
	i = self.inven[self.INVEN_HEAD]; if i and i[1] and i[1].moddable_tile then add[#add+1] = {image = base..(i[1].moddable_tile)..".png", display_y=i[1].moddable_tile_big and -1 or 0, display_h=i[1].moddable_tile_big and 2 or 1} end
	i = self.inven[self.INVEN_FEET]; if i and i[1] and i[1].moddable_tile then add[#add+1] = {image = base..(i[1].moddable_tile)..".png", display_y=i[1].moddable_tile_big and -1 or 0, display_h=i[1].moddable_tile_big and 2 or 1} end
	i = self.inven[self.INVEN_HANDS]; if i and i[1] and i[1].moddable_tile then add[#add+1] = {image = base..(i[1].moddable_tile)..".png", display_y=i[1].moddable_tile_big and -1 or 0, display_h=i[1].moddable_tile_big and 2 or 1} end
	i = self.inven[self.INVEN_CLOAK]; if i and i[1] and i[1].moddable_tile_hood then add[#add+1] = {image = base..(i[1].moddable_tile):format("hood")..".png", display_y=i[1].moddable_tile_big and -1 or 0, display_h=i[1].moddable_tile_big and 2 or 1} end
	i = self.inven[self.INVEN_MAINHAND]; if i and i[1] and i[1].moddable_tile then
		add[#add+1] = {image = base..(i[1].moddable_tile):format("right")..".png", display_y=i[1].moddable_tile_big and -1 or 0, display_h=i[1].moddable_tile_big and 2 or 1}
		if i[1].moddable_tile_particle then
			add[#add].particle = i[1].moddable_tile_particle[1]
			add[#add].particle_args = i[1].moddable_tile_particle[2]
		end
	end
	i = self.inven[self.INVEN_OFFHAND]; if i and i[1] and i[1].moddable_tile then add[#add+1] = {image = base..(i[1].moddable_tile):format("left")..".png", display_y=i[1].moddable_tile_big and -1 or 0, display_h=i[1].moddable_tile_big and 2 or 1} end

	if self.moddable_tile_ornament and self.moddable_tile_ornament[self.female and "female" or "male"] then add[#add+1] = {image = base..self.moddable_tile_ornament[self.female and "female" or "male"]..".png"} end

	if self.x and game.level then game.level.map:updateMap(self.x, self.y) end
end

--- Call when an object is worn
-- This doesnt call the base interface onWear, it copies the code because we need some tricky stuff
function _M:onWear(o, bypass_set)
	o.wielded = {}

	if o.set_list and not bypass_set then
		local list = {}
		for i, d in ipairs(o.set_list) do
			local po, item, inven_id = self:findInAllInventoriesBy(d[1], d[2])
			if po and self:getInven(inven_id).worn then
				list[#list+1] = po
			end
		end
		if #list == #o.set_list then
			for i, po in ipairs(list) do
				self:onTakeoff(po, true)
				po:check("on_set_complete", self)
				self:onWear(po, true)
				po.set_complete = true
			end
			o:check("on_set_complete", self)
			o.set_complete = true
		end
	end

	o:check("on_wear", self)
	if o.wielder then
		for k, e in pairs(o.wielder) do
			o.wielded[k] = self:addTemporaryValue(k, e)
		end
	end

	if o.talent_on_spell then
		self.talent_on_spell = self.talent_on_spell or {}
		for i = 1, #o.talent_on_spell do
			local id = util.uuid()
			self.talent_on_spell[id] = o.talent_on_spell[i]
			o.talent_on_spell[i]._id = id
		end
	end

	-- apply any special cursed logic
	if self:knowTalent(self.T_DEFILING_TOUCH) then
		local t = self:getTalentFromId(self.T_DEFILING_TOUCH)
		t.on_onWear(self, t, o)
	end

	self:updateModdableTile()
	if self == game.player then game:playSound("actions/wear") end
end

--- Call when an object is taken off
function _M:onTakeoff(o, bypass_set)
	engine.interface.ActorInventory.onTakeoff(self, o)

	if o.set_list and o.set_complete and not bypass_set then
		local list = {}
		for i, d in ipairs(o.set_list) do
			local po, item, inven_id = self:findInAllInventoriesBy(d[1], d[2])
			if po then
				self:onTakeoff(po, true)
				po:check("on_set_broken", self)
				if po._special_set then
					for k, id in pairs(po._special_set) do
						po:removeTemporaryValue(k, id)
					end
					po._special_set = nil
				end
				self:onWear(po, true)
				po.set_complete = nil
			end
		end
		o:check("on_set_broken", self)
		if o._special_set then
			for k, id in pairs(o._special_set) do o:removeTemporaryValue(k, id) end
			o._special_set = nil
		end
		o.set_complete = nil
	end

	if o._special_wear then
		for k, id in pairs(o._special_wear) do o:removeTemporaryValue(k, id) end
		o._special_wear = nil
	end

	if o.talent_on_spell then
		self.talent_on_spell = self.talent_on_spell or {}
		for i = 1, #o.talent_on_spell do
			local id = o.talent_on_spell[i]._id
			self.talent_on_spell[id] = nil
		end
	end

	-- apply any special cursed logic
	if self:knowTalent(self.T_DEFILING_TOUCH) then
		local t = self:getTalentFromId(self.T_DEFILING_TOUCH)
		t.on_onTakeOff(self, t, o)
	end

	self:updateModdableTile()
	if self == game.player then game:playSound("actions/takeoff") end
end

--- Call when an object is added
function _M:onAddObject(o)
	-- curse the item
	if self:knowTalent(self.T_DEFILING_TOUCH) then
		local t = self:getTalentFromId(self.T_DEFILING_TOUCH)
		t.curseItem(self, t, o)
	end

	engine.interface.ActorInventory.onAddObject(self, o)

	self:checkEncumbrance()

	-- Achievement checks
	if self.player then
		if o.unique and not o.lore and not o.randart then
			game.player:registerArtifactsPicked(o)
		end
		world:gainAchievement("DEUS_EX_MACHINA", self, o)
	end
end

--- Call when an object is removed
function _M:onRemoveObject(o)
	engine.interface.ActorInventory.onRemoveObject(self, o)

	self:checkEncumbrance()
end

--- Returns the possible offslot
function _M:getObjectOffslot(o)
	if o.dual_wieldable and self:attr("allow_any_dual_weapons") then
		return "OFFHAND"
	else
		return o.offslot
	end
end

--- Can we wear this item?
function _M:canWearObject(o, try_slot)
	if self:attr("forbid_arcane") and o.power_source and o.power_source.arcane then
		return nil, "antimagic"
	end
	if o.power_source and o.power_source.antimagic and not self:attr("forbid_arcane") then
		return nil, "requires antimagic"
	end

	return engine.interface.ActorInventory.canWearObject(self, o, try_slot)
end

function _M:lastLearntTalentsMax(what)
	return what == "generic" and 3 or 4
end

function _M:capLastLearntTalents(what)
	if self.no_last_learnt_talents_cap then return end
	local list = self.last_learnt_talents[what]
	local max = self:lastLearntTalentsMax(what)
	while #list > max do table.remove(list, 1) end
end

--- Actor learns a talent
-- @param t_id the id of the talent to learn
-- @return true if the talent was learnt, nil and an error message otherwise
function _M:learnTalent(t_id, force, nb, extra)
	if not engine.interface.ActorTalents.learnTalent(self, t_id, force, nb) then return false end

	-- If we learned a spell, get mana, if you learned a technique get stamina, if we learned a wild gift, get power
	local t = _M.talents_def[t_id]

	extra = extra or {}

	if not t.no_unlearn_last and self.last_learnt_talents and not extra.no_unlearn then
		local list = t.generic and self.last_learnt_talents.generic or self.last_learnt_talents.class
		table.insert(list, t_id)
		self:capLastLearntTalents(t.generic and "generic" or "class")
	end

	if t.dont_provide_pool then return true end

	self:learnPool(t)
	return true
end

--- Actor learns a resource pool
-- @param talent a talent definition table
function _M:learnPool(t)
	if t.type[1]:find("^spell/") and not self:knowTalent(self.T_MANA_POOL) and t.mana or t.sustain_mana then
		self:learnTalent(self.T_MANA_POOL, true)
		self.resource_pool_refs[self.T_MANA_POOL] = (self.resource_pool_refs[self.T_MANA_POOL] or 0) + 1
	end
	if t.type[1]:find("^wild%-gift/") and not self:knowTalent(self.T_EQUILIBRIUM_POOL) and t.equilibrium or t.sustain_equilibrium then
		self:learnTalent(self.T_EQUILIBRIUM_POOL, true)
		self.resource_pool_refs[self.T_EQUILIBRIUM_POOL] = (self.resource_pool_refs[self.T_EQUILIBRIUM_POOL] or 0) + 1
	end
	if t.type[1]:find("^technique/") and not self:knowTalent(self.T_STAMINA_POOL) and t.stamina or t.sustain_stamina then
		self:learnTalent(self.T_STAMINA_POOL, true)
		self.resource_pool_refs[self.T_STAMINA_POOL] = (self.resource_pool_refs[self.T_STAMINA_POOL] or 0) + 1
	end
	if t.type[1]:find("^corruption/") and not self:knowTalent(self.T_VIM_POOL) and t.vim or t.sustain_vim then
		self:learnTalent(self.T_VIM_POOL, true)
		self.resource_pool_refs[self.T_VIM_POOL] = (self.resource_pool_refs[self.T_VIM_POOL] or 0) + 1
	end
	if t.type[1]:find("^celestial/") and (t.positive or t.sustain_positive) and not self:knowTalent(self.T_POSITIVE_POOL) then
		self:learnTalent(self.T_POSITIVE_POOL, true)
		self.resource_pool_refs[self.T_POSITIVE_POOL] = (self.resource_pool_refs[self.T_POSITIVE_POOL] or 0) + 1
	end
	if t.type[1]:find("^celestial/") and (t.negative or t.sustain_negative) and not self:knowTalent(self.T_NEGATIVE_POOL) then
		self:learnTalent(self.T_NEGATIVE_POOL, true)
		self.resource_pool_refs[self.T_NEGATIVE_POOL] = (self.resource_pool_refs[self.T_NEGATIVE_POOL] or 0) + 1
	end
	if t.type[1]:find("^cursed/") and not self:knowTalent(self.T_HATE_POOL) and t.hate then
		self:learnTalent(self.T_HATE_POOL, true)
		self.resource_pool_refs[self.T_HATE_POOL] = (self.resource_pool_refs[self.T_HATE_POOL] or 0) + 1
	end
	if t.type[1]:find("^chronomancy/") and not self:knowTalent(self.T_PARADOX_POOL) then
		self:learnTalent(self.T_PARADOX_POOL, true)
		self.resource_pool_refs[self.T_PARADOX_POOL] = (self.resource_pool_refs[self.T_PARADOX_POOL] or 0) + 1
	end
	if t.type[1]:find("^psionic/") and not self:knowTalent(self.T_PSI_POOL) then
		self:learnTalent(self.T_PSI_POOL, true)
		self.resource_pool_refs[self.T_PSI_POOL] = (self.resource_pool_refs[self.T_PSI_POOL] or 0) + 1
	end
	-- If we learn an archery talent, also learn to shoot
	if t.type[1]:find("^technique/archery") and not self:knowTalent(self.T_SHOOT) then
		self:learnTalent(self.T_SHOOT, true)
		self.resource_pool_refs[self.T_SHOOT] = (self.resource_pool_refs[self.T_SHOOT] or 0) + 1
	end

	return true
end

--- Actor forgets a talent
-- @param t_id the id of the talent to learn
-- @return true if the talent was unlearnt, nil and an error message otherwise
function _M:unlearnTalent(t_id)
	if not engine.interface.ActorTalents.unlearnTalent(self, t_id, force) then return false end

	local t = _M.talents_def[t_id]

	if not t.no_unlearn_last and self.last_learnt_talents then
		local list = t.generic and self.last_learnt_talents.generic or self.last_learnt_talents.class
		for i = #list, 1, -1 do
			if list[i] == t_id then table.remove(list, i) break end
		end
	end

	-- Check the various pools
	for key, num_refs in pairs(self.resource_pool_refs) do
		if num_refs == 0 then
			self:unlearnTalent(key)
		end
	end
	return true
end

--- Equilibrium check
function _M:equilibriumChance(eq)
	eq = (eq or 0) + self:getEquilibrium()
	local wil = self:getWil()
	-- Do not fail if below willpower
	if eq < wil then return true, 100 end
	eq = eq - wil
	local chance = math.sqrt(eq) / 60
	--print("[Equilibrium] Use chance: ", 100 - chance * 100, "::", self:getEquilibrium())
	chance = util.bound(chance, 0, 1)
	return rng.percent(100 - chance * 100), 100 - chance * 100
end

--- Paradox checks
function _M:paradoxChanceModifier()
	local modifier = self:getWil() * 2
	if self:knowTalent(self.T_PARADOX_MASTERY) then
		modifier = modifier * (1 + (self:getTalentLevel(self.T_PARADOX_MASTERY)/10) or 0)
	end
	--print("[Paradox] Will modifier: ", modifier, "::", self:getParadox())
	return modifier
end

function _M:paradoxFailChance(pa)
	local total_paradox = self:getParadox() + (pa or 0)
	local chance = 	(100 + 2*self:combatFatigue()) / 100 * math.pow((total_paradox - self:paradoxChanceModifier()) / 200, 2)
	if self:getParadox() < 200 then chance = 0 end
	--print("[Paradox] Fail chance: ", chance, "::", self:getParadox())
	chance = util.bound(chance, 0, 100)
	return rng.percent(chance), chance
end

function _M:paradoxAnomalyChance(pa)
	local total_paradox = self:getParadox() + (pa or 0)
	local chance = 	(100 + 2*self:combatFatigue()) / 100 * math.pow((total_paradox- self:paradoxChanceModifier()) / 300, 3)
	if self:getParadox() < 300 then chance = 0 end
	--print("[Paradox] Anomaly chance: ", chance, "::", self:getParadox())
	chance = util.bound(chance, 0, 100)
	return rng.percent(chance), chance
end

function _M:paradoxBackfireChance(pa)
	local total_paradox = self:getParadox() + (pa or 0)
	local chance = (100 + 2*self:combatFatigue()) / 100 * math.pow((total_paradox - self:paradoxChanceModifier()) / 400, 4)
	if self:getParadox() < 400 then chance = 0 end
	--print("[Paradox] Backfire chance: ", chance, "::", self:getParadox())
	chance = util.bound(chance, 0, 100)
	return rng.percent(chance), chance
end

-- Overwrite incParadox to set up threshold log messages
local previous_incParadox = _M.incParadox

function _M:incParadox(paradox)
	-- Failure checks
	if self:getParadox() < 200 and self:getParadox() + paradox >= 200 then
		game.logPlayer(self, "#LIGHT_RED#You feel the edges of time begin to fray!")
	end
	if self:getParadox() > 200 and self:getParadox() + paradox <= 200 then
		game.logPlayer(self, "#LIGHT_BLUE#Time feels more stable.")
	end
	-- Anomaly checks
	if self:getParadox() < 300 and self:getParadox() + paradox >= 300 then
		game.logPlayer(self, "#LIGHT_RED#You feel the edges of space begin to ripple and bend!")
	end
	if self:getParadox() > 300 and self:getParadox() + paradox <= 300 then
		game.logPlayer(self, "#LIGHT_BLUE#Space feels more stable.")
	end
	-- Backfire checks
	if self:getParadox() < 400 and self:getParadox() + paradox >= 400 then
		game.logPlayer(self, "#LIGHT_RED#Space and time both fight against your control!")
	end
	if self:getParadox() > 400 and self:getParadox() + paradox <= 400 then
		game.logPlayer(self, "#LIGHT_BLUE#Space and time have calmed...  somewhat.")
	end
	return previous_incParadox(self, paradox)
end

-- Overwrite incStamina to set up Adrenaline Surge
local previous_incStamina = _M.incStamina

function _M:incStamina(stamina)
	if stamina < 0 and self:hasEffect(self.EFF_ADRENALINE_SURGE) then
		local stamina_cost = math.abs(stamina)
		if self.stamina - stamina_cost < 0 then
			local damage = stamina_cost - (self.stamina or 0)
			self:incStamina(-self.stamina or 0)
			self.life = self.life - damage
		else
			return previous_incStamina(self, stamina)
		end
	else
		return previous_incStamina(self, stamina)
	end
end

--- Called before a talent is used
-- Check the actor can cast it
-- @param ab the talent (not the id, the table)
-- @return true to continue, false to stop
function _M:preUseTalent(ab, silent, fake)
	if self:attr("feared") and (ab.mode ~= "sustained" or not self:isTalentActive(ab.id)) then
		if not silent then game.logSeen(self, "%s is too afraid to use %s.", self.name:capitalize(), ab.name) end
		return false
	end
	-- When silenced you can deactivate spells but not activate them
	if ab.no_silence and self:attr("silence") and (ab.mode ~= "sustained" or not self:isTalentActive(ab.id)) then
		if not silent then game.logSeen(self, "%s is silenced and cannot use %s.", self.name:capitalize(), ab.name) end
		return false
	end
	if ab.is_spell and self:attr("forbid_arcane") and (ab.mode ~= "sustained" or not self:isTalentActive(ab.id)) then
		if not silent then game.logSeen(self, "The spell fizzles.") end
		return false
	end

	-- when using unarmed techniques check for weapons and heavy armor
	if ab.is_unarmed and not (ab.mode == "sustained" and self:isTalentActive(ab.id)) then
		-- first check for heavy and massive armor
		if self:hasMassiveArmor() then
			if not silent then game.logSeen(self, "You are too heavily armoured to use this talent.") end
			return false
		-- next make sure we're unarmed
		elseif not self:isUnarmed() then
			if not silent then game.logSeen(self, "You can't use this talent while holding a weapon or shield.") end
			return false
		end
	end


	if not self:enoughEnergy() and not fake then return false end

	if ab.mode == "sustained" then
		if ab.sustain_mana and self.max_mana < ab.sustain_mana and not self:isTalentActive(ab.id) then
			if not silent then game.logPlayer(self, "You do not have enough mana to activate %s.", ab.name) end
			return false
		end
		if ab.sustain_stamina and self.max_stamina < ab.sustain_stamina and not self:isTalentActive(ab.id) then
			if not silent then game.logPlayer(self, "You do not have enough stamina to activate %s.", ab.name) end
			return false
		end
		if ab.sustain_vim and self.max_vim < ab.sustain_vim and not self:isTalentActive(ab.id) then
			if not silent then game.logPlayer(self, "You do not have enough vim to activate %s.", ab.name) end
			return false
		end
		if ab.sustain_positive and self.max_positive < ab.sustain_positive and not self:isTalentActive(ab.id) then
			if not silent then game.logPlayer(self, "You do not have enough positive energy to activate %s.", ab.name) end
			return false
		end
		if ab.sustain_negative and self.max_negative < ab.sustain_negative and not self:isTalentActive(ab.id) then
			if not silent then game.logPlayer(self, "You do not have enough negative energy to activate %s.", ab.name) end
			return false
		end
		if ab.sustain_hate and self.max_hate < ab.sustain_hate and not self:isTalentActive(ab.id) then
			if not silent then game.logPlayer(self, "You do not have enough hate to activate %s.", ab.name) end
			return false
		end
		if ab.sustain_psi and self.max_psi < ab.sustain_psi and not self:isTalentActive(ab.id) then
			if not silent then game.logPlayer(self, "You do not have enough energy to activate %s.", ab.name) end
			return false
		end
	elseif not self:attr("force_talent_ignore_ressources") then
		if ab.mana and self:getMana() < util.getval(ab.mana, self, ab) * (100 + 2 * self:combatFatigue()) / 100 then
			if not silent then game.logPlayer(self, "You do not have enough mana to cast %s.", ab.name) end
			return false
		end
		if ab.stamina and self:getStamina() < ab.stamina * (100 + self:combatFatigue()) / 100 and (not self:hasEffect(self.EFF_ADRENALINE_SURGE) or self.life < ab.stamina * (100 + self:combatFatigue()) / 100) then
			if not silent then game.logPlayer(self, "You do not have enough stamina to use %s.", ab.name) end
			return false
		end
		if ab.vim and self:getVim() < ab.vim then
			if not silent then game.logPlayer(self, "You do not have enough vim to use %s.", ab.name) end
			return false
		end
		if ab.positive and self:getPositive() < ab.positive * (100 + self:combatFatigue()) / 100 then
			if not silent then game.logPlayer(self, "You do not have enough positive energy to use %s.", ab.name) end
			return false
		end
		if ab.negative and self:getNegative() < ab.negative * (100 + self:combatFatigue()) / 100 then
			if not silent then game.logPlayer(self, "You do not have enough negative energy to use %s.", ab.name) end
			return false
		end
		if ab.hate and self:getHate() < ab.hate then
			if not silent then game.logPlayer(self, "You do not have enough hate to use %s.", ab.name) end
			return false
		end
		if ab.psi and self:getPsi() < ab.psi * (100 + 2 * self:combatFatigue()) / 100 then
			if not silent then game.logPlayer(self, "You do not have enough energy to cast %s.", ab.name) end
			return false
		end
	end

	-- Equilibrium is special, it has no max, but the higher it is the higher the chance of failure (and loss of the turn)
	-- But it is not affected by fatigue
	if (ab.equilibrium or (ab.sustain_equilibrium and not self:isTalentActive(ab.id))) and not fake and not self:attr("force_talent_ignore_ressources") then
		-- Fail ? lose energy and 1/10 more equilibrium
		if (not self:attr("no_equilibrium_fail") and (not self:attr("no_equilibrium_summon_fail") or not ab.is_summon)) and not self:equilibriumChance(ab.equilibrium or ab.sustain_equilibrium) then
			if not silent then game.logPlayer(self, "You fail to use %s due to your equilibrium!", ab.name) end
			self:incEquilibrium((ab.equilibrium or ab.sustain_equilibrium) / 10)
			self:useEnergy()
			return false
		end
	end

	-- Paradox is special, it has no max, but the higher it is the higher the chance of something bad happening
	if (ab.paradox or (ab.sustain_paradox and not self:isTalentActive(ab.id))) and not fake and not self:attr("force_talent_ignore_ressources") then
		-- Check anomalies first since they can reduce paradox, this way paradox is a self correcting resource
		local paradox_scaling = 1 + self.paradox / 300
		if not game.zone.no_anomalies and not self:attr("no_paradox_fail") and self:paradoxAnomalyChance(ab.paradox or ab.sustain_paradox) then
			-- Random anomaly
			local ts = {}
			for id, t in pairs(self.talents_def) do
				if t.type[1] == "chronomancy/anomalies" then ts[#ts+1] = id end
			end
			if not silent then game.logPlayer(self, "You lose control and unleash an anomaly!") end
			self:forceUseTalent(rng.table(ts), {ignore_energy=true})
			self:incParadox(-(ab.paradox and (ab.paradox * paradox_scaling) or ab.sustain_paradox))
			self:useEnergy()
			return false
		-- Now check for failure
		elseif not self:attr("no_paradox_fail") and self:paradoxFailChance(ab.paradox or ab.sustain_paradox) and not self:hasEffect(self.EFF_SPACETIME_STABILITY) then
			if not silent then game.logPlayer(self, "You fail to use %s due to your paradox!", ab.name) end
			self:incParadox(ab.paradox or ab.sustain_paradox / 10)
			self:useEnergy()
			return false
		end
	end

	-- Confused ? lose a turn!
	if self:attr("confused") and (ab.mode ~= "sustained" or not self:isTalentActive(ab.id)) and ab.no_energy ~= true and not fake and not self:attr("force_talent_ignore_ressources") then
		if rng.percent(self:attr("confused")) then
			if not silent then game.logSeen(self, "%s is confused and fails to use %s.", self.name:capitalize(), ab.name) end
			self:useEnergy()
			return false
		end
	end

	-- Failure chance?
	if self:attr("talent_fail_chance") and (ab.mode ~= "sustained" or not self:isTalentActive(ab.id)) and ab.no_energy ~= true and not fake and not self:attr("force_talent_ignore_ressources") then
		if rng.percent(self:attr("talent_fail_chance")) then
			if not silent then game.logSeen(self, "%s fails to use %s.", self.name:capitalize(), ab.name) end
			self:useEnergy()
			return false
		end
	end

	-- Special checks
	if ab.on_pre_use and not (ab.mode == "sustained" and self:isTalentActive(ab.id)) and not ab.on_pre_use(self, ab, silent, fake) then return false end

	if not silent then
		-- Allow for silent talents
		if ab.message ~= nil then
			if ab.message then
				game.logSeen(self, "%s", self:useTalentMessage(ab))
			end
		elseif ab.mode == "sustained" and not self:isTalentActive(ab.id) then
			game.logSeen(self, "%s activates %s.", self.name:capitalize(), ab.name)
		elseif ab.mode == "sustained" and self:isTalentActive(ab.id) then
			game.logSeen(self, "%s deactivates %s.", self.name:capitalize(), ab.name)
		elseif ab.is_spell then
			game.logSeen(self, "%s casts %s.", self.name:capitalize(), ab.name)
		else
			game.logSeen(self, "%s uses %s.", self.name:capitalize(), ab.name)
		end
	end

	return true
end

--- Called before a talent is used
-- Check if it must use a turn, mana, stamina, ...
-- @param ab the talent (not the id, the table)
-- @param ret the return of the talent action
-- @return true to continue, false to stop
function _M:postUseTalent(ab, ret)
	if not ret then return end

	self.changed = true

	-- Handle inscriptions (delay it so it does not affect current inscription)
	game:onTickEnd(function()
		if ab.type[1] == "inscriptions/infusions" then
			self:setEffect(self.EFF_INFUSION_COOLDOWN, 10, {power=1})
		elseif ab.type[1] == "inscriptions/runes" then
			self:setEffect(self.EFF_RUNE_COOLDOWN, 10, {power=1})
		elseif ab.type[1] == "inscriptions/taints" then
			self:setEffect(self.EFF_TAINT_COOLDOWN, 10, {power=1})
		end
	end)

	if not ab.no_energy then
		if ab.is_spell then
			self:useEnergy(game.energy_to_act * self:combatSpellSpeed())
		elseif ab.is_summon then
			self:useEnergy(game.energy_to_act * self:combatSummonSpeed())
		elseif ab.type[1]:find("^technique/") then
			self:useEnergy(game.energy_to_act * self:combatSpeed())
		else
			self:useEnergy()
		end
	end

	local trigger = false
	if ab.mode == "sustained" then
		if not self:isTalentActive(ab.id) then
			if ab.sustain_mana then
				trigger = true; self:incMaxMana(-ab.sustain_mana)
			end
			if ab.sustain_stamina then
				trigger = true; self:incMaxStamina(-ab.sustain_stamina)
			end
			if ab.sustain_vim then
				trigger = true; self:incMaxVim(-ab.sustain_vim)
			end
			if ab.sustain_equilibrium then
				trigger = true; self:incMinEquilibrium(ab.sustain_equilibrium)
			end
			if ab.sustain_positive then
				trigger = true; self:incMaxPositive(-ab.sustain_positive)
			end
			if ab.sustain_negative then
				trigger = true; self:incMaxNegative(-ab.sustain_negative)
			end
			if ab.sustain_hate then
				trigger = true; self:incMaxHate(-ab.sustain_hate)
			end
			if ab.sustain_paradox then
				trigger = true; self:breakGatherTheThreads(); self:incMinParadox(ab.sustain_paradox)
			end
			if ab.sustain_psi then
				trigger = true; self:incMaxPsi(-ab.sustain_psi)
			end
		else
			if ab.sustain_mana then
				self:incMaxMana(ab.sustain_mana)
			end
			if ab.sustain_stamina then
				self:incMaxStamina(ab.sustain_stamina)
			end
			if ab.sustain_vim then
				self:incMaxVim(ab.sustain_vim)
			end
			if ab.sustain_equilibrium then
				self:incMinEquilibrium(-ab.sustain_equilibrium)
			end
			if ab.sustain_positive then
				self:incMaxPositive(ab.sustain_positive)
			end
			if ab.sustain_negative then
				self:incMaxNegative(ab.sustain_negative)
			end
			if ab.sustain_hate then
				self:incMaxHate(ab.sustain_hate)
			end
			if ab.sustain_paradox then
				self:incMinParadox(-ab.sustain_paradox)
			end
			if ab.sustain_psi then
				self:incMaxPsi(ab.sustain_psi)
			end
		end
	elseif not self:attr("force_talent_ignore_ressources") then
		if ab.mana then
			trigger = true; self:incMana(-util.getval(ab.mana, self, ab) * (100 + 2 * self:combatFatigue()) / 100)
		end
		if ab.stamina then
			trigger = true; self:incStamina(-ab.stamina * (100 + self:combatFatigue()) / 100)
		end
		-- Vim is not affected by fatigue
		if ab.vim then
			trigger = true; self:incVim(-ab.vim)
		end
		if ab.positive then
			trigger = true; self:incPositive(-ab.positive * (100 + self:combatFatigue()) / 100)
		end
		if ab.negative then
			trigger = true; self:incNegative(-ab.negative * (100 + self:combatFatigue()) / 100)
		end
		if ab.hate then
			trigger = true; self:incHate(-ab.hate)
		end
		-- Equilibrium is not affected by fatigue
		if ab.equilibrium then
			trigger = true; self:incEquilibrium(ab.equilibrium)
		end
		-- Paradox is not affected by fatigue but it's cost does increase exponentially
		if ab.paradox then
			trigger = true; self:incParadox(ab.paradox * (1 + (self.paradox / 300)))
		end
		if ab.psi then
			trigger = true; self:incPsi(-ab.psi * (100 + 2 * self:combatFatigue()) / 100)
		end
	end

	if trigger and self:hasEffect(self.EFF_BURNING_HEX) then
		local p = self:hasEffect(self.EFF_BURNING_HEX)
		DamageType:get(DamageType.FIRE).projector(p.src, self.x, self.y, DamageType.FIRE, p.dam)
	end

	-- Cancel stealth!
	if ab.id ~= self.T_STEALTH and ab.id ~= self.T_HIDE_IN_PLAIN_SIGHT and not ab.no_break_stealth then self:breakStealth() end
	if ab.id ~= self.T_LIGHTNING_SPEED then self:breakLightningSpeed() end
	if ab.id ~= self.T_PITY then self:breakPity() end
	if ab.id ~= self.T_GATHER_THE_THREADS then self:breakGatherTheThreads() end
	self:breakStepUp()

	if ab.id ~= self.T_REDUX and self:hasEffect(self.EFF_REDUX) and ab.type[1]:find("^chronomancy/") and ab.mode == "activated" and self:getTalentLevel(self.T_REDUX) >= self:getTalentLevel(ab.id) then
		self:removeEffect(self.EFF_REDUX)
		-- this still consumes energy but works as the talent suggests it does
		self:forceUseTalent(ab.id, {ignore_energy=true, ignore_cd = true})
	end

	return true
end

--- Force a talent to activate without using energy or such
function _M:forceUseTalent(t, def)
	if def.no_equilibrium_fail then self:attr("no_equilibrium_fail", 1) end
	if def.no_paradox_fail then self:attr("no_paradox_fail", 1) end
	local ret = {engine.interface.ActorTalents.forceUseTalent(self, t, def)}
	if def.no_equilibrium_fail then self:attr("no_equilibrium_fail", -1) end
	if def.no_paradox_fail then self:attr("no_paradox_fail", -1) end
	return unpack(ret)
end

--- Breaks stealth if active
function _M:breakStealth()
	if self:isTalentActive(self.T_STEALTH) then
		local chance = 0
		if self:knowTalent(self.T_UNSEEN_ACTIONS) then
			chance = 10 + self:getTalentLevel(self.T_UNSEEN_ACTIONS) * 9 + (self:getLck() - 50) * 0.2
		end

		-- Do not break stealth
		if rng.percent(chance) then return end

		self:forceUseTalent(self.T_STEALTH, {ignore_energy=true})
		self.changed = true
	end
end

--- Breaks pity if active
function _M:breakPity()
	if self:isTalentActive(self.T_PITY) then
		self:forceUseTalent(self.T_PITY, {ignore_energy=true})
		self.changed = true
	end
end

--- Breaks step up if active
function _M:breakStepUp()
	if self:hasEffect(self.EFF_STEP_UP) then
		self:removeEffect(self.EFF_STEP_UP)
	end
	if self:hasEffect(self.EFF_WILD_SPEED) then
		self:removeEffect(self.EFF_WILD_SPEED)
	end
	if self:hasEffect(self.EFF_REFLEXIVE_DODGING) then
		self:removeEffect(self.EFF_REFLEXIVE_DODGING)
	end
end

--- Breaks lightning speed if active
function _M:breakLightningSpeed()
	if self:hasEffect(self.EFF_LIGHTNING_SPEED) then
		self:removeEffect(self.EFF_LIGHTNING_SPEED)
	end
end

--- Breaks gather the threads if active
function _M:breakGatherTheThreads()
	if self:hasEffect(self.EFF_GATHER_THE_THREADS) then
		self:removeEffect(self.EFF_GATHER_THE_THREADS)
	end
end

--- Return the full description of a talent
-- You may overload it to add more data (like power usage, ...)
function _M:getTalentFullDescription(t, addlevel, config)
	config = config or {}
	local old = self.talents[t.id]
	if config.force_level then
		self.talents[t.id] = config.force_level
	else
		self.talents[t.id] = (self.talents[t.id] or 0) + (addlevel or 0)
	end

	local d = tstring{}

	d:add({"color",0x6f,0xff,0x83}, "Effective talent level: ", {"color",0x00,0xFF,0x00}, ("%.1f"):format(self:getTalentLevel(t)), true)
	if t.mode == "passive" then d:add({"color",0x6f,0xff,0x83}, "Use mode: ", {"color",0x00,0xFF,0x00}, "Passive", true)
	elseif t.mode == "sustained" then d:add({"color",0x6f,0xff,0x83}, "Use mode: ", {"color",0x00,0xFF,0x00}, "Sustained", true)
	else d:add({"color",0x6f,0xff,0x83}, "Use mode: ", {"color",0x00,0xFF,0x00}, "Activated", true)
	end

	if config.custom then
		d:merge(config.custom)
		d:add(true)
	end
	if not config.ignore_ressources then
		if t.mana or t.sustain_mana then d:add({"color",0x6f,0xff,0x83}, "Mana cost: ", {"color",0x7f,0xff,0xd4}, ""..(util.getval(t.sustain_mana or t.mana, self, t) * (100 + 2 * self:combatFatigue()) / 100), true) end
		if t.stamina or t.sustain_stamina then d:add({"color",0x6f,0xff,0x83}, "Stamina cost: ", {"color",0xff,0xcc,0x80}, ""..(t.sustain_stamina or t.stamina * (100 + self:combatFatigue()) / 100), true) end
		if t.equilibrium or t.sustain_equilibrium then d:add({"color",0x6f,0xff,0x83}, "Equilibrium cost: ", {"color",0x00,0xff,0x74}, ""..(t.equilibrium or t.sustain_equilibrium), true) end
		if t.vim or t.sustain_vim then d:add({"color",0x6f,0xff,0x83}, "Vim cost: ", {"color",0x88,0x88,0x88}, ""..(t.sustain_vim or t.vim), true) end
		if t.positive or t.sustain_positive then d:add({"color",0x6f,0xff,0x83}, "Positive energy cost: ", {"color",255, 215, 0}, ""..(t.sustain_positive or t.positive * (100 + self:combatFatigue()) / 100), true) end
		if t.negative or t.sustain_negative then d:add({"color",0x6f,0xff,0x83}, "Negative energy cost: ", {"color", 127, 127, 127}, ""..(t.sustain_negative or t.negative * (100 + self:combatFatigue()) / 100), true) end
		if t.hate or t.sustain_hate then d:add({"color",0x6f,0xff,0x83}, "Hate cost:  ", {"color", 127, 127, 127}, ""..(t.hate or t.sustain_hate), true) end
		if t.paradox or t.sustain_paradox then d:add({"color",0x6f,0xff,0x83}, "Paradox cost: ", {"color",  176, 196, 222}, ("%0.2f"):format(t.sustain_paradox or t.paradox * (1 + (self.paradox / 300))), true) end
		if t.psi or t.sustain_psi then d:add({"color",0x6f,0xff,0x83}, "Psi cost: ", {"color",0x7f,0xff,0xd4}, ""..(t.sustain_psi or t.psi * (100 + 2 * self.fatigue) / 100), true) end
	end
	if self:getTalentRange(t) > 1 then d:add({"color",0x6f,0xff,0x83}, "Range: ", {"color",0xFF,0xFF,0xFF}, ("%0.2f"):format(self:getTalentRange(t)), true)
	else d:add({"color",0x6f,0xff,0x83}, "Range: ", {"color",0xFF,0xFF,0xFF}, "melee/personal", true)
	end
	if not config.ignore_ressources then
		if self:getTalentCooldown(t) then d:add({"color",0x6f,0xff,0x83}, "Cooldown: ", {"color",0xFF,0xFF,0xFF}, ""..self:getTalentCooldown(t), true) end
	end
	local speed = self:getTalentProjectileSpeed(t)
	if speed then d:add({"color",0x6f,0xff,0x83}, "Travel Speed: ", {"color",0xFF,0xFF,0xFF}, ""..(speed * 100).."% of base", true)
	else d:add({"color",0x6f,0xff,0x83}, "Travel Speed: ", {"color",0xFF,0xFF,0xFF}, "instantaneous", true)
	end
	if not config.ignore_use_time then
		local uspeed = "1 turn"
		if t.no_energy and type(t.no_energy) == "boolean" and t.no_energy == true then uspeed = "instant" end
		d:add({"color",0x6f,0xff,0x83}, "Usage Speed: ", {"color",0xFF,0xFF,0xFF}, uspeed, true)
	end

	d:add({"color",0x6f,0xff,0x83}, "Description: ", {"color",0xFF,0xFF,0xFF})
	d:merge(t.info(self, t):toTString():tokenize(" ()[]"))
	d:add(true)

	self.talents[t.id] = old

	return d
end

function _M:getTalentCooldown(t)
	if not t.cooldown then return end
	local cd = t.cooldown
	if type(cd) == "function" then cd = cd(self, t) end
	if not cd then return end

	if t.type[1] == "inscriptions/infusions" then
		local eff = self:hasEffect(self.EFF_INFUSION_COOLDOWN)
		if eff and eff.power then cd = cd + eff.power end
	elseif t.type[1] == "inscriptions/runes" then
		local eff = self:hasEffect(self.EFF_RUNE_COOLDOWN)
		if eff and eff.power then cd = cd + eff.power end
	elseif t.type[1] == "inscriptions/taints" then
		local eff = self:hasEffect(self.EFF_TAINT_COOLDOWN)
		if eff and eff.power then cd = cd + eff.power end
	end

	if self.talent_cd_reduction[t.id] then cd = cd - self.talent_cd_reduction[t.id] end
	if self.talent_cd_reduction.all then cd = cd - self.talent_cd_reduction.all end
	if t.is_spell then
		return math.ceil(cd * (1 - self.spell_cooldown_reduction or 0))
	else
		return cd
	end
end

--- Starts a talent cooldown; overloaded from the default to handle talent cooldown reduction
-- @param t the talent to cooldown
function _M:startTalentCooldown(t)
	if not t.cooldown then return end
	self.talents_cd[t.id] = self:getTalentCooldown(t)
	self.changed = true
end

--- Setups a talent automatic use
function _M:checkSetTalentAuto(tid, v)
	local t = self:getTalentFromId(tid)
	if v then
		local doit = function()
			self:setTalentAuto(tid, true)
			Dialog:simplePopup("Automatic use enabled", t.name:capitalize().." will now be used as often as possible automatically.")
		end

		local list = {}
		if t.no_energy ~= true then list[#list+1] = "- requires a turn to use" end
		if t.requires_target then list[#list+1] = "- requires a target, your last hostile one will be automatically used" end
		if t.auto_use_warning then list[#list+1] = t.auto_use_warning end

		if #list == 0 then
			doit()
		else
			Dialog:yesnoLongPopup("Automatic use", t.name:capitalize()..":\n"..table.concat(list, "\n").."\n Are you sure?", 500, function(ret)
				if ret then doit() end
			end)
		end
	else
		self:setTalentAuto(tid, false)
		Dialog:simplePopup("Automatic use disabled", t.name:capitalize().." will not be automatically used.")
	end
end

--- How much experience is this actor worth
-- @param target to whom is the exp rewarded
-- @return the experience rewarded
function _M:worthExp(target)
	if not target.level or self.level < target.level - 7 then return 0 end

	-- HHHHAACKKK ! Use a normal scheme for the game except in the infinite dungeon
	if not game.zone.infinite_dungeon then
		local mult = 0.6
		if self.rank == 1 then mult = 0.6
		elseif self.rank == 2 then mult = 0.8
		elseif self.rank == 3 then mult = 3
		elseif self.rank == 3.5 then mult = 12
		elseif self.rank == 4 then mult = 45
		elseif self.rank >= 5 then mult = 100
		end

		return self.level * mult * self.exp_worth * (target.exp_kill_multiplier or 1)
	else
		local mult = 2 + (self.exp_kill_multiplier or 0)
		if self.rank == 1 then mult = 2
		elseif self.rank == 2 then mult = 2
		elseif self.rank == 3 then mult = 3.5
		elseif self.rank == 3.5 then mult = 5
		elseif self.rank == 4 then mult = 6
		elseif self.rank >= 5 then mult = 6.5
		end

		return self.level * mult * self.exp_worth * (target.exp_kill_multiplier or 1)
	end
end

--- Suffocate a bit, lose air
function _M:suffocate(value, src, death_message)
	if self:attr("no_breath") then return false, false end
	if self:attr("invulnerable") then return false, false end
	self.air = self.air - value
	local ae = game.level.map(self.x, self.y, Map.ACTOR)
	if self.air <= 0 then
		game.logSeen(self, "%s suffocates to death!", self.name:capitalize())
		return self:die(src, {special_death_msg=death_message or "suffocated to death"}), true
	end
	return false, true
end

--- Can the actor see the target actor
-- This does not check LOS or such, only the actual ability to see it.<br/>
-- Check for telepathy, invisibility, stealth, ...
function _M:canSeeNoCache(actor, def, def_pct)
	if not actor then return false, 0 end

	-- Full ESP
	if self.esp_all and self.esp_all > 0 then
		return true, 100
	end

	-- ESP, see all, or only types/subtypes
	if self.esp then
		local esp = self.esp
		-- Type based ESP
		if esp[actor.type] and esp[actor.type] > 0 then
			return true, 100
		end
		if esp[actor.type.."/"..actor.subtype] and esp[actor.type.."/"..actor.subtype] > 0 then
			return true, 100
		end
	end

	-- Blindness means can't see anything
	if self:attr("blind") then
		return false, 0
	end

	-- Check for stealth. Checks against the target cunning and level
	if actor:attr("stealth") and actor ~= self then
		local def = self.level / 2 + self:getCun(25, true) + (self:attr("see_stealth") or 0)
		local hit, chance = self:checkHit(def, actor:attr("stealth") + (actor:attr("inc_stealth") or 0), 0, 100)
		if not hit then
			return false, chance
		end
	end

	-- Check for invisibility. This is a "simple" checkHit between invisible and see_invisible attrs
	if actor:attr("invisible") then
		-- Special case, 0 see invisible, can NEVER see invisible things
		if not self:attr("see_invisible") then return false, 0 end
		local hit, chance = self:checkHit(self:attr("see_invisible"), actor:attr("invisible"), 0, 100)
		if not hit then
			return false, chance
		end
	end

	-- check cursed pity talent
	if actor:attr("pity") and actor ~= self then
		if core.fov.distance(self.x, self.y, actor.x, actor.y) >= actor:attr("pity") then
			return false, 10
		end
	end

	if def ~= nil then
		return def, def_pct
	else
		return true, 100
	end
end

function _M:canSee(actor, def, def_pct)
	if not actor then return false, 0 end

	self.can_see_cache = self.can_see_cache or {}
	local s = tostring(def).."/"..tostring(def_pct)

	if self.can_see_cache[actor] and self.can_see_cache[actor][s] then return self.can_see_cache[actor][s][1], self.can_see_cache[actor][s][2] end
	self.can_see_cache[actor] = self.can_see_cache[actor] or {}
	self.can_see_cache[actor][s] = self.can_see_cache[actor][s] or {}

	local res, chance = self:canSeeNoCache(actor, def, def_pct)
	self.can_see_cache[actor][s] = {res,chance}

	-- Make sure the display updates
	if self.player and type(def) == "nil" and actor._mo then actor._mo:onSeen(res) end

	return res, chance
end

--- Reset our own seeing cache
function _M:resetCanSeeCache()
	self.can_see_cache = {}
	setmetatable(self.can_see_cache, {__mode="k"})
end

--- Reset the cache of everything else that had see us on the level
function _M:resetCanSeeCacheOf()
	if not game.level then return end
	for uid, e in pairs(game.level.entities) do
		if e.can_see_cache and e.can_see_cache[self] then e.can_see_cache[self] = nil end
	end
	game.level.map:updateMap(self.x, self.y)
end

--- Does the actor have LOS to the target
function _M:hasLOS(x, y, what)
	if not x or not y then return false, self.x, self.y end
	what = what or "block_sight"

	local lx, ly, is_corner_blocked
	if what == "block_sight" then
		local darkVisionRange
		if self:knowTalent(self.T_DARK_VISION) then
			local t = self:getTalentFromId(self.T_DARK_VISION)
			darkVisionRange = self:getTalentRange(t)
		end

		local l = core.fov.line(self.x, self.y, x, y, "block_sight")
		local inCreepingDark, lastX, lastY = false
		lx, ly, is_corner_blocked = l:step()
		while lx and ly and not is_corner_blocked do
			if game.level.map:checkAllEntities(lx, ly, "block_sight") then
				if darkVisionRange and game.level.map:checkAllEntities(lx, ly, "creepingDark") then
					inCreepingDark = true
				else
					break
				end
			end
			if inCreepingDark and darkVisionRange and core.fov.distance(self.x, self.y, lx, ly) > darkVisionRange then
				lx, ly = lastX or lx, lastY or ly
				break
			end

			lastX, lastY = lx, ly
			lx, ly, is_corner_blocked = l:step()
		end
	else
		local l = core.fov.line(self.x, self.y, x, y, what)
		lx, ly, is_corner_blocked = l:step()
		while lx and ly and not is_corner_blocked do
			if game.level.map:checkAllEntities(lx, ly, what) then break end

			lx, ly, is_corner_blocked = l:step()
		end
	end

	-- Ok if we are at the end reset lx and ly for the next code
	if not lx and not ly and not is_corner_blocked then lx, ly = x, y end

	if lx == x and ly == y then return true, lx, ly end
	return false, lx, ly
end

--- Can the target be applied some effects
-- @param what a string describing what is being tried
function _M:canBe(what)
	if what == "poison" and rng.percent(100 * (self:attr("poison_immune") or 0)) then return false end
	if what == "disease" and rng.percent(100 * (self:attr("disease_immune") or 0)) then return false end
	if what == "cut" and rng.percent(100 * (self:attr("cut_immune") or 0)) then return false end
	if what == "confusion" and rng.percent(100 * (self:attr("confusion_immune") or 0)) then return false end
	if what == "blind" and rng.percent(100 * (self:attr("blind_immune") or 0)) then return false end
	if what == "silence" and rng.percent(100 * (self:attr("silence_immune") or 0)) then return false end
	if what == "disarm" and rng.percent(100 * (self:attr("disarm_immune") or 0)) then return false end
	if what == "pin" and rng.percent(100 * (self:attr("pin_immune") or 0)) and not self:attr("levitation") then return false end
	if what == "stun" and rng.percent(100 * (self:attr("stun_immune") or 0)) then return false end
	if what == "fear" and rng.percent(100 * (self:attr("fear_immune") or 0)) then return false end
	if what == "knockback" and (rng.percent(100 * (self:attr("knockback_immune") or 0)) or self:attr("never_move")) then return false end
	if what == "stone" and rng.percent(100 * (self:attr("stone_immune") or 0)) then return false end
	if what == "instakill" and rng.percent(100 * (self:attr("instakill_immune") or 0)) then return false end
	if what == "teleport" and (rng.percent(100 * (self:attr("teleport_immune") or 0)) or self:attr("encased_in_ice")) then return false end
	if what == "worldport" and game.level.data and game.level.data.no_worldport then return false end
	if what == "summon" and self:attr("suppress_summon") then return false end
	return true
end

-- Tells on_set_temporary_effect() what save to use for a given effect type
local save_for_effects = {
	magical = "combatSpellResist",
	mental = "combatMentalResist",
	physical = "combatPhysicalResist",
}

--- Adjust temporary effects
function _M:on_set_temporary_effect(eff_id, e, p)
	if p.apply_power and (save_for_effects[e.type] or p.apply_save) then
		local save = 0
		p.maximum = p.dur
		p.minimum = p.min_dur or 0 --Default minimum duration is 0. Can specify something else by putting min_dur=foo in p when calling setEffect()
		save = self[p.apply_save or save_for_effects[e.type]](self)
		--local duration = p.maximum - math.max(0, math.floor((save - p.apply_power) / 5))
		local duration = p.maximum - math.max(0, (math.floor(save/5) - math.floor(p.apply_power/5)))
		p.dur = util.bound(duration, p.minimum or 0, p.maximum)
		p.amount_decreased = p.maximum - p.dur
		local save_type = nil
		if p.apply_save then save_type = p.apply_save else save_type = save_for_effects[e.type] end
		if save_type == "combatPhysicalResist"
			then p.save_string = "Physical save"
		elseif save_type == "combatMentalResist"
			then p.save_string = "Mental save"
		elseif save_type == "combatSpellResist"
			then p.save_string = "Spell save"
		end
		if not p.no_ct_effect and e.status == "detrimental" then self:crossTierEffect(eff_id, p.apply_power, p.apply_save or save_for_effects[e.type]) end
		p.total_dur = p.dur
		p.apply_power = nil
	end

	if e.status == "detrimental" and self:knowTalent(self.T_RESILIENT_BONES) then
		p.dur = math.ceil(p.dur * (1 - (self:getTalentLevel(self.T_RESILIENT_BONES) / 12)))
	end
	if e.status == "detrimental" and e.type ~= "other" and self:hasEffect(self.EFF_FADE_FROM_TIME) then
		local fft = self:hasEffect(self.EFF_FADE_FROM_TIME)
		p.dur = math.ceil(p.dur * (1 - (fft.power/100)))
	end
	if e.status == "detrimental" and e.type ~= "magical" and e.type ~= "other" and self:knowTalent(self.T_SUPPRESSION) then
		local t = self:getTalentFromId(self.T_SUPPRESSION)
		p.dur = math.ceil(p.dur * (1 - (t.getPercent(self, t)/100)))
	end
	if self:knowTalent(self.T_VITALITY) and e.status == "detrimental" and (e.subtype.wound or e.subtype.poison or e.subtype.disease) then
		local t = self:getTalentFromId(self.T_VITALITY)
		p.dur = math.ceil(p.dur * (1 - t.getWoundReduction(self, t)))
	end
	if e.status == "detrimental" and self:attr("negative_status_effect_immune") then
		p.dur = 0
	end
end

--- Called when we are the target of a projection
function _M:on_project_acquire(tx, ty, who, t, x, y, damtype, dam, particles, is_projectile, mods)
	if is_projectile and self:attr("projectile_evasion") and rng.percent(self.projectile_evasion) then
		local spread = self.projectile_evasion_spread or 1
		mods.x = x + rng.range(-spread, spread)
		mods.y = y + rng.range(-spread, spread)
		return true
	end
end

--- Called when we are projected upon
-- This is used to do spell reflection, antimagic, ...
function _M:on_project(tx, ty, who, t, x, y, damtype, dam, particles)
	-- Spell reflect
	if self:attr("spell_reflect") and (t.talent and t.talent.reflectable and t.talent.is_spell) and rng.percent(self:attr("spell_reflect")) then
		game.logSeen(self, "%s reflects the spell!", self.name:capitalize())
		-- Setup the bypass so it does not eternally reflect between two actors
		t.bypass = true
		who:project(t, x, y, damtype, dam, particles)
		return true
	end

	-- Spell absorb
	if self:attr("spell_absorb") and (t.talent and t.talent.is_spell) and rng.percent(self:attr("spell_absorb")) then
		game.logSeen(self, "%s ignores the spell!", self.name:capitalize())
		return true
	end
	return false
end

--- Called when we have been projected upon and the DamageType is about to be called
function _M:projected(tx, ty, who, t, x, y, damtype, dam, particles)
	return false
end

--- Called when we are targeted by a projectile
function _M:on_projectile_target(x, y, p)
	if self:attr("slow_projectiles") then
		print("Projectile slowing down from", p.energy.mod)
		p.energy.mod = p.energy.mod * (100 - self.slow_projectiles) / 100
		print("Projectile slowing down to", p.energy.mod)
	end
	if self:knowTalent(self.T_HEIGHTENED_REFLEXES) then
		local t = self:getTalentFromId(self.T_HEIGHTENED_REFLEXES)
		t.do_reflexes(self, t)
	end
end

--- Called when we have acquired grids
function _M:on_project_grids(grids)
	if self:attr("encased_in_ice") then
		-- Only hit yourself
		while next(grids) do grids[next(grids)] = nil end
		grids[self.x] = {[self.y]=true}
	end
end

--- Call when added to a level
-- Used to make escorts and such
function _M:addedToLevel(level, x, y)
	if not self._rst_full then self:resetToFull() self._rst_full = true end -- Only do it once, the first time we come into being
	self:updateModdableTile()
	self:recomputeGlobalSpeed()
	if self.make_escort then
		for _, filter in ipairs(self.make_escort) do
			for i = 1, filter.number do
				if not filter.chance or rng.percent(filter.chance) then
					-- Find space
					local x, y = util.findFreeGrid(self.x, self.y, 10, true, {[Map.ACTOR]=true})
					if not x then break end

					-- Find an actor with that filter
					local m = game.zone:makeEntity(game.level, "actor", filter, nil, true)
					if m and m:canMove(x, y) then
						if filter.no_subescort then m.make_escort = nil end
						game.zone:addEntity(game.level, m, "actor", x, y)
					elseif m then m:removed() end
				end
			end
		end
		self.make_escort = nil
	end

	if game.level.data.zero_gravity then self:setEffect(self.EFF_ZERO_GRAVITY, 1, {})
	else self:removeEffect(self.EFF_ZERO_GRAVITY, nil, true) end

	self:check("on_added_to_level", level, x, y)
end

--- Called upon dropping an object
function _M:onDropObject(o)
	if self:attr("has_transmo") then o.__transmo = false end
end

function _M:transmoPricemod(o) if o.type == "gem" then return 0.40 else return 0.05 end end
function _M:transmoFilter(o) if o:getPrice() <= 0 or o.quest then return false end return true end
function _M:transmoInven(inven, idx, o)
	local price = math.min(o:getPrice() * self:transmoPricemod(o), 25) * o:getNumber()
	local price = math.min(o:getPrice() * self:transmoPricemod(o), 25) * o:getNumber()
	price = math.floor(price * 100) / 100 -- Make sure we get at most 2 digit precision
	if price ~= price or not tostring(price):find("^[0-9]") then price = 1 end -- NaN is the only value that does not equals itself, this is the way to check it since we do not have a math.isnan method
	self:removeObject(self:getInven("INVEN"), idx, true)
	self:sortInven()
	self:incMoney(price)
	if self.hasQuest and self:hasQuest("shertul-fortress") then self:hasQuest("shertul-fortress"):gain_energy(price/10) end
	game.log("You gain %0.2f gold from the transmogrification of %s.", price, o:getName{do_count=true, do_color=true})
end

function _M:transmoGetNumberItems()
	local inven = self:getInven("INVEN")
	local nb = 0
	for i, o in ipairs(inven) do if o.__transmo then nb = nb + 1 end end
	return nb
end
