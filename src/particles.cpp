/*
    TE4 - T-Engine 4
    Copyright (C) 2009 - 2017 Nicolas Casalini

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
#include "lauxlib.h"
#include "lualib.h"
#include "core_lua.h"
#include "auxiliar.h"
#include "core_lua.h"
#include "script.h"
#include <math.h>
#include "SFMT.h"
#include "tSDL.h"
#include "main.h"
#include "useshader.h"
#include "physfs.h"
#include "physfsrwops.h"
}
#include "renderer-moderngl/Particles.hpp"
#include "renderer-moderngl/FBO.hpp"
#include "particles.hpp"

// Lol or what ? Mingw64 on windows seems to not find it ..
#ifndef M_PI
#define M_PI                3.14159265358979323846
#endif
#ifndef M_PI_2
# define M_PI_2		1.57079632679489661923	/* pi/2 */
#endif

#define rng(x, y) (x + rand_div(1 + y - x))

#define PARTICLE_ETERNAL 999999
#define PARTICLES_PER_ARRAY 1000
#define ENGINE_POINTS 0
#define ENGINE_LINES 1
#define BLEND_NORMAL 0
#define BLEND_SHINY 1
#define BLEND_ADDITIVE 2
#define BLEND_MIXED 3

int MAX_THREADS = 1;
extern int nb_cpus;
static particle_thread *threads = NULL;
static int textures_ref = LUA_NOREF;
static int nb_threads = 0;
static int cur_thread = 0;
static DORTarget *alter_fbo = NULL;
static DORTarget *bloom_fbo = NULL;
static StaticSubRenderer *bloom_do = NULL;
static particle_draw_last *pdls_head = NULL;
static particle_draw_last *blooms_head = NULL;
static shader_type *default_particles_shader = NULL;
static vector<tuple<int, float, float>> trigger_cbs(1000);
void thread_add(particles_type *ps);

/********************************************
 ** Panic handling
 ********************************************/
static int particles_lua_panic_handler(lua_State *L)
{
	lua_getglobal(L, "__threaddata");
	particle_thread *pt = (particle_thread*)lua_touserdata(L, -1);
	lua_pop(L, 1);
	printf("Particle thread %d got a panic error, recovering: %s\n", pt->id, lua_tostring(L, -1));
	lua_pop(L, lua_gettop(L));
	longjmp(pt->panicjump, 1);
	return 0;
}
/********************************************/

static shader_type *lua_get_shader(lua_State *L, int idx) {
	if (lua_istable(L, idx)) {
		lua_pushliteral(L, "shad");
		lua_gettable(L, idx);
		shader_type *s = (shader_type*)lua_touserdata(L, -1);
		lua_pop(L, 1);
		return s;
	} else {
		return (shader_type*)lua_touserdata(L, idx);
	}
}

static void getinitfield(lua_State *L, const char *key, int *min, int *max)
{
	lua_pushstring(L, key);
	lua_gettable(L, -2);

	lua_pushnumber(L, 1);
	lua_gettable(L, -2);
	*min = (int)lua_tonumber(L, -1);
	lua_pop(L, 1);

	lua_pushnumber(L, 2);
	lua_gettable(L, -2);
	*max = (int)lua_tonumber(L, -1);
	lua_pop(L, 1);

//	printf("%s :: %d %d\n", key, (int)*min, (int)*max);

	lua_pop(L, 1);
}

static void getparticulefield(lua_State *L, const char *k, float *v)
{
	lua_pushstring(L, k);
	lua_gettable(L, -2);
	*v = (float)lua_tonumber(L, -1);
//	printf("emit %s :: %f\n", k, *v);
	lua_pop(L, 1);
}

static int particles_flush_last(lua_State *L)
{
	while (pdls_head) {
		particle_draw_last *pdl = pdls_head;
		pdls_head = pdls_head->next;
		free(pdl);
	}
	while (blooms_head) {
		particle_draw_last *pdl = blooms_head;
		blooms_head = blooms_head->next;
		free(pdl);
	}
	for (auto &t : trigger_cbs) {
		lua_rawgeti(L, LUA_REGISTRYINDEX, std::get<0>(t));
		lua_pushnumber(L, std::get<1>(t));
		lua_pushnumber(L, std::get<2>(t));
		if (lua_pcall(L, 2, 0, 0)) {
			printf("Particle trigger error: %s\n", lua_tostring(L, -1));
			lua_pop(L, 1);
		}
	}
	trigger_cbs.clear();
	return 0;
}

static int particles_alter_fbo(lua_State *L)
{
	while (pdls_head) {
		particle_draw_last *pdl = pdls_head;
		pdls_head = pdls_head->next;
		free(pdl);
	}

	if (lua_isnil(L, 1)) {
		alter_fbo = NULL;
		return 0;
	}

	alter_fbo = userdata_to_DO<DORTarget>(__FUNCTION__, L, 1, "gl{target}");
	return 0;
}

static int particles_bloom_fbo(lua_State *L)
{
	while (blooms_head) {
		particle_draw_last *pdl = blooms_head;
		blooms_head = blooms_head->next;
		free(pdl);
	}

	if (lua_isnil(L, 1)) {
		bloom_fbo = NULL;
		return 0;
	}

	bloom_fbo = userdata_to_DO<DORTarget>(__FUNCTION__, L, 1, "gl{target}");
	return 0;
}

// Runs into main thread
static int particles_new(lua_State *L)
{
	const char *name_def = luaL_checkstring(L, 1);
	const char *args = luaL_checkstring(L, 2);
	// float zoom = luaL_checknumber(L, 3);
	int density = luaL_checknumber(L, 4);
	texture_type *texture = (texture_type*)auxiliar_checkclass(L, "gl{texture}", 5);
	shader_type *s = NULL;
	if (lua_isuserdata(L, 6)) s = lua_get_shader(L, 6);
	bool fboalter = lua_toboolean(L, 7);
	bool allow_bloom = lua_toboolean(L, 8);

	particles_type *ps = (particles_type*)lua_newuserdata(L, sizeof(particles_type));
	auxiliar_setclass(L, "core{particles}", -1);

	ps->lock = SDL_CreateMutex();
	ps->name_def = strdup(name_def);
	ps->args = strdup(args);
	ps->shift_x = ps->shift_y = 0;
	ps->density = density;
	ps->alive = TRUE;
	ps->i_want_to_die = FALSE;
	ps->l = NULL;
	ps->vertices = NULL;
	ps->particles = NULL;
	ps->init = FALSE;
	ps->send_value = 0;
	ps->send_value_pt = 0;
	ps->trigger_old = 0;
	ps->trigger = 0;
	ps->trigger_pass = 0;
	ps->trigger_cb = LUA_NOREF;
	ps->texture = texture->tex;
	ps->shader = s;
	ps->fboalter = fboalter;
	ps->allow_bloom = allow_bloom;
	ps->sub = NULL;
	ps->recompile = FALSE;
	glGenBuffers(1, &ps->vbo);
	ps->vbo_elements = 0;

	thread_add(ps);
	return 1;
}

