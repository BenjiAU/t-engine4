/*
	TE4 - T-Engine 4
	Copyright (C) 2009 - 2018 Nicolas Casalini

	This program is free software: you can redistribute it and/or modify
	it under the terms of the GNU General Public License as published by
	the Free Software Foundation, either version 3 of the License, or
	(at your option) any later version.

	This program is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	GNU General Public License for more details.

	You should have received a copy of the GNU General Public License
	along with this program.  If not, see <http://www.gnu.org/licenses/>.

	Nicolas Casalini "DarkGod"
	darkgod@te4.org
*/
extern "C" {
#include "lua.h"
#include "lauxlib.h"
#include "lualib.h"
#include "auxiliar.h"
#include "types.h"
#include "physfs.h"
#include "physfsrwops.h"
#include "main.h"
#include "lua_externs.h"
}
#include "core_lua.hpp"
#include "utilities.hpp"

bool utility_spritesheet_generator(int argc, char **argv) {
	lua_State * L = lua_open();
	luaL_openlibs(L);
	luaopen_physfs(L);
	luaopen_core(L);
	luaopen_lpeg(L);
	luaopen_font(L);
	luaopen_binpack(L);
	physfs_reset_dir_allowed(L);
	bootstrap_lua_state(L, argc, argv);
	lua_pushboolean(L, true); lua_setglobal(L, "__reduce_utils");

	if (!luaL_loadfile(L, "/utilities/spritesheet_generator.lua")) {
		for (int i = 3; i < argc; i++) {
			lua_pushstring(L, argv[i]);
		}
		docall(L, argc - 3, 0);
	}

	return true;
}
