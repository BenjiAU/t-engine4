/*
    TE4 - T-Engine 4
    Copyright (C) 2009 - 2016 Nicolas Casalini

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
#include <math.h>
#include "lauxlib.h"
#include "lualib.h"
#include "auxiliar.h"
#include "map.h"
#include "main.h"
#include "script.h"
#include "useshader.h"
#include "assert.h"
}

#include "map.hpp"
#include "renderer-moderngl/TileMap.hpp"

static const char IS_HEX_KEY = 'k';

/*
static int lua_set_is_hex(lua_State *L)
{
	int val = luaL_checknumber(L, 1);
	lua_pushlightuserdata(L, (void *)&IS_HEX_KEY); // push address as guaranteed unique key
	lua_pushnumber(L, val);
	lua_settable(L, LUA_REGISTRYINDEX);
	return 0;
}
*/

static int lua_is_hex(lua_State *L)
{
	lua_checkstack(L, 4);
	lua_pushlightuserdata(L, (void *)&IS_HEX_KEY); // push address as guaranteed unique key
	lua_gettable(L, LUA_REGISTRYINDEX);  /* retrieve value */
	if (lua_isnil(L, -1)) {
		lua_pop(L, 1); // remove nil
		lua_pushlightuserdata(L, (void *)&IS_HEX_KEY); // push address as guaranteed unique key
		lua_pushnumber(L, 0);
		lua_settable(L, LUA_REGISTRYINDEX);
		lua_pushnumber(L, 0);
	}
	return 1;
}

static int map_object_new(lua_State *L)
{
	long uid = luaL_checknumber(L, 1);
	int nb_textures = luaL_checknumber(L, 2);
	int i;

	map_object *obj = (map_object*)lua_newuserdata(L, sizeof(map_object));
	memset(obj, 0, sizeof(map_object));
	auxiliar_setclass(L, "core{mapobj}", -1);
	obj->textures = (GLuint*)calloc(nb_textures, sizeof(GLuint));
	obj->tex_x = (GLfloat*)calloc(nb_textures, sizeof(GLfloat));
	obj->tex_y = (GLfloat*)calloc(nb_textures, sizeof(GLfloat));
	obj->tex_factorx = (GLfloat*)calloc(nb_textures, sizeof(GLfloat));
	obj->tex_factory = (GLfloat*)calloc(nb_textures, sizeof(GLfloat));
	obj->textures_ref = (int*)calloc(nb_textures, sizeof(int));
	obj->textures_is3d = (bool*)calloc(nb_textures, sizeof(bool));
	obj->nb_textures = nb_textures;
	obj->uid = uid;

	obj->on_seen = lua_toboolean(L, 3);
	obj->on_remember = lua_toboolean(L, 4);
	obj->on_unknown = lua_toboolean(L, 5);

	obj->move_max = 0;
	obj->anim_max = 0;
	obj->flip_x = obj->flip_y = false;

	obj->cb_ref = LUA_NOREF;

	obj->mm_r = -1;
	obj->mm_g = -1;
	obj->mm_b = -1;

	obj->valid = true;
	obj->world_x = obj->world_y = 0;
	obj->dx = luaL_checknumber(L, 6);
	obj->dy = luaL_checknumber(L, 7);
	obj->dw = luaL_checknumber(L, 8);
	obj->dh = luaL_checknumber(L, 9);
	obj->scale = luaL_checknumber(L, 10);
	obj->shader = NULL;
	obj->shader_ref = LUA_NOREF;
	obj->tint_r = obj->tint_g = obj->tint_b = 1;
	for (i = 0; i < nb_textures; i++)
	{
		obj->textures[i] = 0;
		obj->textures_is3d[i] = false;
		obj->textures_ref[i] = LUA_NOREF;
	}

	obj->next = NULL;

	return 1;
}

static int map_object_free(lua_State *L)
{
	map_object *obj = (map_object*)auxiliar_checkclass(L, "core{mapobj}", 1);
	int i;

	for (i = 0; i < obj->nb_textures; i++) {
		if (obj->textures_ref[i] != LUA_NOREF)
			luaL_unref(L, LUA_REGISTRYINDEX, obj->textures_ref[i]);
	}

	free(obj->textures);
	free(obj->tex_x);
	free(obj->tex_y);
	free(obj->tex_factorx);
	free(obj->tex_factory);
	free(obj->textures_ref);
	free(obj->textures_is3d);

	if (obj->next)
	{
		luaL_unref(L, LUA_REGISTRYINDEX, obj->next_ref);
		obj->next = NULL;
	}

	if (obj->cb_ref != LUA_NOREF)
	{
		luaL_unref(L, LUA_REGISTRYINDEX, obj->cb_ref);
		obj->cb_ref = LUA_NOREF;
	}

	if (obj->shader_ref != LUA_NOREF) {
		luaL_unref(L, LUA_REGISTRYINDEX, obj->shader_ref);
		obj->shader_ref = LUA_NOREF;
	}

	lua_pushnumber(L, 1);
	return 1;
}

static int map_object_cb(lua_State *L)
{
	map_object *obj = (map_object*)auxiliar_checkclass(L, "core{mapobj}", 1);
	if (obj->cb_ref != LUA_NOREF) luaL_unref(L, LUA_REGISTRYINDEX, obj->cb_ref);
	if (lua_isfunction(L, 2)) obj->cb_ref = luaL_ref(L, LUA_REGISTRYINDEX);
	else obj->cb_ref = LUA_NOREF;
	return 0;
}

static int map_object_chain(lua_State *L)
{
	map_object *obj = (map_object*)auxiliar_checkclass(L, "core{mapobj}", 1);
	map_object *obj2 = (map_object*)auxiliar_checkclass(L, "core{mapobj}", 2);
	if (obj->next) return 0;
	obj->next = obj2;
	lua_pushvalue(L, 2);
	obj->next_ref = luaL_ref(L, LUA_REGISTRYINDEX);
	return 0;
}

static int map_object_on_seen(lua_State *L)
{
	map_object *obj = (map_object*)auxiliar_checkclass(L, "core{mapobj}", 1);
	if (lua_isboolean(L, 2))
	{
		obj->on_seen = lua_toboolean(L, 2);
	}
	lua_pushboolean(L, obj->on_seen);
	return 1;
}

static int map_object_texture(lua_State *L)
{
	map_object *obj = (map_object*)auxiliar_checkclass(L, "core{mapobj}", 1);
	int i = luaL_checknumber(L, 2);
	texture_type *t = (texture_type*)auxiliar_checkclass(L, "gl{texture}", 3);
	bool is3d = lua_toboolean(L, 4);
	if (i < 0 || i >= obj->nb_textures) return 0;

	if (obj->textures_ref[i] != LUA_NOREF) luaL_unref(L, LUA_REGISTRYINDEX, obj->textures_ref[i]);

	lua_pushvalue(L, 3); // Get the texture
	obj->textures_ref[i] = luaL_ref(L, LUA_REGISTRYINDEX); // Ref the texture
//	printf("C Map Object setting texture %d = %d (ref %x)\n", i, *t, obj->textures_ref[i]);
	obj->textures[i] = t->tex;
	obj->textures_is3d[i] = is3d;
	obj->tex_factorx[i] = lua_tonumber(L, 5);
	obj->tex_factory[i] = lua_tonumber(L, 6);
	if (lua_isnumber(L, 7))
	{
		obj->tex_x[i] = lua_tonumber(L, 7);
		obj->tex_y[i] = lua_tonumber(L, 8);
	}
	else
	{
		obj->tex_x[i] = 0;
		obj->tex_y[i] = 0;
	}
	return 0;
}

static int map_object_shader(lua_State *L)
{
	map_object *obj = (map_object*)auxiliar_checkclass(L, "core{mapobj}", 1);
	if (!lua_isnil(L, 2)) {
		shader_type *s = (shader_type*)lua_touserdata(L, 2);
		obj->shader = s;
		lua_pushvalue(L, 2);
		obj->shader_ref = luaL_ref(L, LUA_REGISTRYINDEX);
	} else {
		luaL_unref(L, LUA_REGISTRYINDEX, obj->shader_ref);
		obj->shader_ref = LUA_NOREF;
		obj->shader = NULL;
	}
	return 0;
}

static int map_object_tint(lua_State *L)
{
	map_object *obj = (map_object*)auxiliar_checkclass(L, "core{mapobj}", 1);
	float r = luaL_checknumber(L, 2);
	float g = luaL_checknumber(L, 3);
	float b = luaL_checknumber(L, 4);
	obj->tint_r = r;
	obj->tint_g = g;
	obj->tint_b = b;
	return 0;
}

static int map_object_minimap(lua_State *L)
{
	map_object *obj = (map_object*)auxiliar_checkclass(L, "core{mapobj}", 1);
	float r = luaL_checknumber(L, 2);
	float g = luaL_checknumber(L, 3);
	float b = luaL_checknumber(L, 4);
	obj->mm_r = r / 255;
	obj->mm_g = g / 255;
	obj->mm_b = b / 255;
	return 0;
}

static int map_object_flip_x(lua_State *L)
{
	map_object *obj = (map_object*)auxiliar_checkclass(L, "core{mapobj}", 1);
	obj->flip_x = lua_toboolean(L, 2);

	// Invalidate layers upon which we exist, so that the animation can actually play
	if (lua_isuserdata(L, 3) && lua_istable(L, 4)) {
		map_type *map = (map_type*)auxiliar_checkclass(L, "core{map}", 3);
		lua_pushnil(L);
		while (lua_next(L, 4) != 0) {
			int z = lua_tonumber(L, -1) - 1;
			z = (z < 0) ? 0 : ((z >= map->zdepth) ? map->zdepth : z);
			map->z_changed[z] = true;
			lua_pop(L, 1);
		}		
	}
	return 0;
}

