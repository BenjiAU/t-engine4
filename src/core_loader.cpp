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
#include "types.h"
#include "display.h"
#include "fov/fov.h"
#include "lauxlib.h"
#include "lualib.h"
#include "auxiliar.h"
#include "script.h"
#include "display.h"
#include "physfs.h"
#include "physfsrwops.h"
#include "main.h"
#include "lua_externs.h"
}
#include "texture_holder.hpp"
#include "core_lua.hpp"
#include "core_loader.hpp"
#include <queue>
#include <string>
#include <array>
#include <vector>
#include "glm/glm.hpp"

using namespace std;
using namespace glm;
static int loader_running = 0;

/**************************************************************************
 ** Async code
 **************************************************************************/
class Loader;
SDL_Thread *loader_thread = NULL;
SDL_mutex *loader_mutex;
SDL_sem *loader_sem;
queue<Loader*> loader_queue;
queue<Loader*> loader_queue_done;

class Loader {
public:
	virtual ~Loader() {};
	virtual bool load() = 0;
	virtual bool finish() = 0;
	void done() {
		SDL_mutexP(loader_mutex);
		loader_queue_done.push(this);
		SDL_mutexV(loader_mutex);
	}
};

/************************************************************************************
 ** Palette to texture
 ************************************************************************************/
struct palette_color{GLubyte red; GLubyte green; GLubyte blue; GLubyte alpha;};
class LoaderPalette : public Loader {
private:
	string filename;
	GLuint tex;
	vector<palette_color> colors;
	PHYSFS_file *file;

	palette_color readNextLine() {
		char buf[102400];
		char *ptr = buf;
		int bufsize = 102400;
		int total = 0;

		if (PHYSFS_eof(file)) return palette_color{0, 0, 0, 0};

		bufsize--;  /* allow for null terminating char */
		while ((total < bufsize) && (PHYSFS_read(file, ptr, 1, 1) == 1))
		{
			if (*ptr == '\n')
			{
				if ((total > 0) && (*(ptr-1) == '\r')) *(ptr-1) = '\0';
				break;
			}
			ptr++;
			total++;
		}
		*ptr = '\0';  // null terminate it.

		int len = strlen(buf);
		if (buf[0] != '#' || len != 7) return palette_color{0, 0, 0, 0};
		float blue = stoi(&buf[5], 0, 16); buf[5] = '\0';
		float green = stoi(&buf[3], 0, 16); buf[3] = '\0';
		float red = stoi(&buf[1], 0, 16);
		return palette_color{red, green, blue, 255};
	}
public:
	LoaderPalette(const char *filename, GLuint tex) : tex(tex), filename(filename), colors(256) {};
	virtual ~LoaderPalette() { };
	virtual bool load() {
		file = PHYSFS_openRead(filename.c_str());
		for (int i = 0; i < 256; i++) {
			colors[i] = readNextLine();
		}
		PHYSFS_close(file);
		done();
	}
	virtual bool finish() {
		printf("[LOADER] done loading palette %s in texture %d!\n", filename.c_str(), tex);
		tfglBindTexture(GL_TEXTURE_2D, tex);
		glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, 256, 1, 0, GL_RGBA, GL_UNSIGNED_BYTE, colors.data());
	}
};

/************************************************************************************
 ** PNG to texture
 ************************************************************************************/
class LoaderPNG : public Loader {
private:
	string filename;
	GLuint tex;
	PHYSFS_file *file;
	SDL_Surface *s;
public:
	LoaderPNG(const char *filename, PHYSFS_file *file, GLuint tex) : file(file), tex(tex), filename(filename) {};
	virtual ~LoaderPNG() { };
	virtual bool load() {
		s = IMG_Load_RW(PHYSFSRWOPS_makeRWops(file), TRUE);
		if (!s) printf("ERROR : LoaderPNG : %s\n",SDL_GetError());
		file = NULL;
		done();		
	}
	virtual bool finish() {
		if (s) {
			printf("[LOADER] done loading PNG %s in texture %d!\n", filename.c_str(), tex);
			tfglBindTexture(GL_TEXTURE_2D, tex);
			GLenum texture_format = sdl_gl_texture_format(s);
			GLint nOfColors = s->format->BytesPerPixel;
			glTexImage2D(GL_TEXTURE_2D, 0, nOfColors == 4 ? GL_RGBA : (nOfColors == 3 ? GL_RGB : GL_RED), s->w, s->h, 0, texture_format, GL_UNSIGNED_BYTE, s->pixels);
			SDL_FreeSurface(s);
		}
	}
};

