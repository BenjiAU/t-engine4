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

---------------------------------------------------------
--                       Elves                         --
---------------------------------------------------------
newBirthDescriptor{
	type = "race",
	name = "Elf",
	desc = {
		"The elven races are usually named as a whole 'elves', but this is incorrect.",
		"Elves are split into three separate races - albeit related - of which only two remain in the current age.",
		"Elves usually live about one thousand years, except for the Shaloren who magically sustain themselves forever.",
		"Their view of the world varies wildly across the different elven races.",
	},
	descriptor_choices =
	{
		subrace =
		{
			Shalore = "allow",
			Thalore = "allow",
			__ALL__ = "disallow",
		},
		subclass =
		{
			-- Only human and elves make sense to play celestials
			['Sun Paladin'] = "allow",
			Anorithil = "allow",
			-- Only human, elves, halflings and undeads are supposed to be archmages
			Archmage = "allow",
		},
	},
	copy = {
		type = "humanoid", subtype="elf",
		starting_zone = "trollmire",
		starting_quest = "start-allied",
		resolvers.inventory{ id=true, {defined="ORB_SCRYING"} },
	},

	moddable_attachement_spots = "race_elf",
	cosmetic_options = {
		skin = {
			{name="Skin Color 1", file="base_01"},
			{name="Skin Color 2", file="base_02"},
			{name="Skin Color 3", file="base_03"},
			{name="Skin Color 4", file="base_04"},
			{name="Skin Color 5", file="base_05"},
			{name="Skin Color 6", file="base_06"},
			{name="Skin Color 7", file="base_07"},
			{name="Skin Color 8", file="base_08"},
			{name="Skin Color 9", file="base_09"},
		},
		hairs = {
			{name="Dark Hair 1", file="hair_thalore_01"},
			{name="Dark Hair 2", file="hair_thalore_02"},
			{name="Dark Hair 3", file="hair_thalore_03"},
			{name="Dark Hair 4", file="hair_thalore_04", only_for={sex="Female"}},
			{name="Dark Hair 5", file="hair_thalore_05", only_for={sex="Female"}},
			{name="Blond Hair 1", file="hair_shalore_01"},
			{name="Blond Hair 2", file="hair_shalore_02"},
			{name="Blond Hair 3", file="hair_shalore_03"},
			{name="Blond Hair 4", file="hair_shalore_04", only_for={sex="Female"}},
			{name="Blond Hair 5", file="hair_shalore_05", only_for={sex="Female"}},
			{name="Redhead Hair 1", file="hair_redhead_01", unlock="cosmetic_race_human_redhead"},
			{name="Redhead Hair 2", file="hair_redhead_02", unlock="cosmetic_race_human_redhead"},
			{name="Redhead Hair 3", file="hair_redhead_03", unlock="cosmetic_race_human_redhead"},
			{name="Redhead Hair 4", file="hair_redhead_04", unlock="cosmetic_race_human_redhead", only_for={sex="Female"}},
			{name="Redhead Hair 5", file="hair_redhead_05", unlock="cosmetic_race_human_redhead", only_for={sex="Female"}},
		},
		special = {
			{name="Bikini / Mankini", birth_only=true, on_actor=function(actor, birther, last)
				if not last then local o = birther.obj_list_by_name[birther.descriptors_by_type.sex == 'Female' and 'Bikini' or 'Mankini'] if not o then print("No bikini/mankini found!") return end actor:getInven(actor.INVEN_BODY)[1] = o:cloneFull() actor.moddable_tile_nude = 1
				else actor:registerOnBirthForceWear(birther.descriptors_by_type.sex == 'Female' and "FUN_BIKINI" or "FUN_MANKINI") end
			end},
		},
	},
}

