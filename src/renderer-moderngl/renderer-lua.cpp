/*
    TE4 - T-Engine 4
    Copyright (C) 2009 - 2015 Nicolas Casalini

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

#include "renderer-moderngl/Renderer.hpp"
extern "C" {
#include "auxiliar.h"
#include "renderer-moderngl/renderer-lua.h"
}

/******************************************************************
 ** Generic
 ******************************************************************/

static int gl_generic_color(lua_State *L)
{
	DisplayObject **c = (DisplayObject**)lua_touserdata(L, 1);
	(*c)->setColor(lua_tonumber(L, 2), lua_tonumber(L, 3), lua_tonumber(L, 4), lua_tonumber(L, 5));
	return 0;
}

static int gl_generic_translate(lua_State *L)
{
	DisplayObject **c = (DisplayObject**)lua_touserdata(L, 1);
	(*c)->translate(lua_tonumber(L, 2), lua_tonumber(L, 3), lua_tonumber(L, 4), lua_toboolean(L, 5));
	return 0;
}

static int gl_generic_rotate(lua_State *L)
{
	DisplayObject **c = (DisplayObject**)lua_touserdata(L, 1);
	(*c)->rotate(lua_tonumber(L, 2), lua_tonumber(L, 3), lua_tonumber(L, 4), lua_toboolean(L, 5));
	return 0;
}

static int gl_generic_scale(lua_State *L)
{
	DisplayObject **c = (DisplayObject**)lua_touserdata(L, 1);
	(*c)->scale(lua_tonumber(L, 2), lua_tonumber(L, 3), lua_tonumber(L, 4), lua_toboolean(L, 5));
	return 0;
}

/******************************************************************
 ** Renderer
 ******************************************************************/
static int gl_renderer_new(lua_State *L)
{
	RendererGL **r = (RendererGL**)lua_newuserdata(L, sizeof(RendererGL*));
	auxiliar_setclass(L, "gl{renderer}", -1);

	int w = screen->w / screen_zoom;
	int h = screen->h / screen_zoom;
	if (lua_isnumber(L, 1)) w = lua_tonumber(L, 1);
	if (lua_isnumber(L, 2)) h = lua_tonumber(L, 2);

	*r = new RendererGL(w, h);
	(*r)->setLuaState(L);

	return 1;
}

static int gl_renderer_free(lua_State *L)
{
	RendererGL **r = (RendererGL**)auxiliar_checkclass(L, "gl{renderer}", 1);
	delete(*r);
	lua_pushnumber(L, 1);
	return 1;
}

static int gl_renderer_zsort(lua_State *L)
{
	RendererGL **r = (RendererGL**)auxiliar_checkclass(L, "gl{renderer}", 1);
	(*r)->zSorting(lua_toboolean(L, 2));
	return 0;
}

static int gl_renderer_cutoff(lua_State *L)
{
	RendererGL **c = (RendererGL**)auxiliar_checkclass(L, "gl{renderer}", 1);
	(*c)->cutoff(lua_tonumber(L, 2), lua_tonumber(L, 3), lua_tonumber(L, 4), lua_tonumber(L, 5));
	return 0;
}

static int gl_renderer_toscreen(lua_State *L)
{
	RendererGL **renderer = (RendererGL**)auxiliar_checkclass(L, "gl{renderer}", 1);
	(*renderer)->toScreen();
	return 0;
}

static int gl_renderer_add(lua_State *L)
{
	// We do not make any checks on the types, so the same method can be used for container & renderer and to add any kind of display object
	RendererGL **c = (RendererGL**)lua_touserdata(L, 1);
	DisplayObject **add = (DisplayObject**)lua_touserdata(L, 2);
	(*c)->add(*add);	
	(*add)->setLuaRef(luaL_ref(L, LUA_REGISTRYINDEX));
	return 0;
}

static int gl_renderer_remove(lua_State *L)
{
	// We do not make any checks on the types, so the same method can be used for container & renderer and to add any kind of display object
	RendererGL **c = (RendererGL**)lua_touserdata(L, 1);
	DisplayObject **add = (DisplayObject**)lua_touserdata(L, 2);
	(*c)->remove(*add);
	return 0;
}

