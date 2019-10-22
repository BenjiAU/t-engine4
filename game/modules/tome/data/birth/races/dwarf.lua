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
--                       Dwarves                       --
---------------------------------------------------------
newBirthDescriptor{
	type = "race",
	name = "Dwarf",
	desc = {
		"Dwarves are a secretive people, hailing from their underground home of the Iron Throne.",
		"They are a sturdy race and are known for their masterwork, yet they are not well loved, having left other races to fend for themselves in past conflicts.",
		"All dwarves are united under the Empire and their love of money.",
	},
	descriptor_choices =
	{
		subrace =
		{
			__ALL__ = "disallow",
			Dwarf = "allow",
		},
	},
	copy = {
		faction = "iron-throne",
		type = "humanoid", subtype="dwarf",
		calendar = "dwarf",
		default_wilderness = {"playerpop", "dwarf"},
		starting_zone = "reknor-escape",
		starting_quest = "start-dwarf",
		starting_intro = "dwarf",
		resolvers.inventory{ id=true, {defined="ORB_SCRYING"} },
	},
	random_escort_possibilities = { {"tier1.1", 1, 2}, {"tier1.2", 1, 2}, {"daikara", 1, 2}, {"old-forest", 1, 4}, {"dreadfell", 1, 8}, {"reknor", 1, 2}, },

	moddable_attachement_spots = "race_dwarf",
}

