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

load("/data/general/objects/objects-maj-eyal.lua")

newEntity{ base = "BASE_LORE",
	define_as = "LINANIIL_LECTURE",
	subtype = "lecture on humility", unique=true, no_unique_lore=true, not_in_stores=false,
	name = "Lecture on Humility by Archmage Linaniil", lore="angolwen-linaniil-lecture",
	desc = _t[[Lecture on Humility by Archmage Linaniil. A tale of the first ages and the Spellblaze.]],
	rarity = false,
	cost = 2,
}

newEntity{ base = "BASE_LORE",
	define_as = "TARELION_LECTURE_MAGIC",
	subtype = "magic teaching", unique=true, no_unique_lore=true, not_in_stores=false,
	name = "'What is Magic' by Archmage Tarelion", lore="angolwen-tarelion-magic",
	desc = _t[[Lecture on the nature of magic by Archmage Tarelion.]],
	rarity = false,
	cost = 2,
}

-- Reward for killing Urkis
newEntity{ base = "BASE_RUNE",
	name = "Rune of Dissipation", unique=true, define_as="RUNE_DISSIPATION",
	image = "object/artifact/rune_of_dissipation.png",
	level_range = {5, 50},
	cost = 20,
	inscription_kind = "protect",
	inscription_data = {
		cooldown = 20,
	},
	inscription_talent = "RUNE:_DISSIPATION",
}