static int gl_renderer_clear(lua_State *L)
{
	// We do not make any checks on the types, so the same method can be used for container & renderer and to add any kind of display object
	RendererGL **c = (RendererGL**)lua_touserdata(L, 1);
	(*c)->clear();
	return 0;
}

/******************************************************************
 ** Container
 ******************************************************************/
static int gl_container_new(lua_State *L)
{
	DORContainer **c = (DORContainer**)lua_newuserdata(L, sizeof(DORContainer*));
	auxiliar_setclass(L, "gl{container}", -1);
	*c = new DORContainer();
	(*c)->setLuaState(L);

	return 1;
}

static int gl_container_free(lua_State *L)
{
	DORContainer **c = (DORContainer**)auxiliar_checkclass(L, "gl{container}", 1);
	delete(*c);
	lua_pushnumber(L, 1);
	return 1;
}

static int gl_container_add(lua_State *L)
{
	// We do not make any checks on the types, so the same method can be used for container & renderer and to add any kind of display object
	DORContainer **c = (DORContainer**)lua_touserdata(L, 1);
	DisplayObject **add = (DisplayObject**)lua_touserdata(L, 2);
	(*c)->add(*add);	
	(*add)->setLuaRef(luaL_ref(L, LUA_REGISTRYINDEX));
	return 0;
}

static int gl_container_remove(lua_State *L)
{
	// We do not make any checks on the types, so the same method can be used for container & renderer and to add any kind of display object
	DORContainer **c = (DORContainer**)lua_touserdata(L, 1);
	DisplayObject **add = (DisplayObject**)lua_touserdata(L, 2);
	(*c)->remove(*add);
	return 0;
}

static int gl_container_clear(lua_State *L)
{
	// We do not make any checks on the types, so the same method can be used for container & renderer and to add any kind of display object
	DORContainer **c = (DORContainer**)lua_touserdata(L, 1);
	(*c)->clear();
	return 0;
}

/******************************************************************
 ** Target (FBO)
 ******************************************************************/
static int gl_target_new(lua_State *L)
{
	DORTarget **c = (DORTarget**)lua_newuserdata(L, sizeof(DORTarget*));
	auxiliar_setclass(L, "gl{target}", -1);
	int w = screen->w / screen_zoom;
	int h = screen->h / screen_zoom;
	int nbt = 1;

	if (lua_isnumber(L, 1)) w = lua_tonumber(L, 1);
	if (lua_isnumber(L, 2)) h = lua_tonumber(L, 2);
	if (lua_isnumber(L, 3)) nbt = lua_tonumber(L, 3);

	*c = new DORTarget(w, h, nbt);
	(*c)->setLuaState(L);

	return 1;
}

static int gl_target_free(lua_State *L)
{
	DORTarget **c = (DORTarget**)auxiliar_checkclass(L, "gl{target}", 1);
	delete(*c);
	lua_pushnumber(L, 1);
	return 1;
}

static int gl_target_use(lua_State *L)
{
	// We do not make any checks on the types, so the same method can be used for target & renderer and to add any kind of display object
	DORTarget **c = (DORTarget**)lua_touserdata(L, 1);
	(*c)->use(lua_toboolean(L, 2));
	return 0;
}

static int gl_target_displaysize(lua_State *L)
{
	// We do not make any checks on the types, so the same method can be used for target & renderer and to add any kind of display object
	DORTarget **c = (DORTarget**)lua_touserdata(L, 1);
	(*c)->displaySize(lua_tonumber(L, 2), lua_tonumber(L, 3), lua_toboolean(L, 4));
	return 0;
}

static int gl_target_clearcolor(lua_State *L)
{
	// We do not make any checks on the types, so the same method can be used for target & renderer and to add any kind of display object
	DORTarget **c = (DORTarget**)lua_touserdata(L, 1);
	(*c)->setClearColor(lua_tonumber(L, 2), lua_tonumber(L, 3), lua_tonumber(L, 4), lua_tonumber(L, 5));
	return 0;
}

/******************************************************************
 ** Vertexes
 ******************************************************************/
