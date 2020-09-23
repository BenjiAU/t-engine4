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

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
extern "C" {
#include "tSDL.h"
#include "physfs.h"
#include "lua.h"
#include "lauxlib.h"
#include "lualib.h"
#include "auxiliar.h"
#include "unistd.h"
}
#include "music.hpp"
#include "soloud/include/soloud.h"
#include "soloud/include/soloud_file.h"
#include "soloud/include/soloud_wav.h"

using namespace SoLoud;

namespace SoLoud {
	class PhysfsFile : public File {
	public:
		PHYSFS_file *fff;
		PhysfsFile(const char *path) {
			fff = PHYSFS_openRead(path);
			if (!fff) {
				printf("[SoundSystem] ERROR loading file: %s\n", path);
			}
		}
		virtual ~PhysfsFile() {
			if (!fff) return;
			PHYSFS_close(fff);
		}
		virtual int eof() {
			if (!fff) return 1;
			return PHYSFS_eof(fff);
		}
		virtual unsigned int read(unsigned char *aDst, unsigned int aBytes) {
			return PHYSFS_read(fff, aDst, sizeof(unsigned char), aBytes);
		}
		virtual unsigned int length() {
			if (!fff) return 0;
			return PHYSFS_fileLength(fff);
		}
		virtual void seek(int aOffset) {
			if (!fff) return;
			PHYSFS_seek(fff, aOffset);
		}
		virtual unsigned int pos() {
			if (!fff) return 0;
			return PHYSFS_tell(fff);
		}
	};
}

static SoLoud::Soloud soloud;
Wav tmp;
PhysfsFile *wav_file;

void init_sounds() {
	soloud.init();
	// wav_file = new PhysfsFile("/data/sound/talents/fireflash.ogg");
	// tmp.loadFile(wav_file); // Load a wave
	// soloud.play(tmp);
}

void deinit_sounds() {
	soloud.deinit();
}

static int loadsoundLua(lua_State *L) {
	PHYSFS_file *file;
	const char *s;

	luaL_checktype(L, 1, LUA_TSTRING);
	s = lua_tostring(L, 1);
	bool is_stream = lua_toboolean(L, 2);
	return 1;
}

static int audio_enable(lua_State *L) {
	bool v = lua_toboolean(L, 1);
	return 0;
}

const luaL_Reg soundlib[] = {
	{"load", loadsoundLua},
	{"enable", audio_enable},
	{NULL, NULL}
};

static int soundTostringLua(lua_State *L) {
	return 1;
}

static int soundCollectLua(lua_State *L) {
	return 0;
}

static int sourceCollectLua(lua_State *L) {
	return 0;
}

static int soundNewSource(lua_State *L) {
	return 1;
}

static int soundPlayLua(lua_State *L) {
	return 0;
}

static int soundPauseLua(lua_State *L) {
	return 0;
}

static int soundStopLua(lua_State *L) {
	return 0;
}

static int soundLoopLua(lua_State *L) {
	return 1;
}

static int soundVolumeLua(lua_State *L) {
	return 1;
}

static int soundPitchLua(lua_State *L) {
	return 1;
}

static int soundLocationLua(lua_State *L) {
	return 2;
}

static int soundPlayingLua(lua_State *L) {
	return 1;
}

const luaL_Reg soundFuncs[] = {
	{"__tostring", soundTostringLua},
	{"__gc", soundCollectLua},
	{"use", soundNewSource},
	{NULL, NULL}
};

const luaL_Reg sourceFuncs[] = {
	{"__gc", sourceCollectLua},
	{"play", soundPlayLua},
	{"pause", soundPauseLua},
	{"stop", soundStopLua},
	{"loop", soundLoopLua},
	{"volume", soundVolumeLua},
	{"pitch", soundPitchLua},
	{"location", soundLocationLua},
	{"playing", soundPlayingLua},
	{NULL, NULL}
};

int luaopen_sound(lua_State *L)
{
	auxiliar_newclass(L, "sound{buffer}", soundFuncs);
	auxiliar_newclass(L, "sound{source}", sourceFuncs);
	luaL_openlib(L, "core.sound", soundlib, 0);
	lua_pop(L, 1);
	return 1;
}