static int map_object_flip_y(lua_State *L)
{
	map_object *obj = (map_object*)auxiliar_checkclass(L, "core{mapobj}", 1);
	obj->flip_y = lua_toboolean(L, 2);

	// Invalidate layers upon which we exist, so that the animation can actually play
	if (lua_isuserdata(L, 3) && lua_istable(L, 4)) {
		map_type *map = (map_type*)auxiliar_checkclass(L, "core{map}", 3);
		lua_pushnil(L);
		while (lua_next(L, 4) != 0) {
			int z = lua_tonumber(L, -1) - 1;
			z = (z < 0) ? 0 : ((z >= map->zdepth) ? map->zdepth : z);
			map->z_changed[z] = true;
			lua_pop(L, 1);
		}		
	}
	return 0;
}

static int map_object_print(lua_State *L)
{
	map_object *obj = (map_object*)auxiliar_checkclass(L, "core{mapobj}", 1);
	printf("Map object texture 0: %d\n", obj->textures[0]);
	return 0;
}

static int map_object_invalid(lua_State *L)
{
	map_object *obj = (map_object*)auxiliar_checkclass(L, "core{mapobj}", 1);
	obj->valid = false;
	return 0;
}


static int map_object_set_anim(lua_State *L)
{
	map_object *obj = (map_object*)auxiliar_checkclass(L, "core{mapobj}", 1);

	obj->anim_step = luaL_checknumber(L, 2);
	obj->anim_max = luaL_checknumber(L, 3);
	obj->anim_speed = luaL_checknumber(L, 4);
	obj->anim_loop = luaL_checknumber(L, 5);
	return 0;
}

static int map_object_reset_move_anim(lua_State *L)
{
	map_object *obj = (map_object*)auxiliar_checkclass(L, "core{mapobj}", 1);
	obj->move_max = 0;
	obj->animdx = obj->animdy = 0;

	// Invalidate layers upon which we exist, so that the animation can actually play
	if (lua_isuserdata(L, 2) && lua_istable(L, 3)) {
		map_type *map = (map_type*)auxiliar_checkclass(L, "core{map}", 2);
		lua_pushnil(L);
		while (lua_next(L, 3) != 0) {
			int z = lua_tonumber(L, -1) - 1;
			z = (z < 0) ? 0 : ((z >= map->zdepth) ? map->zdepth : z);
			map->z_changed[z] = true;
			lua_pop(L, 1);
		}		
	}
	return 0;
}

static int map_object_set_move_anim(lua_State *L)
{
	map_object *obj = (map_object*)auxiliar_checkclass(L, "core{mapobj}", 1);

	lua_is_hex(L);
	int is_hex = luaL_checknumber(L, -1);

	// If at rest use starting point
	if (!obj->move_max)
	{
		int ox = luaL_checknumber(L, 2);
		int oy = luaL_checknumber(L, 3);
		obj->oldx = ox;
		obj->oldy = oy + 0.5f*(ox & is_hex);
	}
	// If already moving, compute starting point
	else
	{
		int ox = luaL_checknumber(L, 2);
		int oy = luaL_checknumber(L, 3);
		obj->oldx = obj->animdx + ox;
		obj->oldy = obj->animdy + oy + 0.5f*(ox & is_hex);
	}
	obj->move_step = 0;
	obj->move_max = luaL_checknumber(L, 6);
	obj->move_blur = lua_tonumber(L, 7); // defaults to 0
	obj->move_twitch_dir = lua_tonumber(L, 8); // defaults to 0 (which is equivalent to up or 8)
	obj->move_twitch = lua_tonumber(L, 9); // defaults to 0
	// obj->animdx = obj->animdx - ((float)obj->cur_x - obj->oldx);
	// obj->animdy = obj->animdy - ((float)obj->cur_y - obj->oldy);

	// Invalidate layers upon which we exist, so that the animation can actually play
	if (lua_isuserdata(L, 10) && lua_istable(L, 11)) {
		map_type *map = (map_type*)auxiliar_checkclass(L, "core{map}", 10);
		lua_pushnil(L);
		while (lua_next(L, 11) != 0) {
			int z = lua_tonumber(L, -1) - 1;
			z = (z < 0) ? 0 : ((z >= map->zdepth) ? map->zdepth : z);
			map->z_changed[z] = true;
			lua_pop(L, 1);
		}		
	}
	
	return 0;
}

static int map_object_get_move_anim(lua_State *L)
{
	map_object *obj = (map_object*)auxiliar_checkclass(L, "core{mapobj}", 1);
	map_type *map = (map_type*)auxiliar_checkclass(L, "core{map}", 2);
	int i = luaL_checknumber(L, 3);
	int j = luaL_checknumber(L, 4);

	float mapdx = 0, mapdy = 0;
	if (map->move_max)
	{
		float adx = (float)map->mx - map->oldmx;
		float ady = (float)map->my - map->oldmy;
		mapdx = -(adx * map->move_step / (float)map->move_max - adx);
		mapdy = -(ady * map->move_step / (float)map->move_max - ady);
	}

	if (!obj->move_max) // || obj->display_last == DL_NONE)
	{
//		printf("==== GET %f x %f\n", mapdx, mapdy);
		lua_pushnumber(L, mapdx);
		lua_pushnumber(L, mapdy);
	}
	else
	{
//		printf("==== GET %f x %f :: %f x %f\n", mapdx, mapdy,obj->animdx,obj->animdy);
		lua_pushnumber(L, mapdx + obj->animdx);
		lua_pushnumber(L, mapdy + obj->animdy);
	}
	return 2;
}

static int map_object_get_world_pos(lua_State *L)
{
	map_object *obj = (map_object*)auxiliar_checkclass(L, "core{mapobj}", 1);
	lua_pushnumber(L, obj->world_x);
	lua_pushnumber(L, obj->world_y);
	return 2;
}

static int map_object_is_valid(lua_State *L)
{
	map_object *obj = (map_object*)auxiliar_checkclass(L, "core{mapobj}", 1);
	lua_pushboolean(L, obj->valid);
	return 1;
}

static int map_objects_to_displayobject(lua_State *L)
{
	int w = luaL_checknumber(L, 1);
	int h = luaL_checknumber(L, 2);
	float a = (lua_isnumber(L, 3) ? lua_tonumber(L, 3) : 1);
	bool allow_cb = true;
	bool allow_shader = true;
	if (lua_isboolean(L, 4)) allow_cb = lua_toboolean(L, 4);
	if (lua_isboolean(L, 5)) allow_shader = lua_toboolean(L, 5);

	DORTileObject *to = new DORTileObject(w, h, a, allow_cb, allow_shader);
	to->setLuaState(L);

	int moid = 6;
	while (lua_isuserdata(L, moid))
	{
		map_object *m = (map_object*)auxiliar_checkclass(L, "core{mapobj}", moid);
		lua_pushvalue(L, -1);
		int ref = luaL_ref(L, LUA_REGISTRYINDEX);

		to->addMapObject(m, ref);
		moid++;
	}

	DisplayObject **v = (DisplayObject**)lua_newuserdata(L, sizeof(DisplayObject*));
	*v = to;
	auxiliar_setclass(L, "gl{tileobject}", -1);
	return 1;
}

static void setup_seens_texture(map_type *map)
{
	if (map->seens_texture) glDeleteTextures(1, &(map->seens_texture));
	if (map->seens_map) free(map->seens_map);

	int f = (map->is_hex & 1);
	int realw=1;
	while (realw < f + (1+f)*(map->w+10)) realw *= 2;
	int realh=1;
	while (realh < f + (1+f)*(map->h+10)) realh *= 2;
	map->seens_map_w = realw;
	map->seens_map_h = realh;

	glGenTextures(1, &(map->seens_texture));
	printf("C Map seens texture: %d (%dx%d)\n", map->seens_texture, map->w+10, map->h+10);
	tglBindTexture(GL_TEXTURE_2D, map->seens_texture);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
	glTexImage2D(GL_TEXTURE_2D, 0, 4, map->seens_map_w, map->seens_map_h, 0, GL_BGRA, GL_UNSIGNED_BYTE, NULL);
	map->seens_map = (GLubyte*)calloc((map->seens_map_w)*(map->seens_map_h)*4, sizeof(GLubyte));
	map->seen_changed = true;

	// Black it all
	int i;
	for (i = 0; i < map->seens_map_w * map->seens_map_h; i++)
	{
		map->seens_map[(i*4)] = 0;
		map->seens_map[(i*4)+1] = 0;
		map->seens_map[(i*4)+2] = 0;
		map->seens_map[(i*4)+3] = 255;
	}
}

#define QUADS_PER_BATCH 5000

