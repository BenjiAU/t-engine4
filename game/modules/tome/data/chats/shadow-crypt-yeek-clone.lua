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

local cultist = nil
for uid, e in pairs(game.level.entities) do if e.define_as == "CULTIST_RAK_SHOR" then cultist = true end end

if cultist then

newChat{ id="welcome",
	text = [[No time to talk fellow Wayist! ATTACK! FOR THE WAY!]],
	answers = {
		{"[leave]"},
	}
}

else 

newChat{ id="welcome",
	text = [[The foolish cultist that created me is no more. What am I to do now...]],
	answers = {
		{"You are me, come with me!", jump="nocome"},
		{"You should head back to Irkkk.", jump="irkkk"},
	}
}

newChat{ id="nocome",
	text = [[I fear that would get confusing very fast. I think I will go back to Irkkk. Farewell my clone!]],
	answers = {
		{"Clone? No you are the clone.", jump="clone"},
		{"Farewell.", action=function(npc, player) npc:disappear() end},
	}
}

newChat{ id="clone",
	text = [[Sure... if you prefer to think about it this way. We are all part of The Way anyway.]],
	answers = {
		{"Farewell.", action=function(npc, player) npc:disappear() end},
	}
}

newChat{ id="irkkk",
	text = [[I think so too, farewell my clone.]],
	answers = {
		{"Clone? No you are the clone.", jump="clone"},
		{"Farewell.", action=function(npc, player) npc:disappear() end},
	}
}

end


return "welcome"