---------------------------------------------------------
--                       Dwarves                       --
---------------------------------------------------------
newBirthDescriptor
{
	type = "subrace",
	name = "Dwarf",
	desc = {
		"Dwarves are a secretive people, hailing from their underground home of the Iron Throne.",
		"They are a sturdy race and are known for their masterwork, yet they are not well loved, having left other races to fend for themselves in past conflicts.",
		"They possess the #GOLD#Resilience of the Dwarves#WHITE# which allows them to increase their armour, physical and spell saves for a few turns.",
		"#GOLD#Stat modifiers:",
		"#LIGHT_BLUE# * +4 Strength, -2 Dexterity, +3 Constitution",
		"#LIGHT_BLUE# * -2 Magic, +3 Willpower, +0 Cunning",
		"#GOLD#Life per level:#LIGHT_BLUE# 14",
		"#GOLD#Experience penalty:#LIGHT_BLUE# 0%",
	},
	inc_stats = { str=4, con=3, wil=3, mag=-2, dex=-2 },
	talents_types = { ["race/dwarf"]={true, 0} },
	talents = {
		[ActorTalents.T_DWARF_RESILIENCE]=1,
	},
	copy = {
		moddable_tile = "dwarf_#sex#",
		moddable_tile_ornament2 = {male="beard_02", female="braid_01"},
		random_name_def = "dwarf_#sex#",
		life_rating = 14,
		can_see_iron_council = 1,
		resolvers.inscription("INFUSION:_REGENERATION", {cooldown=10, dur=5, heal=100}, 1),
		resolvers.inscription("INFUSION:_WILD", {cooldown=14, what={physical=true}, dur=4, power=14}, 2),
		resolvers.inscription("INFUSION:_HEALING", {cooldown=12, heal=50}, 3),
		resolvers.birth_extra_tier1_zone{name="tier1", condition=function(e) return e.starting_zone == "reknor-escape" end, "reknor-escape", "deep-bellow"},
	},
	default_cosmetics = { {"hairs", "Dark Hair 1"}, {"facial_features", "Dark Beard 2", {sex="Male"}} },
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
			{name="Dark Hair 1", file="hair_01"},
			{name="Dark Hair 2", file="hair_02"},
			{name="Dark Hair 3", file="hair_03"},
			{name="Dark Hair 4", file="hair_04", only_for={sex="Female"}},
			{name="Dark Hair 5", file="hair_05", only_for={sex="Female"}},
			{name="Dark Hair 6", file="hair_06", only_for={sex="Female"}},
			{name="Dark Hair 7", file="hair_07", only_for={sex="Female"}},
			{name="Dark Hair 8", file="hair_08", only_for={sex="Female"}},
			{name="Dark Hair 9", file="hair_09", only_for={sex="Female"}},
			{name="Dark Hair 10", file="hair_10", only_for={sex="Female"}},
			{name="Blond Hair 1", file="hair_blond_01"},
			{name="Blond Hair 2", file="hair_blond_02"},
			{name="Blond Hair 3", file="hair_blond_03"},
			{name="Blond Hair 4", file="hair_blond_04", only_for={sex="Female"}},
			{name="Blond Hair 5", file="hair_blond_05", only_for={sex="Female"}},
			{name="Blond Hair 6", file="hair_blond_06", only_for={sex="Female"}},
			{name="Blond Hair 7", file="hair_blond_07", only_for={sex="Female"}},
			{name="Blond Hair 8", file="hair_blond_08", only_for={sex="Female"}},
			{name="Blond Hair 9", file="hair_blond_09", only_for={sex="Female"}},
			{name="Blond Hair 10", file="hair_blond_10", only_for={sex="Female"}},
			{name="Redhead Hair 1", file="hair_redhead_01", unlock="cosmetic_race_human_redhead"},
			{name="Redhead Hair 2", file="hair_redhead_02", unlock="cosmetic_race_human_redhead"},
			{name="Redhead Hair 3", file="hair_redhead_03", unlock="cosmetic_race_human_redhead"},
			{name="Redhead Hair 4", file="hair_redhead_04", unlock="cosmetic_race_human_redhead", only_for={sex="Female"}},
			{name="Redhead Hair 5", file="hair_redhead_05", unlock="cosmetic_race_human_redhead", only_for={sex="Female"}},
			{name="Redhead Hair 6", file="hair_redhead_06", unlock="cosmetic_race_human_redhead", only_for={sex="Female"}},
			{name="Redhead Hair 7", file="hair_redhead_07", unlock="cosmetic_race_human_redhead", only_for={sex="Female"}},
			{name="Redhead Hair 8", file="hair_redhead_08", unlock="cosmetic_race_human_redhead", only_for={sex="Female"}},
			{name="Redhead Hair 9", file="hair_redhead_09", unlock="cosmetic_race_human_redhead", only_for={sex="Female"}},
			{name="Redhead Hair 10", file="hair_redhead_10", unlock="cosmetic_race_human_redhead", only_for={sex="Female"}},
		},
		facial_features = {
			{name="Dark Beard 1", file="beard_01", only_for={sex="Male"}},
			{name="Dark Beard 2", file="beard_02", only_for={sex="Male"}},
			{name="Dark Beard 3", file="beard_03", only_for={sex="Male"}},
			{name="Dark Beard 4", file="beard_04", only_for={sex="Male"}},
			{name="Dark Beard 5", file="beard_05", only_for={sex="Male"}},
			{name="Blond Beard 1", file="beard_blond_01", only_for={sex="Male"}},
			{name="Blond Beard 2", file="beard_blond_02", only_for={sex="Male"}},
			{name="Blond Beard 3", file="beard_blond_03", only_for={sex="Male"}},
			{name="Blond Beard 4", file="beard_blond_04", only_for={sex="Male"}},
			{name="Blond Beard 5", file="beard_blond_05", only_for={sex="Male"}},
			{name="Redhead Beard 1", file="beard_redhead_01", unlock="cosmetic_race_human_redhead", only_for={sex="Male"}},
			{name="Redhead Beard 2", file="beard_redhead_02", unlock="cosmetic_race_human_redhead", only_for={sex="Male"}},
			{name="Redhead Beard 3", file="beard_redhead_03", unlock="cosmetic_race_human_redhead", only_for={sex="Male"}},
			{name="Redhead Beard 4", file="beard_redhead_04", unlock="cosmetic_race_human_redhead", only_for={sex="Male"}},
			{name="Redhead Beard 5", file="beard_redhead_05", unlock="cosmetic_race_human_redhead", only_for={sex="Male"}},
			{name="Dark Mustache 1", file="face_mustache_01", only_for={sex="Male"}},
			{name="Dark Mustache 2", file="face_mustache_02", only_for={sex="Male"}},
			{name="Dark Mustache 3", file="face_mustache_03", only_for={sex="Male"}},
			{name="Dark Mustache 4", file="face_mustache_04", only_for={sex="Male"}},
			{name="Blond Mustache 1", file="face_mustache_blond_01", only_for={sex="Male"}},
			{name="Blond Mustache 2", file="face_mustache_blond_02", only_for={sex="Male"}},
			{name="Blond Mustache 3", file="face_mustache_blond_03", only_for={sex="Male"}},
			{name="Blond Mustache 4", file="face_mustache_blond_04", only_for={sex="Male"}},
			{name="Redhead Mustache 1", file="face_mustache_redhead_01", unlock="cosmetic_race_human_redhead", only_for={sex="Male"}},
			{name="Redhead Mustache 2", file="face_mustache_redhead_02", unlock="cosmetic_race_human_redhead", only_for={sex="Male"}},
			{name="Redhead Mustache 3", file="face_mustache_redhead_03", unlock="cosmetic_race_human_redhead", only_for={sex="Male"}},
			{name="Redhead Mustache 4", file="face_mustache_redhead_04", unlock="cosmetic_race_human_redhead", only_for={sex="Male"}},
			{name="Dark Beard", file="beard_01", unlock="cosmetic_race_dwarf_female_beard", only_for={sex="Female"}},
			{name="Blond Beard", file="beard_redhead_01", unlock="cosmetic_race_dwarf_female_beard", only_for={sex="Female"}},
			{name="Redhead Beard", file="face_beard_blond_01", unlock="cosmetic_race_dwarf_female_beard", only_for={sex="Female"}},
			{name="Dark Donut", file="face_donut_01", unlock="cosmetic_race_dwarf_female_beard", only_for={sex="Female"}},
			{name="Blond Donut", file="face_donut_blond_01", unlock="cosmetic_race_dwarf_female_beard", only_for={sex="Female"}},
			{name="Redhead Donut", file="face_donut_redhead_01", unlock="cosmetic_race_dwarf_female_beard", only_for={sex="Female"}},
			{name="Dark Flip", file="face_flip_01", unlock="cosmetic_race_dwarf_female_beard", only_for={sex="Female"}},
			{name="Blond Flip", file="face_flip_blond_01", unlock="cosmetic_race_dwarf_female_beard", only_for={sex="Female"}},
			{name="Redhead Flip", file="face_flip_redhead_01", unlock="cosmetic_race_dwarf_female_beard", only_for={sex="Female"}},
			{name="Dark Mustache", file="face_mustache_01", unlock="cosmetic_race_dwarf_female_beard", only_for={sex="Female"}},
			{name="Blond Mustache", file="face_mustache_blond_01", unlock="cosmetic_race_dwarf_female_beard", only_for={sex="Female"}},
			{name="Redhead Mustache", file="face_mustache_redhead_01", unlock="cosmetic_race_dwarf_female_beard", only_for={sex="Female"}},
			{name="Dark Sideburns", file="face_sideburners_01", unlock="cosmetic_race_dwarf_female_beard", only_for={sex="Female"}},
			{name="Blond Sideburns", file="face_sideburners_blond_01", unlock="cosmetic_race_dwarf_female_beard", only_for={sex="Female"}},
			{name="Redhead Sideburns", file="face_sideburners_redhead_01", unlock="cosmetic_race_dwarf_female_beard", only_for={sex="Female"}},
		},
		special = {
			{name="Bikini / Mankini", birth_only=true, on_actor=function(actor, birther, last)
				if not last then local o = birther.obj_list_by_name[birther.descriptors_by_type.sex == 'Female' and 'Bikini' or 'Mankini'] if not o then print("No bikini/mankini found!") return end actor:getInven(actor.INVEN_BODY)[1] = o:cloneFull() actor.moddable_tile_nude = 1
				else actor:registerOnBirthForceWear(birther.descriptors_by_type.sex == 'Female' and "FUN_BIKINI" or "FUN_MANKINI") end
			end},
		},
	},
}
