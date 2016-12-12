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

#ifndef RENDERER_GL_H
#define RENDERER_GL_H

#include "renderer-moderngl/Renderer.hpp"

class RendererGL;

typedef struct {
	vertex v;
	GLuint tex;
	shader_type *shader;
	SubRenderer *sub;
	DisplayObject *tick;
} sortable_vertex;

/****************************************************************************
 ** Display lists contain a VBO, texture, ... and a list of vertices to be
 ** drawn; those dont change and dont get recomputed until needed
 ****************************************************************************/
class DisplayList {
public:
	int used = 0;
	GLuint vbo = 0;
	GLuint tex = 0;
	shader_type *shader = NULL;
	// DGDGDGDG: make two kind of vertex, the extended & non expanded one and thus two vectors. RendererGL should be able to detect abd pul lthe correct one
	vector<vertex> list;
	SubRenderer *sub = NULL;
	DisplayObject *tick = NULL;

	DisplayList();
	~DisplayList();
};

extern void stopDisplayList();
extern DisplayList* getDisplayList(RendererGL *container, GLuint tex, shader_type *shader);

/****************************************************************************
 ** Handling actual rendering to the screen & such
 ****************************************************************************/
class RendererGL : public SubRenderer {
	friend class DORVertexes;
protected:
	GLuint mode = GL_DYNAMIC_DRAW;
	GLenum kind = GL_TRIANGLES;

	GLuint *vbo_elements_data = NULL;
	GLuint vbo_elements = 0;
	int vbo_elements_nb = 0;
	bool zsort = false;
	vector<DisplayList*> displays;
	int nb_quads = 0;
	bool manual_dl_management = false;

	bool count_draws = false;

	bool cutting = false;
	vec4 cutpos1;
	vec4 cutpos2;

	// bool post_processing = false;
	// vector<shader_type*> post_process_shaders;
	// GLuint post_process_fbos[2] = {0, 0};
	// GLuint post_process_textures[2] = {0, 0};

	virtual void cloneInto(DisplayObject *into);

public:
	vector<sortable_vertex> zvertices;

	RendererGL();
	virtual ~RendererGL();
	virtual DisplayObject* clone();
	virtual const char* getKind() { return "RendererGL"; };

	virtual void addDisplayList(DisplayList* dl) {
		displays.push_back(dl);
	}

	void cutoff(float x, float y, float w, float h) { cutting = true; cutpos1 = vec4(x, y, 0, 1); cutpos2 = vec4(x + w, y + h, 0, 1); };
	void countDraws(bool count) { count_draws = count; };
	void zSorting(bool sort) { zsort = sort; };
	void sortedToDL();
	void update();
	virtual void toScreen(mat4 cur_model, vec4 color);

	void setManualManagement(bool v) { manual_dl_management = v; };
	void resetDisplayLists();

	void activateCutting(mat4 cur_model, bool v);

	// This should be in DORTarget
	// void enablePostProcessing(bool v);
	// void clearPostProcessShaders();
	// void addPostProcessShader(shader_type *s);
};

#endif