/*
    TE4 - T-Engine 4
    Copyright (C) 2009, 2010, 2011 Nicolas Casalini

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
#include "display.h"
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <math.h>
#include <sys/time.h>
#include "lua.h"
#include "lauxlib.h"
#include "lualib.h"
#include "luasocket.h"
#include "luasocket/mime.h"
#include "lua_externs.h"
#include "SFMT.h"

#include "types.h"
#include "script.h"
#include "physfs.h"
#include "physfsrwops.h"
#include "core_lua.h"
#include "getself.h"
#include "music.h"
#include "serial.h"
#include "profile.h"
#include "main.h"
#include "runner/core.h"
#ifdef SELFEXE_WINDOWS
#include <windows.h>
#endif

#define WIDTH 800
#define HEIGHT 600

lua_State *L = NULL;
int nb_cpus;
bool no_debug = FALSE;
int current_mousehandler = LUA_NOREF;
int current_keyhandler = LUA_NOREF;
int current_game = LUA_NOREF;
core_boot_type *core_def = NULL;
bool exit_engine = FALSE;
bool no_sound = FALSE;
bool isActive = TRUE;
bool tickPaused = FALSE;
int mouse_cursor_tex = 0, mouse_cursor_tex_ref = LUA_NOREF;
int mouse_cursor_down_tex = 0, mouse_cursor_down_tex_ref = LUA_NOREF;
int mouse_cursor_ox = 0, mouse_cursor_oy = 0;
int mousex = 0, mousey = 0;
float gamma_correction = 1;
SDL_TimerID display_timer_id = NULL;
SDL_TimerID realtime_timer_id = NULL;

/* OpenGL capabilities */
extern bool shaders_active;
bool fbo_active;
bool multitexture_active;

/* Error handling */
lua_err_type *last_lua_error_head = NULL, *last_lua_error_tail = NULL;

void del_lua_error()
{
	lua_err_type *cur = last_lua_error_head;
	while (cur)
	{
		if (cur->err_msg) free(cur->err_msg);
		if (cur->file) free(cur->file);
		if (cur->func) free(cur->func);

		lua_err_type *ocur = cur;
		cur = cur->next;
		free(ocur);
	}

	last_lua_error_head = NULL;
	last_lua_error_tail = NULL;
}

static void new_lua_error(const char *err)
{
	del_lua_error();

	lua_err_type *cur = calloc(1, sizeof(lua_err_type));
	cur->err_msg = strdup(err);
	cur->next = NULL;

	last_lua_error_head = cur;
	last_lua_error_tail = cur;
}

static void add_lua_error(const char *file, int line, const char *func)
{
	lua_err_type *cur = calloc(1, sizeof(lua_err_type));
	cur->err_msg = NULL;
	cur->file = strdup(file);
	cur->line = line;
	cur->func = strdup(func);
	cur->next = NULL;

	last_lua_error_tail->next = cur;
	last_lua_error_tail = cur;
}

static int traceback (lua_State *L) {
	lua_Debug ar;
	int n = 0;
	printf("Lua Error: %s\n", lua_tostring(L, 1));
	while(lua_getstack(L, n++, &ar)) {
		lua_getinfo(L, "nSl", &ar);
		printf("\tAt %s:%d %s\n", ar.short_src, ar.currentline, ar.name?ar.name:"");
	}

	// Do it again for the lua error popup, if needed
	if (1)
	{
		n = 0;
		new_lua_error(lua_tostring(L, 1));
		while(lua_getstack(L, n++, &ar)) {
			lua_getinfo(L, "nSl", &ar);
			add_lua_error(ar.short_src, ar.currentline, ar.name?ar.name:"");
		}
	}
	return 1;
}