static int particles_set_sub(lua_State *L) 
{
	particles_type *ps = (particles_type*)auxiliar_checkclass(L, "core{particles}", 1);
	particles_type *subps = (particles_type*)auxiliar_checkclass(L, "core{particles}", 2);

	ps->sub = subps;

	return 0;
}

static int particles_trigger_cb(lua_State *L) 
{
	particles_type *ps = (particles_type*)auxiliar_checkclass(L, "core{particles}", 1);
	lua_pushvalue(L, 2);
	ps->trigger_cb = luaL_ref(L, LUA_REGISTRYINDEX);

	return 0;
}

static int particles_send_value(lua_State *L) 
{
	particles_type *ps = (particles_type*)auxiliar_checkclass(L, "core{particles}", 1);
	ps->send_value = lua_tonumber(L, 2);

	return 0;
}

static void do_shift(particles_type *ps, float sx, float sy, bool set) {
	SDL_mutexP(ps->lock);

	if (set) {
		ps->shift_x = sx;
		ps->shift_y = sy;
	} else {
		ps->shift_x += sx;
		ps->shift_y += sy;
	}

	SDL_mutexV(ps->lock);

	if (ps->sub) do_shift(ps->sub, sx, sy, set);
}

// Runs into main thread
static int particles_shift(lua_State *L)
{
	particles_type *ps = (particles_type*)auxiliar_checkclass(L, "core{particles}", 1);
	if (lua_toboolean(L, 4)) {
		float sx = lua_tonumber(L, 2);
		float sy = lua_tonumber(L, 3);
		do_shift(ps, sx, sy, true);
	} else {
		float sx = lua_tonumber(L, 2);
		float sy = lua_tonumber(L, 3);
		if (!sx && !sy) return 0;
		do_shift(ps, sx, sy, false);
	}
	return 0;
}

// Runs into main thread
static int particles_free(lua_State *L)
{
	particles_type *ps = (particles_type*)auxiliar_checkclass(L, "core{particles}", 1);
	plist *l = ps->l;

//	printf("Deleting particle from main lua state %x :: %x\n", (int)ps->l, (int)ps);

	if (l && l->pt) SDL_mutexP(l->pt->lock);

	ps->alive = FALSE;
	if (l) l->ps = NULL;
	ps->l = NULL;
	SDL_DestroyMutex(ps->lock);

	if (ps->vertices) { free(ps->vertices); ps->vertices = NULL; }
	if (ps->particles) { free(ps->particles); ps->particles = NULL; }

	if (l && l->pt) SDL_mutexV(l->pt->lock);

	if (ps->vbo) glDeleteBuffers(1, &ps->vbo);
	if (ps->vbo_elements) glDeleteBuffers(1, &ps->vbo_elements);

	if (ps->trigger_cb != LUA_NOREF) luaL_unref(L, LUA_REGISTRYINDEX, ps->trigger_cb);

	lua_pushnumber(L, 1);
	return 1;
}

// Runs into main thread
static int particles_is_alive(lua_State *L)
{
	particles_type *ps = (particles_type*)auxiliar_checkclass(L, "core{particles}", 1);

	lua_pushboolean(L, ps->alive);
	return 1;
}

// Runs into main thread
static int particles_die(lua_State *L)
{
	particles_type *ps = (particles_type*)auxiliar_checkclass(L, "core{particles}", 1);

	ps->i_want_to_die = TRUE;
	return 1;
}