/************************************************************************************
 ** PNG to cubemap texture
 ************************************************************************************/
class LoaderPNGCubemap : public Loader {
private:
	array<string, 6> filenames;
	GLuint tex;
	array<PHYSFS_file*, 6> files = {nullptr, nullptr, nullptr, nullptr, nullptr, nullptr};
	array<SDL_Surface*, 6> s = {nullptr, nullptr, nullptr, nullptr, nullptr, nullptr};
public:
	LoaderPNGCubemap(array<string, 6> &filenames, array<PHYSFS_file*, 6> &files, GLuint tex) : tex(tex) {
		for (int i = 0; i < 6; i++) {
			this->filenames[i] = filenames[i];
			this->files[i] = files[i];
		}
	};
	virtual ~LoaderPNGCubemap() { };
	virtual bool load() {
		for (int i = 0; i < 6; i++) {
			s[i] = IMG_Load_RW(PHYSFSRWOPS_makeRWops(files[i]), TRUE);
			if (!s[i]) printf("ERROR : LoaderPNGCubemap : %s\n", SDL_GetError());
			files[i] = NULL;
		}
		done();		
	}
	virtual bool finish() {
		if (s[0] && s[1] && s[2] && s[3] && s[4] && s[5]) {
			printf("[LOADER] done loading cubemap PNG %s / %s / %s / %s / %s / %s in texture %d!\n", filenames[0].c_str(), filenames[1].c_str(), filenames[2].c_str(), filenames[3].c_str(), filenames[4].c_str(), filenames[5].c_str(), tex);
			tfglBindTexture(GL_TEXTURE_CUBE_MAP, tex);

			GLenum texture_format = sdl_gl_texture_format(s[0]);
			GLint nOfColors = s[0]->format->BytesPerPixel;
			int w = s[0]->w;
			int h = s[0]->h;

			for (int i = 0; i < 6; i++) {
				glTexImage2D(GL_TEXTURE_CUBE_MAP_POSITIVE_X + i, 0, nOfColors == 4 ? GL_RGBA : GL_RGB, w, h, 0, texture_format, GL_UNSIGNED_BYTE, s[i]->pixels);
				SDL_FreeSurface(s[i]);
			}
			// glTexImage2D(GL_TEXTURE_2D, 0, nOfColors == 4 ? GL_RGBA : GL_RGB, s->w, s->h, 0, texture_format, GL_UNSIGNED_BYTE, s->pixels);
		}
	}
};

/************************************************************************************
 ** PNG(greyscale) to noise data
 ************************************************************************************/
void noise_data::define(int32_t w, int32_t h) {
	this->w = w; this->h = h;
	data = new float[w * h];
	for (int32_t i = 0; i < w * h; i++) data[i] = 0;
}
void noise_data::set(SDL_Surface *s) {
	int nOfColors = s->format->BytesPerPixel;
	if (nOfColors != 1) printf("[LOADER] LoaderNoise ERROR, surface has %d colors\n", nOfColors);
	double tot = 0;
	for (int32_t i = 0; i < w * h; i++) {
		unsigned char b = ((unsigned char*)s->pixels)[i];
		tot += (float)b / (float)255.0;
	}
	float avg = tot / (w * h);
	for (int32_t i = 0; i < w * h; i++) {
		unsigned char b = ((unsigned char*)s->pixels)[i];
		data[i] = ((float)b / (float)255.0) - avg;
	}
}

class LoaderNoise : public Loader {
private:
	string filename;
	noise_data *noise;
	PHYSFS_file *file;
	SDL_Surface *s;
public:
	LoaderNoise(const char *filename, PHYSFS_file *file, noise_data *noise) : file(file), noise(noise), filename(filename) {};
	virtual ~LoaderNoise() { };
	virtual bool load() {
		s = IMG_Load_RW(PHYSFSRWOPS_makeRWops(file), TRUE);
		if (!s) printf("ERROR : LoaderNoise : %s\n",SDL_GetError());
		file = NULL;
		done();		
	}
	virtual bool finish() {
		if (s) {
			noise->set(s);
			SDL_FreeSurface(s);
			printf("[LOADER] done loading noise %s!\n", filename.c_str());
		}
	}
};

/************************************************************************************
 ** PNG to points list
 ************************************************************************************/
bool points_list::hasData() {
	if (finished) return true;
	if (lock.test_and_set()) return false;
	else {
		finished = true;
		lock.clear();
	}
	return false;
}