static int map_new(lua_State *L)
{
	int w = luaL_checknumber(L, 1);
	int h = luaL_checknumber(L, 2);
	int mx = luaL_checknumber(L, 3);
	int my = luaL_checknumber(L, 4);
	int mwidth = luaL_checknumber(L, 5);
	int mheight = luaL_checknumber(L, 6);
	int tile_w = luaL_checknumber(L, 7);
	int tile_h = luaL_checknumber(L, 8);
	int zdepth = luaL_checknumber(L, 9);
	int is_hex = luaL_checknumber(L, 10);
	int i, j;

	map_type *map = (map_type*)lua_newuserdata(L, sizeof(map_type));
	auxiliar_setclass(L, "core{map}", -1);

	map->obscure_r = map->obscure_g = map->obscure_b = 0.6f;
	map->obscure_a = 1;
	map->shown_r = map->shown_g = map->shown_b = 1;
	map->shown_a = 1;

	map->default_shader = NULL;

	map->minimap = NULL;
	map->mm_texture = 0;
	map->mm_w = map->mm_h = 0;

	map->minimap_gridsize = 4;

	map->is_hex = (is_hex > 0);
	lua_pushlightuserdata(L, (void *)&IS_HEX_KEY); // push address as guaranteed unique key
	lua_pushnumber(L, map->is_hex);
	lua_settable(L, LUA_REGISTRYINDEX);

	map->vertices = (GLfloat*)calloc(2*6*QUADS_PER_BATCH, sizeof(GLfloat)); // 2 coords, 4 vertices per particles
	map->colors = (GLfloat*)calloc(4*6*QUADS_PER_BATCH, sizeof(GLfloat)); // 4 color data, 4 vertices per particles
	map->texcoords = (GLfloat*)calloc(4*6*QUADS_PER_BATCH, sizeof(GLfloat));

	map->displayed_x = map->displayed_y = 0;
	map->w = w;
	map->h = h;
	map->zdepth = zdepth;
	map->tile_w = tile_w;
	map->tile_h = tile_h;
	map->move_max = 0;

	// Compute line grids array for fast drawing
	map->nb_grid_lines_vertices = 0;
	map->grid_lines_vertices = NULL;
	map->grid_lines_textures = NULL;
	map->grid_lines_colors = NULL;

	// Make up the map objects list, thus we can iterate them later
	lua_newtable(L);
	map->mo_list_ref = luaL_ref(L, LUA_REGISTRYINDEX); // Ref the table

	// In case we can't support NPOT textures round up to nearest POT
	for (i = 1; i <= 3; i++)
	{
		int tw = tile_w * i;
		int realw=1;
		while (realw < tw) realw *= 2;
		map->tex_tile_w[i-1] = (GLfloat)tw / realw;

		int th = tile_h * i;
		int realh=1;
		while (realh < th) realh *= 2;
		map->tex_tile_h[i-1] = (GLfloat)th / realh;
	}

	map->mx = mx;
	map->my = my;
	map->mwidth = mwidth;
	map->mheight = mheight;
	map->grids = (map_object****)calloc(w, sizeof(map_object***));
	map->grids_ref = (int***)calloc(w, sizeof(int**));
	map->grids_seens = (float*)calloc(w * h, sizeof(float));
	map->grids_remembers = (bool**)calloc(w, sizeof(bool*));
	map->grids_lites = (bool**)calloc(w, sizeof(bool*));
	map->grids_important = (bool**)calloc(w, sizeof(bool*));
	printf("C Map size %d:%d :: %d\n", mwidth, mheight,mwidth * mheight);

	map->seens_texture = 0;
	map->seens_map = NULL;
	setup_seens_texture(map);

	for (i = 0; i < w; i++)
	{
		map->grids[i] = (map_object***)calloc(h, sizeof(map_object**));
		map->grids_ref[i] = (int**)calloc(h, sizeof(int*));
//		map->grids_seens[i] = calloc(h, sizeof(float));
		map->grids_remembers[i] = (bool*)calloc(h, sizeof(bool));
		map->grids_lites[i] = (bool*)calloc(h, sizeof(bool));
		map->grids_important[i] = (bool*)calloc(h, sizeof(bool));
		for (j = 0; j < h; j++)
		{
			map->grids[i][j] = (map_object**)calloc(zdepth, sizeof(map_object*));
			map->grids_ref[i][j] = (int*)calloc(zdepth, sizeof(int));
			map->grids_important[i][j] = false;
		}
	}

	map->z_callbacks = (int*)calloc(zdepth, sizeof(int));
	for (i = 0; i < zdepth; i++) map->z_callbacks[i] = LUA_NOREF;

	map->z_changed = (bool*)calloc(zdepth, sizeof(bool));
	for (i = 0; i < zdepth; i++) map->z_changed[i] = true;

	map->z_renderers = (RendererGL**)calloc(zdepth, sizeof(RendererGL*));
	for (i = 0; i < zdepth; i++) {
		map->z_renderers[i] = new RendererGL();
		char *name = (char*)calloc(20, sizeof(char));
		sprintf(name, "map-layer-%d", i);
		map->z_renderers[i]->setRendererName(name, false);
		map->z_renderers[i]->setManualManagement(true);
	}

	return 1;
}

static int map_free(lua_State *L)
{
	map_type *map = (map_type*)auxiliar_checkclass(L, "core{map}", 1);
	int i, j;

	for (i = 0; i < map->w; i++)
	{
		for (j = 0; j < map->h; j++)
		{
			free(map->grids[i][j]);
			free(map->grids_ref[i][j]);
		}
		free(map->grids[i]);
		free(map->grids_ref[i]);
//		free(map->grids_seens[i]);
		free(map->grids_remembers[i]);
		free(map->grids_lites[i]);
		free(map->grids_important[i]);
	}
	free(map->grids);
	free(map->grids_ref);
	free(map->grids_seens);
	free(map->grids_remembers);
	free(map->grids_lites);
	free(map->grids_important);

	for (i = 0; i < map->zdepth; i++) {
		if (map->z_callbacks[i] != LUA_NOREF) luaL_unref(L, LUA_REGISTRYINDEX, map->z_callbacks[i]);
		delete map->z_renderers[i];
	}
	free(map->z_callbacks);
	free(map->z_changed);
	free(map->z_renderers);

	free(map->colors);
	free(map->texcoords);
	free(map->vertices);

	if (map->grid_lines_vertices) free(map->grid_lines_vertices);
	if (map->grid_lines_colors) free(map->grid_lines_colors);
	if (map->grid_lines_textures) free(map->grid_lines_textures);

	luaL_unref(L, LUA_REGISTRYINDEX, map->mo_list_ref);

	glDeleteTextures(1, &map->seens_texture);
	free(map->seens_map);

	if (map->minimap) free(map->minimap);
	if (map->mm_texture) glDeleteTextures(1, &map->mm_texture);

	lua_pushnumber(L, 1);
	return 1;
}

static int map_define_grid_lines(lua_State *L) {
	map_type *map = (map_type*)auxiliar_checkclass(L, "core{map}", 1);
	int size = luaL_checknumber(L, 2);
	if (!size) {
		if (map->grid_lines_vertices) free(map->grid_lines_vertices);
		if (map->grid_lines_colors) free(map->grid_lines_colors);
		if (map->grid_lines_textures) free(map->grid_lines_textures);
		map->grid_lines_vertices = NULL;
		map->grid_lines_colors = NULL;
		map->grid_lines_textures = NULL;
		map->nb_grid_lines_vertices = 0;
		return 0;
	}

	float r = luaL_checknumber(L, 3);
	float g = luaL_checknumber(L, 4);
	float b = luaL_checknumber(L, 5);
	float a = luaL_checknumber(L, 6);

	if (map->grid_lines_vertices) free(map->grid_lines_vertices);
	if (map->grid_lines_colors) free(map->grid_lines_colors);
	if (map->grid_lines_textures) free(map->grid_lines_textures);

	int mwidth = map->mwidth;
	int mheight = map->mheight;
	int tile_w = map->tile_w;
	int tile_h = map->tile_h;
	int grid_w = 1 + mwidth;
	int grid_h = 1 + mheight;
	map->nb_grid_lines_vertices = grid_w + grid_h;
	map->grid_lines_vertices = (GLfloat*)calloc(2 * 4 * map->nb_grid_lines_vertices, sizeof(GLfloat)); // 4 coords per lines
	map->grid_lines_textures = (GLfloat*)calloc(2 * 4 * map->nb_grid_lines_vertices, sizeof(GLfloat)); // 4 coords per lines
	map->grid_lines_colors = (GLfloat*)calloc(4 * 4 * map->nb_grid_lines_vertices, sizeof(GLfloat)); // 4 coords per lines
	int vi = 0, ci = 0, ti = 0, i;
	// Verticals
	for (i = 0; i < grid_w; i++) {
		map->grid_lines_vertices[vi++] = i * tile_w - size / 2;	map->grid_lines_vertices[vi++] = 0;
		map->grid_lines_vertices[vi++] = i * tile_w + size / 2;	map->grid_lines_vertices[vi++] = 0;
		map->grid_lines_vertices[vi++] = i * tile_w + size / 2;	map->grid_lines_vertices[vi++] = mheight * tile_h;
		map->grid_lines_vertices[vi++] = i * tile_w - size / 2;	map->grid_lines_vertices[vi++] = mheight * tile_h;

		map->grid_lines_colors[ci++] = r; map->grid_lines_colors[ci++] = g; map->grid_lines_colors[ci++] = b; map->grid_lines_colors[ci++] = a; 
		map->grid_lines_colors[ci++] = r; map->grid_lines_colors[ci++] = g; map->grid_lines_colors[ci++] = b; map->grid_lines_colors[ci++] = a; 
		map->grid_lines_colors[ci++] = r; map->grid_lines_colors[ci++] = g; map->grid_lines_colors[ci++] = b; map->grid_lines_colors[ci++] = a; 
		map->grid_lines_colors[ci++] = r; map->grid_lines_colors[ci++] = g; map->grid_lines_colors[ci++] = b; map->grid_lines_colors[ci++] = a; 

		map->grid_lines_textures[ti++] = 0; map->grid_lines_textures[ti++] = 0; 
		map->grid_lines_textures[ti++] = 1; map->grid_lines_textures[ti++] = 0; 
		map->grid_lines_textures[ti++] = 1; map->grid_lines_textures[ti++] = 1; 
		map->grid_lines_textures[ti++] = 0; map->grid_lines_textures[ti++] = 1; 
	}
	// Horizontals
	for (i = 0; i < grid_h; i++) {
		map->grid_lines_vertices[vi++] = 0;			map->grid_lines_vertices[vi++] = i * tile_h - size / 2;
		map->grid_lines_vertices[vi++] = 0;			map->grid_lines_vertices[vi++] = i * tile_h + size / 2;
		map->grid_lines_vertices[vi++] = mwidth * tile_w;	map->grid_lines_vertices[vi++] = i * tile_h + size / 2;
		map->grid_lines_vertices[vi++] = mwidth * tile_w;	map->grid_lines_vertices[vi++] = i * tile_h - size / 2;

		map->grid_lines_colors[ci++] = r; map->grid_lines_colors[ci++] = g; map->grid_lines_colors[ci++] = b; map->grid_lines_colors[ci++] = a; 
		map->grid_lines_colors[ci++] = r; map->grid_lines_colors[ci++] = g; map->grid_lines_colors[ci++] = b; map->grid_lines_colors[ci++] = a; 
		map->grid_lines_colors[ci++] = r; map->grid_lines_colors[ci++] = g; map->grid_lines_colors[ci++] = b; map->grid_lines_colors[ci++] = a; 
		map->grid_lines_colors[ci++] = r; map->grid_lines_colors[ci++] = g; map->grid_lines_colors[ci++] = b; map->grid_lines_colors[ci++] = a; 

		map->grid_lines_textures[ti++] = 0; map->grid_lines_textures[ti++] = 0; 
		map->grid_lines_textures[ti++] = 1; map->grid_lines_textures[ti++] = 0; 
		map->grid_lines_textures[ti++] = 1; map->grid_lines_textures[ti++] = 1; 
		map->grid_lines_textures[ti++] = 0; map->grid_lines_textures[ti++] = 1; 
	}
	return 0;
}