// Runs into particles thread
static void particles_update(particles_type *ps, bool last, bool no_update)
{
	int w = 0;
	bool alive = FALSE;
	float zoom = 1;
	float i, j;
	float a;
	float lx, ly, lsize;

	if (!ps->init) return;

	if (last) SDL_mutexP(ps->lock);

	ps->recompile = FALSE;

	particles_vertex *vertices = ps->vertices;

	if (!no_update) ps->rotate += ps->rotate_v;

	ps->batch_nb = 0;
	for (w = 0; w < ps->nb; w++)
	{
		particle_type *p = &ps->particles[w];

		if (p->life > 0)
		{
			if (!no_update) {
				alive = TRUE;

				if (p->life != PARTICLE_ETERNAL) p->life--;

				p->ox = p->x;
				p->oy = p->y;

				p->x += p->xv;
				p->y += p->yv;

				if (p->vel)
				{
					p->x += cos(p->dir) * p->vel;
					p->y += sin(p->dir) * p->vel;
				}

				p->dir += p->dirv;
				p->vel += p->velv;
				p->r += p->rv;
				p->g += p->gv;
				p->b += p->bv;
				p->a += p->av;
				p->size += p->sizev;

				p->xv += p->xa;
				p->yv += p->ya;
				p->dirv += p->dira;
				p->velv += p->vela;
				p->rv += p->ra;
				p->gv += p->ga;
				p->bv += p->ba;
				p->av += p->aa;
				p->sizev += p->sizea;
			}

			if (last)
			{
				float r = p->r, g = p->g, b = p->b, a = p->a;
				if (ps->engine == ENGINE_LINES) {
					if (p->trail >= 0 && p->trail < ps->nb) {
						lx = ps->particles[p->trail].x;
						ly = ps->particles[p->trail].y;
						lsize = ps->particles[p->trail].size;
						float angle = atan2(p->y - ly, p->x - lx) + M_PI_2;
						float cangle = cos(angle);
						float sangle = sin(angle);
						// printf("%d: trailing from %d: %fx%f(%f) with angle %f to %fx%f(%f)\n",w, p->trail, lx,ly,lsize,angle*180/M_PI,p->x,p->y,p->size);

						vertices[ps->batch_nb++] = particles_vertex({{lx + cangle * lsize / 2, ly + sangle * lsize / 2, 0, 1}, {p->u1, p->v1}, {r, g, b, a}});
						vertices[ps->batch_nb++] = particles_vertex({{lx - cangle * lsize / 2, ly - sangle * lsize / 2, 0, 1}, {p->u2, p->v1}, {r, g, b, a}});
						vertices[ps->batch_nb++] = particles_vertex({{p->x - cangle * p->size / 2, p->y - sangle * p->size / 2, 0, 1}, {p->u2, p->v2}, {r, g, b, a}});
						vertices[ps->batch_nb++] = particles_vertex({{p->x + cangle * p->size / 2, p->y + sangle * p->size / 2, 0, 1}, {p->u1, p->v2}, {r, g, b, a}});
					}
				} else {
					if (!p->trail)
					{
						i = p->x * zoom - p->size / 2;
						j = p->y * zoom - p->size / 2;

						vertices[ps->batch_nb++] = particles_vertex({{i, j, 0, 1}, {p->u1, p->v1}, {r, g, b, a}});
						vertices[ps->batch_nb++] = particles_vertex({{p->size + i, j, 0, 1}, {p->u2, p->v1}, {r, g, b, a}});
						vertices[ps->batch_nb++] = particles_vertex({{p->size + i, p->size + j, 0, 1}, {p->u2, p->v2}, {r, g, b, a}});
						vertices[ps->batch_nb++] = particles_vertex({{i, p->size + j, 0, 1}, {p->u1, p->v2}, {r, g, b, a}});
					}
					else
					{
						if ((p->ox <= p->x) && (p->oy <= p->y))
						{
							vertices[ps->batch_nb++] = particles_vertex({{0 +  p->ox * zoom, 0 +  p->oy * zoom, 0, 1}, {p->u1, p->v1}, {r, g, b, a}});
							vertices[ps->batch_nb++] = particles_vertex({{p->size +  p->x * zoom, 0 +  p->y * zoom, 0, 1}, {p->u2, p->v1}, {r, g, b, a}});
							vertices[ps->batch_nb++] = particles_vertex({{p->size +  p->x * zoom, p->size +  p->y * zoom, 0, 1}, {p->u2, p->v2}, {r, g, b, a}});
							vertices[ps->batch_nb++] = particles_vertex({{0 +  p->x * zoom, p->size +  p->y * zoom, 0, 1}, {p->u1, p->v2}, {r, g, b, a}});
						}
						else if ((p->ox <= p->x) && (p->oy > p->y))
						{
							vertices[ps->batch_nb++] = particles_vertex({{0 +  p->x * zoom, 0 +  p->y * zoom, 0, 1}, {p->u1, p->v1}, {r, g, b, a}});
							vertices[ps->batch_nb++] = particles_vertex({{p->size +  p->x * zoom, 0 +  p->y * zoom, 0, 1}, {p->u2, p->v1}, {r, g, b, a}});
							vertices[ps->batch_nb++] = particles_vertex({{p->size +  p->x * zoom, p->size +  p->y * zoom, 0, 1}, {p->u2, p->v2}, {r, g, b, a}});
							vertices[ps->batch_nb++] = particles_vertex({{0 +  p->ox * zoom, p->size +  p->oy * zoom, 0, 1}, {p->u1, p->v2}, {r, g, b, a}});
						}
						else if ((p->ox > p->x) && (p->oy <= p->y))
						{
							vertices[ps->batch_nb++] = particles_vertex({{0 +  p->x * zoom, 0 +  p->y * zoom, 0, 1}, {p->u1, p->v1}, {r, g, b, a}});
							vertices[ps->batch_nb++] = particles_vertex({{p->size +  p->ox * zoom, 0 +  p->oy * zoom, 0, 1}, {p->u2, p->v1}, {r, g, b, a}});
							vertices[ps->batch_nb++] = particles_vertex({{p->size +  p->x * zoom, p->size +  p->y * zoom, 0, 1}, {p->u2, p->v2}, {r, g, b, a}});
							vertices[ps->batch_nb++] = particles_vertex({{0 +  p->x * zoom, p->size +  p->y * zoom, 0, 1}, {p->u1, p->v2}, {r, g, b, a}});
						}
						else if ((p->ox > p->x) && (p->oy > p->y))
						{
							vertices[ps->batch_nb++] = particles_vertex({{0 +  p->x * zoom, 0 +  p->y * zoom, 0, 1}, {p->u1, p->v1}, {r, g, b, a}});
							vertices[ps->batch_nb++] = particles_vertex({{p->size +  p->x * zoom, 0 +  p->y * zoom, 0, 1}, {p->u2, p->v1}, {r, g, b, a}});
							vertices[ps->batch_nb++] = particles_vertex({{p->size +  p->ox * zoom, p->size +  p->oy * zoom, 0, 1}, {p->u2, p->v2}, {r, g, b, a}});
							vertices[ps->batch_nb++] = particles_vertex({{0 +  p->x * zoom, p->size +  p->y * zoom, 0, 1}, {p->u1, p->v2}, {r, g, b, a}});
						}
					}
				}
			}
		}
	}

	if (last)
	{
		ps->trigger = ps->trigger_pass;
		ps->send_value_pt = ps->send_value;
		ps->send_value = 0;

		if (!no_update) ps->alive = alive || ps->no_stop;

		SDL_mutexV(ps->lock);
	}
}

