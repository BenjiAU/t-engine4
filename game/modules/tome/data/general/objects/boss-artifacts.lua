-- ToME - Tales of Middle-Earth
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

local Stats = require "engine.interface.ActorStats"
local Talents = require "engine.interface.ActorTalents"

-- This file describes artifacts associated with a boss of the game, they have a high chance of dropping their respective ones, but they can still be found elsewhere

newEntity{ base = "BASE_LONGSWORD",
	power_source = {nature=true},
	define_as = "LONGSWORD_WINTERTIDE", rarity=false, unided_name = "glittering longsword", image="object/artifact/wintertide.png",
	name = "Wintertide", unique=true,
	desc = [[The air seems to freeze around the blade of this sword, draining all heat from the area.
It is said the Conclave created this weapon for their warmaster during the dark times of the first allure war.]],
	require = { stat = { str=35 }, },
	level_range = {35, 45},
	rarity = 280,
	cost = 2000,
	material_level = 5,
	combat = {
		dam = 45,
		apr = 10,
		physcrit = 10,
		dammod = {str=1},
		damrange = 1.4,
		melee_project={[DamageType.ICE] = 45},
	},
	wielder = {
		lite = 1,
		see_invisible = 2,
		resists={[DamageType.COLD] = 25},
		inc_damage = { [DamageType.COLD] = 20 },
	},
	max_power = 18, power_regen = 1,
	use_power = { name = "generate a burst of ice", power = 8,
		use = function(self, who)
			local tg = {type="ball", range=0, radius=4, selffire=false}
			who:project(tg, who.x, who.y, engine.DamageType.ICE, 40 + (who:getMag() + who:getWil()), {type="freeze"})
			game:playSoundNear(who, "talents/ice")
			game.logSeen(who, "%s invokes the power of %s!", who.name:capitalize(), self.name)
			return {id=true, used=true}
		end
	},
}