static int gl_vertexes_new(lua_State *L)
{
	DORVertexes **v = (DORVertexes**)lua_newuserdata(L, sizeof(DORVertexes*));
	auxiliar_setclass(L, "gl{vertexes}", -1);
	*v = new DORVertexes();
	(*v)->setLuaState(L);

	return 1;
}

static int gl_vertexes_free(lua_State *L)
{
	DORVertexes **v = (DORVertexes**)auxiliar_checkclass(L, "gl{vertexes}", 1);
	delete(*v);
	lua_pushnumber(L, 1);
	return 1;
}

static int gl_vertexes_quad(lua_State *L)
{
	DORVertexes **v = (DORVertexes**)auxiliar_checkclass(L, "gl{vertexes}", 1);
	float x1 = lua_tonumber(L, 2);  float y1 = lua_tonumber(L, 3);  float u1 = lua_tonumber(L, 4);  float v1 = lua_tonumber(L, 5); 
	float x2 = lua_tonumber(L, 6);  float y2 = lua_tonumber(L, 7);  float u2 = lua_tonumber(L, 8);  float v2 = lua_tonumber(L, 9); 
	float x3 = lua_tonumber(L, 10); float y3 = lua_tonumber(L, 11); float u3 = lua_tonumber(L, 12); float v3 = lua_tonumber(L, 13); 
	float x4 = lua_tonumber(L, 14); float y4 = lua_tonumber(L, 15); float u4 = lua_tonumber(L, 16); float v4 = lua_tonumber(L, 17); 
	float r = lua_tonumber(L, 18); float g = lua_tonumber(L, 19); float b = lua_tonumber(L, 20); float a = lua_tonumber(L, 21);
	(*v)->addQuad(
		x1, y1, u1, v1, 
		x2, y2, u2, v2, 
		x3, y3, u3, v3, 
		x4, y4, u4, v4, 
		r, g, b, a
	);
	return 0;
}

static int gl_vertexes_texture(lua_State *L)
{
	DORVertexes **v = (DORVertexes**)auxiliar_checkclass(L, "gl{vertexes}", 1);
	texture_type *t = (texture_type*)auxiliar_checkclass(L, "gl{texture}", 2);
	lua_pushvalue(L, 2);
	(*v)->setTexture(t->tex, luaL_ref(L, LUA_REGISTRYINDEX));

	return 0;
}

static int gl_vertexes_shader(lua_State *L)
{
	DORVertexes **v = (DORVertexes**)auxiliar_checkclass(L, "gl{vertexes}", 1);
	shader_type *shader = (shader_type*)lua_touserdata(L, 2);
	(*v)->setShader(shader);
	return 0;
}

/******************************************************************
 ** Text
 ******************************************************************/
static int gl_text_new(lua_State *L)
{
	DORText **v = (DORText**)lua_newuserdata(L, sizeof(DORText*));
	auxiliar_setclass(L, "gl{text}", -1);
	*v = new DORText();
	(*v)->setLuaState(L);

	font_type *f = (font_type*)auxiliar_checkclass(L, "sdl{font}", 1);
	if (lua_isnumber(L, 2)) (*v)->setMaxWidth(lua_tonumber(L, 2));
	(*v)->setNoLinefeed(lua_toboolean(L, 3));

	lua_pushvalue(L, 1);
	(*v)->setFont(f, luaL_ref(L, LUA_REGISTRYINDEX));

	return 1;
}

static int gl_text_free(lua_State *L)
{
	DORText **v = (DORText**)auxiliar_checkclass(L, "gl{text}", 1);
	delete(*v);
	lua_pushnumber(L, 1);
	return 1;
}

static int gl_text_linefeed(lua_State *L)
{
	DORText **v = (DORText**)auxiliar_checkclass(L, "gl{text}", 1);
	(*v)->setNoLinefeed(!lua_toboolean(L, 2));

	return 0;
}

static int gl_text_max_width(lua_State *L)
{
	DORText **v = (DORText**)auxiliar_checkclass(L, "gl{text}", 1);
	(*v)->setMaxWidth(lua_tonumber(L, 2));

	return 0;
}

static int gl_text_text_color(lua_State *L)
{
	DORText **v = (DORText**)auxiliar_checkclass(L, "gl{text}", 1);
	(*v)->setTextColor(lua_tonumber(L, 2), lua_tonumber(L, 3), lua_tonumber(L, 4), lua_tonumber(L, 5));

	return 0;
}