// Runs into main thread
static void particles_draw(particles_type *ps, mat4 model) 
{
	if (!ps->alive || !ps->vertices) return;

	SDL_mutexP(ps->lock);

	if (ps->blend_mode == BLEND_SHINY) glBlendFunc(GL_SRC_ALPHA,GL_ONE);
	else if (ps->blend_mode == BLEND_ADDITIVE) glBlendFunc(GL_ONE, GL_ONE);
	else if (ps->blend_mode == BLEND_MIXED) glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);

	if (multitexture_active) tglActiveTexture(GL_TEXTURE0);
	tglBindTexture(GL_TEXTURE_2D, ps->texture);
	if (alter_fbo) {
		tglActiveTexture(GL_TEXTURE1);
		glBindTexture(GL_TEXTURE_2D, alter_fbo->getTexture(0));
	}

	// Make the elements vbo, but only once
	// We do it now instead of on creation because we dont know at creation the max particles we'll need
	if (!ps->vbo_elements) {
		glGenBuffers(1, &ps->vbo_elements);
		GLuint *vbo_elements_data = (GLuint*)malloc(sizeof(GLuint) * ps->nb * 6);
		for (int i = 0; i < ps->nb; i++) {
			vbo_elements_data[i * 6 + 0] = i * 4 + 0;
			vbo_elements_data[i * 6 + 1] = i * 4 + 1;
			vbo_elements_data[i * 6 + 2] = i * 4 + 2;

			vbo_elements_data[i * 6 + 3] = i * 4 + 0;
			vbo_elements_data[i * 6 + 4] = i * 4 + 2;
			vbo_elements_data[i * 6 + 5] = i * 4 + 3;
		}
		glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, ps->vbo_elements);
		glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(GLuint) * ps->nb * 6, vbo_elements_data, GL_STATIC_DRAW);
		free(vbo_elements_data);
	} else {
		glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, ps->vbo_elements);
	}

	glBindBuffer(GL_ARRAY_BUFFER, ps->vbo);
	glBufferData(GL_ARRAY_BUFFER, sizeof(particles_vertex) * ps->batch_nb, NULL, GL_STREAM_DRAW);
	glBufferSubData(GL_ARRAY_BUFFER, 0, sizeof(particles_vertex) * ps->batch_nb, ps->vertices);

	vec4 color(1, 1, 1, 1);
	mat4 rot = mat4();
	rot = glm::rotate(rot, ps->rotate, glm::vec3(0, 0, 1));
	rot = glm::scale(rot, glm::vec3(ps->zoom, ps->zoom, ps->zoom));
	mat4 mvp = View::getCurrent()->get() * model * rot;

	shader_type *shader = ps->shader;
	if (!shader) shader = default_particles_shader;
	if (!shader) { useNoShader(); if (!current_shader) return; }
	else { useShaderSimple(shader); current_shader = shader; }
	shader = current_shader;

	if (shader->p_tick != -1) { GLfloat t = cur_frame_tick; glUniform1fv(shader->p_tick, 1, &t); }
	if (shader->p_color != -1) { glUniform4fv(shader->p_color, 1, glm::value_ptr(color)); }
	if (shader->p_mvp != -1) { glUniformMatrix4fv(shader->p_mvp, 1, GL_FALSE, glm::value_ptr(mvp)); }
	if (shader->p_texsize != -1) {
		GLfloat c[2];
		int w = 1, h = 1;
		if (alter_fbo) alter_fbo->getDisplaySize(&w, &h);
		c[0] = w;
		c[1] = h;
		glUniform2fv(shader->p_texsize, 1, c);
	}
	glEnableVertexAttribArray(shader->vertex_attrib);
	glVertexAttribPointer(shader->vertex_attrib, 4, GL_FLOAT, GL_FALSE, sizeof(particles_vertex), (void*)0);
	glEnableVertexAttribArray(shader->texcoord_attrib);
	glVertexAttribPointer(shader->texcoord_attrib, 2, GL_FLOAT, GL_FALSE, sizeof(particles_vertex), (void*)offsetof(particles_vertex, tex));
	glEnableVertexAttribArray(shader->color_attrib);
	glVertexAttribPointer(shader->color_attrib, 4, GL_FLOAT, GL_FALSE, sizeof(particles_vertex), (void*)offsetof(particles_vertex, color));

	// glDrawArrays(GL_TRIANGLES, 0, ps->batch_nb);
	glDrawElements(GL_TRIANGLES, ps->batch_nb * 6, GL_UNSIGNED_INT, (void*)0);
	// glDrawArrays(GL_QUADS, 0, ps->batch_nb);

	if (ps->blend_mode) glBlendFunc(GL_SRC_ALPHA,GL_ONE_MINUS_SRC_ALPHA);

	if (alter_fbo) {
		tglActiveTexture(GL_TEXTURE0);
	}

	glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);
	glBindBuffer(GL_ARRAY_BUFFER, 0);

	if (ps->trigger_cb != LUA_NOREF && ps->trigger != ps->trigger_old) {
		trigger_cbs.push_back(make_tuple(ps->trigger_cb, ps->trigger, ps->trigger_old));
		ps->trigger_old = ps->trigger;
	}

	SDL_mutexV(ps->lock);
}

// Runs into main thread
void particles_to_screen(particles_type *ps, mat4 model)
{
	if (!ps->init) return;
	if (!ps->texture) return;

	if (ps->recompile) particles_update(ps, TRUE, TRUE);

	if (ps->allow_bloom && bloom_fbo) {
		particle_draw_last *pdl = (particle_draw_last*)malloc(sizeof(particle_draw_last));
		pdl->ps = ps;
		pdl->model = model;
		pdl->next = blooms_head;
		blooms_head = pdl;
		return;
	}
	if (ps->fboalter) {
		particle_draw_last *pdl = (particle_draw_last*)malloc(sizeof(particle_draw_last));
		pdl->ps = ps;
		pdl->model = model;
		pdl->next = pdls_head;
		pdls_head = pdl;
		return;
	}
	particles_draw(ps, model);

	if (ps->sub) {
		ps = ps->sub;
		if (ps->allow_bloom) {
			particle_draw_last *pdl = (particle_draw_last*)malloc(sizeof(particle_draw_last));
			pdl->ps = ps;
			pdl->model = model;
			pdl->next = blooms_head;
			blooms_head = pdl;
		}
		if (ps->fboalter) {
			particle_draw_last *pdl = (particle_draw_last*)malloc(sizeof(particle_draw_last));
			pdl->ps = ps;
			pdl->model = model;
			pdl->next = pdls_head;
			pdls_head = pdl;
		}
		else particles_draw(ps, model);
	}
	return;
}

// Runs into main thread
static int lua_particles_to_screen(lua_State *L)
{
	particles_type *ps = (particles_type*)auxiliar_checkclass(L, "core{particles}", 1);
	float x = luaL_checknumber(L, 2);
	float y = luaL_checknumber(L, 3);
	bool show = lua_toboolean(L, 4);
	float zoom = lua_isnumber(L, 5) ? lua_tonumber(L, 5) : 1;
	if (!show) return 0;

	mat4 model = mat4();
	model = glm::scale(model, glm::vec3(zoom, zoom, zoom));
	model = glm::translate(model, glm::vec3(x, y, 0));

	particles_to_screen(ps, model);
	return 0;
}

// Runs into main thread
static int particles_get_do(lua_State *L)
{
	particles_type *ps = (particles_type*)auxiliar_checkclass(L, "core{particles}", 1);
	if (!lua_istable(L, 2)) {
		lua_pushliteral(L, "2nd argument is not an engine.Particles");
		lua_error(L);
		return 0;
	}

	DORParticles *pdo = new DORParticles();
	lua_pushvalue(L, 2);
	pdo->setParticles(ps, luaL_ref(L, LUA_REGISTRYINDEX));

	DisplayObject **v = (DisplayObject**)lua_newuserdata(L, sizeof(DisplayObject*));
	*v = pdo;
	auxiliar_setclass(L, "gl{particles}", -1);
	return 1;
}

// Runs into main thread
static int particles_draw_alter(lua_State *L)
{
	if (!pdls_head) return 0;
	while (pdls_head) {
		particle_draw_last *pdl = pdls_head;
		particles_draw(pdl->ps, pdl->model);
		pdls_head = pdls_head->next;
		free(pdl);
	}
	return 0;
}

