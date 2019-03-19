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
#include "renderer-moderngl/VBO.hpp"

class RendererGL;

/****************************************************************************
 ** Display lists contain a VBO, texture, ... and a list of vertices to be
 ** drawn; those dont change and dont get recomputed until needed
 ****************************************************************************/
class DisplayList {
public:
	int used = 0;
	GLuint vbo[5] = {0,0,0,0,0};
	textures_array tex;
	shader_type *shader = NULL;
	uint8_t data_kind = VERTEX_BASE;
	RenderKind render_kind = RenderKind::QUADS;
	vector<vertex> list;
	vector<vertex_kind_info> list_kind_info;
	vector<vertex_map_info> list_map_info;
	vector<vertex_model_info> list_model_info;
	vector<vertex_picking_info> list_picking_info;
	SubRenderer *sub = NULL;
	DisplayObject *tick = NULL;

	DisplayList();
	~DisplayList();
};

extern void stopDisplayList();
extern DisplayList* getDisplayList(RendererGL *container, textures_array &tex, shader_type *shader, uint8_t data_kind, RenderKind render_kind);
inline DisplayList* getDisplayList(RendererGL *container, GLuint tex0, shader_type *shader, uint8_t data_kind, RenderKind render_kind) { textures_array tex = tex0; return getDisplayList(container, tex, shader, data_kind, render_kind); }
inline DisplayList* getDisplayList(RendererGL *container, texture_info tex0, shader_type *shader, uint8_t data_kind, RenderKind render_kind) { textures_array tex = tex0; return getDisplayList(container, tex, shader, data_kind, render_kind); }
inline DisplayList* getDisplayList(RendererGL *container) { return getDisplayList(container, (GLuint)0, NULL, VERTEX_BASE, RenderKind::QUADS); };

/****************************************************************************
 ** Handling actual rendering to the screen & such
 ****************************************************************************/
// Full sort will sort the vertices at the end, it's slow but precise.
// Fast sort will sort the DOs, it's faster but only works on DORFlatSortable childs that are flat on the z plane
// GL sort will turn on depth test and let OpenGL handle it. Transparency will bork
enum class SortMode { NO_SORT, FAST, FULL, GL }; 

using SortMethod = bool(DORFlatSortable *i, DORFlatSortable *j);

class RendererGL : public SubRenderer {
	friend class DORVertexes;
protected:
	VBOMode mode = VBOMode::DYNAMIC;

	View *view = NULL;	

	GLuint *vbo_elements_data = NULL;
	GLuint vbo_elements = 0;
	int vbo_elements_nb = 0;
	SortMethod *sort_method;
	SortMode zsort = SortMode::NO_SORT;
	vector<DisplayList*> displays;
	bool recompute_fast_sort = true;
	bool manual_dl_management = false;

	bool count_draws = false;
	bool count_time = false;
	bool count_vertexes = false;

	bool allow_blending = true;
	bool premultiplied_alpha = false;
	bool disable_depth_writing = false;

	bool cutting = false;
	vec4 cutpos1;
	vec4 cutpos2;

	bool line_smooth = false;
	float line_width = 1;

	shader_type *my_default_shader = NULL;
	int my_default_shader_lua_ref = LUA_NOREF;

	virtual void cloneInto(DisplayObject *into);

public:
	vector<DisplayObject*> sorted_dos;
	// vector<sortable_vertex> zvertices;

	RendererGL(VBOMode mode);
	virtual ~RendererGL();
	virtual DisplayObject* clone();
	virtual const char* getKind() { return "RendererGL"; };

	virtual void addDisplayList(DisplayList* dl) {
		displays.push_back(dl);
	}

	virtual void setSortingChanged() { recompute_fast_sort = true; }

	void setShader(shader_type *s, int lua_ref);
	void cutoff(float x, float y, float w, float h) { cutting = true; cutpos1 = vec4(x, y, 0, 1); cutpos2 = vec4(x + w, y + h, 0, 1); };
	void countVertexes(bool count) { count_vertexes = count; };
	void countDraws(bool count) { count_draws = count; };
	void countTime(bool count) { count_time = count; };
	void enableSorting(bool sort) { enableSorting(sort ? SortMode::FAST : SortMode::NO_SORT); };
	void enableSorting(SortMode mode, SortAxis axis = SortAxis::Z);
	void enableBlending(bool v) { allow_blending = v; };
	void disableDepthWriting(bool v) { disable_depth_writing = v; };
	void premultipliedAlpha(bool v) { premultiplied_alpha = v; };
	void setLineMode(float size, bool smooth) { line_width = size; line_smooth = smooth; }
	void sortedToDL();
	void update();
	virtual void toScreen(mat4 cur_model, vec4 color);

	void setManualManagement(bool v) { manual_dl_management = v; };
	void resetDisplayLists();

	void setView(View *view) {
		this->view = view;
	}

	void activateCutting(mat4 cur_model, bool v);
};

#endif
