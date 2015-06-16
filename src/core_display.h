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
#ifndef _CORE_DISPLAY_H_
#define _CORE_DISPLAY_H_

#include "tgl.h"
#include "useshader.h"
#include "vertex_objects.h"

typedef struct
{
	GLuint fbo;
	GLuint *textures;
	GLenum *buffers;
	int nbt;
	int w, h;
} lua_fbo;

extern int gl_tex_white;
extern GLint max_texture_size;
extern lua_vertexes *generic_vx;

extern int luaopen_core_display(lua_State *L);
extern void core_display_init();
extern int sdl_surface_drawstring(lua_State *L);
extern int sdl_surface_drawstring_aa(lua_State *L);
extern SDL_Surface *SDL_DisplayFormatAlpha(SDL_Surface *surface);


#endif