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
#ifndef DISPLAYOBJECTS_H
#define DISPLAYOBJECTS_H

extern "C" {
#include "tgl.h"
#include "useshader.h"
extern lua_State *L;
}

#include <vector>

#define GLM_FORCE_INLINE
#include "glm/glm.hpp"
#include "glm/gtc/matrix_transform.hpp"
#include "glm/gtc/type_ptr.hpp"
#include "glm/ext.hpp"

using namespace glm;
using namespace std;

enum class RenderKind { QUADS, TRIANGLES, POINTS, LINES }; 

class View;
class RendererGL;
class DisplayObject;
class DORPhysic;

#define DO_STANDARD_CLONE_METHOD(class_name) virtual DisplayObject* clone() { DisplayObject *into = new class_name(); this->cloneInto(into); return into; }

const int DO_MAX_TEX = 3;

enum {
	VERTEX_BASE = 0,
	VERTEX_MAP_INFO = 1,
	VERTEX_KIND_INFO = 2,
	VERTEX_MODEL_INFO = 4,
	VERTEX_PICKING_INFO = 8,
	VERTEX_NORMAL_INFO = 16,
};

struct vertex {
	vec4 pos;
	vec2 tex;
	vec4 color;
};
struct vertex_map_info {
	vec4 texcoords;
	vec4 mapcoords;
};
struct vertex_kind_info {
	float kind;
};
struct vertex_picking_info {
	float id[4];
};
struct vertex_model_info {
	mat4 model;
};
struct vertex_normal_info {
	vec3 normal;
};

struct recomputematrix {
	mat4 model;
	vec4 color;
	bool visible;
};

enum TweenSlot : unsigned char {
	TX = 0, TY = 1, TZ = 2, 
	SX = 3, SY = 4, SZ = 5, 
	RX = 6, RY = 7, RZ = 8, 
	R = 9, G = 10, B = 11, A = 12,
	WAIT = 13,
	UNI1 = 14, UNI2 = 15, UNI3 = 16, 
	MAX = 17
};

inline void pickingConvertTo(uint32_t id, vertex_picking_info &picking) {
	picking.id[0] = (float)(id & 0xFF) / 255.0;
	picking.id[1] = (float)((id >> 8) & 0xFF) / 255.0;
	picking.id[2] = (float)((id >> 16) & 0xFF) / 255.0;
	picking.id[3] = 1.0;
}

typedef float (*easing_ptr)(float,float,float);

struct TweenState {
	easing_ptr easing;
	float from, to;
	float cur, time;
	int on_end_ref, on_change_ref;
};

class DORTweener : public IRealtime {
protected:
	DisplayObject *who = NULL;
	array<TweenState, (short)TweenSlot::MAX> tweens;

public:
	DORTweener(DisplayObject *d);
	virtual ~DORTweener();
	virtual void killMe();
	bool hasTween(TweenSlot slot);
	void setTween(TweenSlot slot, easing_ptr easing, float from, float to, float time, int on_end_ref, int on_change_ref);
	void cancelTween(TweenSlot slot);
	virtual void onKeyframe(float nb_keyframes);
};

extern int donb;

enum class SortAxis { NONE, X, Y, Z, GFX }; 

/****************************************************************************
 ** All childs of that can be sorted in fast mode by RendererGl
 ****************************************************************************/
class DORFlatSortable {
public:
	shader_type *sort_shader;
	array<GLuint, DO_MAX_TEX> sort_tex;
	vec4 sort_coords;
};

/****************************************************************************
 ** Generic display object
 ****************************************************************************/
class DisplayObject : public DORFlatSortable {
	friend class DORPhysic;
	friend class DORTweener;
	friend class View;
public:
	static int weak_registry_ref;
	static bool pixel_perfect;
	static uint32_t do_nb;
protected:
	int weak_self_ref = LUA_NOREF;
	int lua_ref = LUA_NOREF;
	// lua_State *L = NULL;
	mat4 model;
	vec4 color;
	vec4 sort_center = vec4(0, 0, 0, 1);
	bool sort_center_set = false;
	SortAxis sort_axis = SortAxis::Z;
	bool visible = true;
	float x = 0, y = 0, z = 0;
	float rot_x = 0, rot_y = 0, rot_z = 0;
	float scale_x = 1, scale_y = 1, scale_z = 1;
	bool changed = true;
	bool changed_children = true;
	bool stop_parent_recursing = false;

	DORTweener *tweener = NULL;
	vector<DORPhysic*> physics;
	
	virtual void cloneInto(DisplayObject *into);
public:
	DisplayObject *parent = NULL;
	DisplayObject();
	virtual ~DisplayObject();
	virtual const char* getKind() = 0;
	virtual DisplayObject* clone() = 0;