static glm::vec4 getpixel(SDL_Surface *surface, int x, int y)
{
	int bpp = surface->format->BytesPerPixel;
	/* Here p is the address to the pixel we want to retrieve */
	Uint8 *p = (Uint8 *)surface->pixels + y * surface->pitch + x * bpp;

	switch(bpp) {
	case 1:
		return glm::vec4((float)*p / 255.0, (float)*p / 255.0, (float)*p / 255.0, (float)*p / 255.0);
	case 2:
		return glm::vec4((float)p[0] / 255.0, (float)p[1] / 255.0, (float)p[1] / 255.0, (float)p[1] / 255.0);
	case 3:
		// if(SDL_BYTEORDER == SDL_BIG_ENDIAN)
		// 	return p[0] << 16 | p[1] << 8 | p[2];
		// else
		// 	return p[0] | p[1] << 8 | p[2] << 16;
	case 4:
		return glm::vec4((float)p[0] / 255.0, (float)p[1] / 255.0, (float)p[2] / 255.0, (float)p[3] / 255.0);
	default:
		return glm::vec4();       /* shouldn't happen, but avoids warnings */
	}
}

void points_list::set(SDL_Surface *s) {
	int nOfColors = s->format->BytesPerPixel;
	if (nOfColors != 4) printf("[LOADER] LoaderPointsList ERROR, surface has %d colors\n", nOfColors);
	
	for (int32_t j = 0; j < s->h; j++) {
		for (int32_t i = 0; i < s->w; i++) {
			glm::vec4 color = getpixel(s, i, j);
			// unsigned char r = ((unsigned char*)s->pixels)[j * s->w + i + 0];
			// unsigned char g = ((unsigned char*)s->pixels)[j * s->w + i + 1];
			// unsigned char b = ((unsigned char*)s->pixels)[j * s->w + i + 2];
			// unsigned char a = ((unsigned char*)s->pixels)[j * s->w + i + 3];
			// printf("tst point %dx%d : %0.2f,%0.2f,%0.2f,%0.2f\n", i,j,color.r,color.g,color.b,color.a);
			if (color.a > 0.7) list.emplace_back(glm::vec2(i-s->w/2, j-s->h/2), color);
		}
	}

	lock.clear();
}

class LoaderPointsList : public Loader {
private:
	string filename;
	points_list *list;
	PHYSFS_file *file;
	SDL_Surface *s;
public:
	LoaderPointsList(const char *filename, PHYSFS_file *file, points_list *list) : file(file), list(list), filename(filename) {};
	virtual ~LoaderPointsList() { };
	virtual bool load() {
		s = IMG_Load_RW(PHYSFSRWOPS_makeRWops(file), TRUE);
		if (!s) printf("ERROR : LoaderPointsList : %s\n",SDL_GetError());
		file = NULL;
		done();		
	}
	virtual bool finish() {
		if (s) {
			list->set(s);
			SDL_FreeSurface(s);
			printf("[LOADER] done loading points list %s (%d points)!\n", filename.c_str(), list->list.size());
		}
	}
};

/************************************************************************************
 ** Loader thread
 ************************************************************************************/
static int thread_loader(void *data) {
	while (true) {
		SDL_SemWait(loader_sem);

		SDL_mutexP(loader_mutex);
		Loader *l = loader_queue.front();
		loader_queue.pop();
		SDL_mutexV(loader_mutex);		
		l->load();
	}	
}

// Runs on main thread
static void create_loader_thread() {
	if (loader_thread) return;

	loader_mutex = SDL_CreateMutex();
	loader_sem = SDL_CreateSemaphore(0);

	loader_thread = SDL_CreateThread(thread_loader, "loader", NULL);
	if (loader_thread == NULL) {
		printf("Unable to create loader thread: %s\n", SDL_GetError());
		return;
	}

	printf("Created loader thread\n");
	return;
}

/**************************************************************************
 ** Lua code
 **************************************************************************/

static int lua_loader_palette(lua_State *L) {
	const char *filename = luaL_checkstring(L, 1);
	if (!PHYSFS_exists(filename)) return 0;

	// This is a bit fugly, we go and peek inside the fiel to know the size of the png
	int sw = 256;
	int sh = 1;

	texture_lua *t = new(L) texture_lua();
	glGenTextures(1, &t->texture_id);
	tfglBindTexture(GL_TEXTURE_2D, t->texture_id);
	t->w = sw;
	t->h = sh;
	t->no_free = false;

	// Paramétrage de la texture.
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);

	SDL_mutexP(loader_mutex);
	loader_queue.push(new LoaderPalette(filename, t->texture_id));
	loader_running++;
	SDL_mutexV(loader_mutex);
	SDL_SemPost(loader_sem);

	// if this is chagned remember to change the caching superload in utils.lua
	lua_pushnumber(L, sw);
	lua_pushnumber(L, sh);
	lua_pushnumber(L, 1);
	lua_pushnumber(L, 1);
	lua_pushnumber(L, sw);
	lua_pushnumber(L, sh);

	return 7;
}