---------------------------------------------------------
--                       Elves                         --
---------------------------------------------------------
newBirthDescriptor
{
	type = "subrace",
	name = "Shalore",
	desc = {
		"Shaloren elves have close ties with the magic of the world, and produced in the past many great mages.",
		"Yet they remain quiet and try to hide their magic from the world, for they remember too well the Spellblaze - and the Spellhunt that followed.",
		"They possess the #GOLD#Grace of the Eternals#WHITE# talent which allows them a boost of speed every once in a while.",
		"#GOLD#Stat modifiers:",
		"#LIGHT_BLUE# * -2 Strength, +1 Dexterity, +0 Constitution",
		"#LIGHT_BLUE# * +2 Magic, +3 Willpower, +1 Cunning",
		"#GOLD#Life per level:#LIGHT_BLUE# 9",
		"#GOLD#Experience penalty:#LIGHT_BLUE# 12%",
	},
	inc_stats = { str=-2, mag=2, wil=3, cun=1, dex=1, con=0 },
	experience = 1.3,
	talents_types = { ["race/shalore"]={true, 0} },
	talents = { [ActorTalents.T_SHALOREN_SPEED]=1 },
	default_cosmetics = { {"hairs", "Blond Hair 1"} },
	copy = {
		moddable_tile = "elf_#sex#",
		moddable_tile_base = "base_01.png",
		moddable_tile_ornament = {female="braid_02"},
		random_name_def = "shalore_#sex#", random_name_max_syllables = 4,
		default_wilderness = {"playerpop", "shaloren"},
		starting_zone = "scintillating-caves",
		starting_quest = "start-shaloren",
		faction = "shalore",
		starting_intro = "shalore",
		life_rating = 9,
		resolvers.inscription("RUNE:_SHIELDING", {cooldown=14, dur=5, power=100}, 1),
		resolvers.inscription("RUNE:_SHATTER_AFFLICTIONS", {cooldown=18, shield=50}, 2),
		resolvers.inscription("RUNE:_BLINK", {cooldown=16, range=3, dur=3, power=15}, 3),
	},
	experience = 1.12,
	random_escort_possibilities = { {"tier1.1", 1, 2}, {"tier1.2", 1, 2}, {"daikara", 1, 2}, {"old-forest", 1, 4}, {"dreadfell", 1, 8}, {"reknor", 1, 2}, },
}

newBirthDescriptor
{
	type = "subrace",
	name = "Thalore",
	desc = {
		"Thaloren elves have spent most of the ages hidden within their forests, seldom leaving them.",
		"The ages of the world passed by and yet they remained unchanged.",
		"Their affinity for nature and their reclusion have made them great protectors of the natural order, often opposing their Shaloren cousins.",
		"They possess the #GOLD#Gift of the Woods#WHITE# talent, which allows them to regenerate life and increase healing once in a while.",
		"#GOLD#Stat modifiers:",
		"#LIGHT_BLUE# * +2 Strength, +3 Dexterity, +1 Constitution",
		"#LIGHT_BLUE# * -2 Magic, +1 Willpower, +0 Cunning",
		"#GOLD#Life per level:#LIGHT_BLUE# 11",
		"#GOLD#Experience penalty:#LIGHT_BLUE# 0%",
	},
	inc_stats = { str=2, mag=-2, wil=1, cun=0, dex=3, con=1 },
	talents_types = { ["race/thalore"]={true, 0} },
	talents = { [ActorTalents.T_THALOREN_WRATH]=1 },
	default_cosmetics = { {"hairs", "Dark Hair 1"} },
	copy = {
		moddable_tile = "elf_#sex#",
		moddable_tile_base = "base_01.png",
		moddable_tile_ornament = {female="braid_01"},
		random_name_def = "thalore_#sex#",
		default_wilderness = {"playerpop", "thaloren"},
		starting_zone = "norgos-lair",
		starting_quest = "start-thaloren",
		faction = "thalore",
		starting_intro = "thalore",
		life_rating = 11,
		resolvers.inscription("INFUSION:_REGENERATION", {cooldown=10, dur=5, heal=100}, 1),
		resolvers.inscription("INFUSION:_WILD", {cooldown=14, what={physical=true}, dur=4, power=14}, 2),
		resolvers.inscription("INFUSION:_HEALING", {cooldown=12, heal=50}, 3),
	},
	random_escort_possibilities = { {"tier1.1", 1, 2}, {"tier1.2", 1, 2}, {"daikara", 1, 2}, {"old-forest", 1, 4}, {"dreadfell", 1, 8}, {"reknor", 1, 2}, },
}
