-- ToME - Tales of Maj'Eyal
-- Copyright (C) 2009 - 2020 Nicolas Casalini
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
	name = "Call of the Crypt",
	type = {"spell/master-of-bones",1},
	require = spells_req1,
	points = 5,
	fake_ressource = true,
	mana = 5,
	soul = function(self, t) return math.max(1, math.min(t.getMax(self, t), self:getSoul())) end,
	cooldown = 14,
	tactical = { ATTACK = 10 },
	requires_target = true,
	autolearn_talent = "T_SOUL_POOL",
	range = 0,
	minions_list = {
		skel_warrior = {
			type = "undead", subtype = "skeleton",
			name = "skeleton warrior", color=colors.SLATE, image="npc/skeleton_warrior.png",
			blood_color = colors.GREY,
			display = "s", color=colors.SLATE,
			combat = { dam=1, atk=1, apr=1 },
			level_range = {1, nil}, exp_worth = 0,
			body = { INVEN = 10, MAINHAND=1, OFFHAND=1, BODY=1, QUIVER=1 },
			infravision = 10,
			rank = 2,
			size_category = 3,
			autolevel = "warrior",
			ai = "dumb_talented_simple", ai_state = { ai_move="move_complex", talent_in=4, },
			stats = { str=14, dex=12, mag=10, con=12 },
			resolvers.racial(),
			resolvers.tmasteries{ ["technique/other"]=0.3, ["technique/2hweapon-offense"]=0.3, ["technique/2hweapon-cripple"]=0.3 },
			open_door = true,
			cut_immune = 1,
			blind_immune = 1,
			fear_immune = 1,
			see_invisible = 2,
			poison_immune = 1,
			undead = 1,
			rarity = 1,
			skeleton_minion = "warrior",

			max_life = resolvers.rngavg(90,100),
			combat_armor = 5, combat_def = 1,
			resolvers.equip{ {type="weapon", subtype="greatsword", autoreq=true} },
			resolvers.talents{
				T_STUNNING_BLOW={base=1, every=7, max=5},
				T_WEAPON_COMBAT={base=1, every=7, max=10},
				T_WEAPONS_MASTERY={base=1, every=7, max=10},
			},
			ai_state = { talent_in=1, },
		},
		a_skel_warrior = {
			type = "undead", subtype = "skeleton",
			name = "armoured skeleton warrior", color=colors.STEEL_BLUE, image="npc/armored_skeleton_warrior.png",
			blood_color = colors.GREY,
			display = "s", color=colors.STEEL_BLUE,
			combat = { dam=1, atk=1, apr=1 },
			level_range = {1, nil}, exp_worth = 0,
			body = { INVEN = 10, MAINHAND=1, OFFHAND=1, BODY=1, QUIVER=1 },
			infravision = 10,
			rank = 2,
			size_category = 3,
			autolevel = "warrior",
			ai = "dumb_talented_simple", ai_state = { ai_move="move_complex", talent_in=4, },
			stats = { str=14, dex=12, mag=10, con=12 },
			resolvers.racial(),
			resolvers.tmasteries{ ["technique/other"]=0.3, ["technique/2hweapon-offense"]=0.3, ["technique/2hweapon-cripple"]=0.3 },
			open_door = true,
			cut_immune = 1,
			blind_immune = 1,
			fear_immune = 1,
			poison_immune = 1,
			see_invisible = 2,
			undead = 1,
			rarity = 1,
			skeleton_minion = "warrior",

			resolvers.inscriptions(1, "rune"),
			resolvers.talents{
				T_WEAPON_COMBAT={base=1, every=7, max=10},
				T_WEAPONS_MASTERY={base=1, every=7, max=10},
				T_ARMOUR_TRAINING={base=2, every=14, max=4},
				T_SHIELD_PUMMEL={base=1, every=7, max=5},
				T_RIPOSTE={base=3, every=7, max=7},
				T_OVERPOWER={base=1, every=7, max=5},
			},
			resolvers.equip{ {type="weapon", subtype="longsword", autoreq=true}, {type="armor", subtype="shield", autoreq=true}, {type="armor", subtype="heavy", autoreq=true} },
			ai_state = { talent_in=1, },
		},
		skel_m_archer = {
			type = "undead", subtype = "skeleton",
			name = "skeleton master archer", color=colors.LIGHT_UMBER, image="npc/master_skeleton_archer.png",
			blood_color = colors.GREY,
			display = "s",
			combat = { dam=1, atk=1, apr=1 },
			level_range = {1, nil}, exp_worth = 0,
			body = { INVEN = 10, MAINHAND=1, OFFHAND=1, BODY=1, QUIVER=1 },
			infravision = 10,
			rank = 2,
			size_category = 3,
			autolevel = "warrior",
			ai = "dumb_talented_simple", ai_state = { ai_move="move_complex", talent_in=4, },
			stats = { str=14, dex=12, mag=10, con=12 },
			resolvers.racial(),
			resolvers.tmasteries{ ["technique/other"]=0.3, ["technique/2hweapon-offense"]=0.3, ["technique/2hweapon-cripple"]=0.3 },
			open_door = true,
			cut_immune = 1,
			blind_immune = 1,
			fear_immune = 1,
			poison_immune = 1,
			see_invisible = 2,
			undead = 1,
			rarity = 1,
			skeleton_minion = "archer",

			max_life = resolvers.rngavg(70,80),
			combat_armor = 5, combat_def = 1,
			resolvers.talents{ T_BOW_MASTERY={base=1, every=7, max=10}, T_WEAPON_COMBAT={base=1, every=7, max=10}, T_SHOOT=1, T_PINNING_SHOT=3, T_CRIPPLING_SHOT=3, },
			ai_state = { talent_in=1, },
			rank = 3,
			autolevel = "archer",
			resolvers.equip{ {type="weapon", subtype="longbow", autoreq=true}, {type="ammo", subtype="arrow", autoreq=true} },
		},
		skel_mage = {
			type = "undead", subtype = "skeleton",
			name = "skeleton mage", color=colors.LIGHT_RED, image="npc/skeleton_mage.png",
			blood_color = colors.GREY,
			display = "s",
			combat = { dam=1, atk=1, apr=1 },
			level_range = {1, nil}, exp_worth = 0,
			body = { INVEN = 10, MAINHAND=1, OFFHAND=1, BODY=1, QUIVER=1 },
			infravision = 10,
			rank = 2,
			size_category = 3,
			autolevel = "warrior",
			ai = "dumb_talented_simple", ai_state = { ai_move="move_complex", talent_in=4, },
			stats = { str=14, dex=12, mag=10, con=12 },
			resolvers.racial(),
			resolvers.tmasteries{ ["technique/other"]=0.3, ["technique/2hweapon-offense"]=0.3, ["technique/2hweapon-cripple"]=0.3 },
			open_door = true,
			cut_immune = 1,
			blind_immune = 1,
			fear_immune = 1,
			poison_immune = 1,
			see_invisible = 2,
			undead = 1,
			rarity = 1,
			skeleton_minion = "mage",

			max_life = resolvers.rngavg(50,60),
			max_mana = resolvers.rngavg(70,80),
			combat_armor = 3, combat_def = 1,
			stats = { str=10, dex=12, cun=14, mag=14, con=10 },
			resolvers.talents{ T_STAFF_MASTERY={base=1, every=10, max=5}, T_FLAME={base=1, every=7, max=5}, T_MANATHRUST={base=2, every=7, max=5} },
			resolvers.equip{ {type="weapon", subtype="staff", autoreq=true} },
			autolevel = "caster",
			ai_state = { talent_in=1, },
		},
	},
	radius = function(self, t) return self:getTalentRadius(self:getTalentFromId(self.T_NECROTIC_AURA)) end,
	target = function(self, t) return {type="cone", range=self:getTalentRange(t), radius=self:getTalentRadius(t), selffire=false, talent=t} end,
	getNb = function(self, t, ignore)
		return math.max(1, math.floor(self:combatTalentScale(t, 1, 2, "log")))
	end,
	getMax = function(self, t, ignore)
		local max = math.max(1, math.floor(self:combatTalentScale(t, 1, 4.5)))
		if ignore then return max end
		return math.max(0, max - necroArmyStats(self).nb_skeleton)
	end,
	getLevel = function(self, t) return math.floor(self:combatScale(self:getTalentLevel(t), -6, 0.9, 2, 5)) end, -- -6 @ 1, +2 @ 5, +5 @ 8
	on_pre_use = function(self, t) return math.min(t.getMax(self, t), self:getSoul()) >= 1 end,
	action = function(self, t)
		local nb = t:_getNb(self)
		local max = t:_getMax(self)
		nb = math.min(nb, max, self:getSoul())
		if nb < 1 then return end
		local lev = t.getLevel(self, t)

		-- Summon minions in a cone
		local tg = self:getTalentTarget(t)
		local x, y = self:getTarget(tg)
		if not x or not y then return nil end
		local possible_spots = {}
		self:project(tg, x, y, function(px, py)
			if not game.level.map:checkAllEntities(px, py, "block_move") then
				possible_spots[#possible_spots+1] = {x=px, y=py}
			end
		end)
		if #possible_spots == 0 then return end

		local use_ressource = not self:attr("zero_resource_cost") and not self:attr("force_talent_ignore_ressources")
		for i = 1, nb do
			local pos = rng.tableRemove(possible_spots)
			if pos then
				if use_ressource then self:incSoul(-1) end
				necroSetupSummon(self, self:getTalentLevel(t) >= 3 and t.minions_list.a_skel_warrior or t.minions_list.skel_warrior, pos.x, pos.y, lev, nil, true)
				self.__call_crypt_count = (self.__call_crypt_count or 0) + 1
				if self.__call_crypt_count == 3 then
					self.__call_crypt_count = 0
					if self:getTalentLevel(t) >= 5 then
						local pos = rng.tableRemove(possible_spots)
						if pos then necroSetupSummon(self, rng.percent(50) and t.minions_list.skel_mage or t.minions_list.skel_m_archer, pos.x, pos.y, lev, nil, true) end
					end
				end
			end
		end

		if use_ressource then self:incMana(-util.getval(t.mana, self, t) * (100 + 2 * self:combatFatigue()) / 100) end
		game:playSoundNear(self, "talents/skeleton")
		return true
	end,
	info = function(self, t)
		return ([[Call upon the battle fields of old to collect bones and fuse them with souls, combining them to create skeletal minions to do your bidding.
		Up to %d skeleton warriors of level %d are summoned. Up to %d skeletons can be controlled at once.
		At level 3 the summons become armoured skeletons warriors.
		At level 5 every 3 summoned warriors a free skeleton mage or skeleton archer is also created (without costing a soul).

		#GREY##{italic}#Skeleton minions come in fewer numbers than ghoul minions but are generaly more durable.#{normal}#
		]]):tformat(t:_getNb(self), math.max(1, self.level + t:_getLevel(self)), t:_getMax(self, true))
	end,
}

