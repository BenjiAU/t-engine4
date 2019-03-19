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
#ifndef __TGL_H
#define __TGL_H

#ifdef __APPLE__
#include <OpenGL/gl.h>
#include <OpenGL/glu.h>
#include <OpenGL/glext.h>
#else
#ifdef _WIN32
#include <windows.h>
#endif
#include <GL/gl.h>
#include <GL/glu.h>
#ifndef _WIN32
#include <GL/glext.h>
#endif
#endif

#define KEYFRAMES_PER_SEC 30

// typedef struct {
// 	GLuint tex;
// 	int w, h;
// 	bool no_free;
// } texture_type;

extern GLint max_texture_size;

extern float gl_c_r;
extern float gl_c_g;
extern float gl_c_b;
extern float gl_c_a;

#define tglColor4f(r, g, b, a) \
	{ \
	if (((r) != gl_c_r) || ((g) != gl_c_g) || ((b) != gl_c_b) || ((a) != gl_c_a)) { glColor4f((r), (g), (b), (a)); gl_c_r=(r); gl_c_g=(g); gl_c_b=(b); gl_c_a=(a); } \
	}

extern float gl_c_cr;
extern float gl_c_cg;
extern float gl_c_cb;
extern float gl_c_ca;

#define tglClearColor(r, g, b, a) \
	{ \
	if (((r) != gl_c_cr) || ((g) != gl_c_cg) || ((b) != gl_c_cb) || ((a) != gl_c_ca)) { glClearColor((r), (g), (b), (a)); gl_c_cr=(r); gl_c_cg=(g); gl_c_cb=(b); gl_c_ca=(a); } \
	}

extern GLenum gl_c_texture_unit;
#define tglActiveTexture(tu) \
	{ \
	if ((tu) != gl_c_texture_unit) { glActiveTexture((tu)); gl_c_texture_unit=(tu); } \
	}

//printf("swithch texture %d : %d\n", t, glIsTexture(t));
extern GLuint gl_c_texture;
#define tglBindTexture(w, t) \
	{ \
	if ((t) != gl_c_texture) { glBindTexture((w), (t)); gl_c_texture=(t); } \
	}
#define tfglBindTexture(w, t) \
	{ \
	glBindTexture((w), (t)); gl_c_texture=(t); \
	}

extern GLuint gl_c_fbo;
#define tglBindFramebuffer(w, t) \
	{ \
	glBindFramebuffer((w), (t)); gl_c_fbo=(t); \
	}

extern GLuint gl_c_shader;
#define tglUseProgramObject(shad) \
	{ \
	if ((shad) != gl_c_shader) { glUseProgram((shad)); gl_c_shader=(shad); } \
	}


extern int nb_rgl;
extern int nb_draws;
#define glDrawArrays(a, b, c) \
	{ \
	glDrawArrays((a), (b), (c)); nb_draws++; \
	}
#define glDrawElements(a, b, c, d) \
	{ \
	glDrawElements((a), (b), (c), (d)); nb_draws++; \
	}

extern int gl_c_vertices_nb, gl_c_texcoords_nb, gl_c_colors_nb;
extern GLfloat *gl_c_vertices_ptr;
extern GLfloat *gl_c_texcoords_ptr;
extern GLfloat *gl_c_colors_ptr;
#define glVertexPointer(nb, t, v, p) \
{ \
	if ((p) != gl_c_vertices_ptr || (nb) != gl_c_vertices_nb) { glVertexPointer((nb), (t), (v), (p)); gl_c_vertices_ptr=(p); gl_c_vertices_nb = (nb); } \
}
#define glColorPointer(nb, t, v, p) \
{ \
	if ((p) != gl_c_colors_ptr || (nb) != gl_c_texcoords_nb) { glColorPointer((nb), (t), (v), (p)); gl_c_colors_ptr=(p); gl_c_colors_nb = (nb); } \
}
#define glTexCoordPointer(nb, t, v, p) \
{ \
	if ((p) != gl_c_texcoords_ptr || (nb) != gl_c_colors_nb) { glTexCoordPointer((nb), (t), (v), (p)); gl_c_texcoords_ptr=(p); gl_c_texcoords_nb = (nb); } \
}

#endif