void stackDump (lua_State *L) {
	int i=lua_gettop(L);
	printf(" ----------------  Stack Dump ----------------\n" );
	while(  i   ) {
		int t = lua_type(L, i);
		switch (t) {
		case LUA_TSTRING:
			printf("%d:`%s'\n", i, lua_tostring(L, i));
			break;
		case LUA_TBOOLEAN:
			printf("%d: %s\n",i,lua_toboolean(L, i) ? "true" : "false");
			break;
		case LUA_TNUMBER:
			printf("%d: %g\n",  i, lua_tonumber(L, i));
			break;
		default:
#if defined(__PTRDIFF_TYPE__)
			if((sizeof(__PTRDIFF_TYPE__) == sizeof(long int)))
				printf("%d: %s // %lx\n", i, lua_typename(L, t), (unsigned long int)lua_topointer(L, i));
			else
				printf("%d: %s // %x\n", i, lua_typename(L, t), (unsigned int)lua_topointer(L, i));
#else
			printf("%d: %s // %x\n", i, lua_typename(L, t), lua_topointer(L, i));
#endif
			break;
		}
		i--;
	}
	printf("--------------- Stack Dump Finished ---------------\n" );
}

int docall (lua_State *L, int narg, int nret)
{
//	printf("<===%d\n", lua_gettop(L));
	int status;
	int base = lua_gettop(L) - narg;  /* function index */
	lua_pushcfunction(L, traceback);  /* push traceback function */
	lua_insert(L, base);  /* put it under chunk and args */
	status = lua_pcall(L, narg, nret, base);
	lua_remove(L, base);  /* remove traceback function */
	/* force a complete garbage collection in case of errors */
	if (status != 0) { lua_pop(L, 1); lua_gc(L, LUA_GCCOLLECT, 0); }
//	printf(">===%d\n", lua_gettop(L));
	if (lua_gettop(L) != nret)
	{
		stackDump(L);
//		assert(0);
		lua_settop(L, base);
	}
	return status;
}

/* No print function, does .. nothing */
int noprint(lua_State *L)
{
	return 0;
}

// define our data that is passed to our redraw function
typedef struct {
	Uint32 color;
} MainStateData;

int event_filter(const SDL_Event *event)
{
	// Do not allow the user to close without asking the game to know about it
	if (event->type == SDL_QUIT && (current_game != LUA_NOREF))
	{
		lua_rawgeti(L, LUA_REGISTRYINDEX, current_game);
		lua_pushstring(L, "onQuit");
		lua_gettable(L, -2);
		lua_remove(L, -2);
		lua_rawgeti(L, LUA_REGISTRYINDEX, current_game);
		docall(L, 1, 0);

		return 0;
	}
	return 1;
}