static int map_set_z_callback(lua_State *L)
{
	map_type *map = (map_type*)auxiliar_checkclass(L, "core{map}", 1);
	int z = luaL_checknumber(L, 2);

	if (map->z_callbacks[z] != LUA_NOREF) luaL_unref(L, LUA_REGISTRYINDEX, map->z_callbacks[z]);

	if (lua_isfunction(L, 3)) {
		lua_pushvalue(L, 3);
		map->z_callbacks[z] = luaL_ref(L, LUA_REGISTRYINDEX);
	}
	return 0;
}

static int map_set_zoom(lua_State *L)
{
	map_type *map = (map_type*)auxiliar_checkclass(L, "core{map}", 1);
	int tile_w = luaL_checknumber(L, 2);
	int tile_h = luaL_checknumber(L, 3);
	int mwidth = luaL_checknumber(L, 4);
	int mheight = luaL_checknumber(L, 5);
	map->tile_w = tile_w;
	map->tile_h = tile_h;
	map->mwidth = mwidth;
	map->mheight = mheight;
	map->seen_changed = true;
	setup_seens_texture(map);
	return 0;
}

static int map_set_default_shader(lua_State *L)
{
	map_type *map = (map_type*)auxiliar_checkclass(L, "core{map}", 1);
	if (!lua_isnil(L, 2)) {
		shader_type *s = (shader_type*)lua_touserdata(L, 2);
		map->default_shader = s;
	} else {
		map->default_shader = NULL;
	}
	return 0;
}

static int map_set_obscure(lua_State *L)
{
	map_type *map = (map_type*)auxiliar_checkclass(L, "core{map}", 1);
	float r = luaL_checknumber(L, 2);
	float g = luaL_checknumber(L, 3);
	float b = luaL_checknumber(L, 4);
	float a = luaL_checknumber(L, 5);
	map->obscure_r = r;
	map->obscure_g = g;
	map->obscure_b = b;
	map->obscure_a = a;
	map->seen_changed = true;
	return 0;
}

static int map_set_shown(lua_State *L)
{
	map_type *map = (map_type*)auxiliar_checkclass(L, "core{map}", 1);
	float r = luaL_checknumber(L, 2);
	float g = luaL_checknumber(L, 3);
	float b = luaL_checknumber(L, 4);
	float a = luaL_checknumber(L, 5);
	map->shown_r = r;
	map->shown_g = g;
	map->shown_b = b;
	map->shown_a = a;
	map->seen_changed = true;
	return 0;
}

static int map_set_minimap_gridsize(lua_State *L)
{
	map_type *map = (map_type*)auxiliar_checkclass(L, "core{map}", 1);
	float s = luaL_checknumber(L, 2);
	map->minimap_gridsize = s;
	return 0;
}

static int map_set_grid(lua_State *L)
{
	map_type *map = (map_type*)auxiliar_checkclass(L, "core{map}", 1);
	int x = luaL_checknumber(L, 2);
	int y = luaL_checknumber(L, 3);
	if (x < 0 || y < 0 || x >= map->w || y >= map->h) return 0;

	// Get the mo list
	lua_rawgeti(L, LUA_REGISTRYINDEX, map->mo_list_ref);

	int i;
	for (i = 0; i < map->zdepth; i++)
	{
		// Remove the old object if any from the mo list
		// We use the pointer value directly as an index
		if (map->grids[x][y][i])
		{
#if defined(__PTRDIFF_TYPE__)
			if(sizeof(__PTRDIFF_TYPE__) == sizeof(long int))
				lua_pushnumber(L, (unsigned long int)map->grids[x][y][i]);
			else if(sizeof(__PTRDIFF_TYPE__) == sizeof(long long))
				lua_pushnumber(L, (long long)map->grids[x][y][i]);
			else
				lua_pushnumber(L, (long int)map->grids[x][y][i]);
#else
			lua_pushnumber(L, (long long)map->grids[x][y][i]);
#endif
			lua_pushnil(L);
			lua_settable(L, 5); // Access the list of all mos for the map

			luaL_unref(L, LUA_REGISTRYINDEX, map->grids_ref[x][y][i]);
		}

		lua_pushnumber(L, i + 1);
		lua_gettable(L, 4); // Access the table of mos for this spot
		map_object *old = map->grids[x][y][i];
		map->grids[x][y][i] = lua_isnoneornil(L, -1) ? NULL : (map_object*)auxiliar_checkclass(L, "core{mapobj}", -1);
		if (map->grids[x][y][i])
		{
			map->grids[x][y][i]->cur_x = x;
			map->grids[x][y][i]->cur_y = y;
			lua_pushvalue(L, -1);
			map->grids_ref[x][y][i] = luaL_ref(L, LUA_REGISTRYINDEX);
		}

		// Note that the layer changed so that we rebuild DisplayLists for this layer
		if (map->grids[x][y][i] != old) {
			map->z_changed[i] = true;
		}

		// Set the object in the mo list
		// We use the pointer value directly as an index
		lua_pushnumber(L, (long)map->grids[x][y][i]);
		lua_pushvalue(L, -2);
		lua_settable(L, 5); // Access the list of all mos for the map

		// Remove the mo and get the next
		lua_pop(L, 1);
	}

	// Pop the mo list
	lua_pop(L, 1);
	return 0;
}

static int map_set_seen(lua_State *L)
{
	map_type *map = (map_type*)auxiliar_checkclass(L, "core{map}", 1);
	int x = luaL_checknumber(L, 2);
	int y = luaL_checknumber(L, 3);
	float v = lua_tonumber(L, 4);

	if (x < 0 || y < 0 || x >= map->w || y >= map->h) return 0;
	map->grids_seens[y*map->w+x] = v;
	map->seen_changed = true;
	return 0;
}

static int map_set_remember(lua_State *L)
{
	map_type *map = (map_type*)auxiliar_checkclass(L, "core{map}", 1);
	int x = luaL_checknumber(L, 2);
	int y = luaL_checknumber(L, 3);
	bool v = lua_toboolean(L, 4);

	if (x < 0 || y < 0 || x >= map->w || y >= map->h) return 0;
	map->grids_remembers[x][y] = v;
	map->seen_changed = true;
	return 0;
}

static int map_set_lite(lua_State *L)
{
	map_type *map = (map_type*)auxiliar_checkclass(L, "core{map}", 1);
	int x = luaL_checknumber(L, 2);
	int y = luaL_checknumber(L, 3);
	bool v = lua_toboolean(L, 4);

	if (x < 0 || y < 0 || x >= map->w || y >= map->h) return 0;
	map->grids_lites[x][y] = v;
	map->seen_changed = true;
	return 0;
}

static int map_set_important(lua_State *L)
{
	map_type *map = (map_type*)auxiliar_checkclass(L, "core{map}", 1);
	int x = luaL_checknumber(L, 2);
	int y = luaL_checknumber(L, 3);
	bool v = lua_toboolean(L, 4);

	if (x < 0 || y < 0 || x >= map->w || y >= map->h) return 0;
	map->grids_important[x][y] = v;
	map->seen_changed = true;
	return 0;
}

static int map_clean_seen(lua_State *L)
{
	map_type *map = (map_type*)auxiliar_checkclass(L, "core{map}", 1);
	int i, j;

	for (i = 0; i < map->w; i++)
		for (j = 0; j < map->h; j++)
			map->grids_seens[j*map->w+i] = 0;
	map->seen_changed = true;
	return 0;
}

