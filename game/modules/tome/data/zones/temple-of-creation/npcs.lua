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

load("/data/general/npcs/aquatic_critter.lua", rarity(5))
load("/data/general/npcs/aquatic_demon.lua", rarity(7))
load("/data/general/npcs/naga.lua", rarity(0))

local Talents = require("engine.interface.ActorTalents")

newEntity{ define_as = "SLASUL",
	allow_infinite_dungeon = true,
	type = "humanoid", subtype = "naga", unique = true,
	name = "Slasul",
	faction="temple-of-creation",
	display = "@", color=colors.VIOLET,
	resolvers.nice_tile{image="invis.png", add_mos = {{image="npc/humanoid_naga_slasul.png", display_h=2, display_y=-1}}},
	desc = [[This powerful naga is at home in the Temple of Creation, and unlike his followers he uses a mace and a shield.]],
	killer_message = "and perverted into a monstrous aberration as a warning to the surface",
	global_speed = 1.7,
	level_range = {30, nil}, exp_worth = 4,
	max_life = 350, life_rating = 19, fixed_rating = true,
	max_stamina = 85,
	stats = { str=25, dex=10, cun=40, mag=50, con=50 },
	rank = 4,
	size_category = 3,
	can_breath={water=1},
	infravision = 10,
	move_others=true,

	instakill_immune = 1,
	teleport_immune = 1,
	confusion_immune= 1,
	combat_spellresist = 25,
	combat_mentalresist = 25,
	combat_physresist = 30,

	resists = { [DamageType.COLD] = 60, [DamageType.ACID] = 20, },

	body = { INVEN = 10, MAINHAND=1, OFFHAND=1, BODY=1, LITE=1 },
	resolvers.equip{
		{type="weapon", subtype="mace", force_drop=true, tome_drops="boss", autoreq=true},
		{type="armor", subtype="shield", force_drop=true, tome_drops="boss", autoreq=true},
		{type="armor", subtype="heavy", force_drop=true, tome_drops="boss", autoreq=true},
		{type="jewelry", subtype="lite", defined="ELDRITCH_PEARL", autoreq=true},
	},
	resolvers.drops{chance=100, nb=1, {defined="SLASUL_NOTE"} },
	resolvers.drops{chance=100, nb=5, {tome_drops="boss"} },

	resolvers.talents{
		[Talents.T_WEAPON_COMBAT]={base=6, every=6, max=10},
		[Talents.T_WEAPONS_MASTERY]={base=6, every=6, max=10},
		[Talents.T_SHIELD_EXPERTISE]={base=3, every=7, max=6},
		[Talents.T_SHIELD_PUMMEL]={base=2, every=7, max=6},
		[Talents.T_RIPOSTE]=5,
		[Talents.T_BLINDING_SPEED]={base=3, every=7, max=6},
		[Talents.T_PERFECT_STRIKE]=5,

		[Talents.T_SPIT_POISON]={base=5, every=5, max=9},

		[Talents.T_HEAL]={base=6, every=7, max=7},
		[Talents.T_UTTERCOLD]=5,
		[Talents.T_ICE_SHARDS]=5,
		[Talents.T_FREEZE]=3,
		[Talents.T_TIDAL_WAVE]=5,
		[Talents.T_ICE_STORM]=5,
		[Talents.T_WATER_BOLT]=5,

		[Talents.T_MIND_DISRUPTION]=5,
	},
	resolvers.sustains_at_birth(),

	autolevel = "warrior",
	ai = "tactical", ai_state = { talent_in=1, ai_move="move_astar", },
	ai_tactic = resolvers.tactic"melee",
	resolvers.inscriptions(4, "infusion"),
	resolvers.inscriptions(1, {"manasurge rune"}),

	on_die = function(self, who)
		game.player:resolveSource():setQuestStatus("temple-of-creation", engine.Quest.COMPLETED, "kill-slasul")
		game.player:resolveSource():hasQuest("temple-of-creation"):portal_back()
	end,

	can_talk = "slasul",
}