newTalent{
	name = "Bone Wall",
	type = {"spell/master-of-bones", 2},
	require = spells_req2,
	points = 5,
	mana = 20,
	cooldown = 18, fixed_cooldown = true,
	range = 10,
	tactical = { ATTACKAREA = {COLD = 1, DARKNESS=1}, DISABLE = {pin=1} },
	requires_target = true,
	target = function(self, t)
		local halflength = math.floor(t.getLength(self,t)/2)
		local block = function(_, lx, ly)
			return game.level.map:checkAllEntities(lx, ly, "block_move")
		end
		return {
			type="wall", range=self:getTalentRange(t), halflength=halflength, talent=t, halfmax_spots=halflength+1, block_radius=block,
			nowarning=true, first_target="friend", custom_scan_filter=function(target)
				return target.summoner == self and target.necrotic_minion and target.skeleton_minion
			end,
		}
	end,
	getChance = function(self, t) return math.floor(self:combatTalentScale(t, 20, 50)) end,
	getDuration = function(self, t) return math.floor(self:combatTalentScale(t, 4, 8)) end,
	getLength = function(self, t) return 1 + math.floor(self:combatTalentScale(t, 3, 7)/2)*2 end,
	getDamage = function(self, t) return self:combatTalentSpellDamage(t, 3, 15) end,
	on_pre_use = function(self, t) return necroArmyStats(self).nb_skeleton > 0 end,
	action = function(self, t)
		local tg = self:getTalentTarget(t)
		local x, y, target = self:getTargetLimited(tg)
		if not target or not target.summoner == self or not target.necrotic_minion or not target.skeleton_minion then return nil end

		target:die(self)

		local damage = self:spellCrit(t:_getDamage(self))
		local chance = t:_getChance(self)
		local radius = 1

		self:project(tg, x, y, function(px, py, tg, self)
			local oe = game.level.map(px, py, Map.TERRAIN)
			if not oe or oe.special then return end
			if not oe or oe:attr("temporary") or game.level.map:checkAllEntities(px, py, "block_move") or oe.special then return end
			local e = mod.class.Object.new{
				old_feat = oe,
				name = _t"bone wall",
				image = oe.image,
				add_mos = table.clone(oe.add_mos or {}, true),
				add_displays = table.clone(oe.add_displays or {}),
				desc = _t"a summoned wall of bones",
				type = "wall",
				display = '#', color=colors.GREY, back_color=colors.BLUE,
				always_remember = true,
				can_pass = {pass_wall=1},
				does_block_move = true,
				pass_projectile = true,
				show_tooltip = true,
				block_move = true,
				block_sight = false,
				temporary = t.getDuration(self, t),
				x = px, y = py,
				canAct = false,
				dam = damage,
				pin_chance = chance,
				act = function(self)
					local t = self.summoner:getTalentFromId(self.T_BONE_WALL)
					local tg = {type="ball", range=0, radius=1, friendlyfire=false, talent=t, x=self.x, y=self.y}
					self.summoner.__project_source = self
					self.summoner:projectApply(tg, self.x, self.y, engine.Map.ACTOR, function(target)
						if target.turn_procs.bone_wall then return end
						target.turn_procs.bone_wall = true
						target.turn_procs.bone_wall = true
						engine.DamageType:get(engine.DamageType.FROSTDUSK).projector(self.summoner, target.x, target.y, engine.DamageType.FROSTDUSK, self.dam)
						if target:canBe("pin") and rng.percent(self.pin_chance) then
							target:setEffect(target.EFF_PINNED, 4, {apply_power=self.summoner:combatSpellpower()})
						end
					end, "hostile")
					self.summoner.__project_source = nil
					self:useEnergy()
					self.temporary = self.temporary - 1
					if self.temporary <= 0 then
						game.level.map(self.x, self.y, engine.Map.TERRAIN, self.old_feat)
						game.level:removeEntity(self)
						game.level.map:updateMap(self.x, self.y)
						game.nicer_tiles:updateAround(game.level, self.x, self.y)
					end
				end,
				dig = function(src, x, y, old)
					game.level:removeEntity(old, true)
					return nil, old.old_feat
				end,
				summoner_gain_exp = true,
				summoner = self,
			}
			e.add_displays[#e.add_displays+1] = mod.class.Grid.new{image="terrain/bone_wall_0"..rng.range(1,4)..".png", z=19}
			e.tooltip = mod.class.Grid.tooltip
			game.level:addEntity(e)
			game.level.map(px, py, Map.TERRAIN, e)
		--	game.nicer_tiles:updateAround(game.level, px, py)
		--	game.level.map:updateMap(px, py)
		end)
		game:playSoundNear(self, "talents/skeleton")
		return true
	end,
	info = function(self, t)
		return ([[Sacrifice one skeleton to turn it into a wall of bones of %d length for %d turns.
		The wall is strong enough to block movement but projectiles and sight are not hampered.
		Any foes adjacent to it takes %0.2f frostdusk damage and has %d%% chances to be pinned for 4 turns.
		]]):tformat(3 + math.floor(self:getTalentLevel(t) / 2) * 2, t:_getDuration(self), damDesc(self, DamageType.FROSTDUSK, t:_getDamage(self)), t:_getChance(self))
	end,
}

newTalent{
	name = "Assemble",
	type = {"spell/master-of-bones",3},
	require = spells_req3,
	points = 5,
	cooldown = 20,
	mana = 30,
	minions_list = {
		bone_giant = {
			type = "undead", subtype = "giant",
			blood_color = colors.GREY,
			display = "K",
			combat = { dam=resolvers.levelup(resolvers.mbonus(45, 20), 1, 1), atk=15, apr=10, dammod={str=0.8} },
			body = { INVEN = 10, MAINHAND=1, OFFHAND=1, BODY=1 },
			infravision = 10,
			life_rating = 12,
			max_stamina = 90,
			rank = 2,
			size_category = 4,
			movement_speed = 1.5,
			autolevel = "warrior",
			ai = "dumb_talented_simple", ai_state = { ai_move="move_complex", talent_in=2, },
			stats = { str=20, dex=12, mag=16, con=16 },
			resists = { [DamageType.PHYSICAL] = 20, [DamageType.BLIGHT] = 20, [DamageType.COLD] = 50, },
			open_door = 1,
			no_breath = 1,
			confusion_immune = 1,
			poison_immune = 1,
			blind_immune = 1,
			fear_immune = 1,
			stun_immune = 1,
			is_bone_giant = true,
			see_invisible = resolvers.mbonus(15, 5),
			undead = 1,
			name = "bone giant", color=colors.WHITE,
			desc=_t[[A towering creature, made from the bones of dozens of dead bodies. It is covered by an unholy aura.]],
			resolvers.nice_tile{image="invis.png", add_mos = {{image="npc/undead_giant_bone_giant.png", display_h=2, display_y=-1}}},
			max_life = resolvers.rngavg(100,120),
			level_range = {1, nil}, exp_worth = 0,
			combat_armor = 20, combat_def = 0,
			on_melee_hit = {[DamageType.BLIGHT]=resolvers.mbonus(15, 5)},
			melee_project = {[DamageType.BLIGHT]=resolvers.mbonus(15, 5)},
			resolvers.talents{ T_BONE_ARMOUR={base=3, every=10, max=5}, T_STUN={base=3, every=10, max=5}, },
		},
		h_bone_giant = {
			type = "undead", subtype = "giant",
			blood_color = colors.GREY,
			display = "K",
			combat = { dam=resolvers.levelup(resolvers.mbonus(45, 20), 1, 1), atk=15, apr=10, dammod={str=0.8} },
			body = { INVEN = 10, MAINHAND=1, OFFHAND=1, BODY=1 },
			infravision = 10,
			life_rating = 12,
			max_stamina = 90,
			rank = 2,
			size_category = 4,
			movement_speed = 1.5,
			autolevel = "warrior",
			ai = "dumb_talented_simple", ai_state = { ai_move="move_complex", talent_in=2, },
			stats = { str=20, dex=12, mag=16, con=16 },
			resists = { [DamageType.PHYSICAL] = 20, [DamageType.BLIGHT] = 20, [DamageType.COLD] = 50, },
			open_door = 1,
			no_breath = 1,
			confusion_immune = 1,
			poison_immune = 1,
			blind_immune = 1,
			fear_immune = 1,
			stun_immune = 1,
			is_bone_giant = true,
			see_invisible = resolvers.mbonus(15, 5),
			undead = 1,
			name = "heavy bone giant", color=colors.RED,
			desc=_t[[A towering creature, made from the bones of hundreds of dead bodies. It is covered by an unholy aura.]],
			resolvers.nice_tile{image="invis.png", add_mos = {{image="npc/undead_giant_heavy_bone_giant.png", display_h=2, display_y=-1}}},
			level_range = {1, nil}, exp_worth = 0,
			max_life = resolvers.rngavg(100,120),
			combat_armor = 20, combat_def = 0,
			on_melee_hit = {[DamageType.BLIGHT]=resolvers.mbonus(15, 5)},
			melee_project = {[DamageType.BLIGHT]=resolvers.mbonus(15, 5)},
			resolvers.talents{ T_BONE_ARMOUR={base=3, every=10, max=5}, T_THROW_BONES={base=4, every=10, max=7}, T_STUN={base=3, every=10, max=5}, },
		},
		e_bone_giant = {
			type = "undead", subtype = "giant",
			blood_color = colors.GREY,
			display = "K",
			combat = { dam=resolvers.levelup(resolvers.mbonus(45, 20), 1, 1), atk=15, apr=10, dammod={str=0.8} },
			body = { INVEN = 10, MAINHAND=1, OFFHAND=1, BODY=1 },
			infravision = 10,
			life_rating = 12,
			max_stamina = 90,
			rank = 2,
			size_category = 4,
			movement_speed = 1.5,
			autolevel = "warrior",
			ai = "dumb_talented_simple", ai_state = { ai_move="move_complex", talent_in=2, },
			stats = { str=20, dex=12, mag=16, con=16 },
			resists = { [DamageType.PHYSICAL] = 20, [DamageType.BLIGHT] = 20, [DamageType.COLD] = 50, },
			open_door = 1,
			no_breath = 1,
			confusion_immune = 1,
			poison_immune = 1,
			blind_immune = 1,
			fear_immune = 1,
			stun_immune = 1,
			is_bone_giant = true,
			see_invisible = resolvers.mbonus(15, 5),
			undead = 1,
			name = "eternal bone giant", color=colors.GREY,
			desc=_t[[A towering creature, made from the bones of hundreds of dead bodies. It is covered by an unholy aura.]],
			resolvers.nice_tile{image="invis.png", add_mos = {{image="npc/undead_giant_eternal_bone_giant.png", display_h=2, display_y=-1}}},
			level_range = {1, nil}, exp_worth = 0,
			max_life = resolvers.rngavg(100,120),
			combat_armor = 40, combat_def = 20,
			on_melee_hit = {[DamageType.BLIGHT]=resolvers.mbonus(15, 5)},
			melee_project = {[DamageType.BLIGHT]=resolvers.mbonus(15, 5)},
			autolevel = "warriormage",
			resists = {all = 50},
			resolvers.talents{ T_BONE_ARMOUR={base=5, every=10, max=7}, T_STUN={base=3, every=10, max=5}, T_SKELETON_REASSEMBLE=5, },
		},
	},
	tactical = { ATTACK = 2 },
	requires_target = true,
	range = 10,
	getLevel = function(self, t) return math.floor(self:combatScale(self:getTalentLevel(t), -6, 0.9, 2, 5)) end, -- -6 @ 1, +2 @ 5, +5 @ 8
	on_pre_use = function(self, t) local stats = necroArmyStats(self) return stats.nb_skeleton >= 3 end,
	action = function(self, t)
		local stats = necroArmyStats(self)
		if stats.nb_skeleton < 3 then return end
		if stats.bone_giant then stats.bone_giant:die(self) end

		local list = {}
		for _, m in ipairs(stats.list) do if m.skeleton_minion then list[#list+1] = m end end
		table.sort(list, function(a, b)
			local pa, pb = a.life / a.max_life, b.life / b.max_life
			if pa == pb then return a.creation_turn < b.creation_turn end
			return pa < pb
		end)

		local lev = t.getLevel(self, t)
		local pos
		for i = 1, 3 do
			local skel = table.remove(list)
			if i == 1 then pos = {x=skel.x, y=skel.y} end
			skel:die(self)
		end

		local def = t.minions_list.bone_giant
		if self:getTalentLevel(t) >= 6 then def = t.minions_list.e_bone_giant
		elseif self:getTalentLevel(t) >= 3 then def = t.minions_list.h_bone_giant
		end

		necroSetupSummon(self, def, pos.x, pos.y, lev, nil, true)

		game:playSoundNear(self, "talents/skeleton")
		return true
	end,
	info = function(self, t)
		return ([[Every army of undead minions needs its spearhead. To that end you combine 3 skeleton minions into a bone giant of level %d.
		The minions used are automatically selected by taking the weaker and older ones first and a Lord of Skull is never used.
		At level 3 a heavy bone giant is created instead.
		At level 6 an eternal bone giant is created instead.
		Only one bone giant may be active at any time, casting this spell while one exists will destroy it and replace it with a new one.
		]]):
		tformat(math.max(1, self.level + t:_getLevel(self)))
	end,
}

newTalent{
	name = "Lord of Skulls",
	type = {"spell/master-of-bones", 4},
	require = spells_req4,
	points = 5,
	soul = function(self, t) return self:getTalentLevel(t) < 6 and 1 or 3 end,
	mana = 50,
	cooldown = 30,
	tactical = { SPECIAL=10 },
	getLife = function(self, t) return self:combatTalentScale(t, 30, 80) end,
	range = 10,
	target = function(self, t) return {type="hit", range=self:getTalentRange(t)} end,
	ai_outside_combat = true,
	onAIGetTarget = function(self, t)
		local targets = {}
		for _, act in pairs(game.level.entities) do
			if act.summoner == self and act.necrotic_minion and act.skeleton_minion and self:hasLOS(act.x, act.y) and core.fov.distance(self.x, self.y, act.x, act.y) <= self:getTalentRange(t) then
			targets[#targets+1] = act
		end end
		if #targets == 0 then return nil end
		local tgt = rng.table(targets)
		return tgt.x, tgt.y, tgt
	end,
	on_pre_use = function(self, t) return necroArmyStats(self).nb_skeleton > 0 end,
	action = function(self, t, p)
		local tg = self:getTalentTarget(t)
		local x, y, target = self:getTargetLimited(tg)
		if not x or not y or not target then return nil end
		if not target.skeleton_minion or target.summoner ~= self then return nil end

		local stats = necroArmyStats(self)
		if stats.lord_of_skulls then stats.lord_of_skulls:removeEffect(stats.lord_of_skulls.EFF_LORD_OF_SKULLS, false, true) end

		target:setEffect(target.EFF_LORD_OF_SKULLS, 1, {life=t:_getLife(self), talents=self:getTalentLevel(t) >= 6})
		return true
	end,	
	info = function(self, t)
		return ([[Consume a soul to empower one of your skeleton, making it into a Lord of Skulls.
		The Lord of Skulls gain %d%% more life, is instantly healed to full.
		There can be only one active Lord of Skulls, casting this spell on an other skeleton removes the effect from the current one.
		At level 6 it also gains a new talent:
		- Warriors learn Giant Leap, a powerful jump attack that deals damage and dazes and impact and frees the skeleton from any stun, daze and pin effects they may have
		- Archers learn Vital Shot, a devastating attack that can stun and cripple their foes
		- Mages learn Meteoric Crash, a destructive spell that crushes and burns foes in a big radius for multiple turns
		]]):
		tformat(t:_getLife(self))
	end,
}