static int map_clean_remember(lua_State *L)
{
	map_type *map = (map_type*)auxiliar_checkclass(L, "core{map}", 1);
	int i, j;

	for (i = 0; i < map->w; i++)
		for (j = 0; j < map->h; j++)
			map->grids_remembers[i][j] = false;
	map->seen_changed = true;
	return 0;
}

static int map_clean_lite(lua_State *L)
{
	map_type *map = (map_type*)auxiliar_checkclass(L, "core{map}", 1);
	int i, j;

	for (i = 0; i < map->w; i++)
		for (j = 0; j < map->h; j++)
			map->grids_lites[i][j] = false;
	map->seen_changed = true;
	return 0;
}

static int map_get_seensinfo(lua_State *L)
{
	map_type *map = (map_type*)auxiliar_checkclass(L, "core{map}", 1);
	lua_pushnumber(L, map->tile_w);
	lua_pushnumber(L, map->tile_h);
	lua_pushnumber(L, map->seensinfo_w);
	lua_pushnumber(L, map->seensinfo_h);
	return 4;
}

static void map_update_seen_texture(map_type *map)
{
	tglBindTexture(GL_TEXTURE_2D, map->seens_texture);
	gl_c_texture = -1;

	int mx = map->used_mx;
	int my = map->used_my;
	GLubyte *seens = map->seens_map;
	int ptr = 0;
	int f = (map->is_hex & 1);
	int ii, jj;
	map->seensinfo_w = map->w+10;
	map->seensinfo_h = map->h+10;

	for (jj = 0; jj < map->h+10; jj++)
	{
		for (ii = 0; ii < map->w+10; ii++)
		{
			int i = ii, j = jj;
			int ri = i-5, rj = j-5;
			ptr = (((1+f)*j + (ri & f)) * map->seens_map_w + (1+f)*i) * 4;
			ri = (ri < 0) ? 0 : (ri >= map->w) ? map->w-1 : ri;
			rj = (rj < 0) ? 0 : (rj >= map->h) ? map->h-1 : rj;
			if ((i < 0) || (j < 0) || (i >= map->w+10) || (j >= map->h+10))
			{
				seens[ptr] = 0;
				seens[ptr+1] = 0;
				seens[ptr+2] = 0;
				seens[ptr+3] = 255;
				if (f) {
					ptr += 4;
					seens[ptr] = 0;
					seens[ptr+1] = 0;
					seens[ptr+2] = 0;
					seens[ptr+3] = 255;
					ptr += 4 * map->seens_map_w - 4;
					seens[ptr] = 0;
					seens[ptr+1] = 0;
					seens[ptr+2] = 0;
					seens[ptr+3] = 255;
					ptr += 4;
					seens[ptr] = 0;
					seens[ptr+1] = 0;
					seens[ptr+2] = 0;
					seens[ptr+3] = 255;
				}
				//ptr += 4;
				continue;
			}
			float v = map->grids_seens[rj*map->w+ri] * 255;
			if (v)
			{
				if (v > 255) v = 255;
				if (v < 0) v = 0;
				seens[ptr] = (GLubyte)0;
				seens[ptr+1] = (GLubyte)0;
				seens[ptr+2] = (GLubyte)0;
				seens[ptr+3] = (GLubyte)255-v;
				if (f) {
					ptr += 4;
					seens[ptr] = (GLubyte)0;
					seens[ptr+1] = (GLubyte)0;
					seens[ptr+2] = (GLubyte)0;
					seens[ptr+3] = (GLubyte)255-v;
					ptr += 4 * map->seens_map_w - 4;
					seens[ptr] = (GLubyte)0;
					seens[ptr+1] = (GLubyte)0;
					seens[ptr+2] = (GLubyte)0;
					seens[ptr+3] = (GLubyte)255-v;
					ptr += 4;
					seens[ptr] = (GLubyte)0;
					seens[ptr+1] = (GLubyte)0;
					seens[ptr+2] = (GLubyte)0;
					seens[ptr+3] = (GLubyte)255-v;
				}
			}
			else if (map->grids_remembers[ri][rj])
			{
				seens[ptr] = 0;
				seens[ptr+1] = 0;
				seens[ptr+2] = 0;
				seens[ptr+3] = 255 - map->obscure_a * 255;
				if (f) {
					ptr += 4;
					seens[ptr] = 0;
					seens[ptr+1] = 0;
					seens[ptr+2] = 0;
					seens[ptr+3] = 255 - map->obscure_a * 255;
					ptr += 4 * map->seens_map_w - 4;
					seens[ptr] = 0;
					seens[ptr+1] = 0;
					seens[ptr+2] = 0;
					seens[ptr+3] = 255 - map->obscure_a * 255;
					ptr += 4;
					seens[ptr] = 0;
					seens[ptr+1] = 0;
					seens[ptr+2] = 0;
					seens[ptr+3] = 255 - map->obscure_a * 255;
				}
			}
			else
			{
				seens[ptr] = 0;
				seens[ptr+1] = 0;
				seens[ptr+2] = 0;
				seens[ptr+3] = 255;
				if (f) {
					ptr += 4;
					seens[ptr] = 0;
					seens[ptr+1] = 0;
					seens[ptr+2] = 0;
					seens[ptr+3] = 255;
					ptr += 4 * map->seens_map_w - 4;
					seens[ptr] = 0;
					seens[ptr+1] = 0;
					seens[ptr+2] = 0;
					seens[ptr+3] = 255;
					ptr += 4;
					seens[ptr] = 0;
					seens[ptr+1] = 0;
					seens[ptr+2] = 0;
					seens[ptr+3] = 255;
				}
			}
			//ptr += 4;
		}
		// Skip the rest of the texture, silly GPUs not supporting NPOT textures!
		//ptr += (map->seens_map_w - map->w) * 4;
	}
	glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, map->seens_map_w, map->seens_map_h, GL_BGRA, GL_UNSIGNED_BYTE, seens);
}

static int map_update_seen_texture_lua(lua_State *L)
{
	map_type *map = (map_type*)auxiliar_checkclass(L, "core{map}", 1);
	map_update_seen_texture(map);
	return 0;
}

static int map_draw_seen_texture(lua_State *L)
{
	map_type *map = (map_type*)auxiliar_checkclass(L, "core{map}", 1);
	int x = lua_tonumber(L, 2);
	int y = lua_tonumber(L, 3);
	int nb_keyframes = 0;
	x += -map->tile_w * 5;
	y += -map->tile_h * 5;
	int w = (map->seens_map_w) * map->tile_w;
	int h = (map->seens_map_h) * map->tile_h;

	int mx = map->mx;
	int my = map->my;
//	x -= map->tile_w * (map->used_animdx + map->used_mx);
//	y -= map->tile_h * (map->used_animdy + map->used_my);
	x -= map->tile_w * (map->used_animdx + map->oldmx);
	y -= map->tile_h * (map->used_animdy + map->oldmy);


	tglBindTexture(GL_TEXTURE_2D, map->seens_texture);

	int f = 1 + (map->is_hex & 1);
	GLfloat texcoords[2*4] = {
		0, 0,
		0, (GLfloat)f,
		(GLfloat)f, (GLfloat)f,
		(GLfloat)f, 0,
	};
	GLfloat colors[4*4] = {
		1,1,1,1,
		1,1,1,1,
		1,1,1,1,
		1,1,1,1,
	};
	glColorPointer(4, GL_FLOAT, 0, colors);
	glTexCoordPointer(2, GL_FLOAT, 0, texcoords);

	GLfloat vertices[2*4] = {
		(GLfloat)x, (GLfloat)y,
		(GLfloat)x, (GLfloat)y + (GLfloat)h,
		(GLfloat)x + (GLfloat)w, (GLfloat)y + (GLfloat)h,
		(GLfloat)x + (GLfloat)w, (GLfloat)y,
	};
	glVertexPointer(2, GL_FLOAT, 0, vertices);

	glDrawArrays(GL_QUADS, 0, 4);
	return 0;
}

static int map_bind_seen_texture(lua_State *L)
{
	map_type *map = (map_type*)auxiliar_checkclass(L, "core{map}", 1);
	int unit = luaL_checknumber(L, 2);
	if (unit > 0 && !multitexture_active) return 0;

	if (unit > 0) tglActiveTexture(GL_TEXTURE0+unit);
	tglBindTexture(GL_TEXTURE_2D, map->seens_texture);
	if (unit > 0) tglActiveTexture(GL_TEXTURE0);

	return 0;
}

static int map_set_scroll(lua_State *L)
{
	map_type *map = (map_type*)auxiliar_checkclass(L, "core{map}", 1);
	int x = luaL_checknumber(L, 2);
	int y = luaL_checknumber(L, 3);
	int smooth = luaL_checknumber(L, 4);

	if (smooth)
	{
		// Not moving, use starting point
		if (!map->move_max)
		{
			map->oldmx = map->mx;
			map->oldmy = map->my;
		}
		// Already moving, compute starting point
		else
		{
			map->oldmx = map->oldmx + map->used_animdx;
			map->oldmy = map->oldmy + map->used_animdy;
		}
	} else {
		map->oldmx = x;
		map->oldmy = y;
	}

	map->move_step = 0;
	map->move_max = smooth;
	map->used_animdx = 0;
	map->used_animdy = 0;
	map->mx = x;
	map->my = y;
	map->seen_changed = true;

	for (int z = 0; z < map->zdepth; z++) map->z_changed[z] = true;
	return 0;
}

