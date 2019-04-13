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
#include "auxiliar.h"
#include "types.h"
#include "physfs.h"
#include "physfsrwops.h"
#include "main.h"
}

#include "MaxRectsBinPack.h"
#include <string>
#include <memory>
#include <vector>
#include <algorithm>

using namespace std;
using namespace rbp;

struct sprite_holder {
	string filename;
	SDL_Surface *s;
	uint32_t x, y;
	uint32_t w, h;

	sprite_holder(const char *fn, SDL_Surface *s) : filename(fn), s(s) {
		w = s->w;
		h = s->h;
	}
};
typedef shared_ptr<sprite_holder> sp_sprite_holder;
static bool sort_sprites(sp_sprite_holder &a, sp_sprite_holder &b) {
	return a->w * a->h > b->w * b->h;
}


struct spritesheet {
	uint32_t id;
	bool verbose = false;
	uint32_t max_w, max_h;
	uint32_t w = 256, h = 256;
	bool last_grow_dir = true;
	MaxRectsBinPack bin;
	vector<sp_sprite_holder> sprites;

	spritesheet(uint32_t id, uint32_t max_w, uint32_t max_h, bool verbose) : id(id), max_w(max_w), max_h(max_h), verbose(verbose) {
		bin.Init(w, h, false);
		if (verbose) printf("Initializing bin[%d] to size %dx%d.\n", id, w, h);
	}

	bool grow() {
		if ((w <= max_w / 2) && (h <= max_h / 2)) {
			if (last_grow_dir) w = w * 2;
			else h = h * 2;
			last_grow_dir = !last_grow_dir;
		} else if ((w > max_w / 2) && (h <= max_h / 2)) {
			h = h * 2;
		} else if ((w <= max_w / 2) && (h > max_h / 2)) {
			w = w * 2;
		} else {
			return false;
		}

		bin.Init(w, h, false);
		if (verbose) printf("******************** Growing bin[%d] to size %dx%d **********************\n", id, w, h);
		for (auto sprite : sprites) insert(sprite, true); // No need to check if we can pack; the sheet is bigger we can always pack

		return true;
	}

	bool insert(sp_sprite_holder sprite, bool no_add=false) {
		// Read next rectangle to pack.
		int rectWidth = sprite->w + 2;
		int rectHeight = sprite->h + 2;
		if (verbose) printf("Bin[%d] Packing rectangle %s of size %dx%d:\n", id, sprite->filename.c_str(), rectWidth, rectHeight);

		// Perform the packing.
		MaxRectsBinPack::FreeRectChoiceHeuristic heuristic = MaxRectsBinPack::RectBestShortSideFit; // This can be changed individually even for each rectangle packed.
		Rect packedRect = bin.Insert(rectWidth, rectHeight, heuristic);

		// Test success or failure.
		if (packedRect.height > 0) {
			if (verbose) printf("  + Bin[%d] Packed to (x,y)=(%d,%d), (w,h)=(%d,%d). Free space left: %.2f%%\n", id, packedRect.x, packedRect.y, packedRect.width, packedRect.height, 100.f - bin.Occupancy()*100.f);
			sprite->x = packedRect.x + 1;
			sprite->y = packedRect.y + 1;
			if (!no_add) sprites.push_back(sprite);
			return true;
		} else {
			if (grow()) {
				return insert(sprite);
			} else {
				if (verbose) printf("  - Bin[%d] Failed! Could not find a proper position to pack this rectangle into. Skipping this one.\n", id);
				return false;
			}
		}
	}
};