// Runs into main thread
static int particles_has_alter(lua_State *L)
{
	lua_pushboolean(L, pdls_head ? true : false);
	return 1;
}

static void draw_bloom(mat4 model, vec4 color) {
	if (!blooms_head) return;
	while (blooms_head) {
		particle_draw_last *pdl = blooms_head;
		particles_draw(pdl->ps, model * pdl->model);
		blooms_head = blooms_head->next;
		free(pdl);
	}
}

// Runs into main thread
static int particles_set_default_shader(lua_State *L)
{
	if (lua_isnil(L, 1)) {
		default_particles_shader = NULL;
	} else {
		default_particles_shader = lua_get_shader(L, 1);
	}
	return 0;
}

// Runs into main thread
static int particles_bloom_do(lua_State *L)
{
	if (!bloom_do) {
		bloom_do = new StaticSubRenderer(draw_bloom);
	}

	DisplayObject **v = (DisplayObject**)lua_newuserdata(L, sizeof(DisplayObject*));
	*v = bloom_do;
	auxiliar_setclass(L, "gl{staticsub}", -1);
	return 1;
}

// Runs into main thread
static int particles_draw_bloom(lua_State *L)
{
	draw_bloom(mat4(), vec4(1, 1, 1, 1));
	return 0;
}

// Runs into main thread
static int particles_has_bloom(lua_State *L)
{
	lua_pushboolean(L, blooms_head ? true : false);
	return 1;
}

// Runs into particles thread
static int particles_emit(lua_State *L)
{
	plist *l = (plist*)lua_touserdata(L, lua_upvalueindex(1)); // The first upvalue, store in the closure, is the particle's plist
	particles_type *ps = l->ps;
	if (!ps || !ps->init) return 0;
	int nb = luaL_checknumber(L, 2);
	if (!nb) {
		lua_pushnumber(L, 0);
		return 1;
	}
//	printf("Emitting %d particles out of %d for system %x\n", nb, ps->nb, (int)ps);

	nb = (nb * ps->density) / 100;
	if (!nb) nb = 1;

	int emited = 0;
	int i;
	for (i = 0; i < ps->nb; i++)
	{
		particle_type *p = &ps->particles[i];

		if (!p->life)
		{
			if (l->generator_ref == LUA_NOREF)
			{
				p->life = rng(ps->life_min, ps->life_max);
				p->size = rng(ps->size_min, ps->size_max);
				p->sizev = rng(ps->sizev_min, ps->sizev_max);
				p->sizea = rng(ps->sizea_min, ps->sizea_max);

				p->x = p->y = 0;

				float angle = rng(ps->angle_min, ps->angle_max) * M_PI / 180;
				float v = rng(ps->anglev_min, ps->anglev_max) / ps->base;
				float a = rng(ps->anglea_min, ps->anglea_max) / ps->base;
				p->xa = cos(angle) * a;
				p->ya = sin(angle) * a;
				p->xv = cos(angle) * v;
				p->yv = sin(angle) * v;

				p->dir = 0;
				p->dirv = 0;
				p->dira = 0;
				p->vel = 0;
				p->velv = 0;
				p->vela = 0;

				p->r = rng(ps->r_min, ps->r_max) / 255.0f;
				p->g = rng(ps->g_min, ps->g_max) / 255.0f;
				p->b = rng(ps->b_min, ps->b_max) / 255.0f;
				p->a = rng(ps->a_min, ps->a_max) / 255.0f;

				p->rv = rng(ps->rv_min, ps->rv_max) / ps->base;
				p->gv = rng(ps->gv_min, ps->gv_max) / ps->base;
				p->bv = rng(ps->bv_min, ps->bv_max) / ps->base;
				p->av = rng(ps->av_min, ps->av_max) / ps->base;

				p->ra = rng(ps->ra_min, ps->ra_max) / ps->base;
				p->ga = rng(ps->ga_min, ps->ga_max) / ps->base;
				p->ba = rng(ps->ba_min, ps->ba_max) / ps->base;
				p->aa = rng(ps->aa_min, ps->aa_max) / ps->base;
				p->trail = FALSE;
			}
			else
			{
				lua_getglobal(L, "__fcts");
				lua_pushnumber(L, l->generator_ref);
				lua_rawget(L, -2);
				if (lua_isnil(L, -1)) { 
//					printf("Particle emitter error %x (%d) is nil\n", (int)l, l->generator_ref); 
				}
				else {
					lua_pushnumber(L, i);
					if (lua_pcall(L, 1, 1, 0))
					{
//						printf("Particle emitter error %x (%d): %s\n", (int)l, l->generator_ref, lua_tostring(L, -1));
						lua_pop(L, 1);
					}
				}
				if (!lua_isnil(L, -1))
				{
					float life;
					float trail;
					getparticulefield(L, "trail", &trail); p->trail = trail;

					getparticulefield(L, "life", &life); p->life = life;
					getparticulefield(L, "size", &(p->size));
					getparticulefield(L, "sizev", &(p->sizev));
					getparticulefield(L, "sizea", &(p->sizea));

					getparticulefield(L, "x", &(p->x));
					getparticulefield(L, "xv", &(p->xv));
					getparticulefield(L, "xa", &(p->xa));

					getparticulefield(L, "y", &(p->y));
					getparticulefield(L, "yv", &(p->yv));
					getparticulefield(L, "ya", &(p->ya));

					getparticulefield(L, "dir", &(p->dir));
					getparticulefield(L, "dirv", &(p->dirv));
					getparticulefield(L, "dira", &(p->dira));

					getparticulefield(L, "vel", &(p->vel));
					getparticulefield(L, "velv", &(p->velv));
					getparticulefield(L, "vela", &(p->vela));

					getparticulefield(L, "r", &(p->r));
					getparticulefield(L, "rv", &(p->rv));
					getparticulefield(L, "ra", &(p->ra));

					getparticulefield(L, "g", &(p->g));
					getparticulefield(L, "gv", &(p->gv));
					getparticulefield(L, "ga", &(p->ga));

					getparticulefield(L, "b", &(p->b));
					getparticulefield(L, "bv", &(p->bv));
					getparticulefield(L, "ba", &(p->ba));

					getparticulefield(L, "a", &(p->a));
					getparticulefield(L, "av", &(p->av));
					getparticulefield(L, "aa", &(p->aa));

					getparticulefield(L, "u1", &(p->u1));
					getparticulefield(L, "v1", &(p->v1));
					getparticulefield(L, "u2", &(p->u2)); if (!p->u2) p->u2 = 1;
					getparticulefield(L, "v2", &(p->v2)); if (!p->v2) p->v2 = 1;
				}
				lua_pop(L, 1);
				lua_pop(L, 1); // global table
			}
			p->x += ps->shift_x / ps->zoom;
			p->y += ps->shift_y / ps->zoom;
			p->ox = p->x;
			p->oy = p->y;

			nb--;
			emited++;
			if (!nb) break;
		}
	}
	lua_pushnumber(L, emited);
	return 1;
}