static int map_get_scroll(lua_State *L)
{
	map_type *map = (map_type*)auxiliar_checkclass(L, "core{map}", 1);
	lua_pushnumber(L, -map->tile_w*(map->used_animdx + map->oldmx - map->mx));
	lua_pushnumber(L, -map->tile_h*(map->used_animdy + map->oldmy - map->my));
	return 2;
}

// #define useDefaultShader(map) { \
// 	if (map->default_shader) tglUseProgramObject(map->default_shader->shader) \
// 	else tglUseProgramObject(0) \
// }

// #define useNoShader() { \
// 	tglUseProgramObject(0); \
// }

// #define unbatchQuads(vert, col) { \
// 	if ((vert)) glDrawArrays(GL_TRIANGLES, 0, (vert) / 2); \
// 	(vert) = 0; \
// 	(col) = 0; \
// }

// #define setMapGLArrays(vertices, texcoords, colors) { \
// 	glTexCoordPointer(2, GL_FLOAT, 0, texcoords); \
// 	glVertexPointer(2, GL_FLOAT, 0, vertices); \
// 	glColorPointer(4, GL_FLOAT, 0, colors);	 \
// }

static inline void do_quad(lua_State *L, const map_object *m, const map_object *dm, const map_type *map, int z,
		float anim, float dx, float dy, float tldx, float tldy, float
		dw, float dh, float r, float g, float b, float a, int i, int j)
{
	float x1, x2, y1, y2;

	if (m->flip_x) { // Check m and not dm so the whole thing flips
		x2 = dx; x1 = map->tile_w * dw * dm->scale + dx;
	} else {
		x1 = dx; x2 = map->tile_w * dw * dm->scale + dx;
	}
	if (m->flip_y) { // Check m and not dm so the whole thing flips
		y2 = dy; y1 = map->tile_h * dh * dm->scale + dy;
	} else {
		y1 = dy; y2 = map->tile_h * dh * dm->scale + dy;
	}

	float tx1 = dm->tex_x[0] + anim, tx2 = dm->tex_x[0] + anim + dm->tex_factorx[0];
	float ty1 = dm->tex_y[0] + anim, ty2 = dm->tex_y[0] + anim + dm->tex_factory[0];

	shader_type *shader = default_shader;
	if (dm->shader) shader = dm->shader;
	else if (m->shader) shader = m->shader;
	else if (map->default_shader) shader = map->default_shader;

	auto dl = getDisplayList(map->z_renderers[z], dm->textures[0], shader);

	// Make sure we do not have to reallocate each step
	// DGDGDGDG: actually do it

	// Put it directly into the DisplayList
	dl->list.push_back({{x1, y1, 0, 1}, {tx1, ty1}, {r, g, b, a}});
	dl->list.push_back({{x2, y1, 0, 1}, {tx2, ty1}, {r, g, b, a}});
	dl->list.push_back({{x2, y2, 0, 1}, {tx2, ty2}, {r, g, b, a}});
	dl->list.push_back({{x1, y2, 0, 1}, {tx1, ty2}, {r, g, b, a}});

	// DGDGDGDG
	// if (L && dm->cb_ref != LUA_NOREF)
	// {
	// 	useNoShader();
	// 	lua_rawgeti(L, LUA_REGISTRYINDEX, dm->cb_ref);
	// 	lua_checkstack(L, 8);
	// 	lua_pushnumber(L, dx);
	// 	lua_pushnumber(L, dy);
	// 	lua_pushnumber(L, map->tile_w * (dw) * (dm->scale));
	// 	lua_pushnumber(L, map->tile_h * (dh) * (dm->scale));
	// 	lua_pushnumber(L, (dm->scale));
	// 	lua_pushboolean(L, true);
	// 	lua_pushnumber(L, tldx);
	// 	lua_pushnumber(L, tldy);
	// 	if (lua_pcall(L, 8, 1, 0))
	// 	{
	// 		printf("Display callback error: UID %ld: %s\n", dm->uid, lua_tostring(L, -1));
	// 		lua_pop(L, 1);
	// 	}
	// 	if (lua_isboolean(L, -1)) {
	// 		setMapGLArrays(vertices, texcoords, colors);
	// 	}
	// 	lua_pop(L, 1);
	// 	if (m->shader) useShader(m->shader, dx, dy, map->tile_w, map->tile_h, dm->tex_x[0], dm->tex_y[0], dm->tex_factorx[0], dm->tex_factory[0], r, g, b, a);
	// 	else useDefaultShader(map);
	// }
}

// static inline void display_map_quad(lua_State *L, map_type *map, int scrollx, int scrolly, int bdx, int bdy, int dz, map_object *m, int i, int j, float a, float seen, int nb_keyframes, bool always_show) ALWAYS_INLINE;
static inline void display_map_quad(lua_State *L, map_type *map, int scrollx, int scrolly, int bdx, int bdy, int dz, map_object *m, int i, int j, float a, float seen, int nb_keyframes, bool always_show)
{
	map_object *dm;
	float r, g, b;
	GLfloat *vertices = map->vertices;
	GLfloat *colors = map->colors;
	GLfloat *texcoords = map->texcoords;
	bool up_important = false;
	float anim;
	int zc;
	int anim_step;
	int dx = scrollx + bdx;
	int dy = scrolly + bdy;

	/********************************************************
	 ** Select the color to use
	 ********************************************************/
	if (always_show)
	{
		if (m->tint_r < 1 || m->tint_g < 1 || m->tint_b < 1)
		{
			r = (map->shown_r + m->tint_r)/2; g = (map->shown_g + m->tint_g)/2; b = (map->shown_b + m->tint_b)/2;
		}
		else
		{
			r = map->shown_r; g = map->shown_g; b = map->shown_b;
		}
		a = 1;
	}
	else if (seen)
	{
		if (m->tint_r < 1 || m->tint_g < 1 || m->tint_b < 1)
		{
			r = (map->shown_r + m->tint_r)/2; g = (map->shown_g + m->tint_g)/2; b = (map->shown_b + m->tint_b)/2;
		}
		else
		{
			r = map->shown_r; g = map->shown_g; b = map->shown_b;
		}
		r *= seen;
		g *= seen;
		b *= seen;
		a = seen;
	}
	else
	{
		if (m->tint_r < 1 || m->tint_g < 1 || m->tint_b < 1)
		{
			r = (map->obscure_r + m->tint_r)/2; g = (map->obscure_g + m->tint_g)/2; b = (map->obscure_b + m->tint_b)/2;
		}
		else
		{
			r = map->obscure_r; g = map->obscure_g; b = map->obscure_b;
		}
		a = map->obscure_r;
	}

	/********************************************************
	 ** Setup all textures we need
	 ********************************************************/
	a = (a > 1) ? 1 : ((a < 0) ? 0 : a);
	int z;

	/********************************************************
	 ** Compute/display movement and motion blur
	 ********************************************************/
	float animdx = 0, animdy = 0;
	float tlanimdx = 0, tlanimdy = 0;
	// if (m->display_last == DL_NONE) m->move_max = 0;

	// WTF?!
	// lua_is_hex(L);
	// int is_hex = luaL_checknumber(L, -1);
	bool is_hex = map->is_hex;

	if (m->move_max)
	{
		map->z_changed[dz] = true;
		m->move_step += nb_keyframes;
		if (m->move_step >= m->move_max) m->move_max = 0; // Reset once in place
		// if (m->display_last == DL_NONE) m->display_last = DL_TRUE;

		if (m->move_max)
		{
			float adx = (float)i - m->oldx;
			float ady = (float)j - m->oldy + 0.5f*(i & is_hex);

			// Motion bluuuurr!
			if (m->move_blur)
			{
				int step;
				for (z = 1; z <= m->move_blur; z++)
				{
					step = m->move_step - z;
					if (step >= 0)
					{
						animdx = tlanimdx = map->tile_w * (adx * step / (float)m->move_max - adx);
						animdy = tlanimdy = map->tile_h * (ady * step / (float)m->move_max - ady);
						dm = m;
						while (dm)
						{
						 	// if (m != dm && dm->shader) {
								// unbatchQuads((*vert_idx), (*col_idx));
								// // printf(" -- unbatch3\n");

								// for (zc = dm->nb_textures - 1; zc > 0; zc--)
								// {
								// 	if (multitexture_active) tglActiveTexture(GL_TEXTURE0+zc);
								// 	tglBindTexture(dm->textures_is3d[zc] ? GL_TEXTURE_3D : GL_TEXTURE_2D, dm->textures[zc]);
								// }
								// if (dm->nb_textures && multitexture_active) tglActiveTexture(GL_TEXTURE0); // Switch back to default texture unit

						 	// 	useShader(dm->shader, dx, dy, map->tile_w, map->tile_h, dm->tex_x[0], dm->tex_y[0], dm->tex_factorx[0], dm->tex_factory[0], r, g, b, a);
						 	// }

							do_quad(L, m, dm, map, dz,
								0,
								dx + dm->dx * map->tile_w + animdx,
								dy + dm->dy * map->tile_h + animdy,
								dx + dm->dx * map->tile_w + tlanimdx,
								dy + dm->dy * map->tile_h + tlanimdy,
								dm->dw,
								dm->dh,
								r, g, b, a,
								i, j);
							dm = dm->next;
						}
					}
				}
			}

			// Final step
			animdx = tlanimdx = adx * m->move_step / (float)m->move_max - adx;
			animdy = tlanimdy = ady * m->move_step / (float)m->move_max - ady;

			if (m->move_twitch) {
				float where = (0.5 - fabsf(m->move_step / (float)m->move_max - 0.5)) * 2;
				if (m->move_twitch_dir == 4) animdx -= m->move_twitch * where;
				else if (m->move_twitch_dir == 6) animdx += m->move_twitch * where;
				else if (m->move_twitch_dir == 2) animdy += m->move_twitch * where;
				else if (m->move_twitch_dir == 1) { animdx -= m->move_twitch * where; animdy += m->move_twitch * where; }
				else if (m->move_twitch_dir == 3) { animdx += m->move_twitch * where; animdy += m->move_twitch * where; }
				else if (m->move_twitch_dir == 7) { animdx -= m->move_twitch * where; animdy -= m->move_twitch * where; }
				else if (m->move_twitch_dir == 9) { animdx += m->move_twitch * where; animdy -= m->move_twitch * where; }
				else animdy -= m->move_twitch * where;
			}

//			printf("==computing %f x %f : %f x %f // %d/%d\n", animdx, animdy, adx, ady, m->move_step, m->move_max);
		}
	}

//	if ((j - 1 >= 0) && map->grids_important[i][j - 1] && map->grids[i][j-1][9] && !map->grids[i][j-1][9]->move_max) up_important = true;

	/********************************************************
	 ** Display the entity
	 ********************************************************/
	dm = m;
	tglBindTexture(GL_TEXTURE_2D, m->textures[0]);
	while (dm)
	{
		if (!dm->anim_max) anim = 0;
		else {
			dm->anim_step += (dm->anim_speed * nb_keyframes);
			anim_step = dm->anim_step;
			if (dm->anim_step >= dm->anim_max) {
				dm->anim_step = 0;
				if (dm->anim_loop == 0) dm->anim_max = 0;
				else if (dm->anim_loop > 0) dm->anim_loop--;
			}
			anim = (float)anim_step / dm->anim_max;
			map->z_changed[dz] = true;
		}
		dm->world_x = bdx + (dm->dx + animdx) * map->tile_w;
		dm->world_y = bdy + (dm->dy + animdy) * map->tile_h;

	 	// if (m != dm && dm->shader) {
			// unbatchQuads((*vert_idx), (*col_idx));
			// // printf(" -- unbatch3\n");

			// for (zc = dm->nb_textures - 1; zc > 0; zc--)
			// {
			// 	if (multitexture_active) tglActiveTexture(GL_TEXTURE0+zc);
			// 	tglBindTexture(dm->textures_is3d[zc] ? GL_TEXTURE_3D : GL_TEXTURE_2D, dm->textures[zc]);
			// }
			// if (dm->nb_textures && multitexture_active) tglActiveTexture(GL_TEXTURE0); // Switch back to default texture unit

	 	// 	useShader(dm->shader, dx, dy, map->tile_w, map->tile_h, dm->tex_x[0], dm->tex_y[0], dm->tex_factorx[0], dm->tex_factory[0], r, g, b, a);
	 	// }

		do_quad(L, m, dm, map, dz,
			anim,
			dx + (dm->dx + animdx) * map->tile_w,
			dy + (dm->dy + animdy) * map->tile_h,
			dx + (dm->dx + tlanimdx) * map->tile_w,
			dy + (dm->dy + tlanimdy) * map->tile_h,
			dm->dw,
			dm->dh,
			r, g, b, ((dm->dy < 0) && up_important) ? a / 3 : a,
			i, j);
		dm->animdx = animdx;
		dm->animdy = animdy;
		dm = dm->next;
	}

	/********************************************************
	 ** Cleanup
	 ********************************************************/
	// m->display_last = DL_TRUE;
}