void on_event(SDL_Event *event)
{
	switch (event->type) {
	case SDL_KEYDOWN:
	case SDL_KEYUP:
		if (current_keyhandler != LUA_NOREF)
		{
			lua_rawgeti(L, LUA_REGISTRYINDEX, current_keyhandler);
			lua_pushstring(L, "receiveKey");
			lua_gettable(L, -2);
			lua_remove(L, -2);
			lua_rawgeti(L, LUA_REGISTRYINDEX, current_keyhandler);
			lua_pushnumber(L, event->key.keysym.sym);
/*
			Uint8 *_pKeyState = SDL_GetKeyState(NULL);
			lua_pushboolean(L, (_pKeyState[SDLK_RCTRL] || _pKeyState[SDLK_LCTRL]) ? TRUE : FALSE);
			lua_pushboolean(L, (_pKeyState[SDLK_RSHIFT] || _pKeyState[SDLK_LSHIFT]) ? TRUE : FALSE);
			lua_pushboolean(L, (_pKeyState[SDLK_RALT] || _pKeyState[SDLK_LALT]) ? TRUE : FALSE);
			lua_pushboolean(L, (_pKeyState[SDLK_RMETA] || _pKeyState[SDLK_LMETA]) ? TRUE : FALSE);
*/
			lua_pushboolean(L, (event->key.keysym.mod & KMOD_CTRL) ? TRUE : FALSE);
			lua_pushboolean(L, (event->key.keysym.mod & KMOD_SHIFT) ? TRUE : FALSE);
			lua_pushboolean(L, (event->key.keysym.mod & KMOD_ALT) ? TRUE : FALSE);
			lua_pushboolean(L, (event->key.keysym.mod & KMOD_META) ? TRUE : FALSE);
			/* Convert unicode UCS-2 to UTF8 string */
			if (event->key.keysym.unicode)
			{
				wchar_t wc = event->key.keysym.unicode;

				char buf[4] = {0,0,0,0};
				if (wc < 0x80)
				{
					buf[0] = wc;
				}
				else if (wc < 0x800)
				{
					buf[0] = (0xC0 | wc>>6);
					buf[1] = (0x80 | wc & 0x3F);
				}
				else
				{
					buf[0] = (0xE0 | wc>>12);
					buf[1] = (0x80 | wc>>6 & 0x3F);
					buf[2] = (0x80 | wc & 0x3F);
				}

				lua_pushstring(L, buf);
			}
			else
				lua_pushnil(L);
			lua_pushboolean(L, (event->type == SDL_KEYUP) ? TRUE : FALSE);
			docall(L, 8, 0);
		}
		break;
	case SDL_MOUSEBUTTONDOWN:
	case SDL_MOUSEBUTTONUP:
		if (current_mousehandler != LUA_NOREF)
		{
			lua_rawgeti(L, LUA_REGISTRYINDEX, current_mousehandler);
			lua_pushstring(L, "receiveMouse");
			lua_gettable(L, -2);
			lua_remove(L, -2);
			lua_rawgeti(L, LUA_REGISTRYINDEX, current_mousehandler);
			switch (event->button.button)
			{
			case SDL_BUTTON_LEFT:
				lua_pushstring(L, "left");
				break;
			case SDL_BUTTON_MIDDLE:
				lua_pushstring(L, "middle");
				break;
			case SDL_BUTTON_RIGHT:
				lua_pushstring(L, "right");
				break;
			case SDL_BUTTON_WHEELUP:
				lua_pushstring(L, "wheelup");
				break;
			case SDL_BUTTON_WHEELDOWN:
				lua_pushstring(L, "wheeldown");
				break;
			default:
				lua_pushstring(L, "button");
				lua_pushnumber(L, event->button.button);
				lua_concat(L, 2);
				break;
			}
			lua_pushnumber(L, event->button.x);
			lua_pushnumber(L, event->button.y);
			lua_pushboolean(L, (event->type == SDL_MOUSEBUTTONUP) ? TRUE : FALSE);
			docall(L, 5, 0);
		}
		break;
	case SDL_MOUSEMOTION:
		mousex = event->motion.x;
		mousey = event->motion.y;

		if (current_mousehandler != LUA_NOREF)
		{
			lua_rawgeti(L, LUA_REGISTRYINDEX, current_mousehandler);
			lua_pushstring(L, "receiveMouseMotion");
			lua_gettable(L, -2);
			lua_remove(L, -2);
			lua_rawgeti(L, LUA_REGISTRYINDEX, current_mousehandler);
			if (event->motion.state & SDL_BUTTON(1)) lua_pushstring(L, "left");
			else if (event->motion.state & SDL_BUTTON(2)) lua_pushstring(L, "middle");
			else if (event->motion.state & SDL_BUTTON(3)) lua_pushstring(L, "right");
			else if (event->motion.state & SDL_BUTTON(4)) lua_pushstring(L, "wheelup");
			else if (event->motion.state & SDL_BUTTON(5)) lua_pushstring(L, "wheeldown");
			else lua_pushstring(L, "none");
			lua_pushnumber(L, event->motion.x);
			lua_pushnumber(L, event->motion.y);
			lua_pushnumber(L, event->motion.xrel);
			lua_pushnumber(L, event->motion.yrel);
			docall(L, 6, 0);
		}
		break;
	}
}

// redraw the screen and update game logics, if any
void on_tick()
{
	static int Frames = 0;
	static int T0     = 0;

	if (current_game != LUA_NOREF)
	{
		lua_rawgeti(L, LUA_REGISTRYINDEX, current_game);
		lua_pushstring(L, "tick");
		lua_gettable(L, -2);
		lua_remove(L, -2);
		lua_rawgeti(L, LUA_REGISTRYINDEX, current_game);
		docall(L, 1, 1);
		tickPaused = lua_toboolean(L, -1);
		lua_pop(L, 1);
	}

	/* Gather our frames per second */
	Frames++;
	{
		int t = SDL_GetTicks();
		if (t - T0 >= 10000) {
			float seconds = (t - T0) / 1000.0;
			float fps = Frames / seconds;
//			printf("%d ticks  in %g seconds = %g TPS\n", Frames, seconds, fps);
			T0 = t;
			Frames = 0;
		}
	}
}