static const struct luaL_Reg particleslib[] =
{
	{"newEmitter", particles_new},
	{"defineAlterFBO", particles_alter_fbo},
	{"defineBloomFBO", particles_bloom_fbo},
	{"flushLast", particles_flush_last},
	{"drawAlterings", particles_draw_alter},
	{"hasAlterings", particles_has_alter},
	{"getBloomsDO", particles_bloom_do},
	{"drawBlooms", particles_draw_bloom},
	{"hasBlooms", particles_has_bloom},
	{"defaultShader", particles_set_default_shader},
	{NULL, NULL},
};

static const struct luaL_Reg particles_reg[] =
{
	{"__gc", particles_free},
	{"toScreen", lua_particles_to_screen},
	{"isAlive", particles_is_alive},
	{"setSub", particles_set_sub},
	{"shift", particles_shift},
	{"die", particles_die},
	{"trigger", particles_trigger_cb},
	{"send", particles_send_value},
	{"getDO", particles_get_do},
	{NULL, NULL},
};

int luaopen_particles(lua_State *L)
{
	auxiliar_newclass(L, "core{particles}", particles_reg);
	luaL_openlib(L, "core.particles", particleslib, 0);
	lua_pushliteral(L, "ETERNAL");
	lua_pushnumber(L, PARTICLE_ETERNAL);
	lua_rawset(L, -3);

	lua_pushliteral(L, "ENGINE_LINES");
	lua_pushnumber(L, ENGINE_LINES);
	lua_rawset(L, -3);

	lua_pushliteral(L, "ENGINE_POINTS");
	lua_pushnumber(L, ENGINE_POINTS);
	lua_rawset(L, -3);

	lua_pushliteral(L, "BLEND_NORMAL");
	lua_pushnumber(L, BLEND_NORMAL);
	lua_rawset(L, -3);

	lua_pushliteral(L, "BLEND_SHINY");
	lua_pushnumber(L, BLEND_SHINY);
	lua_rawset(L, -3);

	lua_pushliteral(L, "BLEND_ADDITIVE");
	lua_pushnumber(L, BLEND_ADDITIVE);
	lua_rawset(L, -3);

	lua_pushliteral(L, "BLEND_MIXED");
	lua_pushnumber(L, BLEND_MIXED);
	lua_rawset(L, -3);

	lua_pop(L, 1);

	// Make a table to store all textures
	lua_newtable(L);
	textures_ref = luaL_ref(L, LUA_REGISTRYINDEX);

	trigger_cbs.clear();
	trigger_cbs.reserve(1000);

	return 1;
}

/*********************************************************
 ** Multithread particle code
 *********************************************************/

// Runs on particles thread
void thread_particle_run(particle_thread *pt, plist *l)
{
	lua_State *L = pt->L;
	particles_type *ps = l->ps;
	if (!ps || !ps->l || !ps->init || !ps->alive || ps->i_want_to_die) return;

	if (setjmp(pt->panicjump) == 0) {
		// Update
		lua_getglobal(L, "__fcts");
		lua_pushnumber(L, l->updator_ref);
		lua_rawget(L, -2);
		lua_pushnumber(L, l->emit_ref);
		lua_rawget(L, -3);

		if (!lua_isfunction(L, -2) || !lua_istable(L, -1)) {
	//		printf("L(%x) Particle updater error %x (%d, %d) is nil: %s / %s\n", (int)L, (int)l, l->updator_ref, l->emit_ref, lua_tostring(L, -1), lua_tostring(L, -2));
			lua_pop(L, 2);
		}
		else {
			bool run = FALSE;
			lua_pushliteral(L, "ps");
			lua_rawget(L, -2);
			if (!lua_isnil(L, -1)) run = TRUE;
			lua_pop(L, 1);

			if (run) {
				lua_pushnumber(L, ps->send_value_pt);
				if (lua_pcall(L, 2, 1, 0))
				{
	//				printf("L(%x) Particle updater error %x (%d, %d): %s\n", (int)L, (int)l, l->updator_ref, l->emit_ref, lua_tostring(L, -1));
	//				ps->i_want_to_die = TRUE;
					lua_pop(L, 1);
				}
				ps->trigger_pass = lua_tonumber(L, -1);
				lua_pop(L, 1);
			}
		}
		lua_pop(L, 1); // global table

		particles_update(ps, TRUE, FALSE);
	} else {
		// We panic'ed! This particule is borked and needs to die
		ps->i_want_to_die = TRUE;
	}
}