	// void setLuaState(lua_State *L) { this->L = L; };
	void setWeakSelfRef(int ref) {weak_self_ref = ref; };
	int getWeakSelfRef() { return weak_self_ref; };
	void setLuaRef(int ref) {lua_ref = ref; };
	int unsetLuaRef() { int ref = lua_ref; lua_ref = LUA_NOREF; return ref; };
	void setParent(DisplayObject *parent);
	void removeFromParent();
	void setChanged(bool force=false);
	virtual void setSortingChanged();
	bool isChanged() { return changed; };
	void resetChanged() { changed = false; changed_children = false; };
	bool independantRenderer() { return stop_parent_recursing; };

	int enablePhysic();
	DORPhysic *getPhysic(int pid);
	void destroyPhysic(int pid);

	void recomputeModelMatrix();
	recomputematrix computeParentCompositeMatrix(DisplayObject *stop_at, recomputematrix cur);

	vec4 getColor() { return color; };
	void getRotate(float *dx, float *dy, float *dz) { *dx = rot_x; *dy = rot_y; *dz = rot_z; };
	void getTranslate(float *dx, float *dy, float *dz) { *dx = x; *dy = y; *dz = z; };
	vec4 getTranslate() { return vec4(x, y, z, 1); };
	void getScale(float *dx, float *dy, float *dz) { *dx = scale_x; *dy = scale_y; *dz = scale_z; };
	bool getShown() { return visible; };

	void setColor(float r, float g, float b, float a);
	void resetModelMatrix();
	void translate(float x, float y, float z, bool increment);
	void rotate(float x, float y, float z, bool increment);
	void scale(float x, float y, float z, bool increment);
	void shown(bool v);
	void sortCenter(float x, float y, float z);

	bool hasTween(TweenSlot slot);
	void tween(TweenSlot slot, easing_ptr easing, float from, float to, float time, int on_end_ref, int on_change_ref);
	void cancelTween(TweenSlot slot);
	float getDefaultTweenSlotValue(TweenSlot slot);

	virtual void tick() {}; // Overload that and register your object into a display list's tick to interrupt display list chain and call tick() before your first one is displayed

	virtual void render(RendererGL *container, mat4& cur_model, vec4& color, bool cur_visible) = 0;
	// virtual void renderZ(RendererGL *container, mat4& cur_model, vec4& color, bool cur_visible) = 0;
	virtual void sortCoords(RendererGL *container, mat4& cur_model);
};

/****************************************************************************
 ** DO that has a vertex list
 ****************************************************************************/
class DORVertexes : public DisplayObject {
	friend class DisplayObject;
	friend class DORTweener;
protected:
	RenderKind render_kind = RenderKind::QUADS;
	uint8_t data_kind = VERTEX_BASE;
	vector<vertex> vertices;
	vector<vertex_map_info> vertices_map_info;
	vector<vertex_kind_info> vertices_kind_info;
	vector<vertex_model_info> vertices_model_info;
	vector<vertex_picking_info> vertices_picking_info;
	vector<vertex_normal_info> vertices_normal_info;
	array<int, DO_MAX_TEX> tex_lua_ref{{ LUA_NOREF, LUA_NOREF, LUA_NOREF}};
	array<GLuint, DO_MAX_TEX> tex{{0, 0, 0}};
	int tex_max = 1;

	array<GLint, 3> tween_uni{{0, 0, 0}};
	array<GLfloat, 3> tween_uni_val{{0, 0, 0}};

	shader_type *shader;

	virtual void cloneInto(DisplayObject *into);

public:
	DORVertexes() {
		vertices.reserve(4);
		shader = default_shader;
	};
	virtual ~DORVertexes();
	DO_STANDARD_CLONE_METHOD(DORVertexes);
	virtual const char* getKind() { return "DORVertexes"; };

	void clear();

	void setDataKinds(uint8_t kinds);
	void setRenderKind(RenderKind kind) { render_kind = kind; }

	void reserveQuads(int nb) { if (nb <= 0) return; vertices.reserve(4 * nb); };

	int addQuadPie(
		float x1, float y1, float x2, float y2,
		float u1, float v1, float u2, float v2,
		float angle,
		float r, float g, float b, float a
	);
	int addQuad(
		float x1, float y1, float u1, float v1, 
		float x2, float y2, float u2, float v2, 
		float x3, float y3, float u3, float v3, 
		float x4, float y4, float u4, float v4, 
		float r, float g, float b, float a
	);
	int addQuad(
		float x1, float y1, float z1, float u1, float v1, 
		float x2, float y2, float z2, float u2, float v2, 
		float x3, float y3, float z3, float u3, float v3, 
		float x4, float y4, float z4, float u4, float v4, 
		float r, float g, float b, float a
	);
	int addQuad(vertex v1, vertex v2, vertex v3, vertex v4);
	int addQuadKindInfo(float v1, float v2, float v3, float v4);
	int addQuadMapInfo(vertex_map_info v1, vertex_map_info v2, vertex_map_info v3, vertex_map_info v4);
	int addQuadPickingInfo(vertex_picking_info v1, vertex_picking_info v2, vertex_picking_info v3, vertex_picking_info v4);
	int addQuadNormalInfo(vertex_normal_info n1, vertex_normal_info n2, vertex_normal_info n3, vertex_normal_info n4);

