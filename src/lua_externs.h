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
#ifndef _LUA_EXTERNS_H_
#define _LUA_EXTERNS_H_

/* Some lua stuff that's external but has no headers */
extern int luaopen_bit(lua_State *L);
extern int luaopen_diamond_square(lua_State *L);
extern int luaopen_fov(lua_State *L);
extern int luaopen_gas(lua_State *L);
extern int luaopen_lanes(lua_State *L);
extern int luaopen_lpeg(lua_State *L);
extern int luaopen_lxp(lua_State *L);
extern int luaopen_map(lua_State *L);
extern int luaopen_md5_core (lua_State *L);
extern int luaopen_mime_core(lua_State *L);
extern int luaopen_noise(lua_State *L);
extern int luaopen_particles(lua_State *L);
extern int luaopen_physfs(lua_State *L);
extern int luaopen_profiler(lua_State *L);
extern int luaopen_shaders(lua_State *L);
extern int luaopen_socket_core(lua_State *L);
extern int luaopen_struct(lua_State *L);
extern int luaopen_zlib (lua_State *L);
extern int luaopen_colors (lua_State *L);
extern int luaopen_navmesh(lua_State *L);
extern int luaopen_particles_system(lua_State *L);
extern int luaopen_clipper(lua_State *L);
extern int luaopen_map2d(lua_State *L);
extern int luaopen_binpack(lua_State *L);

extern int luaopen_discord(lua_State *L);
extern void te4_discord_update();

extern int luaopen_loader(lua_State *L);
extern void loader_tick();

extern int luaopen_wait(lua_State *L);
extern bool draw_waiting(lua_State *L);
extern bool is_waiting();

extern void create_particles_thread();
extern void free_particles_thread();
extern void free_profile_thread();
extern void lua_particles_system_clean();
extern void threaded_runner_start();
extern void threaded_runner_keyframe(float nb_keyframes);

// extern void copy_surface_to_texture(SDL_Surface *s);
// extern GLenum sdl_gl_texture_format(SDL_Surface *s);

extern void font_cleanup();
extern void core_loader_waitall();

#endif