static int generate_spritesheet(lua_State *L) {
	const char *spritesheet_name = luaL_checkstring(L, 1);
	uint32_t max_w = lua_tonumber(L, 2);
	uint32_t max_h = lua_tonumber(L, 3);
	bool verbose = lua_toboolean(L, 5);
	if (!max_w) max_w = 512;
	if (!max_h) max_h = 512;


	Uint32 rmask, gmask, bmask, amask;
	/* SDL interprets each pixel as a 32-bit number, so our masks must depend on the endianness (byte order) of the machine */
#if SDL_BYTEORDER == SDL_BIG_ENDIAN
	rmask = 0xff000000;
	gmask = 0x00ff0000;
	bmask = 0x0000ff00;
	amask = 0x000000ff;
#else
	rmask = 0x000000ff;
	gmask = 0x0000ff00;
	bmask = 0x00ff0000;
	amask = 0xff000000;
#endif

	MaxRectsBinPack bin;

	vector<sp_sprite_holder> sprites;

	lua_pushnil(L);
	while (lua_next(L, 4) != 0) {
		const char *filename = luaL_checkstring(L, -1);

		if (verbose) printf("*** Loading file %s\n", filename);

		PHYSFS_file *file = PHYSFS_openRead(filename);
		SDL_Surface *s = IMG_Load_RW(PHYSFSRWOPS_makeRWops(file), TRUE);
		sprites.emplace_back(new sprite_holder(filename, s));

		lua_pop(L, 1);
	}
	std::sort(sprites.begin(), sprites.end(), sort_sprites);

	vector<spritesheet> sheets;
	sheets.emplace_back(1, max_w, max_h, verbose);

	for (auto sprite : sprites) {
		int sheet_id = 0;
		while (true) {
			if (sheets[sheet_id].insert(sprite)) break;
			sheet_id++;
			if (sheets.size() <= sheet_id) sheets.emplace_back(sheet_id + 1, max_w, max_h, verbose);
		}
	}
	if (verbose) printf("Done. All rectangles packed.\n");

	uint32_t biggest_w = 0, biggest_h = 0;
	for (auto& sheet : sheets) {
		if (sheet.w > biggest_w) biggest_w = sheet.w;
		if (sheet.h > biggest_h) biggest_h = sheet.h;
	}

	lua_newtable(L);
	lua_newtable(L);
	lua_pushnumber(L, biggest_w); lua_setfield(L, -3, "__width");
	lua_pushnumber(L, biggest_h); lua_setfield(L, -3, "__height");
	for (auto& sheet : sheets) {
		if (verbose) printf("************* IN SHEET %d [%dx%d]\n", sheet.id, sheet.w, sheet.h);

		SDL_Surface *sheet_s = SDL_CreateRGBSurface(0, sheet.w, sheet.h, 32, rmask, gmask, bmask, amask);

		for (auto sprite : sheet.sprites) {
			// if (verbose) printf(" - %s : %dx%d [%dx%d]\n", sprite.filename.c_str(), sprite.x, sprite.y, sprite.w, sprite.h);
			lua_newtable(L);

			lua_pushnumber(L, (float)sprite->x / (float)sheet.w); lua_setfield(L, -2, "x");
			lua_pushnumber(L, (float)sprite->y / (float)sheet.h); lua_setfield(L, -2, "y");
			lua_pushnumber(L, (float)sprite->w / (float)sheet.w); lua_setfield(L, -2, "factorx");
			lua_pushnumber(L, (float)sprite->h / (float)sheet.h); lua_setfield(L, -2, "factory");
			lua_pushnumber(L, sprite->w); lua_setfield(L, -2, "w");
			lua_pushnumber(L, sprite->h); lua_setfield(L, -2, "h");
			lua_pushstring(L, "/data/gfx/"); lua_pushstring(L, spritesheet_name); lua_pushnumber(L, sheet.id); lua_pushstring(L, ".png"); lua_concat(L, 4); lua_setfield(L, -2, "set");

			lua_setfield(L, -3, sprite->filename.c_str());

			SDL_Rect dstrect;
			dstrect.x = sprite->x;
			dstrect.y = sprite->y;
			dstrect.w = sprite->w;
			dstrect.h = sprite->h;
			SDL_BlitSurface(sprite->s, NULL, sheet_s, &dstrect);

			// Cleanup
			SDL_FreeSurface(sprite->s);
		}

		lua_pushstring(L, "/data/gfx/"); lua_pushstring(L, spritesheet_name); lua_pushnumber(L, sheet.id); lua_pushstring(L, ".png"); lua_concat(L, 4);
		SDL_Surface **s = (SDL_Surface**)lua_newuserdata(L, sizeof(SDL_Surface*));
		auxiliar_setclass(L, "sdl{surface}", -1);
		*s = sheet_s;
		lua_rawset(L, -3);
	}

	return 2;
}

static const struct luaL_Reg plib[] = {
	{"generateSpritesheet", generate_spritesheet},
	{NULL, NULL},
};

extern "C" int luaopen_binpack(lua_State *L) {
	luaL_openlib(L, "core.binpack", plib, 0);

	lua_settop(L, 0);
	return 1;
}