#define MAKE_BYTE(b) ((b) & 0xFF)
#define MAKE_DWORD(a,b,c,d) ((MAKE_BYTE(a) << 24) | (MAKE_BYTE(b) << 16) | (MAKE_BYTE(c) << 8) | MAKE_BYTE(d))
#define MAKE_DWORD_PTR(p) MAKE_DWORD((p)[0], (p)[1], (p)[2], (p)[3])
static int lua_loader_png(lua_State *L) {
	const char *filename = luaL_checkstring(L, 1);
	bool nearest = lua_toboolean(L, 2);
	bool norepeat = lua_toboolean(L, 3);
	bool exact_size = lua_toboolean(L, 4);

	if (!PHYSFS_exists(filename)) return 0;

	// This is a bit fugly, we go and peek inside the fiel to know the size of the png
	unsigned char buffer[29];
	PHYSFS_file *file = PHYSFS_openRead(filename);
	PHYSFS_read(file, buffer, 1, 29);
	PHYSFS_seek(file, 0);
	int sw = MAKE_DWORD_PTR(buffer + 16);
	int sh = MAKE_DWORD_PTR(buffer + 20);

	texture_lua *t = new(L) texture_lua();
	glGenTextures(1, &t->texture_id);
	tfglBindTexture(GL_TEXTURE_2D, t->texture_id);
	t->w = sw;
	t->h = sh;
	t->no_free = false;

	// Paramétrage de la texture.
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, norepeat ? GL_CLAMP_TO_EDGE : GL_REPEAT);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, norepeat ? GL_CLAMP_TO_EDGE : GL_REPEAT);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
	if (nearest) glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);

	SDL_mutexP(loader_mutex);
	loader_queue.push(new LoaderPNG(filename, file, t->texture_id));
	loader_running++;
	SDL_mutexV(loader_mutex);
	SDL_SemPost(loader_sem);
	// LoaderPNG *l = new LoaderPNG(filename, file, t);
	// l->load();
	// l->finish();
	// delete l;

	// if this is chagned remember to change the caching superload in utils.lua
	lua_pushnumber(L, sw);
	lua_pushnumber(L, sh);
	lua_pushnumber(L, 1);
	lua_pushnumber(L, 1);
	lua_pushnumber(L, sw);
	lua_pushnumber(L, sh);

	return 7;
}

bool loader_png(const char *filename, texture_lua *t, bool nearest, bool norepeat, bool exact_size) {
	if (!PHYSFS_exists(filename)) return false;

	// This is a bit fugly, we go and peek inside the fiel to know the size of the png
	unsigned char buffer[29];
	PHYSFS_file *file = PHYSFS_openRead(filename);
	PHYSFS_read(file, buffer, 1, 29);
	PHYSFS_seek(file, 0);
	int sw = MAKE_DWORD_PTR(buffer + 16);
	int sh = MAKE_DWORD_PTR(buffer + 20);

	glGenTextures(1, &t->texture_id);
	printf("[LOADER] preparing texture %s => %d\n", filename, t->texture_id);
	tfglBindTexture(GL_TEXTURE_2D, t->texture_id);
	t->w = sw;
	t->h = sh;
	t->no_free = false;

	// Paramétrage de la texture.
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, norepeat ? GL_CLAMP_TO_EDGE : GL_REPEAT);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, norepeat ? GL_CLAMP_TO_EDGE : GL_REPEAT);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
	if (nearest) glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);

	SDL_mutexP(loader_mutex);
	loader_queue.push(new LoaderPNG(filename, file, t->texture_id));
	loader_running++;
	SDL_mutexV(loader_mutex);
	SDL_SemPost(loader_sem);
	return true;
}

