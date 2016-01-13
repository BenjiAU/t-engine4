-- ToME - Tales of Maj'Eyal
-- Copyright (C) 2009 - 2016 Nicolas Casalini
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

load("/data/general/grids/basic.lua")
load("/data/general/grids/forest.lua")
load("/data/general/grids/water.lua")

-- This is mostly copied over from the Old Forest grids.lua

	local grass_editer = { method="borders_def", def="dark_grass"}

	newEntity{
		define_as = "GRASS",
		type = "floor", subtype = "dark_grass",
		name = "grass", image = "terrain/grass/dark_grass_main_01.png",
		display = '.', color=colors.LIGHT_GREEN, back_color={r=44,g=95,b=43},
		grow = "TREE",
		nice_tiler = { method="replace", base={"GRASS_PATCH", 100, 1, 14}},
		nice_editer = grass_editer,
	}
	for i = 1, 14 do newEntity{ base = "GRASS", define_as = "GRASS_PATCH"..i, image = ("terrain/grass/dark_grass_main_%02d.png"):format(i) } end

	local treesdef = {
		{"oldforest_tree_01", {tall=-1, "shadow", "trunk_01", {"foliage_summer_%02d",1,2}}},
		{"oldforest_tree_01", {tall=-1, "shadow", "trunk_02", {"foliage_summer_%02d",3,3}}},
		{"oldforest_tree_01", {tall=-1, "shadow", "trunk_03", {"foliage_summer_%02d",4,4}}},
		{"oldforest_tree_02", {tall=-1, "shadow", "trunk_01", {"foliage_summer_%02d",1,2}}},
		{"oldforest_tree_02", {tall=-1, "shadow", "trunk_02", {"foliage_summer_%02d",3,3}}},
		{"oldforest_tree_02", {tall=-1, "shadow", "trunk_03", {"foliage_summer_%02d",4,4}}},
		{"oldforest_tree_03", {tall=-1, "shadow", "trunk_01", {"foliage_summer_%02d",1,2}}},
		{"oldforest_tree_03", {tall=-1, "shadow", "trunk_02", {"foliage_summer_%02d",3,3}}},
		{"oldforest_tree_03", {tall=-1, "shadow", "trunk_03", {"foliage_summer_%02d",4,4}}},
		{"small_oldforest_tree_01", {"shadow", "trunk_01", {"foliage_summer_%02d",1,2}}},
		{"small_oldforest_tree_01", {"shadow", "trunk_02", {"foliage_summer_%02d",3,3}}},
		{"small_oldforest_tree_01", {"shadow", "trunk_03", {"foliage_summer_%02d",4,4}}},
		{"small_oldforest_tree_02", {"shadow", "trunk_01", {"foliage_summer_%02d",1,2}}},
		{"small_oldforest_tree_02", {"shadow", "trunk_02", {"foliage_summer_%02d",3,3}}},
		{"small_oldforest_tree_02", {"shadow", "trunk_03", {"foliage_summer_%02d",4,4}}},
		{"small_oldforest_tree_03", {"shadow", "trunk_01", {"foliage_summer_%02d",1,2}}},
		{"small_oldforest_tree_03", {"shadow", "trunk_02", {"foliage_summer_%02d",3,3}}},
		{"small_oldforest_tree_03", {"shadow", "trunk_03", {"foliage_summer_%02d",4,4}}},

		{"oldforest_tree_01", {tall=-1, "shadow", "trunk_01", {"foliage_bare_%02d",1,2}}},
		{"oldforest_tree_01", {tall=-1, "shadow", "trunk_02", {"foliage_bare_%02d",3,3}}},
		{"oldforest_tree_01", {tall=-1, "shadow", "trunk_03", {"foliage_bare_%02d",4,4}}},
		{"oldforest_tree_02", {tall=-1, "shadow", "trunk_01", {"foliage_bare_%02d",1,2}}},
		{"oldforest_tree_02", {tall=-1, "shadow", "trunk_02", {"foliage_bare_%02d",3,3}}},
		{"oldforest_tree_02", {tall=-1, "shadow", "trunk_03", {"foliage_bare_%02d",4,4}}},
		{"oldforest_tree_03", {tall=-1, "shadow", "trunk_01", {"foliage_bare_%02d",1,2}}},
		{"oldforest_tree_03", {tall=-1, "shadow", "trunk_02", {"foliage_bare_%02d",3,3}}},
		{"oldforest_tree_03", {tall=-1, "shadow", "trunk_03", {"foliage_bare_%02d",4,4}}},
		{"small_oldforest_tree_01", {"shadow", "trunk_01", {"foliage_bare_%02d",1,2}}},
		{"small_oldforest_tree_01", {"shadow", "trunk_02", {"foliage_bare_%02d",3,3}}},
		{"small_oldforest_tree_01", {"shadow", "trunk_03", {"foliage_bare_%02d",4,4}}},
		{"small_oldforest_tree_02", {"shadow", "trunk_01", {"foliage_bare_%02d",1,2}}},
		{"small_oldforest_tree_02", {"shadow", "trunk_02", {"foliage_bare_%02d",3,3}}},
		{"small_oldforest_tree_02", {"shadow", "trunk_03", {"foliage_bare_%02d",4,4}}},
		{"small_oldforest_tree_03", {"shadow", "trunk_01", {"foliage_bare_%02d",1,2}}},
		{"small_oldforest_tree_03", {"shadow", "trunk_02", {"foliage_bare_%02d",3,3}}},
		{"small_oldforest_tree_03", {"shadow", "trunk_03", {"foliage_bare_%02d",4,4}}},
	}

	newEntity{
		define_as = "TREE",
		type = "wall", subtype = "dark_grass",
		name = "tree",
		image = "terrain/tree.png",
		display = '#', color=colors.LIGHT_GREEN, back_color={r=44,g=95,b=43},
		always_remember = true,
		can_pass = {pass_tree=1},
		does_block_move = true,
		block_sight = true,
		dig = "GRASS",
		nice_tiler = { method="replace", base={"TREE", 100, 1, 30}},
		nice_editer = grass_editer,
	}
	newEntity{
		define_as = "HARDTREE",
		type = "wall", subtype = "dark_grass",
		name = "tall thick tree",
		image = "terrain/tree.png",
		display = '#', color=colors.LIGHT_GREEN, back_color={r=44,g=95,b=43},
		always_remember = true,
		does_block_move = true,
		block_sight = true,
		block_sense = true,
		block_esp = true,
		nice_tiler = { method="replace", base={"HARDTREE", 100, 1, 30}},
		nice_editer = grass_editer,
	}
	for i = 1, 30 do
		newEntity(class:makeNewTrees({base="TREE", define_as = "TREE"..i, image = "terrain/grass/dark_grass_main_01.png"}, treesdef, 3))
	end
	for i = 1, 30 do
		newEntity(class:makeNewTrees({base="HARDTREE", define_as = "HARDTREE"..i, image = "terrain/grass/dark_grass_main_01.png"}, treesdef))
	end

	newEntity{
		define_as = "DISTORTED_GROVE", base = "GRASS_UP4",
		image = "terrain/grass/dark_grass_main_01.png",
		nice_editer = grass_editer,
		change_level = 3, change_zone = "atof+distorted-grove",
		notice = true, always_remember=true, force_down=true,

	}

	newEntity{
		define_as = "POINT_ZERO_PORTAL",
		name = "temporal portal",
		display = '>', color_r=255, color_g=255, color_b=0, image = "terrain/grass/dark_grass_main_01.png", add_displays = {class.new{image = "terrain/temporal_instability_blue.png"}},
		notice = true,
		always_remember = true,
		change_level = 1, change_zone = "atof+point-zero",
	}
