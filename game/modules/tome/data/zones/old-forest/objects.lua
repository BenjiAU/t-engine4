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

load("/data/general/objects/objects.lua")

local Stats = require "engine.interface.ActorStats"

-- Artifact, droped (and used!) by Bill the Stone Troll

newEntity{ base = "BASE_SHIELD",
	define_as = "OLD_MAN_WILLOW_SHIELD",
	name = "Old Man Willow's Barkwood", unique=true,
	desc = [[The barkwood of the Old Man's Willow, made into roughly the shape of a shield.]],
	require = { stat = { str=25 }, },
	cost = 20,

	special_combat = {
		dam = resolvers.rngavg(20,30),
		physcrit = 2,
		dammod = {str=1.5},
	},
	wielder = {
		combat_armor = 5,
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
	unique = true,
	unided_name = "burned piece of wood",
	name = "Petrified Wood", subtype = "black",
	color = colors.WHITE, image="object/bloodstone.png",
	level_range = {35, 45},
	desc = [[A piece of the scorched wood took from the remains of Snaproot.]],
	rarity = false,
	cost = 100,
	material_level = 5,
	imbue_powers = {
		resists = { [DamageType.NATURE] = 25, [DamageType.FIRE] = -10, [DamageType.COLD] = 10 },
		inc_stats = { [Stats.STAT_CON] = 10, },
	},
}