static int lua_loader_cubemap_png(lua_State *L) {
	const char *filename = luaL_checkstring(L, 1);
	int scheme = lua_tonumber(L, 2);
	bool nearest = lua_toboolean(L, 3);
	bool norepeat = lua_toboolean(L, 4);

	string tmpname(filename);
	size_t pos = tmpname.find("%s");
	if (pos == string::npos) return 0;

	string prefix = tmpname.substr(0, pos);
	string postfix = tmpname.substr(pos + 2);


	array<string, 6> adds;
	if (scheme == 0) adds = {"right", "left", "up", "down", "back", "front"};
	else if (scheme == 1) adds = {"px", "nx", "py", "ny", "pz", "nz"};;
	array<string, 6> filenames;

	for (int i = 0; i < 6; i++) {
		filenames[i] = prefix + adds[i] + postfix;
		if (!PHYSFS_exists(filenames[i].c_str())) {
			printf("[LOADER] pngCubemap: %s does not exist!\n", filenames[i].c_str());
			return 0;
		}
	}

	array<PHYSFS_file*, 6> files;
	for (int i = 0; i < 6; i++) {
		files[i] = PHYSFS_openRead(filenames[i].c_str());
	}

	// This is a bit fugly, we go and peek inside the fiel to know the size of the png, we also assume their are all the same size
	unsigned char buffer[29];
	PHYSFS_read(files[0], buffer, 1, 29);
	PHYSFS_seek(files[0], 0);
	int sw = MAKE_DWORD_PTR(buffer + 16);
	int sh = MAKE_DWORD_PTR(buffer + 20);

	texture_lua *t = new(L) texture_lua();
	glGenTextures(1, &t->texture_id);
	tfglBindTexture(GL_TEXTURE_CUBE_MAP, t->texture_id);
	t->kind = TextureKind::CUBEMAP;
	t->w = sw;
	t->h = sh;
	t->no_free = false;

	// Paramétrage de la texture.
	glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_WRAP_S, norepeat ? GL_CLAMP_TO_EDGE : GL_REPEAT);
	glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_WRAP_T, norepeat ? GL_CLAMP_TO_EDGE : GL_REPEAT);
	glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_WRAP_T, norepeat ? GL_CLAMP_TO_EDGE : GL_REPEAT);
	glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
	if (nearest) glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_MAG_FILTER, GL_NEAREST);

	SDL_mutexP(loader_mutex);
	loader_queue.push(new LoaderPNGCubemap(filenames, files, t->texture_id));
	loader_running++;
	SDL_mutexV(loader_mutex);
	SDL_SemPost(loader_sem);

	return 1;
}

bool loader_noise(const char *filename, noise_data *noise) {
	if (!PHYSFS_exists(filename)) return false;

	// This is a bit fugly, we go and peek inside the fiel to know the size of the png
	unsigned char buffer[29];
	PHYSFS_file *file = PHYSFS_openRead(filename);
	PHYSFS_read(file, buffer, 1, 29);
	PHYSFS_seek(file, 0);
	int sw = MAKE_DWORD_PTR(buffer + 16);
	int sh = MAKE_DWORD_PTR(buffer + 20);

	noise->define(sw, sh);

	SDL_mutexP(loader_mutex);
	loader_queue.push(new LoaderNoise(filename, file, noise));
	loader_running++;
	SDL_mutexV(loader_mutex);
	SDL_SemPost(loader_sem);
	return true;
}

bool loader_points_list(const char *filename, points_list *list) {
	if (!PHYSFS_exists(filename)) return false;

	list->lock.test_and_set();
	PHYSFS_file *file = PHYSFS_openRead(filename);

	SDL_mutexP(loader_mutex);
	loader_queue.push(new LoaderPointsList(filename, file, list));
	loader_running++;
	SDL_mutexV(loader_mutex);
	SDL_SemPost(loader_sem);
	return true;
}

void loader_tick() {
	if (!loader_running) return;

	bool stop = false;
	while (!stop) {
		SDL_mutexP(loader_mutex);
		Loader *l = NULL;
		if (!loader_queue_done.empty()) {
			l = loader_queue_done.front();
			loader_queue_done.pop();
		} else {
			stop = true;
		}
		SDL_mutexV(loader_mutex);
		if (l) {
			l->finish();
			loader_running--;
			delete l;
		}
	}
	// printf("LOADER LEFT: %d\n", loader_running);
}

void core_loader_waitall() {
	while (loader_running) {
		loader_tick();
		if (loader_running) SDL_Delay(10);
	}
}

static int lua_loader_wait(lua_State *L) {
	core_loader_waitall();
	return 0;
}

static const struct luaL_Reg loaderlib[] = {
	{"palette", lua_loader_palette},
	{"png", lua_loader_png},
	{"pngCubemap", lua_loader_cubemap_png},
	{"waitAll", lua_loader_wait},
	{NULL, NULL},
};

int luaopen_loader(lua_State *L) {
	luaL_openlib(L, "core.loader", loaderlib, 0);

	lua_settop(L, 0);

	create_loader_thread();
	return 1;
}
