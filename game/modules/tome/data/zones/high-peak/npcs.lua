-- ToME - Tales of Middle-Earth
-- Copyright (C) 2009, 2010 Nicolas Casalini
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

-- Orcs & trolls
load("/data/general/npcs/orc-grushnak.lua", rarity(0))
load("/data/general/npcs/orc-vor.lua", rarity(0))
load("/data/general/npcs/orc-gorbat.lua", rarity(0))
load("/data/general/npcs/orc-rak-shor.lua", rarity(6))
load("/data/general/npcs/orc.lua", rarity(8))
--load("/data/general/npcs/troll.lua", rarity(0))

-- Others
load("/data/general/npcs/naga.lua", rarity(6))
load("/data/general/npcs/snow-giant.lua", rarity(6))

-- Demons
load("/data/general/npcs/minor-demon.lua", rarity(3))
load("/data/general/npcs/major-demon.lua", rarity(3))

-- Drakes
load("/data/general/npcs/fire-drake.lua", rarity(10))
load("/data/general/npcs/cold-drake.lua", rarity(10))
load("/data/general/npcs/multihued-drake.lua", rarity(10))

-- Undeads
load("/data/general/npcs/bone-giant.lua", rarity(10))
load("/data/general/npcs/vampire.lua", rarity(10))
load("/data/general/npcs/ghoul.lua", rarity(10))
load("/data/general/npcs/skeleton.lua", rarity(10))

load("/data/general/npcs/all.lua", rarity(4, 35))

local Talents = require("engine.interface.ActorTalents")

-- Alatar & Palando, the final bosses
newEntity{
	define_as = "ALATAR",
	type = "humanoid", subtype = "istari",
	name = "Alatar the Blue",
	display = "@", color=colors.AQUAMARINE,
	faction = "blue-wizards",

	desc = [[Lost to the memory of the West, the Blue Wizards have setup in the Far East, slowly growing corrupt. Now they must be stopped.]],
	level_range = {75, 75}, exp_worth = 15,
	max_life = 1000, life_rating = 36, fixed_rating = true,
	max_mana = 10000,
	mana_regen = 10,
	rank = 5,
	size_category = 3,
	stats = { str=40, dex=60, cun=60, mag=30, con=40 },

	body = { INVEN = 10, MAINHAND=1, OFFHAND=1, BODY=1 },
	resolvers.equip{
		{type="weapon", subtype="staff", ego_chance=100, autoreq=true},
		{type="armor", subtype="cloth", ego_chance=100, autoreq=true},
	},
	resolvers.drops{chance=100, nb=10, {ego_chance=100} },

	resolvers.talents{
		[Talents.T_FLAME]=5,
		[Talents.T_FREEZE]=5,
		[Talents.T_LIGHTNING]=5,
		[Talents.T_MANATHRUST]=5,
		[Talents.T_INFERNO]=5,
		[Talents.T_FLAMESHOCK]=5,
		[Talents.T_STONE_SKIN]=5,
		[Talents.T_STRIKE]=5,
		[Talents.T_HEAL]=5,
		[Talents.T_REGENERATION]=5,
		[Talents.T_ILLUMINATE]=5,
		[Talents.T_QUICKEN_SPELLS]=5,
		[Talents.T_SPELL_SHAPING]=5,
		[Talents.T_ARCANE_POWER]=5,
		[Talents.T_METAFLOW]=5,
		[Talents.T_PHASE_DOOR]=5,
		[Talents.T_ESSENCE_OF_SPEED]=5,
	},
	resolvers.sustains_at_birth(),

	autolevel = "caster",
	ai = "dumb_talented_simple", ai_state = { talent_in=1, ai_move="move_astar" },
}