static int gl_text_set(lua_State *L)
{
	DORText **v = (DORText**)auxiliar_checkclass(L, "gl{text}", 1);
	(*v)->setText(lua_tostring(L, 2));

	return 0;
}

static int gl_text_stats(lua_State *L)
{
	DORText **v = (DORText**)auxiliar_checkclass(L, "gl{text}", 1);

	lua_pushnumber(L, (*v)->w);
	lua_pushnumber(L, (*v)->h);
	lua_pushnumber(L, (*v)->nb_lines);
	return 3;
}

static int gl_text_shader(lua_State *L)
{
	DORText **v = (DORText**)auxiliar_checkclass(L, "gl{text}", 1);
	shader_type *shader = (shader_type*)lua_touserdata(L, 2);
	(*v)->setShader(shader);
	return 0;
}


/******************************************************************
 ** Lua declarations
 ******************************************************************/

static const struct luaL_Reg gl_renderer_reg[] =
{
	{"__gc", gl_renderer_free},
	{"zSort", gl_renderer_zsort},
	{"color", gl_generic_color},
	{"translate", gl_generic_translate},
	{"rotate", gl_generic_rotate},
	{"scale", gl_generic_scale},
	{"add", gl_renderer_add},
	{"remove", gl_renderer_remove},
	{"clear", gl_renderer_clear},
	{"cutoff", gl_renderer_cutoff},
	{"toScreen", gl_renderer_toscreen},
	{NULL, NULL},
};

static const struct luaL_Reg gl_target_reg[] =
{
	{"__gc", gl_target_free},
	{"use", gl_target_use},
	{"displaySize", gl_target_displaysize},
	{"clearColor", gl_target_clearcolor},
	{"color", gl_generic_color},
	{"translate", gl_generic_translate},
	{"rotate", gl_generic_rotate},
	{"scale", gl_generic_scale},
	{NULL, NULL},
};

static const struct luaL_Reg gl_container_reg[] =
{
	{"__gc", gl_container_free},
	{"add", gl_container_add},
	{"remove", gl_container_remove},
	{"clear", gl_container_clear},
	{"color", gl_generic_color},
	{"translate", gl_generic_translate},
	{"rotate", gl_generic_rotate},
	{"scale", gl_generic_scale},
	{NULL, NULL},
};

static const struct luaL_Reg gl_vertexes_reg[] =
{
	{"__gc", gl_vertexes_free},
	{"quad", gl_vertexes_quad},
	{"texture", gl_vertexes_texture},
	{"shader", gl_vertexes_shader},
	{"color", gl_generic_color},
	{"translate", gl_generic_translate},
	{"rotate", gl_generic_rotate},
	{"scale", gl_generic_scale},
	{NULL, NULL},
};

static const struct luaL_Reg gl_text_reg[] =
{
	{"__gc", gl_text_free},
	{"text", gl_text_set},
	{"textColor", gl_text_text_color},
	{"getStats", gl_text_stats},
	{"maxWidth", gl_text_max_width},
	{"linefeed", gl_text_linefeed},
	{"shader", gl_text_shader},
	{"color", gl_generic_color},
	{"translate", gl_generic_translate},
	{"rotate", gl_generic_rotate},
	{"scale", gl_generic_scale},
	{NULL, NULL},
};

const luaL_Reg rendererlib[] = {
	{"renderer", gl_renderer_new},
	{"vertexes", gl_vertexes_new},
	{"text", gl_text_new},
	{"container", gl_container_new},
	{"target", gl_target_new},
	{NULL, NULL}
};

int luaopen_renderer(lua_State *L)
{
	auxiliar_newclass(L, "gl{renderer}", gl_renderer_reg);
	auxiliar_newclass(L, "gl{vertexes}", gl_vertexes_reg);
	auxiliar_newclass(L, "gl{text}", gl_text_reg);
	auxiliar_newclass(L, "gl{container}", gl_container_reg);
	auxiliar_newclass(L, "gl{target}", gl_target_reg);
	luaL_openlib(L, "core.renderer", rendererlib, 0);
	return 1;
}