void call_draw(int nb_keyframes)
{
	if (nb_keyframes > 30) nb_keyframes = 30;

	// Notify the particles threads that there are new keyframes
	thread_particle_new_keyframes(nb_keyframes);

	if (current_game != LUA_NOREF)
	{
		lua_rawgeti(L, LUA_REGISTRYINDEX, current_game);
		lua_pushstring(L, "display");
		lua_gettable(L, -2);
		lua_remove(L, -2);
		lua_rawgeti(L, LUA_REGISTRYINDEX, current_game);
		lua_pushnumber(L, (nb_keyframes < 0) ? 0 : nb_keyframes);
		docall(L, 2, 0);
	}

	/* Mouse pointer */
	if (mouse_cursor_tex && mouse_cursor_down_tex)
	{
		GLfloat texcoords[2*4] = {
			0, 0,
			1, 0,
			1, 1,
			0, 1,
		};
		GLfloat colors[4*4] = {
			1, 1, 1, 1,
			1, 1, 1, 1,
			1, 1, 1, 1,
			1, 1, 1, 1,
		};

		glTexCoordPointer(2, GL_FLOAT, 0, texcoords);
		glColorPointer(4, GL_FLOAT, 0, colors);

		int x = mousex + mouse_cursor_ox;
		int y = mousey + mouse_cursor_oy;
		int down = SDL_GetMouseState(NULL, NULL);
		tglBindTexture(GL_TEXTURE_2D, down ? mouse_cursor_down_tex : mouse_cursor_tex);

		GLfloat vertices[2*4] = {
			x, y,
			x, y + 32,
			x + 32, y + 32,
			x + 32, y,
		};
		glVertexPointer(2, GL_FLOAT, 0, vertices);
		glDrawArrays(GL_QUADS, 0, 4);
	}
}

long total_keyframes = 0;
void on_redraw()
{
	static int Frames = 0;
	static int T0     = 0;
	static float nb_keyframes = 0;
	static int last_keyframe = 0;
	static float reference_fps = 30;
	static int count_keyframes = 0;

	/* Gather our frames per second */
	Frames++;
	{
		int t = SDL_GetTicks();
		if (t - T0 >= 1000) {
			float seconds = (t - T0) / 1000.0;
			float fps = Frames / seconds;
			reference_fps = fps;
//			printf("%d frames in %g seconds = %g FPS (%d keyframes)\n", Frames, seconds, fps, count_keyframes);
			T0 = t;
			Frames = 0;
			last_keyframe = 0;
			nb_keyframes = 0;
			count_keyframes = 0;
		}
	}

	glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
	glLoadIdentity();

	float step = 30 / reference_fps;
	nb_keyframes += step;

	int nb = ceilf(nb_keyframes);
	count_keyframes += nb - last_keyframe;
	total_keyframes += nb - last_keyframe;
//	printf("keyframes: %f / %f by %f => %d\n", nb_keyframes, reference_fps, step, nb - (last_keyframe));
	call_draw(nb - last_keyframe);

	SDL_GL_SwapBuffers();

	last_keyframe = nb;
}

void pass_command_args(int argc, char *argv[])
{
	int i;

	if (current_game != LUA_NOREF)
	{
		lua_rawgeti(L, LUA_REGISTRYINDEX, current_game);
		lua_pushstring(L, "commandLineArgs");
		lua_gettable(L, -2);
		lua_remove(L, -2);
		lua_rawgeti(L, LUA_REGISTRYINDEX, current_game);
		lua_newtable(L);

		for (i = 1; i <= argc; i++)
		{
			lua_pushnumber(L, i);
			lua_pushstring(L, argv[i]);
			lua_settable(L, -3);
		}
		docall(L, 2, 0);
	}
}

