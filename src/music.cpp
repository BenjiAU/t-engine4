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
#include "soloud/include/soloud_wavstream.h"
#include <memory>
#include <vector>
#include <unordered_map>

using namespace SoLoud;
using namespace std;

namespace SoLoud {
	class PhysfsFile : public File {
	public:
		PHYSFS_file *fff = nullptr;
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
		bool exists() {return fff && true || false;}
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

static Soloud soloud;
static string base_folder = "/data/sound/";

void init_sounds() {
	soloud.init();
}

void deinit_sounds() {
	soloud.deinit();
}

static float default_ttl = 120;

static bool float_get_lua_table(lua_State *L, int table_idx, const char *field, float &res) {
	bool ret = false;
	lua_pushstring(L, field);
	lua_gettable(L, table_idx);
	if (lua_isnumber(L, -1)) {
		res = lua_tonumber(L, -1);
		ret = true;
	} else {
		ret = false;
	}
	lua_pop(L, 1);
	return ret;
}
static bool string_get_lua_table(lua_State *L, int table_idx, const char *field, const char **res) {
	bool ret = false;
	lua_pushstring(L, field);
	lua_gettable(L, table_idx);
	if (lua_isstring(L, -1)) {
		*res = lua_tostring(L, -1);
		ret = true;
	} else {
		ret = false;
	}
	lua_pop(L, 1);
	return ret;
}

static float global_volume = 1;

struct LoadedSound {
	float ttl = 60;
	float die_in = 60;
	float speed = 1;
	float volume = 1;
	AudioSource *data = nullptr;
	string name;
	LoadedSound() : ttl(default_ttl), die_in(default_ttl) {}
	~LoadedSound() {
		if (data) {
			data->stop();
			delete data;
		}
	}
	void loadWav(string file, lua_State *L = nullptr, int lua_def_stack = 0) {
		name = file;
		file = base_folder + file;
		bool rewrote_file = false;
		
		if (L) {
			bool clean_stack = false;
			int stack = 0;
			if (lua_def_stack && lua_istable(L, lua_def_stack)) {
				stack = lua_def_stack;
			} else {
				string luafile = file + ".lua";
				if (PHYSFS_exists(luafile.c_str())) {
					clean_stack = true;
					luaL_loadfile(L, luafile.c_str());
					lua_call(L, 0, 1);
					if (lua_istable(L, lua_gettop(L))) stack = lua_gettop(L);
				}
			}

			if (stack) {
				const char *newfile = nullptr;
				if (string_get_lua_table(L, stack, "file", &newfile)) {
					file = base_folder + string(newfile);
					rewrote_file = true;
				}
				if (float_get_lua_table(L, stack, "volume", volume)) {
					volume /= 100.0;
				}
				float_get_lua_table(L, stack, "speed", speed);
				if (clean_stack) lua_pop(L, 1);
			}
		}

		if (!rewrote_file) file = file + ".ogg";
		PhysfsFile f(file.c_str());
		auto w = new Wav();
		w->setInaudibleBehavior(false, true);
		if (f.exists()) w->loadFile(&f);
		w->setVolume(volume * global_volume);
		data = w;
	}
};

static unordered_map<string, unique_ptr<LoadedSound>> loaded_sounds;

static int sound_base_folder(lua_State *L) {
	auto file = string(lua_tostring(L, 1));
	base_folder = file;
	return 0;
}

static int sound_default_ttl(lua_State *L) {
	default_ttl = lua_tonumber(L, 1);
	return 0;
}

static int sound_max_sounds(lua_State *L) {
	soloud.setMaxActiveVoiceCount(lua_tonumber(L, 1));
	return 0;
}

static int audio_global_volume(lua_State *L) {
	global_volume = lua_tonumber(L, 1);
	for (auto& s : loaded_sounds) {
		s.second->data->setVolume(s.second->volume * global_volume);
	}
	return 0;
}

static LoadedSound* do_load(string &name, lua_State *L = nullptr, int lua_def_stack = 0) {
	auto it = loaded_sounds.find(name);
	if (it != loaded_sounds.end()) {
		// printf("Reusing %s\n", name.c_str());
		return it->second.get();
	}
	auto s = new LoadedSound();
	s->loadWav(name, L, lua_def_stack);
	loaded_sounds.emplace(name, s);
	printf("[SOUND] Loading %s\n", name.c_str());
	return s;
}

// do_load version for the external code, no need to access LoadedSound
bool load_sound(string &name) {
	auto it = loaded_sounds.find(name);
	if (it != loaded_sounds.end()) {
		// printf("Reusing %s\n", name.c_str());
		return it->second.get()->data ? true : false;
	}
	auto s = new LoadedSound();
	s->loadWav(name);
	loaded_sounds.emplace(name, s);
	printf("[SOUND] Loading %s\n", name.c_str());
	return s->data ? true : false;
}

static int sound_load(lua_State *L) {
	auto name = string(lua_tostring(L, 1));
	do_load(name, L, 2);
	return 0;
}

static int audio_enable(lua_State *L) {
	bool v = lua_toboolean(L, 1);
	soloud.fadeGlobalVolume(v and 1 or 0, 0.3);
	return 0;
}

static int sound_play(lua_State *L) {
	if (soloud.getActiveVoiceCount() >= soloud.getMaxActiveVoiceCount()) {
		lua_pushnumber(L, 0);
		return 1;
	}

	auto name = string(lua_tostring(L, 1));
	auto s = do_load(name, L, 3);
	if (!s->data) return 0;
	s->die_in = s->ttl;
	handle h;
	if (lua_istable(L, 2)) {
		float x = 0, y = 0, z = 0;
		float_get_lua_table(L, 2, "x", x);
		float_get_lua_table(L, 2, "y", y);
		float_get_lua_table(L, 2, "z", z);
		h = soloud.play3d(*s->data, x, y, z);
	} else {
		h = soloud.play(*s->data);
	}
	if (s->speed != 1) soloud.setRelativePlaySpeed(h, s->speed);
	int *lh = (int*)lua_newuserdata(L, sizeof(int));
	auxiliar_setclass(L, "sound{handle}", -1);
	*lh = h;
	return 1;
}

bool play_sound(string &name) {
	if (soloud.getActiveVoiceCount() >= soloud.getMaxActiveVoiceCount()) {
		return false;
	}

	auto s = do_load(name);
	if (!s->data) return false;
	s->die_in = s->ttl;
	handle h;
	// if (lua_istable(L, 2)) {
	// 	float x = 0, y = 0, z = 0;
	// 	float_get_lua_table(L, 2, "x", x);
	// 	float_get_lua_table(L, 2, "y", y);
	// 	float_get_lua_table(L, 2, "z", z);
	// 	h = soloud.play3d(*s->data, x, y, z);
	// } else {
		h = soloud.play(*s->data);
	// }
	if (s->speed != 1) soloud.setRelativePlaySpeed(h, s->speed);
	return true;
}

static int sound_pause(lua_State *L) {
	int h = *(int*)auxiliar_checkclass(L, "sound{handle}", 1);
	soloud.setPause(h, lua_toboolean(L, 2));
	return 0;
}

static int sound_stop(lua_State *L) {
	int h = *(int*)auxiliar_checkclass(L, "sound{handle}", 1);
	soloud.stop(h);
	return 0;
}

static int sound_loop(lua_State *L) {
	int h = *(int*)auxiliar_checkclass(L, "sound{handle}", 1);
	soloud.setLooping(h, lua_toboolean(L, 2));
	return 0;
}

static int sound_volume(lua_State *L) {
	int h = *(int*)auxiliar_checkclass(L, "sound{handle}", 1);
	float v = lua_tonumber(L, 2) * global_volume;
	float fade = lua_tonumber(L, 3);
	if (fade) {
		if (lua_toboolean(L, 4)) soloud.fadeVolume(h, soloud.getVolume(h) * v, fade);
		else soloud.fadeVolume(h, v, fade);
	} else {
		if (lua_toboolean(L, 4)) soloud.setVolume(h, soloud.getVolume(h) * v);		
		else soloud.setVolume(h, v);
	}
	return 0;
}

static int sound_speed(lua_State *L) {
	int h = *(int*)auxiliar_checkclass(L, "sound{handle}", 1);
	soloud.setRelativePlaySpeed(h, lua_tonumber(L, 2));
	return 0;
}

static int sound_is_playing(lua_State *L) {
	int h = *(int*)auxiliar_checkclass(L, "sound{handle}", 1);
	lua_pushboolean(L, soloud.isValidVoiceHandle(h));
	return 1;
}

struct PlayingMusic {
	float die_in = 0;
	handle h;
	WavStream stream;
	string name;
	PhysfsFile *file = nullptr;
	~PlayingMusic() {
		stream.stop();
		printf("[MUSIC] unloading %s\n", name.c_str());
		if (file) delete file;
	}
	bool load(string &cfile) {
		name = cfile;
		file = new PhysfsFile(cfile.c_str());
		// music->setInaudibleBehavior(false, true);
		stream.loadFile(file); // Load a wave
		stream.setLooping(true);
		printf("[MUSIC] Loading %s\n", cfile.c_str());
	}
};

static vector<unique_ptr<PlayingMusic>> current_musics;
static float music_volume = 1;

static int play_music(lua_State *L) {
	const char* file = lua_tostring(L, 1);
	string cfile(file);
	float fade = 1;
	if (lua_isnumber(L, 2)) fade = lua_tonumber(L, 2);

	auto m = new PlayingMusic();
	current_musics.emplace_back(m);
	
	m->load(cfile);
	m->h = soloud.playBackground(m->stream);
	soloud.setProtectVoice(m->h, true);
	soloud.setInaudibleBehavior(m->h, true, false);
	if (fade == 0) {
		soloud.setVolume(m->h, music_volume);
	} else {
		soloud.setVolume(m->h, 0);
		soloud.fadeVolume(m->h, music_volume, fade);
	}
	lua_pushnumber(L, m->h);
	return 1;
}

static int volume_music(lua_State *L) {
	float volume = lua_tonumber(L, 1);
	float fade = 1;
	if (lua_isnumber(L, 2)) fade = lua_tonumber(L, 2);

	music_volume = volume;
	for (auto& m : current_musics) {
		if (m->die_in) continue;
		if (fade == 0) {
			soloud.setVolume(m->h, volume);
		} else {
			soloud.fadeVolume(m->h, volume, fade);
		}
	}
	return 0;
}

static int list_music(lua_State *L) {
	lua_newtable(L);
	int i = 1;
	for (auto& m : current_musics) {
		if (m->die_in) continue;
		lua_pushstring(L, m->name.c_str());
		lua_rawseti(L, -2, i++);
	}
	return 1;
}

static int stop_musics(lua_State *L) {
	float fade = 1;
	if (lua_isnumber(L, 1)) fade = lua_tonumber(L, 1);
	bool has_keep = lua_istable(L, 2);

	for (auto& m : current_musics) {
		// Check those to kill or not
		if (has_keep) {
			bool keep = false;
			lua_pushstring(L, m->name.c_str());
			lua_gettable(L, 2);
			if (lua_toboolean(L, -1)) {
				lua_pop(L, 1);
				lua_pushstring(L, m->name.c_str());
				lua_pushliteral(L, "playing");
				lua_settable(L, 2);
				keep = true;
			} else {
				lua_pop(L, 1);
			}
			if (keep) continue;
		}
		if (fade == 0) {
			soloud.setVolume(m->h, 0);
			m->die_in = 0.0001;
		} else {
			soloud.fadeVolume(m->h, 0, fade);
			m->die_in = fade;
		}
	}
	return 0;
}

void update_audio(float nb_keyframes) {
	// printf("%d / %d sounds\n", soloud.getActiveVoiceCount(), soloud.getVoiceCount());

	for (auto m = current_musics.begin(); m != current_musics.end();) {
		if ((*m)->die_in) {
			(*m)->die_in -= nb_keyframes / 30.0;
			if ((*m)->die_in <= 0) {
				m = current_musics.erase(m);
				continue;
			}
		}
		m++;
	}	

	for (auto s = loaded_sounds.begin(); s != loaded_sounds.end();) {
		if (s->second->die_in) {
			s->second->die_in -= nb_keyframes / 30.0;
			if (s->second->die_in <= 0) {
				s = loaded_sounds.erase(s);
				continue;
			}
		}
		s++;
	}
}

void kill_audio() {
	current_musics.clear();
	loaded_sounds.clear();
}

const luaL_Reg handle_fcts[] = {
	{"play", sound_play},
	{"pause", sound_pause},
	{"stop", sound_stop},
	{"loop", sound_loop},
	{"volume", sound_volume},
	{"pitch", sound_speed},
	{"playing", sound_is_playing},
	{NULL, NULL}
};

const luaL_Reg soundlib[] = {
	{"baseFolder", sound_base_folder},
	{"cacheTime", sound_default_ttl},
	{"maxSounds", sound_max_sounds},
	{"globalVolume", audio_global_volume},
	{"load", sound_load},
	{"play", sound_play},
	{"enable", audio_enable},
	{NULL, NULL}
};

const luaL_Reg musiclib[] = {
	{"stopCurrent", stop_musics},
	{"play", play_music},
	{"volume", volume_music},
	{"list", list_music},
	{NULL, NULL}
};

int luaopen_sound(lua_State *L)
{
	auxiliar_newclass(L, "sound{handle}", handle_fcts);
	luaL_openlib(L, "core.sound", soundlib, 0);
	luaL_openlib(L, "core.music", musiclib, 0);
	lua_pop(L, 1);
	return 1;
}