#define MIN(a,b) ((a < b) ? a : b)

void map_toscreen(lua_State *L, map_type *map, int x, int y, int nb_keyframes, bool always_show, mat4 model, vec4 color)
{
	bool changed = false;
	int i = 0, j = 0, z = 0;
	int mx = map->mx;
	int my = map->my;

	// nb_draws = 0;

	// Smooth scrolling
	// If we use shaders for FOV display it means we must uses fbos for smooth scroll too
	float animdx = 0, animdy = 0;
	if (map->move_max)
	{
		map->move_step += nb_keyframes;
		if (map->move_step >= map->move_max)
		{
			map->move_max = 0;
			map->oldmx = map->mx;
			map->oldmy = map->my;
		}

		if (map->move_max)
		{
			float adx = (float)map->mx - map->oldmx;
			float ady = (float)map->my - map->oldmy;
			animdx = adx * map->move_step / (float)map->move_max;
			animdy = ady * map->move_step / (float)map->move_max;
			mx = (int)(map->oldmx + animdx);
			my = (int)(map->oldmy + animdy);
		}
		changed = true;
	}
	float scrollx = map->tile_w * (animdx + map->oldmx);
	float scrolly = map->tile_h * (animdy + map->oldmy);
	map->used_animdx = animdx;
	map->used_animdy = animdy;
	map->displayed_x = x - scrollx;
	map->displayed_y = y - scrolly;

	mat4 scrollmodel = mat4();
	scrollmodel = glm::translate(scrollmodel, glm::vec3(-scrollx, -scrolly, 0));
	model = model * scrollmodel;

	map->used_mx = mx;
	map->used_my = my;

	int mini = mx - 1, maxi = mx + map->mwidth + 2, minj =  my - 1, maxj = my + map->mheight + 2;
	if(mini < 0)
		mini = 0;
	if(minj < 0)
		minj = 0;
	if(maxi > map->w)
		maxi = map->w;
	if(maxj > map->h)
		maxj = map->h;

	// Always display some more of the map to make sure we always see it all
	for (z = 0; z < map->zdepth; z++)
	{
		auto render = map->z_renderers[z];
		if (map->z_changed[z]) {
			// printf("map layer %d is invalid\n", z);
			render->resetDisplayLists();
			render->setChanged();
			map->z_changed[z] = false;

			for (j = minj; j < maxj; j++)
			{
				for (i = mini; i < maxi; i++)
				{
					int dx = i * map->tile_w;
					int dy = j * map->tile_h + (i & map->is_hex) * map->tile_h / 2;
					map_object *mo = map->grids[i][j][z];
					if (!mo) continue;

					if ((mo->on_seen && map->grids_seens[j*map->w+i]) || (mo->on_remember && (always_show || map->grids_remembers[i][j])) || mo->on_unknown)
					{
						if (map->grids_seens[j*map->w+i])
						{
							display_map_quad(L, map, x, y, dx, dy, z, mo, i, j, 1, map->grids_seens[j*map->w+i], nb_keyframes, always_show);
						}
						else
						{
							display_map_quad(L, map, x, y, dx, dy, z, mo, i, j, 1, 0, nb_keyframes, always_show);
						}
					}
				}
			}
			// printf(">===HANDLING layer %d\n", z);
		}

		// DGDGDGDG
		// if (L && map->z_callbacks[z] != LUA_NOREF) {
		// 	/* Draw remaining ones */
		// 	unbatchQuads(vert_idx, col_idx);
		// 		// printf(" -- unbatch5\n");

		// 	lua_rawgeti(L, LUA_REGISTRYINDEX, map->z_callbacks[z]);
		// 	lua_checkstack(L, 4);
		// 	lua_pushnumber(L, z);
		// 	lua_pushnumber(L, nb_keyframes);
		// 	lua_pushvalue(L, 7);
		// 	if (lua_pcall(L, 3, 1, 0))
		// 	{
		// 		printf("Map z-callback error: Z %d: %s\n", z, lua_tostring(L, -1));
		// 		lua_pop(L, 1);
		// 	}
		// 	if (lua_isboolean(L, -1)) {
		// 		glTexCoordPointer(2, GL_FLOAT, 0, texcoords);
		// 		glVertexPointer(2, GL_FLOAT, 0, vertices);
		// 		glColorPointer(4, GL_FLOAT, 0, colors);
		// 	}
		// 	lua_pop(L, 1);
		// }

		render->toScreen(model, color);
	}

	// "Decay" displayed status for all mos
	if (L) {
		// lua_rawgeti(L, LUA_REGISTRYINDEX, map->mo_list_ref);
		// lua_pushnil(L);
		// while (lua_next(L, -2) != 0)
		// {
		// 	map_object *mo = (map_object*)auxiliar_checkclass(L, "core{mapobj}", -1);
		// 	if (mo->display_last == DL_TRUE) mo->display_last = DL_TRUE_LAST;
		// 	else if (mo->display_last == DL_TRUE_LAST) mo->display_last = DL_NONE;
		// 	lua_pop(L, 1); // Remove value, keep key for next iteration
		// }

		if (always_show && changed)
		{
			lua_getglobal(L, "game");
			lua_pushliteral(L, "updateFOV");
			lua_gettable(L, -2);
			if (lua_isfunction(L, -1)) {
				lua_pushvalue(L, -2);
				lua_call(L, 1, 0);
				lua_pop(L, 1);
			}
			else lua_pop(L, 2);
			map_update_seen_texture(map);
			map->seen_changed = false;
		}
	}
}

static int lua_map_toscreen(lua_State *L)
{
	map_type *map = (map_type*)auxiliar_checkclass(L, "core{map}", 1);
	int x = luaL_checknumber(L, 2);
	int y = luaL_checknumber(L, 3);
	int nb_keyframes = luaL_checknumber(L, 4);
	bool always_show = lua_toboolean(L, 5);

	vec4 color = {1, 1, 1, 1};
	mat4 model = mat4();

	map_toscreen(L, map, x, y, nb_keyframes, always_show, model, color);

	return 0;
}