int redraw_pending = 0;

Uint32 redraw_timer(Uint32 interval, void *param)
{
	SDL_Event event;
	SDL_UserEvent userevent;

	/* In this example, our callback pushes an SDL_USEREVENT event
	 into the queue, and causes ourself to be called again at the
	 same interval: */

	userevent.type = SDL_USEREVENT;
	userevent.code = 0;
	userevent.data1 = NULL;
	userevent.data2 = NULL;

	event.type = SDL_USEREVENT;
	event.user = userevent;

	if (!redraw_pending && isActive) {
		SDL_PushEvent(&event);
		redraw_pending = 1;
	}
	return(interval);
}

int realtime_pending = 0;

Uint32 realtime_timer(Uint32 interval, void *param)
{
	SDL_Event event;
	SDL_UserEvent userevent;

	/* In this example, our callback pushes an SDL_USEREVENT event
	 into the queue, and causes ourself to be called again at the
	 same interval: */

	userevent.type = SDL_USEREVENT;
	userevent.code = 2;
	userevent.data1 = NULL;
	userevent.data2 = NULL;

	event.type = SDL_USEREVENT;
	event.user = userevent;

	if (!realtime_pending && isActive) {
		SDL_PushEvent(&event);
//		realtime_pending = 1;
	}
	return(interval);
}

// Calls the lua music callback
void on_music_stop()
{
	if (current_game != LUA_NOREF)
	{
		lua_rawgeti(L, LUA_REGISTRYINDEX, current_game);
		lua_pushstring(L, "onMusicStop");
		lua_gettable(L, -2);
		lua_remove(L, -2);
		if (lua_isfunction(L, -1))
		{
			lua_rawgeti(L, LUA_REGISTRYINDEX, current_game);
			docall(L, 1, 0);
		}
		else
			lua_pop(L, 1);
	}
}

// Setup realtime
void setupRealtime(float freq)
{
	if (!freq)
	{
		if (realtime_timer_id) SDL_RemoveTimer(realtime_timer_id);
		realtime_timer_id = NULL;
		printf("[ENGINE] Switching to turn based\n");
	}
	else
	{
		float interval = 1000 / freq;
		realtime_timer_id = SDL_AddTimer((int)interval, realtime_timer, NULL);
		printf("[ENGINE] Switching to realtime, interval %d ms\n", (int)interval);
	}
}

void setupDisplayTimer(int fps)
{
	if (display_timer_id) SDL_RemoveTimer(display_timer_id);
	display_timer_id = SDL_AddTimer(1000 / fps, redraw_timer, NULL);
	printf("[ENGINE] Setting requested FPS to %d (%d ms)\n", fps, 1000 / fps);
}


/* general OpenGL initialization function */
int initGL()
{
	/* Set the background black */
	tglClearColor( 0.0f, 0.0f, 0.0f, 1.0f );

	/* Depth buffer setup */
	glClearDepth( 1.0f );

	/* The Type Of Depth Test To Do */
	glDepthFunc(GL_LEQUAL);

	glEnable(GL_BLEND);
	glBlendFunc(GL_SRC_ALPHA,GL_ONE_MINUS_SRC_ALPHA);

	glEnableClientState(GL_VERTEX_ARRAY);
	glEnableClientState(GL_TEXTURE_COORD_ARRAY);
	glEnableClientState(GL_COLOR_ARRAY);

	return( TRUE );
}

