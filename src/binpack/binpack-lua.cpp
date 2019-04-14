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
#include "glm/glm.hpp"

using namespace std;
using namespace rbp;

enum class Padding : uint8_t {
	NONE = 0,
	ALPHA0 = 1,
	IMAGE = 2,
};

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
	Padding padding_mode = Padding::NONE;
	uint8_t padding_size = 0;

	spritesheet(uint32_t id, uint32_t max_w, uint32_t max_h, Padding mode, uint8_t size, bool verbose) : id(id), max_w(max_w), max_h(max_h), padding_mode(mode), padding_size(size), verbose(verbose) {
		bin.Init(w, h, false);
		if (verbose) printf("Initializing bin[%d] to size %dx%d with padding %s : %d.\n", id, w, h, (mode == Padding::NONE) ? "none" : (mode == Padding::ALPHA0) ? "alpha0" : (mode == Padding::IMAGE) ? "image" : "???", padding_size);
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
		int rectWidth = sprite->w;
		int rectHeight = sprite->h;

		if (padding_mode != Padding::NONE) {
			rectWidth += padding_size * 2;
			rectHeight += padding_size * 2;
		}

		if (verbose) printf("Bin[%d] Packing rectangle %s of size %dx%d:\n", id, sprite->filename.c_str(), rectWidth, rectHeight);

		// Perform the packing.
		MaxRectsBinPack::FreeRectChoiceHeuristic heuristic = MaxRectsBinPack::RectBestShortSideFit; // This can be changed individually even for each rectangle packed.
		Rect packedRect = bin.Insert(rectWidth, rectHeight, heuristic);

		// Test success or failure.
		if (packedRect.height > 0) {
			if (verbose) printf("  + Bin[%d] Packed to (x,y)=(%d,%d), (w,h)=(%d,%d). Free space left: %.2f%%\n", id, packedRect.x, packedRect.y, packedRect.width, packedRect.height, 100.f - bin.Occupancy()*100.f);
			sprite->x = packedRect.x + padding_size;
			sprite->y = packedRect.y + padding_size;
			if (padding_mode != Padding::NONE) {
				sprite->x += padding_size;
				sprite->y += padding_size;
			}
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

static void blit_surface(SDL_Surface *from, glm::ivec4 from_coords, SDL_Surface *to, glm::ivec4 to_coords) {
	SDL_Rect srcrect;
	srcrect.x = from_coords.x;
	srcrect.y = from_coords.y;
	srcrect.w = from_coords.z;
	srcrect.h = from_coords.w;

	SDL_Rect dstrect;
	dstrect.x = to_coords.x;
	dstrect.y = to_coords.y;
	dstrect.w = to_coords.z;
	dstrect.h = to_coords.w;

	if (from_coords.x == -1) {
		SDL_BlitSurface(from, NULL, to, &dstrect);
	} else {
		SDL_BlitSurface(from, &srcrect, to, &dstrect);
	}
}

static int generate_spritesheet(lua_State *L) {
	const char *spritesheet_name = luaL_checkstring(L, 1);
	uint32_t max_w = lua_tonumber(L, 2);
	uint32_t max_h = lua_tonumber(L, 3);
	bool verbose = lua_toboolean(L, 6);
	if (!max_w) max_w = 512;
	if (!max_h) max_h = 512;

	uint32_t padding_size = 0;
	Padding padding_mode = Padding::NONE;

	if (lua_istable(L, 5)) {
		lua_rawgeti(L, 5, 1);
		padding_mode = static_cast<Padding>((uint8_t)lua_tonumber(L, -1)); lua_pop(L, 1);
		lua_rawgeti(L, 5, 2);
		padding_size = lua_tonumber(L, -1); lua_pop(L, 1);
	}

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
	sheets.emplace_back(1, max_w, max_h, padding_mode, padding_size, verbose);

	for (auto sprite : sprites) {
		int sheet_id = 0;
		while (true) {
			if (sheets[sheet_id].insert(sprite)) break;
			sheet_id++;
			if (sheets.size() <= sheet_id) sheets.emplace_back(sheet_id + 1, max_w, max_h, padding_mode, padding_size, verbose);
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

			blit_surface(sprite->s, {-1,-1,-1,-1}, sheet_s, {sprite->x, sprite->y, sprite->w, sprite->h});

			if (padding_mode == Padding::IMAGE) {
				for (int i = 1; i <= padding_size; i++) {
					blit_surface(sprite->s, {0, 0, 1, sprite->h}, sheet_s, {sprite->x - i, sprite->y, 1, sprite->h});
					blit_surface(sprite->s, {sprite->w-2, 0, 1, sprite->h}, sheet_s, {sprite->x + sprite->w-1 + i, sprite->y, 1, sprite->h});

					blit_surface(sprite->s, {0, 0, sprite->w, 1}, sheet_s, {sprite->x, sprite->y - i, sprite->w, 1});
					blit_surface(sprite->s, {0, sprite->h-2, sprite->w, 1}, sheet_s, {sprite->x, sprite->y + sprite->h-1 + i, sprite->w, 1});

					for (int j = 1; j <= padding_size; j++) {
						blit_surface(sprite->s, {0, 0, 1, 1}, sheet_s, {sprite->x - i, sprite->y - j, 1, 1});
						blit_surface(sprite->s, {sprite->w-1, 0, 1, 1}, sheet_s, {sprite->x + sprite->w-1 + i, sprite->y - j, 1, 1});
						blit_surface(sprite->s, {0, sprite->h-1, 1, 1}, sheet_s, {sprite->x - i, sprite->y + sprite->h-1 + j, 1, 1});
						blit_surface(sprite->s, {sprite->w-1, sprite->h-1, 1, 1}, sheet_s, {sprite->x + sprite->w-1 + i, sprite->y + sprite->h-1 + j, 1, 1});
					}
				}
			}

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
	lua_pushliteral(L, "PADDING_NONE"); lua_pushnumber(L, static_cast<uint8_t>(Padding::NONE)); lua_rawset(L, -3);
	lua_pushliteral(L, "PADDING_ALPHA0"); lua_pushnumber(L, static_cast<uint8_t>(Padding::ALPHA0)); lua_rawset(L, -3);
	lua_pushliteral(L, "PADDING_IMAGE"); lua_pushnumber(L, static_cast<uint8_t>(Padding::IMAGE)); lua_rawset(L, -3);

	lua_settop(L, 0);
	return 1;
}