extern int gl_tex_white;
static int map_line_grids(lua_State *L) {
	map_type *map = (map_type*)auxiliar_checkclass(L, "core{map}", 1);
	if (!map->grid_lines_vertices) return 0;

	int x = luaL_checknumber(L, 2);
	int y = luaL_checknumber(L, 3);

	if (lua_isuserdata(L, 4))
	{
		texture_type *t = (texture_type*)auxiliar_checkclass(L, "gl{texture}", 4);
		tglBindTexture(GL_TEXTURE_2D, t->tex);
	}
	else if (lua_toboolean(L, 4))
	{
		// Do nothing, we keep the currently bound texture
	}
	else
	{
		tfglBindTexture(GL_TEXTURE_2D, gl_tex_white);
	}

	glTranslatef(x - map->used_animdx * map->tile_w, y - map->used_animdy * map->tile_h, 0);
	glVertexPointer(2, GL_FLOAT, 0, map->grid_lines_vertices);
	glColorPointer(4, GL_FLOAT, 0, map->grid_lines_colors);
	glTexCoordPointer(2, GL_FLOAT, 0, map->grid_lines_textures);
	glDrawArrays(GL_QUADS, 0, map->nb_grid_lines_vertices * 4);
	glTranslatef(-x + map->used_animdx * map->tile_w, -y + map->used_animdy * map->tile_h, 0);
	return 0;	
}

static int minimap_to_screen(lua_State *L)
{
	map_type *map = (map_type*)auxiliar_checkclass(L, "core{map}", 1);
	int x = luaL_checknumber(L, 2);
	int y = luaL_checknumber(L, 3);
	int mdx = luaL_checknumber(L, 4);
	int mdy = luaL_checknumber(L, 5);
	int mdw = luaL_checknumber(L, 6);
	int mdh = luaL_checknumber(L, 7);
	float transp = luaL_checknumber(L, 8);
	int z = 0, i = 0, j = 0;
	int vert_idx = 0;
	int col_idx = 0;
	GLfloat r, g, b, a;

	int f = (map->is_hex & 1);
	// Create/recreate the minimap data if needed
	if (map->mm_w != mdw || map->mm_h != mdh)
	{
		if (map->mm_texture) glDeleteTextures(1, &(map->mm_texture));
		if (map->minimap) free(map->minimap);

		// In case we can't support NPOT textures round up to nearest POT
		int realw=1;
		int realh=1;
		while (realw < mdw) realw *= 2;
		while (realh < f + (1+f)*mdh) realh *= 2;

		glGenTextures(1, &(map->mm_texture));
		map->mm_w = mdw;
		map->mm_h = mdh;
		map->mm_rw = realw;
		map->mm_rh = realh;
		printf("C Map minimap texture: %d (%dx%d; %dx%d)\n", map->mm_texture, mdw, mdh, realw, realh);
		tglBindTexture(GL_TEXTURE_2D, map->mm_texture);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
		glTexImage2D(GL_TEXTURE_2D, 0, 4, realw, realh, 0, GL_BGRA, GL_UNSIGNED_BYTE, NULL);
		map->minimap = (GLubyte*)calloc(realw*realh*4, sizeof(GLubyte));
	}

	tglBindTexture(GL_TEXTURE_2D, map->mm_texture);

	int ptr;
	GLubyte *mm = map->minimap;
	memset(mm, 0, map->mm_rh * map->mm_rw * 4 * sizeof(GLubyte));

	int mini = mdx, maxi = mdx + mdw, minj = mdy, maxj = mdy + mdh;

	if(mini < 0)
		mini = 0;
	if(minj < 0)
		minj = 0;
	if(maxi > map->w)
		maxi = map->w;
	if(maxj > map->h)
		maxj = map->h;

	for (z = 0; z < map->zdepth; z++)
	{
		for (j = minj; j < maxj; j++)
		{
			for (i = mini; i < maxi; i++)
			{
				map_object *mo = map->grids[i][j][z];
				if (!mo || mo->mm_r < 0) continue;
				ptr = (((1+f)*(j-mdy) + (i & f)) * map->mm_rw + (i-mdx)) * 4;

				if ((mo->on_seen && map->grids_seens[j*map->w+i]) || (mo->on_remember && map->grids_remembers[i][j]) || mo->on_unknown)
				{
					if (map->grids_seens[j*map->w+i])
					{
						r = mo->mm_r; g = mo->mm_g; b = mo->mm_b; a = transp;
					}
					else
					{
						r = mo->mm_r * 0.6; g = mo->mm_g * 0.6; b = mo->mm_b * 0.6; a = transp * 0.6;
					}
					mm[ptr] = b * 255;
					mm[ptr+1] = g * 255;
					mm[ptr+2] = r * 255;
					mm[ptr+3] = a * 255;
					if (f) {
						ptr += 4 * map->mm_rw;
						mm[ptr] = b * 255;
						mm[ptr+1] = g * 255;
						mm[ptr+2] = r * 255;
						mm[ptr+3] = a * 255;
					}
				}
			}
		}
	}
	glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, map->mm_rw, map->mm_rh, GL_BGRA, GL_UNSIGNED_BYTE, mm);

	// Display it
	GLfloat texcoords[2*4] = {
		0, 0,
		0, (float)((1+f)*mdh)/(float)map->mm_rh,
		(float)mdw/(float)map->mm_rw, (float)((1+f)*mdh)/(float)map->mm_rh,
		(float)mdw/(float)map->mm_rw, 0,
	};
	GLfloat colors[4*4] = {
		1,1,1,1,
		1,1,1,1,
		1,1,1,1,
		1,1,1,1,
	};
	glColorPointer(4, GL_FLOAT, 0, colors);
	glTexCoordPointer(2, GL_FLOAT, 0, texcoords);

	GLfloat vertices[2*4] = {
		(GLfloat)x, (GLfloat)y,
		(GLfloat)x, (GLfloat)y + mdh * map->minimap_gridsize,
		(GLfloat)x + mdw * map->minimap_gridsize, (GLfloat)y + mdh * map->minimap_gridsize,
		(GLfloat)x + mdw * map->minimap_gridsize, (GLfloat)y,
	};
	glVertexPointer(2, GL_FLOAT, 0, vertices);
	glDrawArrays(GL_QUADS, 0, 4);
//	printf("display mm %dx%d :: %dx%d\n",x,y,mdw,mdh);
	return 0;
}

static int map_get_display_object(lua_State *L)
{
	map_type *map = (map_type*)auxiliar_checkclass(L, "core{map}", 1);

	DORTileMap *tm = new DORTileMap();
	tm->setMap(map);

	DisplayObject **v = (DisplayObject**)lua_newuserdata(L, sizeof(DisplayObject*));
	*v = tm;
	auxiliar_setclass(L, "gl{tilemap}", -1);
	return 1;
}

static const struct luaL_Reg maplib[] =
{
	{"newMap", map_new},
	{"newObject", map_object_new},
	{"mapObjectsToDisplayObject", map_objects_to_displayobject},
	{NULL, NULL},
};

static const struct luaL_Reg map_reg[] =
{
	{"__gc", map_free},
	{"close", map_free},
	{"updateSeensTexture", map_update_seen_texture_lua},
	{"bindSeensTexture", map_bind_seen_texture},
	{"drawSeensTexture", map_draw_seen_texture},
	{"setZoom", map_set_zoom},
	{"setShown", map_set_shown},
	{"setObscure", map_set_obscure},
	{"setGrid", map_set_grid},
	{"zCallback", map_set_z_callback},
	{"cleanSeen", map_clean_seen},
	{"cleanRemember", map_clean_remember},
	{"cleanLite", map_clean_lite},
	{"setDefaultShader", map_set_default_shader},
	{"setSeen", map_set_seen},
	{"setRemember", map_set_remember},
	{"setLite", map_set_lite},
	{"setImportant", map_set_important},
	{"getSeensInfo", map_get_seensinfo},
	{"setScroll", map_set_scroll},
	{"getScroll", map_get_scroll},
	{"toScreen", lua_map_toscreen},
	{"toScreenMiniMap", minimap_to_screen},
	{"toScreenLineGrids", map_line_grids},
	{"setupGridLines", map_define_grid_lines},
	{"setupMiniMapGridSize", map_set_minimap_gridsize},
	{"getMapDO", map_get_display_object},
	{NULL, NULL},
};

static const struct luaL_Reg map_object_reg[] =
{
	{"__gc", map_object_free},
	{"texture", map_object_texture},
	{"displayCallback", map_object_cb},
	{"chain", map_object_chain},
	{"tint", map_object_tint},
	{"shader", map_object_shader},
	{"print", map_object_print},
	{"invalidate", map_object_invalid},
	{"isValid", map_object_is_valid},
	{"onSeen", map_object_on_seen},
	{"minimap", map_object_minimap},
	{"resetMoveAnim", map_object_reset_move_anim},
	{"setMoveAnim", map_object_set_move_anim},
	{"getMoveAnim", map_object_get_move_anim},
	{"getWorldPos", map_object_get_world_pos},
	{"setAnim", map_object_set_anim},
	{"flipX", map_object_flip_x},
	{"flipY", map_object_flip_y},
	{NULL, NULL},
};

int luaopen_map(lua_State *L)
{
	auxiliar_newclass(L, "core{map}", map_reg);
	auxiliar_newclass(L, "core{mapobj}", map_object_reg);
	luaL_openlib(L, "core.map", maplib, 0);
	lua_pop(L, 1);
	return 1;
}