int resizeWindow(int width, int height)
{
	/* Height / width ration */
	GLfloat ratio;

	SDL_GL_SetAttribute( SDL_GL_DOUBLEBUFFER, 1 );
	initGL();

	/* Protect against a divide by zero */
	if ( height == 0 )
		height = 1;

	ratio = ( GLfloat )width / ( GLfloat )height;

//	tglActiveTexture(GL_TEXTURE0);
	glEnable(GL_TEXTURE_2D);

	/* Setup our viewport. */
	glViewport( 0, 0, ( GLsizei )width, ( GLsizei )height );

	/* change to the projection matrix and set our viewing volume. */
	glMatrixMode(GL_PROJECTION);
	glLoadIdentity();

	/* Set our perspective */
	//gluPerspective( 45.0f, ratio, 0.1f, 100.0f );
	glOrtho(0, width, height, 0, -101, 101);

	/* Make sure we're chaning the model view and not the projection */
	glMatrixMode( GL_MODELVIEW );

	/* Reset The View */
	glLoadIdentity( );

	SDL_SetGamma(gamma_correction, gamma_correction, gamma_correction);

	return( TRUE );
}

void do_resize(int w, int h, bool fullscreen)
{
	int flags = SDL_OPENGL | SDL_RESIZABLE;

	if (fullscreen) flags = SDL_OPENGL | SDL_FULLSCREEN;

	screen = SDL_SetVideoMode(w, h, 32, flags);
	if (screen==NULL) {
		printf("error opening screen: %s\n", SDL_GetError());
		return;
	}
	glewInit();

	resizeWindow(screen->w, screen->h);
}

void boot_lua(int state, bool rebooting, int argc, char *argv[])
{
	core_def->corenum = 0;

	if (state == 1)
	{
		const char *selfexe;

		/* When rebooting we destroy the lua state to free memory and we reset physfs */
		if (rebooting)
		{
			current_mousehandler = LUA_NOREF;
			current_keyhandler = LUA_NOREF;
			current_game = LUA_NOREF;
			lua_close(L);
			PHYSFS_deinit();
		}

		/***************** Physfs Init *****************/
		PHYSFS_init(argv[0]);

		selfexe = get_self_executable(argc, argv);
		if (selfexe && PHYSFS_mount(selfexe, "/", 1))
		{
		}
		else
		{
			printf("NO SELFEXE: bootstrapping from CWD\n");
			PHYSFS_mount("bootstrap", "/bootstrap", 1);
		}

		/***************** Lua Init *****************/
		L = lua_open();  /* create state */
		luaL_openlibs(L);  /* open libraries */
		luaopen_physfs(L);
		luaopen_core(L);
		luaopen_fov(L);
		luaopen_socket_core(L);
		luaopen_mime_core(L);
		luaopen_struct(L);
		luaopen_profiler(L);
		luaopen_bit(L);
		luaopen_lpeg(L);
		luaopen_lxp(L);
		luaopen_md5_core(L);
		luaopen_map(L);
		luaopen_particles(L);
		luaopen_gas(L);
		luaopen_sound(L);
		luaopen_noise(L);
		luaopen_diamond_square(L);
		luaopen_shaders(L);
		luaopen_serial(L);
		luaopen_profile(L);
		luaopen_zlib(L);
		luaopen_bit(L);

		// Override "print" if requested
		if (no_debug)
		{
			lua_pushcfunction(L, noprint);
			lua_setglobal(L, "print");
		}

		// Make the uids repository
		lua_newtable(L);
		lua_setglobal(L, "__uids");

		// Tell the boostrapping code the selfexe path
		if (selfexe)
			lua_pushstring(L, selfexe);
		else
			lua_pushnil(L);
		lua_setglobal(L, "__SELFEXE");

		// Will be useful
#ifdef __APPLE__
		lua_pushboolean(L, TRUE);
		lua_setglobal(L, "__APPLE__");
#endif

		// Run bootstrapping
		if (!luaL_loadfile(L, "/bootstrap/boot.lua"))
		{
			docall(L, 0, 0);
		}
		// Could not load bootstrap! Try to mount the engine from working directory as last resort
		else
		{
			lua_pop(L, 1);
			printf("WARNING: No bootstrap code found, defaulting to working directory for engine code!\n");
			PHYSFS_mount("game/thirdparty", "/", 1);
			PHYSFS_mount("game/", "/", 1);
		}

		// And run the lua engine pre init scripts
		if (!luaL_loadfile(L, "/loader/pre-init.lua"))
			docall(L, 0, 0);
		else
			lua_pop(L, 1);

		create_particles_thread();
	}
	else if (state == 2)
	{
		SDL_WM_SetCaption("T-Engine4", NULL);

		// Now we can open lua lanes, the physfs paths are set and it can load it's lanes-keeper.lua file
		luaopen_lanes(L);

		// And run the lua engine scripts
		if (!luaL_loadfile(L, "/loader/init.lua"))
		{
			if (core_def->reboot_engine) lua_pushstring(L, core_def->reboot_engine); else lua_pushnil(L);
			if (core_def->reboot_engine_version) lua_pushstring(L, core_def->reboot_engine_version); else lua_pushnil(L);
			if (core_def->reboot_module) lua_pushstring(L, core_def->reboot_module); else lua_pushnil(L);
			if (core_def->reboot_name) lua_pushstring(L, core_def->reboot_name); else lua_pushnil(L);
			lua_pushboolean(L, core_def->reboot_new);
			if (core_def->reboot_einfo) lua_pushstring(L, core_def->reboot_einfo); else lua_pushnil(L);
			docall(L, 6, 0);
		}
		else
		{
			lua_pop(L, 1);
		}
	}
}

