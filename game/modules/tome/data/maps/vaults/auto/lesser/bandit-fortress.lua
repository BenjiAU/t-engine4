-- ToME - Tales of Maj'Eyal
-- Copyright (C) 2009 - 2018 Nicolas Casalini
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

setStatusAll{no_teleport=true, vault_only_door_open=true, room_map = {can_open=true}}
--setStatusAll{no_teleport=true, vault_only_door_open=true, room_map = {special=false, can_open=true}}
unique = "bandit-fortress" -- one per map
--startx, starty = 40, 19
border = 0
roomcheck = function(room, zone, level, map) -- one per zone, level restricted
	return not zone._bandit_fortress and resolvers.current_level >= 10 and zone.npc_list.__loaded_files["/data/general/npcs/thieve.lua"]
end
specialList("actor", {
	"/data/general/npcs/fire-drake.lua",
	"/data/general/npcs/aquatic_critter.lua",
	"/data/general/npcs/minotaur.lua",
	"/data/general/npcs/troll.lua",
	"/data/general/npcs/thieve.lua",
})
onplace = function(room, zone, level, map, data) -- flag the map as having this vault
	map._bandit_fortress = level.level
end
onGenerated(function(zone, level, map) -- update the zone after the vault is placed (in case the level was regenerated)
	if map._bandit_fortress == level.level then
		zone._bandit_fortress = level.level
	end
end
)

rotates = {"default", "90", "180", "270", "flipx", "flipy"}
defineTile('%', "WALL")
defineTile('.', "FLOOR")
defineTile('#', "HARDWALL")
defineTile('+', "DOOR")
defineTile('X', "DOOR_VAULT")
defineTile('~', "DEEP_WATER")
defineTile('*', "FLOOR", {random_filter={type="gem"}})
defineTile('$', "FLOOR", {random_filter={add_levels=25, type="money"}})
defineTile('/', "FLOOR", {random_filter={add_levels=5, tome_mod="vault"}})
defineTile('x', "FLOOR", {random_filter={add_levels=10, tome_mod="vault"}})
defineTile('L', "FLOOR", {random_filter={add_levels=15, tome_mod="gvault"}})
defineTile('^', "FLOOR", nil, nil, {random_filter={add_levels=20}})
defineTile('D', "FLOOR", nil, {random_filter={add_levels=15, name = "fire drake"}})
defineTile('p', "FLOOR", nil, {random_filter={add_levels=5, name = "assassin"}})
defineTile('P', "FLOOR", nil, {random_filter={add_levels=10, name = "bandit lord"}})
defineTile('H', "FLOOR", nil, {random_filter={add_levels=10, subtype = "minotaur"}})
defineTile('T', "FLOOR", nil, {random_filter={add_levels=20, subtype = "troll"}})
defineTile('A', "DEEP_WATER", nil, {random_filter={add_levels=10, type = "aquatic", subtype = "critter",}})

return {

[[........................................]],
[[.##########~~~~~~~~~~~~~~~~~~##########.]],
[[.#.p.....p#~~~A~~~~~~~~~~~~~~#.....p..#.]],
[[.#.######.#~~~~~~~~~~~~~~~~~~#.######.#.]],
[[.#.#xxxx#.#~~~~~~~~~A~~~~~A~~#.#xxx.#.#.]],
[[.#p#HHHH#.####################p#TTTT#p#.]],
[[.#.#pppP#.#*$$pH.+.#HLH.D..+^#.#HHHH#.#.]],
[[.#.#....#p#$*$pH.#.#LHH.D..#^#.#xxx.#.#.]],
[[.#.###+##.########.#########.#.##+###.#.]],
[[.#..p.....#..DDLL#.%.........+.p....p.#.]],
[[.#####+####%######+####################.]],
[[~A~~~#.#**#^.../$#P.....p....+.pp/#~~~~~]],
[[~~~~~#.#**#$.../$#.p.......p.#.pP/#~A~~~]],
[[~~~~~#.#**#$.../$#...p.....p.#ppp/#~~~~~]],
[[~~~~~#.#%%###+##############+#+####~~~~~]],
[[~~A~~#..HH#..p#.T............#////#~~~A~]],
[[~~~~~#....#p..#......T...p...#////#~~~~~]],
[[~~~~~#....#..p#..P...........######~~~~~]],
[[A~~~~#...P#...+T.....H....T...p...X.H...]],
[[~~~~~#P...#####...................X.T...]],
[[~~~~~#P...#####..T....p...p.......X.T...]],
[[~~~~~#...P#HH.+....H.........p....X.H...]],
[[~~~~~#....#.P.#..........T...######~~~~~]],
[[~~~~A#..HH#..p#...P...p......#////#~A~~~]],
[[~~~~~#..^^#p.^#T....T........#////#~~~~~]],
[[~~~~~#.#%%###+##############+#+####~~~~~]],
[[~~A~~#.#**#xxxxxD#.p.......P.#ppp/#A~~~~]],
[[~~~~~#.#**########.....p.....#.pP/#~~~A~]],
[[~~~~~#.#**%DDDLLL#.p.....p...+.pp/#~~~~~]],
[[.#####+###########+####################.]],
[[.#.p....p.+..P......H....TT..+.....p..#.]],
[[.#.###+##.#.....p......p..TT^#.##+###.#.]],
[[.#.#....#.#%################%#p#xxx.#.#.]],
[[.#.#pppP#.#....DDLL#LLDD.....#.#TTTT#.#.]],
[[.#p#HHHH#.####################.#HHHH#p#.]],
[[.#.#xxxx#p#~~~~A~~~~~~~~~A~~~#.#xxx.#.#.]],
[[.#.######.#~~~~~~~~~~~~~~~~~~#.######.#.]],
[[.#..p.....#~~~~~~~~~~~~~~~~A~#p...p...#.]],
[[.##########~~~~~A~~~~~~~~~~~~##########.]],
[[........................................]],

}