	int addPoint(
		float x1, float y1, float z1, float u1, float v1, 
		float r, float g, float b, float a
	);

	void loadObj(const string &filename);
	GLuint getTexture(int id) { return tex[id]; };
	virtual void setTexture(GLuint tex, int lua_ref, int id);
	virtual void setTexture(GLuint tex, int lua_ref) { setTexture(tex, lua_ref, 0); };
	void setShader(shader_type *s);
	void getShaderUniformTween(const char *uniform, uint8_t pos, float default_val);

	virtual void render(RendererGL *container, mat4& cur_model, vec4& color, bool cur_visible);
	virtual void sortCoords(RendererGL *container, mat4& cur_model);
};

/****************************************************************************
 ** DO that can contain others
 ****************************************************************************/
class IContainer{
protected:
	vector<DisplayObject*> dos;
public:
	IContainer() {};
	virtual ~IContainer() {};

	virtual void containerAdd(DisplayObject *self, DisplayObject *dob);
	virtual bool containerRemove(DisplayObject *dob);
	virtual void containerClear();

	virtual void containerRender(RendererGL *container, mat4& cur_model, vec4& color, bool cur_visible);
	virtual void containerSortCoords(RendererGL *container, mat4& cur_model);
};
class DORContainer : public DisplayObject, public IContainer{
protected:
	virtual void cloneInto(DisplayObject *into);
public:
	DORContainer() {};
	virtual ~DORContainer();
	DO_STANDARD_CLONE_METHOD(DORContainer);
	virtual const char* getKind() { return "DORContainer"; };

	virtual void add(DisplayObject *dob);
	virtual void remove(DisplayObject *dob);
	virtual void clear();

	virtual void render(RendererGL *container, mat4& cur_model, vec4& color, bool cur_visible);
	virtual void sortCoords(RendererGL *container, mat4& cur_model);
};


/****************************************************************************
 ** Interface to make a DisplayObject be a sub-renderer: breaking chaining
 ** and using it's own render method
 ****************************************************************************/
class SubRenderer : public DORContainer {
	friend class RendererGL;
protected:
	vec4 use_color;
	mat4 use_model;
	char *renderer_name = NULL;

	virtual void cloneInto(DisplayObject *into);
public:
	SubRenderer() { renderer_name = strdup(getKind()); stop_parent_recursing = true; };
	~SubRenderer() { free((void*)renderer_name); };
	const char* getRendererName() { return renderer_name ? renderer_name : "---unknown---"; };
	void setRendererName(const char *name);
	void setRendererName(char *name, bool copy);

	virtual void render(RendererGL *container, mat4& cur_model, vec4& color, bool cur_visible);
	virtual void sortCoords(RendererGL *container, mat4& cur_model);

	virtual void toScreenSimple();
	virtual void toScreen(mat4 cur_model, vec4 color) = 0;
};


/****************************************************************************
 ** Interface to make a DisplayObject be a sub-renderer: breaking chaining
 ** and using it's own render method
 ****************************************************************************/
typedef void (*static_sub_cb)(mat4 cur_model, vec4 color);
class StaticSubRenderer : public  SubRenderer {
protected:
	static_sub_cb cb;
	virtual void cloneInto(DisplayObject *into);
public:
	StaticSubRenderer(static_sub_cb cb) : cb(cb) {};
	virtual void toScreen(mat4 cur_model, vec4 color);
};


/****************************************************************************
 ** A Dummy DO taht displays nothing and instead calls a lua callback
 ****************************************************************************/
class DORCallback : public SubRenderer, public IRealtime {
protected:
	int cb_ref = LUA_NOREF;
	bool enabled = true;
	float keyframes = 0;

	virtual void cloneInto(DisplayObject *into);

public:
	DORCallback() { };
	virtual ~DORCallback() { refcleaner(&cb_ref); };
	DO_STANDARD_CLONE_METHOD(DORCallback);
	virtual const char* getKind() { return "DORCallback"; };

	void setCallback(int ref) {
		refcleaner(&cb_ref);
		cb_ref = ref;
	};
	void enable(bool v) { enabled = v; setChanged(); };

	virtual void toScreen(mat4 cur_model, vec4 color);
	virtual void onKeyframe(float nb_keyframes);
};

#endif