// Runs on particles thread
extern int docall (lua_State *L, int narg, int nret);
void thread_particle_init(particle_thread *pt, plist *l)
{
	lua_State *L = pt->L;
	particles_type *ps = l->ps;
	int tile_w, tile_h;
	int base_size = 0;

	// Load the particle definition
	// Returns: generator_fct:1, update_fct:2, max:3, gl:4, no_stop:5
	if (!luaL_loadfile(L, ps->name_def))
	{
		// Make a new table to serve as environment for the function
		lua_newtable(L);
		if (!luaL_loadstring(L, ps->args))
		{
			lua_pushvalue(L, -2); // Copy the evn table
			lua_setfenv(L, -2); // Set it as the function env
			if (lua_pcall(L, 0, 0, 0))
			{
				printf("Particle args init error %lx (%s): %s\n", (long int)l, ps->args, lua_tostring(L, -1));
				lua_pop(L, 1);
			}
		}
		else
		{
			lua_pop(L, 1);
			printf("Loading particle arguments failed: %s\n", ps->args);
		}

		// Copy tile_w and tile_h for compatibility with old code
		lua_pushliteral(L, "engine");
		lua_newtable(L);

		lua_pushliteral(L, "Map");
		lua_newtable(L);

		lua_pushliteral(L, "tile_w");
		lua_pushliteral(L, "tile_w");
		lua_gettable(L, -7);
		tile_w = lua_tonumber(L, -1);
		lua_settable(L, -3);
		lua_pushliteral(L, "tile_h");
		lua_pushliteral(L, "tile_h");
		lua_gettable(L, -7);
		tile_h = lua_tonumber(L, -1);
		lua_settable(L, -3);

		lua_settable(L, -3);
		lua_settable(L, -3);

		// The metatable which references the global space
		lua_newtable(L);
		lua_pushliteral(L, "__index");
		lua_pushvalue(L, LUA_GLOBALSINDEX);
		lua_settable(L, -3);

		// Set the environment metatable
		lua_setmetatable(L, -2);

		// Set the environment
		lua_pushvalue(L, -1);
		lua_setfenv(L, -3);
		lua_insert(L, -2);

		// Call the method
		if (lua_pcall(L, 0, 5, 0))
		{
			printf("Particle run error %lx (%s): %s\n", (long int)l, ps->args, lua_tostring(L, -1));
			lua_pop(L, 1);
		}

		// Check base size
		lua_pushliteral(L, "base_size");
		lua_gettable(L, -7);
		base_size = lua_tonumber(L, -1);
		lua_pop(L, 1);
		lua_remove(L, -6);
	}
	else { lua_pop(L, 1); return; }

	int nb = lua_isnumber(L, 3) ? lua_tonumber(L, 3) : 1000;
	nb = (nb * ps->density) / 100;
	if (!nb) nb = 1;
	ps->nb = nb;
	ps->no_stop = lua_toboolean(L, 5);

	ps->zoom = 1;
	if (base_size)
	{
		ps->zoom = (((float)tile_w + (float)tile_h) / 2) / (float)base_size;
	}

	int batch = nb;
	ps->batch_nb = 0;
	ps->vertices = (particles_vertex*)calloc(6*batch, sizeof(particles_vertex)); // 4 vertices per particles, but 6 since we dont use indexing
	ps->particles = (particle_type*)calloc(nb, sizeof(particle_type));

	// Locate the updator
	lua_getglobal(L, "__fcts");
	l->updator_ref = lua_objlen(L, -1) + 1;
	lua_pushnumber(L, lua_objlen(L, -1) + 1);
	lua_pushvalue(L, 2);
	lua_rawset(L, -3);
	lua_pop(L, 1);

	// Grab all parameters
	lua_pushvalue(L, 1);

	lua_pushliteral(L, "system_rotation");
	lua_gettable(L, -2);
	ps->rotate = lua_tonumber(L, -1); lua_pop(L, 1);

	lua_pushliteral(L, "system_rotationv");
	lua_gettable(L, -2);
	ps->rotate_v = lua_tonumber(L, -1); lua_pop(L, 1);

	lua_pushliteral(L, "engine");
	lua_gettable(L, -2);
	ps->engine = lua_tonumber(L, -1); lua_pop(L, 1);

	lua_pushliteral(L, "blend_mode");
	lua_gettable(L, -2);
	ps->blend_mode = lua_tonumber(L, -1); lua_pop(L, 1);

	lua_pushliteral(L, "generator");
	lua_gettable(L, -2);
	if (lua_isnil(L, -1))
	{
		lua_pop(L, 1);
		l->generator_ref = LUA_NOREF;
	}
	else
	{
		lua_getglobal(L, "__fcts");
		l->generator_ref = lua_objlen(L, -1) + 1;
		lua_pushnumber(L, lua_objlen(L, -1) + 1);
		lua_pushvalue(L, -3);
		lua_rawset(L, -3);
		lua_pop(L, 2);
	}

	if (l->generator_ref == LUA_NOREF)
	{
		lua_pushliteral(L, "base");
		lua_gettable(L, -2);
		ps->base = (float)lua_tonumber(L, -1);
		lua_pop(L, 1);

		getinitfield(L, "life", &(ps->life_min), &(ps->life_max));

		getinitfield(L, "angle", &(ps->angle_min), &(ps->angle_max));
		getinitfield(L, "anglev", &(ps->anglev_min), &(ps->anglev_max));
		getinitfield(L, "anglea", &(ps->anglea_min), &(ps->anglea_max));

		getinitfield(L, "size", &(ps->size_min), &(ps->size_max));
		getinitfield(L, "sizev", &(ps->sizev_min), &(ps->sizev_max));
		getinitfield(L, "sizea", &(ps->sizea_min), &(ps->sizea_max));

		getinitfield(L, "r", &(ps->r_min), &(ps->r_max));
		getinitfield(L, "rv", &(ps->rv_min), &(ps->rv_max));
		getinitfield(L, "ra", &(ps->ra_min), &(ps->ra_max));

		getinitfield(L, "g", &(ps->g_min), &(ps->g_max));
		getinitfield(L, "gv", &(ps->gv_min), &(ps->gv_max));
		getinitfield(L, "ga", &(ps->ga_min), &(ps->ga_max));

		getinitfield(L, "b", &(ps->b_min), &(ps->b_max));
		getinitfield(L, "bv", &(ps->bv_min), &(ps->bv_max));
		getinitfield(L, "ba", &(ps->ba_min), &(ps->ba_max));

		getinitfield(L, "a", &(ps->a_min), &(ps->a_max));
		getinitfield(L, "av", &(ps->av_min), &(ps->av_max));
		getinitfield(L, "aa", &(ps->aa_min), &(ps->aa_max));
//		printf("Particle emiter using default generator\n");
	}
	else
	{
//		printf("Particle emiter using custom generator\n");
	}
	lua_pop(L, 1);

	// Pop all returns
	lua_pop(L, 5);

	// Push a special emitter
	lua_newtable(L);
	lua_pushliteral(L, "ps");
	lua_newtable(L);

	lua_pushliteral(L, "emit");
	lua_pushlightuserdata(L, l);
	lua_pushcclosure(L, particles_emit, 1);
	lua_settable(L, -3);

	lua_settable(L, -3);

	lua_getglobal(L, "__fcts");
	l->emit_ref = lua_objlen(L, -1) + 1;
	lua_pushnumber(L, lua_objlen(L, -1) + 1);
	lua_pushvalue(L, -3);
	lua_rawset(L, -3);
	lua_pop(L, 1);
	lua_pop(L, 1);

	free((char*)ps->name_def);
	free((char*)ps->args);
	ps->name_def = ps->args = NULL;
	ps->init = TRUE;
}