// Update core to run
static void define_core(core_boot_type *core_def, const char *coretype, int id, const char *reboot_engine, const char *reboot_engine_version, const char *reboot_module, const char *reboot_name, int reboot_new, const char *reboot_einfo)
{
	if (core_def->coretype) free(core_def->coretype);
	if (core_def->reboot_engine) free(core_def->reboot_engine);
	if (core_def->reboot_engine_version) free(core_def->reboot_engine_version);
	if (core_def->reboot_module) free(core_def->reboot_module);
	if (core_def->reboot_name) free(core_def->reboot_name);
	if (core_def->reboot_einfo) free(core_def->reboot_einfo);

	core_def->corenum = id;
	core_def->coretype = coretype ? strdup(coretype) : NULL;
	core_def->reboot_engine = reboot_engine ? strdup(reboot_engine) : NULL;
	core_def->reboot_engine_version = reboot_engine_version ? strdup(reboot_engine_version) : NULL;
	core_def->reboot_module = reboot_module ? strdup(reboot_module) : NULL;
	core_def->reboot_name = reboot_name ? strdup(reboot_name) : NULL;
	core_def->reboot_einfo = reboot_einfo ? strdup(reboot_einfo) : NULL;
	core_def->reboot_new = reboot_new;
}

/**
 * Core entry point.
 */
