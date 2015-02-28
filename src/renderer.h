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

#ifndef RENDERER_H
#define RENDERER_H

#include "display.h"
#include "vertex_objects.h"
#include "useshader.h"

typedef struct {
	GLuint vbo;
	GLuint mode;
	GLenum kind;
} vertexes_renderer;

extern bool use_modern_gl;

extern vertexes_renderer* vertexes_renderer_new(vertex_mode kind, render_mode mode);
extern void vertexes_renderer_free(vertexes_renderer *vr);
extern void vertexes_renderer_toscreen(vertexes_renderer *vr, lua_vertexes *vx, float x, float y, float r, float g, float b, float a);
extern void renderer_init(int w, int h);
extern void renderer_translate(float x, float y, float z);
extern void renderer_scale(float x, float y, float z);
extern void renderer_rotate(float a, float x, float y, float z);
extern void renderer_pushstate(bool isworld);
extern void renderer_popstate(bool isworld);
extern void renderer_identity(bool isworld);
extern void renderer_push_ortho_state(int w, int h);
extern void renderer_pop_ortho_state();


#endif