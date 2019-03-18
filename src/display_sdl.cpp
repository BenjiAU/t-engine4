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
}
#include "display_sdl.hpp"
#include <stdlib.h>

#define DISPLAY_CHAR_SIZE  16
SDL_Surface *screen = NULL;

// Current gl color, to remove the need to call glColor4f when undeeded
float gl_c_r = 1;
float gl_c_g = 1;
float gl_c_b = 1;
float gl_c_a = 1;
float gl_c_cr = 0;
float gl_c_cg = 0;
float gl_c_cb = 0;
float gl_c_ca = 1;
GLuint gl_c_texture = 0;
GLenum gl_c_texture_unit = GL_TEXTURE0;
GLuint gl_c_fbo = 0;
GLuint gl_c_shader = 0;
int nb_draws = 0;
int gl_c_vertices_nb = 0, gl_c_texcoords_nb = 0, gl_c_colors_nb = 0;
GLfloat *gl_c_vertices_ptr = NULL;
GLfloat *gl_c_texcoords_ptr = NULL;
GLfloat *gl_c_colors_ptr = NULL;