newEntity{
	define_as = "PALLANDO",
	type = "humanoid", subtype = "istari",
	name = "Pallando the Blue",
	display = "@", color=colors.LIGHT_BLUE,
	faction = "blue-wizards",

	desc = [[Lost to the memory of the West, the Blue Wizards have setup in the Far East, slowly growing corrupt. Now they must be stopped.]],
	level_range = {75, 75}, exp_worth = 15,
	max_life = 1000, life_rating = 36, fixed_rating = true,
	max_mana = 10000,
	mana_regen = 10,
	rank = 5,
	size_category = 3,
	stats = { str=40, dex=60, cun=60, mag=30, con=40 },

	body = { INVEN = 10, MAINHAND=1, OFFHAND=1, BODY=1 },
	resolvers.equip{
		{type="weapon", subtype="staff", ego_chance=100, autoreq=true},
		{type="armor", subtype="cloth", ego_chance=100, autoreq=true},
	},
	resolvers.drops{chance=100, nb=10, {ego_chance=100} },

	resolvers.talents{
		[Talents.T_FLAME]=5,
		[Talents.T_FREEZE]=5,
		[Talents.T_LIGHTNING]=5,
		[Talents.T_MANATHRUST]=5,
		[Talents.T_INFERNO]=5,
		[Talents.T_FLAMESHOCK]=5,
		[Talents.T_STONE_SKIN]=5,
		[Talents.T_STRIKE]=5,
		[Talents.T_HEAL]=5,
		[Talents.T_REGENERATION]=5,
		[Talents.T_ILLUMINATE]=5,
		[Talents.T_QUICKEN_SPELLS]=5,
		[Talents.T_SPELL_SHAPING]=5,
		[Talents.T_ARCANE_POWER]=5,
		[Talents.T_METAFLOW]=5,
		[Talents.T_PHASE_DOOR]=5,
		[Talents.T_ESSENCE_OF_SPEED]=5,
	},
	resolvers.sustains_at_birth(),

	autolevel = "caster",
	ai = "dumb_talented_simple", ai_state = { talent_in=1, ai_move="move_astar" },
}

newEntity{ define_as = "HIGH_SUN_PALADIN_AERYN",
	type = "humanoid", subtype = "human",
	display = "p",
	faction = "blue-wizards",
	name = "Fallen Sun Paladin Aeryn", color=colors.VIOLET, unique = true,
	desc = [[A beautiful woman, clad in a shining plate armour. Power radiates from her.]],
	level_range = {56, 56}, exp_worth = 2,
	rank = 5,
	size_category = 3,
	female = true,
	max_life = 250, life_rating = 30, fixed_rating = true,
	infravision = 20,
	stats = { str=15, dex=10, cun=12, mag=16, con=14 },
	instakill_immune = 1,
	move_others=true,

	open_door = true,

	autolevel = "warriormage",
	ai = "dumb_talented_simple", ai_state = { talent_in=2, ai_move="move_astar", },

	body = { INVEN = 10, MAINHAND=1, OFFHAND=1, BODY=1, HEAD=1, FEET=1 },
	resolvers.drops{chance=100, nb=3, {ego_chance=100} },

	resolvers.equip{
		{type="weapon", subtype="mace", ego_chance=100, autoreq=true},
		{type="armor", subtype="shield", ego_chance=100, autoreq=true},
		{type="armor", subtype="massive", ego_chance=100, autoreq=true},
		{type="armor", subtype="feet", ego_chance=100, autoreq=true},
		{type="armor", subtype="head", ego_chance=100, autoreq=true},
	},

	positive_regen = 15,

	resolvers.talents{
		[Talents.T_MASSIVE_ARMOUR_TRAINING]=5,
		[Talents.T_WEAPON_COMBAT]=10,
		[Talents.T_MACE_MASTERY]=10,

		[Talents.T_CHANT_OF_FORTITUDE]=5,
		[Talents.T_SEARING_LIGHT]=5,
		[Talents.T_MARTYRDOM]=5,
		[Talents.T_BARRIER]=5,
		[Talents.T_WEAPON_OF_LIGHT]=5,
		[Talents.T_MARTYRDOM]=5,
		[Talents.T_HEALING_LIGHT]=5,
		[Talents.T_CRUSADE]=8,
		[Talents.T_SUN_FLARE]=5,
		[Talents.T_FIREBEAM]=7,
		[Talents.T_SUNBURST]=8,
	},
	resolvers.sustains_at_birth(),
}