int main(int argc, char *argv[])
{
	core_boot_type given_core_def;
	core_def = &given_core_def;
	core_def->define = &define_core;
	core_def->define(core_def, "te4core", -1, NULL, NULL, NULL, NULL, 0, NULL);

#ifdef SELFEXE_WINDOWS
	freopen ("te4_log.txt", "w", stdout);
#endif

	// Get cpu cores
	nb_cpus = get_number_cpus();
	printf("[CPU] Detected %d CPUs\n", nb_cpus);

	// RNG init
	init_gen_rand(time(NULL));

	// Parse arguments
	int i;
	for (i = 1; i < argc; i++)
	{
		char *arg = argv[i];
		if (!strncmp(arg, "--no-debug", 10)) no_debug = 0;
	}

	// initialize engine and set up resolution and depth
	Uint32 flags=SDL_INIT_VIDEO | SDL_INIT_TIMER;
	if (SDL_Init (flags) < 0) {
		printf("cannot initialize SDL: %s\n", SDL_GetError ());
		return;
	}

	// Filter events, to catch the quit event
	SDL_SetEventFilter(event_filter);

	boot_lua(1, FALSE, argc, argv);

	SDL_WM_SetIcon(IMG_Load_RW(PHYSFSRWOPS_openRead("/engines/default/data/gfx/te4-icon.png"), TRUE), NULL);

//	screen = SDL_SetVideoMode(WIDTH, HEIGHT, 32, SDL_OPENGL | SDL_GL_DOUBLEBUFFER | SDL_HWPALETTE | SDL_HWSURFACE | SDL_RESIZABLE);
//	glewInit();
	do_resize(WIDTH, HEIGHT, FALSE);
	if (screen==NULL) {
		printf("error opening screen: %s\n", SDL_GetError());
		return;
	}
	SDL_WM_SetCaption("T4Engine", NULL);
	SDL_EnableUNICODE(TRUE);
	SDL_EnableKeyRepeat(300, 10);
	TTF_Init();
	if (Mix_OpenAudio(22050, AUDIO_S16, 2, 2048) == -1)
	{
		no_sound = TRUE;
	}
	else
	{
		Mix_VolumeMusic(SDL_MIX_MAXVOLUME);
		Mix_Volume(-1, SDL_MIX_MAXVOLUME);
		Mix_AllocateChannels(16);
	}

	/* Sets up OpenGL double buffering */
	resizeWindow(WIDTH, HEIGHT);

	// Get OpenGL capabilities
	multitexture_active = GLEW_ARB_multitexture;
	shaders_active = GLEW_ARB_shader_objects;
	fbo_active = GLEW_EXT_framebuffer_object || GLEW_ARB_framebuffer_object;
	if (!multitexture_active) shaders_active = FALSE;
	if (!GLEW_VERSION_2_1)
	{
		multitexture_active = FALSE;
		shaders_active = FALSE;
		fbo_active = FALSE;
	}

//	setupDisplayTimer(30);

	boot_lua(2, FALSE, argc, argv);

	pass_command_args(argc, argv);

	SDL_Event event;
	while (!exit_engine)
	{
		if (!isActive || tickPaused) SDL_WaitEvent(NULL);

		/* handle the events in the queue */
		while (SDL_PollEvent(&event))
		{
			switch(event.type)
			{
			case SDL_ACTIVEEVENT:
/*				if ((event.active.state & SDL_APPACTIVE) || (event.active.state & SDL_APPINPUTFOCUS))
				{
					if (event.active.gain == 0)
						isActive = FALSE;
					else
						isActive = TRUE;
				}
				printf("SDL Activity %d\n", isActive);
*/				break;

			case SDL_VIDEORESIZE:
				printf("resize %d x %d\n", event.resize.w, event.resize.h);
				do_resize(event.resize.w, event.resize.h, FALSE);

				if (current_game != LUA_NOREF)
				{
					lua_rawgeti(L, LUA_REGISTRYINDEX, current_game);
					lua_pushstring(L, "onResolutionChange");
					lua_gettable(L, -2);
					lua_remove(L, -2);
					lua_rawgeti(L, LUA_REGISTRYINDEX, current_game);
					docall(L, 1, 0);
				}

				break;

			case SDL_MOUSEBUTTONUP:
			case SDL_MOUSEBUTTONDOWN:
			case SDL_MOUSEMOTION:
			case SDL_KEYDOWN:
			case SDL_KEYUP:
				/* handle key presses */
				on_event(&event);
				tickPaused = FALSE;
				break;
			case SDL_QUIT:
				/* handle quit requests */
				exit_engine = TRUE;
				break;
			case SDL_USEREVENT:
				if (event.user.code == 0 && isActive) {
					on_redraw();
					redraw_pending = 0;
				}
				else if (event.user.code == 2 && isActive) {
					on_tick();
					realtime_pending = 0;
				}
				else if (event.user.code == 1) {
					on_music_stop();
				}
				break;
			default:
				break;
			}
		}

		/* draw the scene */
		if (!realtime_timer_id && isActive && !tickPaused) on_tick();

		/* Reboot the lua engine */
		if (core_def->corenum)
		{
			// Just reboot the lua VM
			if (core_def->corenum == TE4CORE_VERSION)
			{
				tickPaused = FALSE;
				setupRealtime(0);
				boot_lua(1, TRUE, argc, argv);
				boot_lua(2, TRUE, argc, argv);
			}
			// Clean up and tell the runner to run a different core
			else
			{
				lua_close(L);
				free_particles_thread();
				free_profile_thread();
				PHYSFS_deinit();
				break;
			}
		}
	}

	SDL_Quit();

#ifdef SELFEXE_WINDOWS
	fclose(stdout);
#endif
}