newEntity{ base = "BASE_LITE", define_as = "WINTERTIDE_PHIAL",
	power_source = {arcane=true},
	unided_name = "phial filled with darkness", unique = true, image="object/artifact/wintertide_phial.png",
	name = "Wintertide Phial", color=colors.DARK_GREY,
	desc = [[This phial seems filled with darkness, yet it cleanses your thoughts.]],
	level_range = {1, 10},
	rarity = 200,
	encumber = 2,
	cost = 50,
	material_level = 2,

	wielder = {
		lite = 1,
		infravision = 6,
	},

	max_power = 60, power_regen = 1,
	use_power = { name = "cleanse your mind", power = 40,
		use = function(self, who)
			local target = who
			local effs = {}
			local known = false

			-- Go through all spell effects
			for eff_id, p in pairs(target.tmp) do
				local e = target.tempeffect_def[eff_id]
				if e.type == "mental" and e.status == "detrimental" then
					effs[#effs+1] = {"effect", eff_id}
				end
			end

			for i = 1, 3 + math.floor(who:getMag() / 10) do
				if #effs == 0 then break end
				local eff = rng.tableRemove(effs)

				if eff[1] == "effect" then
					target:removeEffect(eff[2])
					known = true
				end
			end
			game.logSeen(who, "%s's mind is clear!", who.name:capitalize())
			return {id=true, used=true}
		end
	},
}

newEntity{ base = "BASE_AMULET",
	power_source = {arcane=true},
	define_as = "FIERY_CHOKER", rarity=false,
	unided_name = "flame-wrought amulet",
	name = "Fiery Choker", unique=true, image="object/artifact/fiery_choker.png",
	desc = [[A choker made of pure flame, forever shifting patterns around the neck of its wearer. Its fire seems to not harm the wearer.]],
	level_range = {32, 42},
	rarity = 220,
	cost = 190,
	wielder = {
		inc_stats = { [Stats.STAT_MAG] = 5, [Stats.STAT_WIL] = 4, [Stats.STAT_CUN] = 3 },
		combat_spellpower = 7,
		combat_spellcrit = 8,
		resists = {
			[DamageType.FIRE] = 20,
			[DamageType.COLD] = -20,
		},
		inc_damage={
			[DamageType.FIRE] = 10,
			[DamageType.COLD] = -5,
		},
		blind_immune = 1,
	},
	talent_on_spell = { {chance=10, talent=Talents.T_VOLCANO, level=3} },
}

-- Artifact, dropped by Rantha
newEntity{ base = "BASE_LEATHER_BOOT",
	power_source = {nature=true},
	define_as = "FROST_TREADS",
	unided_name = "ice-covered boots",
	name = "Frost Treads", unique=true, image="object/artifact/frost_treads.png",
	desc = [[A pair of leather boots. Cold to the touch, they radiate a cold blue light.]],
	require = { stat = { dex=16 }, },
	level_range = {10, 18},
	rarity = 220,
	cost = 40,

	wielder = {
		lite = 1,
		combat_armor = 4,
		combat_def = 1,
		fatigue = 7,
		inc_damage = {
			[DamageType.COLD] = 15,
		},
		resists = {
			[DamageType.COLD] = 20,
			[DamageType.NATURE] = 10,
		},
		inc_stats = { [Stats.STAT_STR] = 4, [Stats.STAT_DEX] = 4, [Stats.STAT_CUN] = 4, },
	},
}

newEntity{ base = "BASE_HELM",
	power_source = {technique=true},
	define_as = "DRAGON_SKULL",
	name = "Dragonskull Helm", unique=true, unided_name="skull helm", image = "object/artifact/dragonskull_helmet.png",
	desc = [[Traces of a dragon's power still remain in this bleached and cracked skull.]],
	require = { stat = { wil=24 }, },
	level_range = {45, 50},
	rarity = 280,
	cost = 200,

	wielder = {
		resists = {
			[DamageType.FIRE] = 15,
			[DamageType.COLD] = 15,
			[DamageType.LIGHTNING] = 15,
		},
		esp = {dragon=1},
		combat_armor = 2,
		fatigue = 12,
		combat_physresist = 12,
		combat_mentalresist = 12,
		combat_spellresist = 12,
	},
}

newEntity{ base = "BASE_TRIDENT",
	power_source = {nature=true},
	define_as = "TRIDENT_TIDES",
	unided_name = "ever-dripping trident",
	name = "Trident of the Tides", unique=true, image = "object/artifact/trident_of_the_tides.png",
	desc = [[The power of the tides rushing through this trident.
Tridents require the exotic weapons mastery talent to use correctly.]],
	require = { stat = { str=35 }, },
	level_range = {30, 40},
	rarity = 230,
	cost = 300,
	material_level = 4,
	combat = {
		dam = 60,
		atk = 10,
		apr = 4,
		physcrit = 15,
		dammod = {str=1.3},
		damrange = 1.4,
		melee_project={
			[DamageType.COLD] = 15,
			[DamageType.NATURE] = 20,
		},
	},

	wielder = {
		combat_spellresist = 18,
		see_invisible = 2,
		resists={[DamageType.COLD] = 25},
		inc_damage = { [DamageType.COLD] = 20 },
	},

	max_power = 150, power_regen = 1,
	use_talent = { id = Talents.T_WATER_BOLT, level=3, power = 60 },
}

newEntity{ base = "BASE_LIGHT_ARMOR",
	power_source = {nature=true},
	define_as = "EEL_SKIN", rarity=false, image = "object/artifact/eel_skin_armor.png",
	name = "Eel-skin armour", unique=true,
	unided_name = "slippery armour", color=colors.VIOLET,
	desc = [[This armour seems to have been patched together from many eels. Yuck.]],
	level_range = {5, 12},
	rarity = 200,
	cost = 500,
	material_level = 2,
	wielder = {
		inc_stats = { [Stats.STAT_DEX] = 2, [Stats.STAT_CUN] = 3,  },
		poison_immune = 0.3,
		combat_armor = 1,
		combat_def = 10,
		fatigue = 2,
	},

	max_power = 50, power_regen = 1,
	use_talent = { id = Talents.T_LIGHTNING, level=2, power = 18 },
	talent_on_spell = { {chance=10, talent=Talents.T_LIGHTNING, level=2} },
}

newEntity{ base = "BASE_HEAVY_ARMOR",
	power_source = {nature=true},
	define_as = "CHROMATIC_HARNESS", rarity=false, image = "object/artifact/armor_chromatic_harness.png",
	name = "Chromatic Harness", unique=true,
	unided_name = "multi-hued scale-mail armour", color=colors.VIOLET,
	desc = [[This dragon scale harness shines with multiple colors, quickly shifting through them in a seemingly chaotic manner.]],
	level_range = {40, 50},
	rarity = 280,
	cost = 500,
	material_level = 5,
	wielder = {
		talent_cd_reduction={[Talents.T_ICE_BREATH]=3, [Talents.T_FIRE_BREATH]=3, [Talents.T_SAND_BREATH]=3, [Talents.T_LIGHTNING_BREATH]=3,},
		inc_stats = { [Stats.STAT_WIL] = 6, [Stats.STAT_CUN] = 4, [Stats.STAT_STR] = 6, [Stats.STAT_LCK] = 10, },
		blind_immune = 0.5,
		stun_immune = 0.5,
		knockback_immune = 1,
		esp = { dragon = 1 },
		combat_def = 10,
		combat_armor = 14,
		fatigue = 16,
		resists = {
			[DamageType.COLD] = 20,
			[DamageType.LIGHTNING] = 20,
			[DamageType.FIRE] = 20,
			[DamageType.PHYSICAL] = 20,
		},
	},
}

newEntity{ base = "BASE_RING",
	power_source = {technique=true},
	define_as = "PRIDE_GLORY", rarity=false,
	name = "Glory of the Pride", unique=true, image="object/artifact/glory_of_the_pride.png",
	desc = [[The most prized treasure of the Battlemaster of the Pride, Grushnak. This gold ring is inscribed in the orc tongue, the black speech.]],
	unided_name = "deep black ring",
	level_range = {40, 50},
	rarity = 280,
	cost = 500,
	material_level = 5,
	wielder = {
		max_mana = -40,
		max_stamina = 40,
		stun_immune = 1,
		confusion_immune = 1,
		combat_atk = 10,
		combat_dam = 10,
		combat_def = 5,
		combat_armor = 10,
		fatigue = -15,
		talent_cd_reduction={
			[Talents.T_RUSH]=6,
		},
		inc_damage={ [DamageType.PHYSICAL] = 8, },
	},
}

newEntity{ base = "BASE_RING",
	power_source = {arcane=true},
	define_as = "NIGHT_SONG", rarity=false,
	name = "Nightsong", unique=true, image = "object/artifact/ring_nightsong.png",
	desc = [[A pitch black ring, unadorned. It seems as though tendrils of darkness creep upon it.]],
	unided_name = "obsidian ring",
	level_range = {15, 23},
	rarity = 250,
	cost = 500,
	material_level = 4,
	wielder = {
		max_stamina = 25,
		combat_def = 6,
		fatigue = -7,
		inc_stats = { [Stats.STAT_CUN] = 6 },
		combat_mentalresist = 13,
		talent_cd_reduction={
			[Talents.T_SHADOWSTEP]=1,
		},
		inc_damage={ [DamageType.PHYSICAL] = 5, },
	},

	max_power = 50, power_regen = 1,
	use_talent = { id = Talents.T_DARK_TENDRILS, level=2, power = 40 },
}

newEntity{ base = "BASE_HELM",
	power_source = {nature=true},
	define_as = "HELM_OF_GARKUL",
	unided_name = "tribal helm",
	name = "Steel Helm of Garkul", unique=true, image="object/artifact/helm_of_garkul.png",
	desc = [[A great helm that belonged to Garkul the Devourer, one of the greatest orcs to live.]],
	require = { stat = { str=16 }, },
	level_range = {12, 22},
	rarity = 200,
	cost = 20,
	material_level = 3,
	skullcracker_mult = 5,

	wielder = {
		combat_armor = 6,
		fatigue = 8,
		inc_stats = { [Stats.STAT_STR] = 5, [Stats.STAT_CON] = 5, [Stats.STAT_WIL] = 4 },
		inc_damage={ [DamageType.PHYSICAL] = 10, },
		combat_physresist = 12,
		combat_mentalresist = 12,
		combat_spellresist = 12,
		talents_types_mastery = {["technique/thuggery"]=0.2},
	},
}

newEntity{ base = "BASE_SHIELD",
	power_source = {nature=true},
	define_as = "LUNAR_SHIELD",
	unique = true,
	name = "Lunar Shield", image = "object/artifact/shield_lunar_shield.png",
	unided_name = "chitinous shield",
	desc = [[A large section of chitin removed from Nimisil. It continues to give off a strange white glow.]],
	color = colors.YELLOW,
	metallic = false,
	require = { stat = { str=35 }, },
	level_range = {40, 50},
	rarity = 280,
	cost = 350,
	material_level = 5,
	special_combat = {
		dam = 45,
		physcrit = 10,
		dammod = {str=1},
		damrange = 1.4,
		damtype = DamageType.ARCANE,
	},
	wielder = {
		resists={[DamageType.DARKNESS] = 25},
		inc_damage={[DamageType.DARKNESS] = 15},

		combat_armor = 7,
		combat_def = 12,
		combat_def_ranged = 5,
		fatigue = 12,

		lite = 1,
		talents_types_mastery = {["celestial/star-fury"]=0.2,["celestial/twilight"]=0.1,},
	},
	talent_on_spell = { {chance=10, talent=Talents.T_MOONLIGHT_RAY, level=2} },
}

newEntity{ base = "BASE_SHIELD",
	power_source = {nature=true},
	define_as = "WRATHROOT_SHIELD",
	unided_name = "large chunk of wood",
	name = "Wrathroot's Barkwood", unique=true, image="object/artifact/shield_wrathroots_barkwood.png",
	desc = [[The barkwood of Wrathroot, made into roughly the shape of a shield.]],
	require = { stat = { str=25 }, },
	level_range = {12, 22},
	rarity = 200,
	cost = 20,
	material_level = 2,
	rarity = false,
	metallic = false,

	special_combat = {
		dam = resolvers.rngavg(20,30),
		physcrit = 2,
		dammod = {str=1.5},
		damrange = 1.4,
	},
	wielder = {
		combat_armor = 10,
		combat_def = 9,
		fatigue = 14,
		resists = {
			[DamageType.FIRE] = -20,
			[DamageType.COLD] = 20,
			[DamageType.NATURE] = 20,
		},
	},
}

newEntity{ base = "BASE_GEM",
	power_source = {nature=true},
	unique = true, define_as = "PETRIFIED_WOOD",
	unided_name = "burned piece of wood",
	name = "Petrified Wood", subtype = "black",
	color = colors.WHITE, image = "object/artifact/petrified_wood.png",
	level_range = {35, 45},
	rarity = 280,
	desc = [[A piece of the scorched wood taken from the remains of Snaproot.]],
	rarity = false,
	cost = 100,
	material_level = 5,
	imbue_powers = {
		resists = { [DamageType.NATURE] = 25, [DamageType.FIRE] = -10, [DamageType.COLD] = 10 },
		inc_stats = { [Stats.STAT_CON] = 10, },
	},
}

newEntity{ base = "BASE_CLOTH_ARMOR",
	power_source = {arcane=true},
	define_as = "BLACK_ROBE", rarity=false,
	name = "Black Robe", unique=true,
	unided_name = "black robe", color=colors.DARK_GREY, image = "object/artifact/robe_black_robe.png",
	desc = [[A silk robe, darker than the darkest night sky, it radiates power.]],
	level_range = {40, 50},
	rarity = 280,
	cost = 500,
	wielder = {
		inc_stats = { [Stats.STAT_MAG] = 5, [Stats.STAT_WIL] = 4, [Stats.STAT_CUN] = 3 },
		see_invisible = 10,
		blind_immune = 1,
		combat_spellpower = 30,
		combat_dam = 10,
		combat_def = 6,
	},
	talent_on_spell = {
		{chance=5, talent=Talents.T_SOUL_ROT, level=3},
		{chance=5, talent=Talents.T_BLOOD_GRASP, level=3},
		{chance=5, talent=Talents.T_BONE_SPEAR, level=3},
	},
}

newEntity{ base = "BASE_WARAXE",
	power_source = {arcane=true},
	define_as = "MALEDICTION", rarity=false,
	unided_name = "pestilent waraxe",
	name = "Malediction", unique=true, image = "object/artifact/axe_malediction.png",
	desc = [[The land withers and crumbles wherever this cursed axe rests.]],
	require = { stat = { str=55 }, },
	level_range = {35, 45},
	rarity = 290,
	cost = 375,
	combat = {
		dam = 55,
		apr = 15,
		physcrit = 10,
		dammod = {str=1},
		damrange = 1.2,
		melee_project={[DamageType.BLIGHT] = 20},
	},
	wielder = {
		life_regen = -0.3,
		inc_damage = { [DamageType.BLIGHT] = 20 },
	},
}

newEntity{ base = "BASE_STAFF",
	power_source = {arcane=true},
	define_as = "STAFF_KOR", rarity=false, image = "object/artifact/staff_kors_fall.png",
	unided_name = "dark staff",
	name = "Kor's Fall", unique=true,
	desc = [[Made from the bones of many creatures, this staff glows with power. You can feel its evilness even from a distance.]],
	require = { stat = { mag=25 }, },
	level_range = {1, 10},
	rarity = 200,
	cost = 60,
	combat = {
		dam = 10,
		apr = 0,
		physcrit = 1.5,
		dammod = {mag=1.1},
	},
	wielder = {
		see_invisible = 2,
		combat_spellpower = 7,
		combat_spellcrit = 8,
		inc_damage={
			[DamageType.FIRE] = 4,
			[DamageType.COLD] = 4,
			[DamageType.ACID] = 4,
			[DamageType.LIGHTNING] = 4,
			[DamageType.BLIGHT] = 4,
		},
	},
}

newEntity{ base = "BASE_AMULET",
	power_source = {arcane=true},
	define_as = "VOX", rarity=false,
	name = "Vox", unique=true,
	unided_name = "ringing amulet", color=colors.BLUE, image="object/artifact/jewelry_amulet_vox.png",
	desc = [[No force can hope to silence the wearer of this amulet.]],
	level_range = {40, 50},
	rarity = 220,
	cost = 3000,
	wielder = {
		see_invisible = 20,
		silence_immune = 0.8,
		combat_spellpower = 9,
		combat_spellcrit = 4,
		max_mana = 50,
		max_vim = 50,
	},
}

newEntity{ base = "BASE_STAFF",
	power_source = {arcane=true},
	define_as = "TELOS_TOP_HALF", rarity=false, image = "object/artifact/staff_broken_top_telos.png",
	slot_forbid = false,
	twohanded = false,
	unided_name = "broken staff",
	name = "Telos's Staff (Top Half)", unique=true,
	desc = [[The top part of Telos's broken staff.]],
	require = { stat = { mag=35 }, },
	level_range = {40, 50},
	rarity = 210,
	encumber = 2.5,
	cost = 500,
	combat = {
		dam = 35,
		apr = 0,
		physcrit = 1.5,
		dammod = {mag=1.0},
	},
	wielder = {
		combat_spellpower = 30,
		combat_spellcrit = 15,
		combat_mentalresist = 8,
		inc_stats = { [Stats.STAT_WIL] = 5, },
	},
}

newEntity{ base = "BASE_AMULET",
	power_source = {arcane=true},
	define_as = "AMULET_DREAD", rarity=false,
	name = "Choker of Dread", unique=true, image = "object/artifact/amulet_choker_of_dread.png",
	unided_name = "dark amulet", color=colors.LIGHT_DARK,
	desc = [[The evilness of undeath radiates from this amulet.]],
	level_range = {20, 28},
	rarity = 220,
	cost = 5000,
	wielder = {
		see_invisible = 10,
		blind_immune = 1,
		combat_spellpower = 5,
		combat_dam = 5,
	},
	max_power = 60, power_regen = 1,
	use_power = { name = "summon an elder vampire to your side", power = 60, use = function(self, who)
		if not who:canBe("summon") then game.logPlayer(who, "You can not summon, you are suppressed!") return end

		-- Find space
		local x, y = util.findFreeGrid(who.x, who.y, 5, true, {[engine.Map.ACTOR]=true})
		if not x then
			game.logPlayer(who, "Not enough space to invoke the vampire!")
			return
		end
		print("Invoking guardian on", x, y)

		local NPC = require "mod.class.NPC"
		local vampire = NPC.new{
			type = "undead", subtype = "vampire",
			display = "V", image = "npc/elder_vampire.png",
			name = "elder vampire", color=colors.RED,
			desc=[[A terrible robed undead figure, this creature has existed in its unlife for many centuries by stealing the life of others. It can
			summon the very shades of its victims from beyond the grave to come enslaved to its aid.]],

			combat = { dam=resolvers.rngavg(9,13), atk=10, apr=9, damtype=engine.DamageType.DRAINLIFE, dammod={str=1.9} },

			body = { INVEN = 10, MAINHAND=1, OFFHAND=1, BODY=1 },

			autolevel = "warriormage",
			ai = "summoned", ai_real = "dumb_talented_simple", ai_state = { talent_in=3, },
			stats = { str=12, dex=12, mag=12, con=12 },
			life_regen = 3,
			size_category = 3,
			rank = 3,
			infravision = 10,

			inc_damage = table.clone(who.inc_damage, true),

			resists = { [engine.DamageType.COLD] = 80, [engine.DamageType.NATURE] = 80, [engine.DamageType.LIGHT] = -50,  },
			blind_immune = 1,
			confusion_immune = 1,
			see_invisible = 5,
			undead = 1,

			level_range = {who.level, who.level}, exp_worth = 0,
			max_life = resolvers.rngavg(90,100),
			combat_armor = 12, combat_def = 10,
			resolvers.talents{ [who.T_STUN]=2, [who.T_BLUR_SIGHT]=3, [who.T_PHANTASMAL_SHIELD]=2, [who.T_ROTTING_DISEASE]=3, },

			faction = who.faction,
			summoner = who,
			summon_time = 15,
		}

		vampire:resolve()
		game.zone:addEntity(game.level, vampire, "actor", x, y)
		vampire:forceUseTalent(vampire.T_TAUNT, {})

		game:playSoundNear(who, "talents/spell_generic")
		return {id=true, used=true}
	end },
}

newEntity{ define_as = "RUNED_SKULL",
	power_source = {arcane=true},
	unique = true,
	type = "gem", subtype="red", image = "object/artifact/bone_runed_skull.png",
	unided_name = "human skull",
	name = "Runed Skull",
	display = "*", color=colors.RED,
	level_range = {40, 50},
	rarity = 390,
	cost = 150,
	encumber = 3,
	material_level = 5,
	desc = [[Dull red runes are etched all over this blackened skull.]],

	carrier = {
		combat_spellpower = 7,
		on_melee_hit = {[DamageType.FIRE]=25},
	},
}

newEntity{ base = "BASE_GREATMAUL",
	power_source = {technique=true},
	define_as = "GREATMAUL_BILL_TRUNK",
	unided_name = "tree trunk", image = "object/artifact/bill_treestump.png",
	name = "Bill's Tree Trunk", unique=true,
	desc = [[This is a big, nasty-looking tree trunk that Bill the Troll used as a weapon. It could still serve this purpose, should you be strong enough to wield it!]],
	require = { stat = { str=25 }, },
	level_range = {1, 10},
	rarity = 200,
	metallic = false,
	cost = 70,
	combat = {
		dam = 30,
		apr = 7,
		physcrit = 1.5,
		dammod = {str=1.3},
		damrange = 1.7,
	},

	wielder = {
	},
}


newEntity{ base = "BASE_SHIELD",
	power_source = {technique=true},
	define_as = "SANGUINE_SHIELD",
	unided_name = "bloody shield",
	name = "Sanguine Shield", unique=true, image = "object/artifact/sanguine_shield.png",
	desc = [[Though tarnished and spattered with blood, the emblem of the Sun still manages to shine through on this shield.]],
	require = { stat = { str=39 }, },
	level_range = {35, 45},
	rarity = 240,
	cost = 120,

	special_combat = {
		dam = 40,
		physcrit = 9,
		dammod = {str=1.2},
	},
	wielder = {
		combat_armor = 4,
		combat_def = 14,
		combat_def_ranged = 14,
		inc_stats = { [Stats.STAT_CON] = 5, },
		fatigue = 19,
		resists = { [DamageType.BLIGHT] = 25, },
		life_regen = 5,
	},
}

newEntity{ base = "BASE_WHIP",
	power_source = {arcane=true},
	define_as = "WHIP_URH_ROK",
	unided_name = "fiery whip",
	name = "Whip of Urh'Rok", color=colors.PURPLE, unique = true, image = "object/artifact/whip_of_urh_rok.png",
	desc = [[With this unbearably bright whip of flame, the demon master Urh'Rok has become known for never having lost in combat.]],
	require = { stat = { dex=48 }, },
	level_range = {40, 50},
	rarity = 390,
	cost = 250,
	material_level = 5,
	combat = {
		dam = resolvers.rngavg(40,45),
		apr = 0,
		physcrit = 9,
		dammod = {dex=1},
		damtype = DamageType.FIREKNOCKBACK,
	},
	wielder = {
		esp = {["demon/minor"]=1, ["demon/major"]=1},
		see_invisible = 2,
	},
	carrier = {
		inc_damage={
			[DamageType.BLIGHT] = 8,
		},
	},
}

newEntity{ base = "BASE_GREATSWORD",
	power_source = {technique=true},
	define_as = "MURDERBLADE", rarity=false,
	name = "Warmaster Gnarg's Murderblade", unique=true, image="object/artifact/warmaster_gnargs_murderblade.png",
	unided_name = "blood-etched greatsword", color=colors.CRIMSON,
	desc = [[A blood-etched greatsword, it has seen many foes. From the inside.]],
	require = { stat = { str=35 }, },
	level_range = {35, 45},
	rarity = 230,
	cost = 300,
	material_level = 5,
	combat = {
		dam = 60,
		apr = 19,
		physcrit = 4.5,
		dammod = {str=1.2},
		special_on_hit = {desc="10% chance to send the wielder into a killing frenzy", fct=function(combat, who)
			if not rng.percent(10) then return end
			who:setEffect(who.EFF_FRENZY, 3, {crit=10, power=0.3, dieat=0.2})
		end},
	},
	wielder = {
		see_invisible = 25,
		inc_stats = { [Stats.STAT_CON] = 5, [Stats.STAT_STR] = 5, [Stats.STAT_DEX] = 5, },
		talents_types_mastery = {
			["technique/2hweapon-cripple"] = 0.2,
			["technique/2hweapon-offense"] = 0.2,
		},
	},
}

newEntity{ base = "BASE_LEATHER_CAP",
	power_source = {arcane=true},
	define_as = "CROWN_ELEMENTS", rarity=false,
	name = "Crown of the Elements", unique=true, image = "object/artifact/crown_of_the_elements.png",
	unided_name = "jeweled crown", color=colors.DARK_GREY,
	desc = [[This jeweled crown shimmers with colors.]],
	level_range = {40, 50},
	rarity = 280,
	cost = 500,
	material_level = 5,
	wielder = {
		inc_stats = { [Stats.STAT_CON] = 5, [Stats.STAT_WIL] = 3, },
		resists={
			[DamageType.FIRE] = 15,
			[DamageType.COLD] = 15,
			[DamageType.ACID] = 15,
			[DamageType.LIGHTNING] = 15,
		},
		melee_project={
			[DamageType.FIRE] = 10,
			[DamageType.COLD] = 10,
			[DamageType.ACID] = 10,
			[DamageType.LIGHTNING] = 10,
		},
		see_invisible = 15,
		combat_armor = 5,
		fatigue = 5,
	},
}

newEntity{ base = "BASE_GLOVES", define_as = "FLAMEWROUGHT",
	power_source = {nature=true},
	unique = true,
	name = "Flamewrought", color = colors.RED, image = "object/artifact/gloves_flamewrought.png",
	unided_name = "chitinous gloves",
	desc = [[These gloves seems to be made out of the exoskeletons of ritches. They are hot to the touch.]],
	level_range = {5, 12},
	rarity = 180,
	cost = 50,
	material_level = 1,
	wielder = {
		inc_stats = { [Stats.STAT_WIL] = 3, },
		resists = { [DamageType.FIRE]= 10, },
		inc_damage = { [DamageType.FIRE]= 5, },
		combat_armor = 2,
		combat = {
			dam = 5,
			apr = 7,
			physcrit = 1,
			physspeed = -0.4,
			dammod = {dex=0.4, str=-0.6, cun=0.4 },
			melee_project={[DamageType.FIRE] = 10},
		},
	},
	max_power = 24, power_regen = 1,
	use_talent = { id = Talents.T_RITCH_FLAMESPITTER_BOLT, level = 2, power = 6 },
}

-- The crystal set
newEntity{ base = "BASE_GEM", define_as = "CRYSTAL_FOCUS",
	power_source = {arcane=true},
	unique = true,
	unided_name = "scintillating crystal",
	name = "Crystal Focus", subtype = "multi-hued",
	color = colors.WHITE, image = "object/artifact/crystal_focus.png",
	level_range = {5, 12},
	desc = [[This crystal radiates the power of the Spellblaze itself.]],
	rarity = 200,
	cost = 50,
	material_level = 2,

	max_power = 1, power_regen = 1,
	use_power = { name = "combine with a weapon", power = 1, use = function(self, who, gem_inven, gem_item)
		who:showInventory("Fuse with which weapon?", who:getInven("INVEN"), function(o) return o.type == "weapon" and not o.egoed and not o.unique end, function(o, item)
			local oldname = o:getName{do_color=true}

			-- Remove the gem
			who:removeObject(gem_inven, gem_item)
			who:sortInven(gem_inven)

			-- Change the weapon
			o.name = "Crystalline "..o.name:capitalize()
			o.unique = o.name
			o.no_unique_lore = true
			if o.combat and o.combat.dam then
				o.combat.dam = o.combat.dam * 1.25
				o.combat.damtype = engine.DamageType.ARCANE
			end
			o.is_crystalline_weapon = true
			o.wielder = o.wielder or {}
			o.wielder.combat_spellpower = 12
			o.wielder.combat_dam = 12
			o.wielder.inc_stats = o.wielder.inc_stats or {}
			o.wielder.inc_stats[engine.interface.ActorStats.STAT_WIL] = 3
			o.wielder.inc_stats[engine.interface.ActorStats.STAT_CON] = 3
			o.wielder.inc_damage = o.wielder.inc_damage or {}
			o.wielder.inc_damage[engine.DamageType.ARCANE] = 10

			o.set_list = { {"is_crystalline_armor", true} }
			o.on_set_complete = function(self, who)
				self.talent_on_spell = { {chance=10, talent="T_MANATHRUST", level=3} }
				self.combat.talent_on_hit = { T_MANATHRUST = {level=3, chance=10} }
				self:specialSetAdd({"wielder","combat_spellcrit"}, 10)
				self:specialSetAdd({"wielder","combat_physcrit"}, 10)
				self:specialSetAdd({"wielder","resists_pen"}, {[engine.DamageType.ARCANE]=20, [engine.DamageType.PHYSICAL]=15})
				game.logPlayer(who, "#GOLD#As the crystalline weapon and armour are brought together, they begin to emit a constant humming.")
			end
			o.on_set_broken = function(self, who)
				self.talent_on_spell = nil
				self.combat.talent_on_hit = nil
				game.logPlayer(who, "#GOLD#The humming from the crystalline artifacts fades as they are separated.")
			end

			who:sortInven()
			who.changed = true

			game.logPlayer(who, "You fix the crystal on the %s and create the %s.", oldname, o:getName{do_color=true})
		end)
	end },
}

newEntity{ base = "BASE_GEM", define_as = "CRYSTAL_HEART",
	power_source = {arcane=true},
	unique = true,
	unided_name = "coruscating crystal",
	name = "Crystal Heart", subtype = "multi-hued",
	color = colors.RED, image = "object/artifact/crystal_heart.png",
	level_range = {35, 42},
	desc = [[This crystal is huge, easily the size of your head. It sparkles brilliantly almost of its own accord.]],
	rarity = 250,
	cost = 200,
	material_level = 5,

	max_power = 1, power_regen = 1,
	use_power = { name = "combine with a suit of body armor", power = 1, use = function(self, who, gem_inven, gem_item)
		-- Body armour only, can be cloth, light, heavy, or massive though. No clue if o.slot works for this.
		who:showInventory("Fuse with which armor?", who:getInven("INVEN"), function(o) return o.type == "armor" and o.slot == "BODY" and not o.egoed and not o.unique end, function(o, item)
			local oldname = o:getName{do_color=true}

			-- Remove the gem
			who:removeObject(gem_inven, gem_item)
			who:sortInven(gem_inven)

			-- Change the weapon... err, armour. No, I'm not copy/pasting here, honest!
			o.name = "Crystalline "..o.name:capitalize()
			o.unique = o.name
			o.no_unique_lore = true
			o.is_crystalline_armor = true

			o.wielder = o.wielder or {}
			-- This is supposed to add 1 def for crap cloth robes if for some reason you choose it instead of better robes, and then multiply by 1.25.
			o.wielder.combat_def = ((o.wielder.combat_def or 0) + 2) * 1.7
			-- Same for armour. Yay crap cloth!
			o.wielder.combat_armor = ((o.wielder.combat_armor or 0) + 3) * 1.7
			o.wielder.combat_spellresist = 35
			o.wielder.combat_physresist = 25
			o.wielder.inc_stats = o.wielder.inc_stats or {}
			o.wielder.inc_stats[engine.interface.ActorStats.STAT_MAG] = 8
			o.wielder.inc_stats[engine.interface.ActorStats.STAT_CON] = 8
			o.wielder.inc_stats[engine.interface.ActorStats.STAT_LCK] = 12
			o.wielder.resists = o.wielder.resists or {}
			o.wielder.resists = { [engine.DamageType.ARCANE] = 35, [engine.DamageType.PHYSICAL] = 15 }
			o.wielder.poison_immune = 1
			o.wielder.disease_immune = 1

			o.set_list = { {"is_crystalline_weapon", true} }
			o.on_set_complete = function(self, who)
				self:specialSetAdd({"wielder","stun_immune"}, 0.5)
				self:specialSetAdd({"wielder","blind_immune"}, 0.5)
			end
			who:sortInven()
			who.changed = true

			game.logPlayer(who, "You fix the crystal on the %s and create the %s.", oldname, o:getName{do_color=true})
		end)
	end },
}

newEntity{ base = "BASE_WAND", define_as = "ROD_OF_ANNULMENT",
	power_source = {arcane=true},
	unided_name = "dark rod",
	name = "Rod of Annulment", color=colors.LIGHT_BLUE, unique=true, image = "object/artifact/rod_of_annulment.png",
	desc = [[You can feel magic draining out around this rod. Even nature itself seems affected.]],
	cost = 50,
	rarity = 380,
	level_range = {5, 12},
	elec_proof = true,
	add_name = false,

	material_level = 2,

	max_power = 30, power_regen = 1,
	use_power = { name = "force some of your foes infusions, runes or talents on cooldown", power = 30,
		use = function(self, who)
			local tg = {type="bolt", range=5}
			local x, y = who:getTarget(tg)
			if not x or not y then return nil end
			who:project(tg, x, y, function(px, py)
				local target = game.level.map(px, py, engine.Map.ACTOR)
				if not target then return end

				local tids = {}
				for tid, lev in pairs(target.talents) do
					local t = target:getTalentFromId(tid)
					if not target.talents_cd[tid] and t.mode == "activated" and not t.innate then tids[#tids+1] = t end
				end
				for i = 1, 3 do
					local t = rng.tableRemove(tids)
					if not t then break end
					target.talents_cd[t.id] = rng.range(3, 5)
					game.logSeen(target, "%s's %s is disrupted!", target.name:capitalize(), t.name)
				end
				target.changed = true
			end, nil, {type="flame"})
			return {id=true, used=true}
		end
	},
}

newEntity{ base = "BASE_WARAXE",
	power_source = {arcane=true},
	define_as = "SKULLCLEAVER",
	unided_name = "crimson waraxe",
	name = "Skullcleaver", unique=true, image = "object/artifact/axe_skullcleaver.png",
	desc = [[A small but sharp axe, with a handle made of polished bone.  The blade has chopped through the skulls of many, and has been stained a deep crimson.]],
	require = { stat = { str=18 }, },
	level_range = {5, 12},
	rarity = 220,
	cost = 50,
	combat = {
		dam = 16,
		apr = 3,
		physcrit = 12,
		dammod = {str=1},
		talent_on_hit = { [Talents.T_GREATER_WEAPON_FOCUS] = {level=2, chance=10} },
		melee_project={[DamageType.DRAINLIFE] = 10},
	},
	wielder = {
		inc_damage = { [DamageType.BLIGHT] = 8 },
	},
}

newEntity{ base = "BASE_DIGGER",
	power_source = {unknown=true},
	define_as = "TOOTH_MOUTH",
	unided_name = "a tooth", unique = true,
	name = "Tooth of the Mouth", image = "object/artifact/tooth_of_the_mouth.png",
	desc = [[A huge tooth taken from the Mouth, in the Deep Bellow.]],
	level_range = {5, 12},
	cost = 50,
	material_level = 3,
	digspeed = 12,
	wielder = {
		inc_damage = { [DamageType.BLIGHT] = 4 },
		on_melee_hit = {[DamageType.BLIGHT] = 15},
		combat_apr = 5,
	},
}

newEntity{ base = "BASE_HEAVY_BOOTS",
	define_as = "WARPED_BOOTS",
	power_source = {unknown=true},
	unique = true,
	name = "The Warped Boots", image = "object/artifact/the_warped_boots.png",
	unided_name = "pair of painful-looking boots",
	desc = [[These blackened boots have lost all vestige of any former glory they might have had. Now, they are a testament to the corruption of the Deep Bellow, and its power.]],
	color = colors.DARK_GREEN,
	level_range = {35, 45},
	rarity = 250,
	cost = 200,
	material_level = 5,
	wielder = {
		combat_armor = 4,
		combat_def = 2,
		combat_dam = 10,
		fatigue = 8,
		combat_spellpower = 10,
		combat_spellcrit = 9,
		life_regen = -0.20,
		inc_damage = { [DamageType.BLIGHT] = 15 },
	},
	max_power = 50, power_regen = 1,
	use_talent = { id = Talents.T_SPIT_BLIGHT, level=3, power = 10 },
}

newEntity{ base = "BASE_BATTLEAXE",
	power_source = {nature=true,},
	define_as = "GAPING_MAW",
	name = "The Gaping Maw", color = colors.SLATE, image = "object/artifact/battleaxe_the_gaping_maw.png",
	unided_name = "huge granite battleaxe", unique = true,
	desc = [[This huge granite battleaxe is as much mace as it is axe.  The shaft is made of blackened wood tightly bound in drakeskin leather and the sharpened granite head glistens with a viscous green fluid.]],
	level_range = {38, 50},
	rarity = 300,
	require = { stat = { str=60 }, },
	cost = 650,
	material_level = 4,
	combat = {
		dam = 72,
		apr = 4,
		physcrit = 8,
		dammod = {str=1.2},
		melee_project={[DamageType.SLIME] = 50, [DamageType.ACID] = 50},
	},
	wielder = {
		inc_stats = { [Stats.STAT_STR] = 6, [Stats.STAT_WIL] = 6, },
		inc_damage={
			[DamageType.NATURE] = 15,
		},
		talent_cd_reduction= {
			[Talents.T_SWALLOW] = 2,
			[Talents.T_MANA_CLASH] = 2,
			[Talents.T_ICE_CLAW] = 1,
		},
	},
}