void thread_particle_die(particle_thread *pt, plist *l)
{
	lua_State *L = pt->L;
	particles_type *ps = l->ps;

//	printf("Deleting particle from list %x :: %x\n", (int)l, (int)ps);
	lua_getglobal(L, "__fcts");
	if (l->emit_ref != LUA_NOREF)
	{
		lua_pushnumber(L, l->emit_ref);
		lua_pushnil(L);
		lua_rawset(L, -3);
	}
	if (l->updator_ref != LUA_NOREF)
	{
		lua_pushnumber(L, l->updator_ref);
		lua_pushnil(L);
		lua_rawset(L, -3);
	}
	if (l->generator_ref != LUA_NOREF)
	{
		lua_pushnumber(L, l->generator_ref);
		lua_pushnil(L);
		lua_rawset(L, -3);
	}
	lua_pop(L, 1);
	l->emit_ref = LUA_NOREF;
	l->updator_ref = LUA_NOREF;
	l->generator_ref = LUA_NOREF;

	if (ps)
	{
		if (ps->vertices) { free(ps->vertices); ps->vertices = NULL; }
		if (ps->particles) { free(ps->particles); ps->particles = NULL; }
		ps->init = FALSE;
		ps->alive = FALSE;
	}
}

// Runs on particles thread
int thread_particles(void *data)
{
	particle_thread *pt = (particle_thread*)data;

	lua_State *L = lua_open();  /* create state */
	lua_pushlightuserdata(L, pt);
	lua_setglobal(L, "__threaddata");
	lua_atpanic(L, particles_lua_panic_handler);
	luaL_openlibs(L);  /* open libraries */
	luaopen_core(L);
	luaopen_particles(L);
	luaopen_shaders(L);
	pt->L = L;
	lua_newtable(L);
	lua_setglobal(L, "__fcts");
	luaL_dostring(L, "os.execute = nil os.getenv = nil os.remove = nil os.rename = nil");
	luaL_dostring(L, "function core.shader.allow() return true end");

	// Override "print" if requested
	if (no_debug)
	{
		lua_pushcfunction(L, noprint);
		lua_setglobal(L, "print");
	}

	// And run the lua engine pre init scripts
	if (!luaL_loadfile(L, "/loader/pre-init.lua")) docall(L, 0, 0);
	else lua_pop(L, 1);

	plist *prev;
	plist *l;
	while (pt->running)
	{
		// Wait for a keyframe
//		printf("Runing particle thread %d (waiting for sem)\n", pt->id);
		SDL_SemWait(pt->keyframes);
//		printf("Runing particle thread %d (waiting for mutex; running(%d))\n", pt->id, pt->running);
		if (!pt->running) break;

		SDL_mutexP(pt->lock);
		int nb = 0;
		l = pt->list;
		prev = NULL;
		while (l)
		{
			if (l->ps && l->ps->alive && !l->ps->i_want_to_die)
			{
				if (l->ps->init) thread_particle_run(pt, l);
				else thread_particle_init(pt, l);

				prev = l;
				l = l->next;
			}
			else
			{
				thread_particle_die(pt, l);

				// Remove dead ones
				if (!prev) pt->list = l->next;
				else prev->next = l->next;

				l = l->next;
			}
			nb++;
		}
//		printf("Particles thread %d has %d systems\n", pt->id, nb);
		SDL_mutexV(pt->lock);
	}

	printf("Cleaning up particle thread %d\n", pt->id);

	// Cleanup
	SDL_mutexP(pt->lock);
	l = pt->list;
	while (l)
	{
		thread_particle_die(pt, l);
		l = l->next;
	}
	SDL_mutexV(pt->lock);

	lua_close(L);

	SDL_DestroySemaphore(pt->keyframes);
	SDL_DestroyMutex(pt->lock);
	printf("Cleaned up particle thread %d\n", pt->id);

	return(0);
}

// Runs on main thread
// Signals all particles threads that some new keyframes have arrived
float nb_keyframes_remaining = 0;
void thread_particle_new_keyframes(float nb_keyframes)
{
	int i, j;
	nb_keyframes += nb_keyframes_remaining;
	for (i = 0; i < MAX_THREADS; i++)
	{
		for (j = 0; j < nb_keyframes; j++) SDL_SemPost(threads[i].keyframes);
		nb_keyframes_remaining = nb_keyframes - j;
		// printf("==particels %f remain %f  :: %d\n", nb_keyframes_remaining, nb_keyframes, j);
	}
}

// Runs on main thread
void thread_add(particles_type *ps)
{
	particle_thread *pt = &threads[cur_thread];

	// Insert it in the head of the list
	SDL_mutexP(pt->lock);
	plist *l = (plist*)malloc(sizeof(plist));
	l->pt = pt;
	l->ps = ps;
	l->next = pt->list;
	pt->list = l;
	ps->l = l;
	SDL_mutexV(pt->lock);

//	printf("New particles registered on thread %d: %s\n", cur_thread, ps->name_def);

	cur_thread++;
	if (cur_thread >= MAX_THREADS) cur_thread = 0;
}

// Runs on main thread
void free_particles_thread()
{
	if (!threads) return;

	int i;
	for (i = 0; i < MAX_THREADS; i++)
	{
		int status;
		int sem_res;
		particle_thread *pt = &threads[i];

		printf("Destroying particle thread %d (waiting for mutex)\n", i);
		SDL_mutexP(pt->lock);
		pt->running = FALSE;
		SDL_mutexV(pt->lock);

		printf("Destroying particle thread %d\n", i);
		sem_res = SDL_SemPost(pt->keyframes);
		if (sem_res) printf("Error while waiting for particle thread to die: %s\n", SDL_GetError());
		printf("Destroying particle thread %d (waiting for thread %lx)\n", i, (long int)pt->thread);
		SDL_WaitThread(pt->thread, &status);
		printf("Destroyed particle thread %d (%d)\n", i, status);
	}
	nb_threads = 0;
	free(threads);
	threads = NULL;
}

// Runs on main thread
void create_particles_thread()
{
	int i;

	// Previous ones
	if (threads)
	{
		free_particles_thread();
	}

	// MAX_THREADS = nb_cpus - 1;
	// MAX_THREADS = (MAX_THREADS < 1) ? 1 : MAX_THREADS;
	MAX_THREADS = 1;
	threads = (particle_thread*)calloc(MAX_THREADS, sizeof(particle_thread));

	cur_thread = 0;
	for (i = 0; i < MAX_THREADS; i++)
	{
		SDL_Thread *thread;
		particle_thread *pt = &threads[i];

		pt->id = nb_threads++;
		pt->list = NULL;
		pt->lock = SDL_CreateMutex();
		pt->keyframes = SDL_CreateSemaphore(0);
		pt->running = TRUE;

		thread = SDL_CreateThread(thread_particles, "particles", pt);
		if (thread == NULL) {
			printf("Unable to create particle thread: %s\n", SDL_GetError());
			continue;
		}
		pt->thread = thread;

		printf("Creating particles thread %d\n", pt->id);
	}
}