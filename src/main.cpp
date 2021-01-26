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
#include "display.h"
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <math.h>
#include <sys/time.h>
#include "lauxlib.h"
#include "lualib.h"
#include "luasocket.h"
#include "luasocket/mime.h"
#include "SFMT.h"

#include "script.h"
#include "physfs.h"
#include "physfsrwops.h"
#include "wfc/lua_wfc_external.h"
#include "getself.h"
#include "serial.h"
#include "main.h"
#include "te4web.h"
#include "lua_externs.h"
#include "refcleaner_clean.h"
#include "particles.h"
#include "renderer-moderngl/renderer-lua.h"
#include "runner/core.h"
#ifdef SELFEXE_WINDOWS
#include <windows.h>
#endif
}

#include "music.hpp"
#include "core_lua.hpp"
#include "profile.hpp"
#include "renderer-moderngl/Interfaces.hpp"
#include "renderer-moderngl/Blending.hpp"
#include "utilities.hpp"
#include "imgui/te4_imgui.hpp"

#define WIDTH 800
#define HEIGHT 600
#define DEFAULT_IDLE_FPS (2)
#define WINDOW_ICON_PATH ("/engines/default/data/gfx/te4-icon.png")

#ifdef SELFEXE_WINDOWS
extern "C" {
// Force nvidia optimus and amd equivalent to use the real GPU instead of the intel crappy one
__declspec( dllexport ) DWORD NvOptimusEnablement                = 0x00000001;
__declspec( dllexport ) int AmdPowerXpressRequestHighPerformance = 1;
}
#endif

int start_xpos = -1, start_ypos = -1;
bool ignore_window_change_pos = false;
bool enable_gl_debug_log = false;
char *override_home = NULL;
int g_argc = 0;
char **g_argv;
float screen_zoom = 1;
bool offscreen_render = false;
int locked_w = 0, locked_h = 0;
SDL_Window *window = NULL;
SDL_Surface *windowIconSurface = NULL;
SDL_GLContext maincontext; /* Our opengl context handle */
SDL_GameController *gamepad = NULL;
SDL_Joystick *gamepadjoy = NULL;
int gamepad_instance_id = -1;
bool is_fullscreen = false;
bool is_borderless = false;
lua_State *L = NULL;
int nb_cpus;
bool no_debug = false;
bool safe_mode = false;
int current_mousehandler = LUA_NOREF;
int current_keyhandler = LUA_NOREF;
int current_gamepadhandler = LUA_NOREF;
int current_game = LUA_NOREF;
core_boot_type *core_def = NULL;
bool exit_engine = false;
bool no_sound = false;
bool no_steam = false;
bool tickPaused = false;
bool anims_paused = false;
int mouse_cursor_ox, mouse_cursor_oy;
int mousex = 0, mousey = 0;
float gamma_correction = 1;
int cur_frame_tick = 0;
int frame_tick_paused_time = 0;
/* The currently requested fps for the program */
int ticks_per_frame = 1;
float current_fps = NORMALIZED_FPS;
int requested_fps = NORMALIZED_FPS;
int max_ms_per_frame = 33;
/* The requested fps for when the program is idle (i.e., doesn't have focus) */
int requested_fps_idle = DEFAULT_IDLE_FPS;
/* The currently "saved" fps, used for idle transitions. */
int requested_fps_idle_saved = 0;
bool forbid_idle_mode = false;
bool no_connectivity = false;

bool desktop_gamma_set = false;
float desktop_gamma = 1.0;

/* OpenGL capabilities */
GLint max_texture_size = 1024;
extern bool shaders_active;
bool fbo_active;
bool multitexture_active;

ImGuiIO *imgui_io = nullptr;

/*
 * Locks for thread safety with respect to the rendering.
 * The locks are used to control access to each timer's respective id and flag.
 */
SDL_mutex *renderingLock;
SDL_TimerID display_timer_id = 0;
int redraw_pending = 0;

/* Error handling */
lua_err_type *last_lua_error_head = NULL, *last_lua_error_tail = NULL;

/*
 * Used to clean up a lock and its corresponding timer/flag.
 *
 * @param lock
 *  The lock which is used by the timer and its event handler.
 *
 * @param timer
 *  The id of the timer to clean up.
 *
 * @param timerFlag
 *  The flag variable that timer and its events use.
 *
 */
static void cleanupTimerLock(SDL_mutex *lock, SDL_TimerID *timer, int *timerFlag);

/*
 * Handles transitions to and from idle mode.
 *
 * A transition is only performed if the game already has a running render timer
 *  and there is an actual idle->normal or normal->idle transition.
 *
 * @param goIdle
 *  Return to normal game rendering speed if zero, go idle otherwise.
 */
static void handleIdleTransition(int goIdle);

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

	lua_err_type *cur = (lua_err_type*)calloc(1, sizeof(lua_err_type));
	cur->err_msg = strdup(err);
	cur->next = NULL;

	last_lua_error_head = cur;
	last_lua_error_tail = cur;
}

static void add_lua_error(const char *file, int line, const char *func)
{
	lua_err_type *cur = (lua_err_type*)calloc(1, sizeof(lua_err_type));
	cur->err_msg = NULL;
	cur->file = strdup(file);
	cur->line = line;
	cur->func = strdup(func);
	cur->next = NULL;

	last_lua_error_tail->next = cur;
	last_lua_error_tail = cur;
}

int traceback (lua_State *L, bool produce_error) {
	lua_Debug ar;
	int n = 0;
	printf("Lua Error: %s\n", lua_tostring(L, 1));
	while(lua_getstack(L, n++, &ar)) {
		lua_getinfo(L, "nSl", &ar);
		printf("\tAt %s:%d %s\n", ar.short_src, ar.currentline, ar.name?ar.name:"");
	}

	// Do it again for the lua error popup, if needed
	if (produce_error)
	{
		n = 0;
		new_lua_error(lua_tostring(L, 1));
		while(lua_getstack(L, n++, &ar)) {
			lua_getinfo(L, "nSl", &ar);
			add_lua_error(ar.short_src, ar.currentline, ar.name?ar.name:"");
		}
	}
	fflush(stdout);
	return 1;
}

static int traceback_error(lua_State *L) {
	return traceback(L, true);
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
			{ printf("%d: %s // %lx\n", i, lua_typename(L, t), (unsigned long int)lua_topointer(L, i)); }
			else
			{ printf("%d: %s // %lx\n", i, lua_typename(L, t), (unsigned long int)lua_topointer(L, i)); }
#else
			printf("%d: %s // %x\n", i, lua_typename(L, t), lua_topointer(L, i));
#endif
			break;
		}
		i--;
	}
	printf("--------------- Stack Dump Finished ---------------\n" );
	fflush(stdout);
}

int docall (lua_State *L, int narg, int nret)
{
#if 1
	int status;
	int base = lua_gettop(L) - narg;  /* function index */
//	printf("<===%d (%d)\n", base, narg);
	lua_pushcfunction(L, traceback_error);  /* push traceback function */
	lua_insert(L, base);  /* put it under chunk and args */
	status = lua_pcall(L, narg, nret, base);
	lua_remove(L, base);  /* remove traceback function */
	/* force a complete garbage collection in case of errors */
	if (status != 0) { lua_pop(L, 1); lua_gc(L, LUA_GCCOLLECT, 0); }
//	printf(">===%d (%d) [%d]\n", lua_gettop(L), nret, status);
	if (lua_gettop(L) != nret + (base - 1))
	{
		stackDump(L);
//		assert(0);
		lua_settop(L, base);
	}
	return status;
#else
	int status=0;
	int base = lua_gettop(L) - narg;  /* function index */
	lua_call(L, narg, nret);
	return status;
#endif
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

int event_filter(void *userdata, SDL_Event* event)
{
	// Do not allow the user to close without asking the game to know about it
	if (event->type == SDL_QUIT && (current_game != LUA_NOREF))
	{
		lua_rawgeti(L, LUA_REGISTRYINDEX, current_game);
		lua_pushliteral(L, "onQuit");
		lua_gettable(L, -2);
		lua_remove(L, -2);
		lua_rawgeti(L, LUA_REGISTRYINDEX, current_game);
		docall(L, 1, 0);

		return 0;
	}
	return 1;
}

#define MIN(a,b) ((a < b) ? a : b)
#define MAX(a,b) ((a < b) ? b : a)

extern SDL_Cursor *mouse_cursor;
extern SDL_Cursor *mouse_cursor_down;

// Calls the lua music callback
void on_music_stop()
{
	if (current_game != LUA_NOREF)
	{
		lua_rawgeti(L, LUA_REGISTRYINDEX, current_game);
		lua_pushliteral(L, "onMusicStop");
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

bool on_event(SDL_Event *event)
{
	ImGui_ImplSDL2_ProcessEvent(event);

	switch (event->type) {
	case SDL_WINDOWEVENT: {
		switch (event->window.event) {
		case SDL_WINDOWEVENT_RESIZED:
			/* Note: SDL can't resize a fullscreen window, so don't bother! */
			if (!is_fullscreen) {
				printf("SDL_WINDOWEVENT_RESIZED: %d x %d\n", event->window.data1, event->window.data2);
				do_resize(event->window.data1, event->window.data2, is_fullscreen, is_borderless, screen_zoom);
				if (current_game != LUA_NOREF)
				{
					lua_rawgeti(L, LUA_REGISTRYINDEX, current_game);
					lua_pushliteral(L, "onResolutionChange");
					lua_gettable(L, -2);
					lua_remove(L, -2);
					lua_rawgeti(L, LUA_REGISTRYINDEX, current_game);
					docall(L, 1, 0);
				}
			} else {
				printf("SDL_WINDOWEVENT_RESIZED: ignored due to fullscreen\n");

			}
			break;
		case SDL_WINDOWEVENT_MOVED: {
			int x, y;
			/* Note: SDL can't resize a fullscreen window, so don't bother! */
			if (!is_fullscreen) {
				SDL_GetWindowPosition(window, &x, &y);
				if (current_game != LUA_NOREF)
				{
					lua_rawgeti(L, LUA_REGISTRYINDEX, current_game);
					lua_pushliteral(L, "onWindowMoved");
					lua_gettable(L, -2);
					lua_remove(L, -2);
					lua_rawgeti(L, LUA_REGISTRYINDEX, current_game);
					lua_pushnumber(L, x);
					lua_pushnumber(L, y);
					docall(L, 3, 0);
				}
			} else {
				printf("SDL_WINDOWEVENT_MOVED: ignored due to fullscreen\n");
			}
			break;
		}
		case SDL_WINDOWEVENT_CLOSE:
			event->type = SDL_QUIT;
			SDL_PushEvent(event);
			break;

		case SDL_WINDOWEVENT_SHOWN:
		case SDL_WINDOWEVENT_FOCUS_GAINED:
			SDL_SetModState(KMOD_NONE);
			/* break from idle */
			//printf("[EVENT HANDLER]: Got a SHOW/FOCUS_GAINED event, restoring full FPS.\n");
			handleIdleTransition(0);
			break;

		case SDL_WINDOWEVENT_HIDDEN:
		case SDL_WINDOWEVENT_FOCUS_LOST:
			/* go idle */
			SDL_SetModState(KMOD_NONE);
			//printf("[EVENT HANDLER]: Got a HIDDEN/FOCUS_LOST event, going idle.\n");
			handleIdleTransition(1);
			break;
		default:
			break;

		}
		break;
	}
	case SDL_QUIT:
		exit_engine = true;
		break;
	case SDL_USEREVENT:
		switch(event->user.code) {
		case 1:
			on_music_stop();
			break;
		default:
			break;
		}
		break;
	case SDL_TEXTINPUT:
		if (imgui_io->WantTextInput) break;
		if (current_keyhandler != LUA_NOREF)
		{
			static Uint32 lastts = 0;
			static char lastc = 0;
			if (browsers_count) { // Somehow CEF3 makes keys sometime arrive duplicated, so prevent that here
				if (event->text.timestamp == lastts) break;
				if ((event->text.timestamp - lastts < 3) && (lastc == event->text.text[0])) break;
			}
			lastts = event->text.timestamp;
			lastc = event->text.text[0];

			lua_rawgeti(L, LUA_REGISTRYINDEX, current_keyhandler);
			lua_pushliteral(L, "receiveKey");
			lua_gettable(L, -2);
			lua_remove(L, -2);
			lua_rawgeti(L, LUA_REGISTRYINDEX, current_keyhandler);
			lua_pushnumber(L, 0);

			SDL_Keymod _pKeyState = SDL_GetModState();
			lua_pushboolean(L, (_pKeyState & KMOD_CTRL) ? true : false);
			lua_pushboolean(L, (_pKeyState & KMOD_SHIFT) ? true : false);
			lua_pushboolean(L, (_pKeyState & KMOD_ALT) ? true : false);
			lua_pushboolean(L, (_pKeyState & KMOD_GUI) ? true : false);

			lua_pushstring(L, event->text.text);
			lua_pushboolean(L, false);
			lua_pushnil(L);
			lua_pushnil(L);
			lua_pushnumber(L, 0);

			docall(L, 11, 0);
		}
		return true;
	case SDL_KEYDOWN:
	case SDL_KEYUP:
		if (imgui_io->WantCaptureKeyboard) break;
		if (current_keyhandler != LUA_NOREF)
		{
			lua_rawgeti(L, LUA_REGISTRYINDEX, current_keyhandler);
			lua_pushliteral(L, "receiveKey");
			lua_gettable(L, -2);
			lua_remove(L, -2);
			lua_rawgeti(L, LUA_REGISTRYINDEX, current_keyhandler);
			lua_pushnumber(L, event->key.keysym.scancode);

			SDL_Keymod _pKeyState = SDL_GetModState();
			lua_pushboolean(L, (_pKeyState & KMOD_CTRL) ? true : false);
			lua_pushboolean(L, (_pKeyState & KMOD_SHIFT) ? true : false);
			lua_pushboolean(L, (_pKeyState & KMOD_ALT) ? true : false);
			lua_pushboolean(L, (_pKeyState & KMOD_GUI) ? true : false);

			lua_pushnil(L);
			lua_pushboolean(L, (event->type == SDL_KEYUP) ? true : false);

			/* Convert unicode UCS-2 to UTF8 string */
			if (event->key.keysym.sym)
			{
				wchar_t wc = event->key.keysym.sym;

				char buf[4] = {0,0,0,0};
				if (wc < 0x80)
				{
					buf[0] = wc;
				}
				else if (wc < 0x800)
				{
					buf[0] = (0xC0 | wc>>6);
					buf[1] = (0x80 | (wc & 0x3F));
				}
				else
				{
					buf[0] = (0xE0 | wc>>12);
					buf[1] = (0x80 | (wc>>6 & 0x3F));
					buf[2] = (0x80 | (wc & 0x3F));
				}

				lua_pushstring(L, buf);
			}
			else
				lua_pushnil(L);

			lua_pushnil(L);
			lua_pushnumber(L, event->key.keysym.sym);

			docall(L, 11, 0);
		}
		return true;
	case SDL_MOUSEBUTTONDOWN:
	case SDL_MOUSEBUTTONUP:
		if (imgui_io->WantCaptureMouse) break;
		if (event->type == SDL_MOUSEBUTTONDOWN) SDL_SetCursor(mouse_cursor_down);
		else SDL_SetCursor(mouse_cursor);

		if (current_mousehandler != LUA_NOREF)
		{
			lua_rawgeti(L, LUA_REGISTRYINDEX, current_mousehandler);
			lua_pushliteral(L, "receiveMouse");
			lua_gettable(L, -2);
			lua_remove(L, -2);
			lua_rawgeti(L, LUA_REGISTRYINDEX, current_mousehandler);
			switch (event->button.button)
			{
			case SDL_BUTTON_LEFT:
#if 1
				{
				SDL_Keymod _pKeyState = SDL_GetModState();
				if (_pKeyState & KMOD_ALT) lua_pushliteral(L, "right");
				else lua_pushliteral(L, "left");
				}
#else
				lua_pushliteral(L, "left");
#endif
				break;
			case SDL_BUTTON_MIDDLE:
				lua_pushliteral(L, "middle");
				break;
			case SDL_BUTTON_RIGHT:
				lua_pushliteral(L, "right");
				break;
			default:
				lua_pushliteral(L, "button");
				lua_pushnumber(L, event->button.button);
				lua_concat(L, 2);
				break;
			}
			lua_pushnumber(L, event->button.x / screen_zoom);
			lua_pushnumber(L, event->button.y / screen_zoom);
			lua_pushboolean(L, (event->type == SDL_MOUSEBUTTONUP) ? true : false);
			docall(L, 5, 0);
		}
		return true;
	case SDL_MOUSEWHEEL:
		if (imgui_io->WantCaptureMouse) break;
		if (current_mousehandler != LUA_NOREF)
		{
			int x = 0, y = 0;
			SDL_GetMouseState(&x, &y);

			int i;
			for (i = 0; i <= 1; i++)
			{
				lua_rawgeti(L, LUA_REGISTRYINDEX, current_mousehandler);
				lua_pushliteral(L, "receiveMouse");
				lua_gettable(L, -2);
				lua_remove(L, -2);
				lua_rawgeti(L, LUA_REGISTRYINDEX, current_mousehandler);
				if (event->wheel.y > 0) lua_pushliteral(L, "wheelup");
				else if (event->wheel.y < 0) lua_pushliteral(L, "wheeldown");
				else if (event->wheel.x > 0) lua_pushliteral(L, "wheelleft");
				else if (event->wheel.x < 0) lua_pushliteral(L, "wheelright");
				else lua_pushliteral(L, "wheelnone");
				lua_pushnumber(L, x / screen_zoom);
				lua_pushnumber(L, y / screen_zoom);
				lua_pushboolean(L, i);
				docall(L, 5, 0);
			}
		}
		return true;
	case SDL_MOUSEMOTION:
		if (imgui_io->WantCaptureMouse) break;
		mousex = event->motion.x / screen_zoom;
		mousey = event->motion.y / screen_zoom;

		if (current_mousehandler != LUA_NOREF)
		{
			lua_rawgeti(L, LUA_REGISTRYINDEX, current_mousehandler);
			lua_pushliteral(L, "receiveMouseMotion");
			lua_gettable(L, -2);
			lua_remove(L, -2);
			lua_rawgeti(L, LUA_REGISTRYINDEX, current_mousehandler);
			if (event->motion.state & SDL_BUTTON(1)) lua_pushliteral(L, "left");
			else if (event->motion.state & SDL_BUTTON(2)) lua_pushliteral(L, "middle");
			else if (event->motion.state & SDL_BUTTON(3)) lua_pushliteral(L, "right");
			else if (event->motion.state & SDL_BUTTON(4)) lua_pushliteral(L, "wheelup");
			else if (event->motion.state & SDL_BUTTON(5)) lua_pushliteral(L, "wheeldown");
			else lua_pushliteral(L, "none");
			lua_pushnumber(L, event->motion.x / screen_zoom);
			lua_pushnumber(L, event->motion.y / screen_zoom);
			lua_pushnumber(L, event->motion.xrel);
			lua_pushnumber(L, event->motion.yrel);
			docall(L, 6, 0);
		}
		return true;
	case SDL_FINGERDOWN:
	case SDL_FINGERUP:
		if (current_mousehandler != LUA_NOREF)
		{
			lua_rawgeti(L, LUA_REGISTRYINDEX, current_mousehandler);
			lua_pushliteral(L, "receiveTouch");
			lua_gettable(L, -2);
			lua_remove(L, -2);
			lua_rawgeti(L, LUA_REGISTRYINDEX, current_mousehandler);
			lua_pushnumber(L, event->tfinger.fingerId);
			lua_pushnumber(L, event->tfinger.x / screen_zoom);
			lua_pushnumber(L, event->tfinger.y / screen_zoom);
			lua_pushnumber(L, event->tfinger.dx);
			lua_pushnumber(L, event->tfinger.dy);
			lua_pushnumber(L, event->tfinger.pressure);
			lua_pushboolean(L, (event->type == SDL_FINGERUP) ? true : false);
			docall(L, 8, 0);
		}
		return true;
	case SDL_FINGERMOTION:
		if (current_mousehandler != LUA_NOREF)
		{
			lua_rawgeti(L, LUA_REGISTRYINDEX, current_mousehandler);
			lua_pushliteral(L, "receiveTouchMotion");
			lua_gettable(L, -2);
			lua_remove(L, -2);
			lua_rawgeti(L, LUA_REGISTRYINDEX, current_mousehandler);
			lua_pushnumber(L, event->tfinger.fingerId);
			lua_pushnumber(L, event->tfinger.x / screen_zoom);
			lua_pushnumber(L, event->tfinger.y / screen_zoom);
			lua_pushnumber(L, event->tfinger.dx);
			lua_pushnumber(L, event->tfinger.dy);
			lua_pushnumber(L, event->tfinger.pressure);
			docall(L, 7, 0);
		}
		return true;
	case SDL_MULTIGESTURE:
		if (current_mousehandler != LUA_NOREF)
		{
			lua_rawgeti(L, LUA_REGISTRYINDEX, current_mousehandler);
			lua_pushliteral(L, "receiveTouchGesture");
			lua_gettable(L, -2);
			lua_remove(L, -2);
			lua_rawgeti(L, LUA_REGISTRYINDEX, current_mousehandler);
			lua_pushnumber(L, event->mgesture.numFingers);
			lua_pushnumber(L, event->mgesture.x / screen_zoom);
			lua_pushnumber(L, event->mgesture.y / screen_zoom);
			lua_pushnumber(L, event->mgesture.dTheta);
			lua_pushnumber(L, event->mgesture.dDist);
			docall(L, 6, 0);
		}
		return true;
	case SDL_CONTROLLERDEVICEADDED:
		if (current_gamepadhandler != LUA_NOREF)
		{
			lua_rawgeti(L, LUA_REGISTRYINDEX, current_gamepadhandler);
			lua_pushliteral(L, "receiveDevice");
			lua_gettable(L, -2);
			lua_remove(L, -2);
			lua_rawgeti(L, LUA_REGISTRYINDEX, current_gamepadhandler);
			lua_pushboolean(L, true);
			lua_pushnumber(L, event->cdevice.which);
			docall(L, 3, 0);
		}
		return true;

	case SDL_CONTROLLERDEVICEREMOVED:
		if (current_gamepadhandler != LUA_NOREF)
		{
			lua_rawgeti(L, LUA_REGISTRYINDEX, current_gamepadhandler);
			lua_pushliteral(L, "receiveDevice");
			lua_gettable(L, -2);
			lua_remove(L, -2);
			lua_rawgeti(L, LUA_REGISTRYINDEX, current_gamepadhandler);
			lua_pushboolean(L, false);
			lua_pushnumber(L, event->cdevice.which);
			docall(L, 3, 0);
		}
		return true;

	case SDL_CONTROLLERBUTTONDOWN:
	case SDL_CONTROLLERBUTTONUP:
		if (current_gamepadhandler != LUA_NOREF)
		{
			lua_rawgeti(L, LUA_REGISTRYINDEX, current_gamepadhandler);
			lua_pushliteral(L, "receiveButton");
			lua_gettable(L, -2);
			lua_remove(L, -2);
			lua_rawgeti(L, LUA_REGISTRYINDEX, current_gamepadhandler);
			lua_pushstring(L, SDL_GameControllerGetStringForButton((SDL_GameControllerButton)event->cbutton.button));
			lua_pushboolean(L, event->cbutton.state == SDL_RELEASED ? true : false);
			docall(L, 3, 0);
		}
		return true;

	case SDL_CONTROLLERAXISMOTION:
		if (current_gamepadhandler != LUA_NOREF)
		{
			float v = (float)event->caxis.value / 32770;
			lua_rawgeti(L, LUA_REGISTRYINDEX, current_gamepadhandler);
			lua_pushliteral(L, "receiveAxis");
			lua_gettable(L, -2);
			lua_remove(L, -2);
			lua_rawgeti(L, LUA_REGISTRYINDEX, current_gamepadhandler);
			lua_pushstring(L, SDL_GameControllerGetStringForAxis((SDL_GameControllerAxis)event->caxis.axis));
			lua_pushnumber(L, v);
			docall(L, 3, 0);
		}
		return true;
	}
	return false;
}

// redraw the screen and update game logics, if any
void on_tick()
{
	static int Frames = 0;
	static int T0     = 0;

	if (current_game != LUA_NOREF)
	{
		lua_rawgeti(L, LUA_REGISTRYINDEX, current_game);
		lua_pushliteral(L, "tick");
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

static void call_draw(float nb_keyframes)
{
	if (draw_waiting(L)) return;

	if (nb_keyframes > NORMALIZED_FPS) nb_keyframes = NORMALIZED_FPS;

	if (current_game != LUA_NOREF)
	{
		lua_rawgeti(L, LUA_REGISTRYINDEX, current_game);
		lua_pushliteral(L, "display");
		lua_gettable(L, -2);
		lua_remove(L, -2);
		lua_rawgeti(L, LUA_REGISTRYINDEX, current_game);
		lua_pushnumber(L, (nb_keyframes < 0) ? 0 : nb_keyframes);
		docall(L, 2, 0);
	}

	mouse_draw_drag();

	// Notify the particles threads that there are new keyframes
	// We do it at the END so they have all the time until next frame to compute
	if (!anims_paused) {
		thread_particle_new_keyframes(nb_keyframes);
		threaded_runner_keyframe(nb_keyframes);
	}
	interface_realtime(nb_keyframes);
}

static bool imgui_loaded = false;
redraw_type_t current_redraw_type = redraw_type_normal;
void on_redraw()
{
	static int last_ticks = 0;
	static int ticks_count = 0;
	static int ticks_count_gc = 0;
	static float keyframes_done = 0;
	static int frames_done = 0;
	static float frames_count = 0;

	int ticks = SDL_GetTicks();
	ticks_count += ticks - last_ticks;
	ticks_count_gc += ticks - last_ticks;

	if (!anims_paused) cur_frame_tick = ticks - frame_tick_paused_time;

	if (imgui_loaded) {
		// Start the Dear ImGui frame
		ImGui_ImplOpenGL3_NewFrame();
		ImGui_ImplSDL2_NewFrame(window);
		ImGui::NewFrame();
	}

	glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

	frames_count = ((float)ticks - last_ticks) / ((float)1000.0 / (float)NORMALIZED_FPS);
	float nb_keyframes = frames_count;
	run_physic_simulation(nb_keyframes);
	call_draw(nb_keyframes);
	keyframes_done += nb_keyframes;
	frames_done++;

	if (imgui_loaded) {
		ImGui::Render();
		ImGui_ImplOpenGL3_RenderDrawData(ImGui::GetDrawData());
	}

	switch (current_redraw_type)
	{
	case redraw_type_user_screenshot:
	case redraw_type_savefile_screenshot:
		// glReadPixels reads from the back buffer, so skip swap when we're doing a screenshot.
		break;
	default:
		//SDL_GL_SwapBuffers();
		SDL_GL_SwapWindow(window);
		break;
	}

	// ticks_per_frame = /;
	last_ticks = ticks;

	if (ticks_count >= 500) {
		current_fps = (float)frames_done * 1000.0 / (float)ticks_count;
		//printf("%d frames in %d ms = %0.2f FPS (%f keyframes)\n", frames_done, ticks_count, current_fps, keyframes_done);
		ticks_count = 0;
		frames_done = 0;
		keyframes_done = 0;
	}

	loader_tick();
#ifdef STEAM_TE4
	if (!no_steam) te4_steam_callbacks();
#endif
#ifdef DISCORD_TE4
	te4_discord_update();
#endif
	if (te4_web_update) te4_web_update(L);

	update_audio(nb_keyframes);

	// Run GC every second, this is the only place the GC should be called
	// This is also a way to ensure the GC wont try to delete things while in callbacks from the display code and such which is annoying
	if (ticks_count_gc >= 5000) {
		refcleaner_clean(L);
		// lua_gc(L, LUA_GCSTEP, 5);
		lua_gc(L, LUA_GCCOLLECT, 0);
		ticks_count_gc = 0;
	}
}

void redraw_now(redraw_type_t rtype) {
	bool changed_gamma = FALSE;
	if (rtype == redraw_type_savefile_screenshot)
	{
		if (current_game != LUA_NOREF)
		{
			// current_game:setFullscreenShaderGamma(1)
			lua_rawgeti(L, LUA_REGISTRYINDEX, current_game);
			lua_pushstring(L, "setFullscreenShaderGamma");
			lua_gettable(L, -2);
			lua_remove(L, -2);
			lua_rawgeti(L, LUA_REGISTRYINDEX, current_game);
			lua_pushnumber(L, 1);
			docall(L, 2, 0);
			changed_gamma = TRUE;
		}
	}

	current_redraw_type = rtype;
	on_redraw();

	if (changed_gamma)
	{
		// current_game:setFullscreenShaderGamma(gamma_correction)
		lua_rawgeti(L, LUA_REGISTRYINDEX, current_game);
		lua_pushstring(L, "setFullscreenShaderGamma");
		lua_gettable(L, -2);
		lua_remove(L, -2);
		lua_rawgeti(L, LUA_REGISTRYINDEX, current_game);
		lua_pushnumber(L, gamma_correction);
		docall(L, 2, 0);
	}
}

redraw_type_t get_current_redraw_type() {
	return current_redraw_type;
}

void pass_command_args(int argc, char *argv[])
{
	int i;

	if (current_game != LUA_NOREF)
	{
		lua_rawgeti(L, LUA_REGISTRYINDEX, current_game);
		lua_pushliteral(L, "commandLineArgs");
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

	// Grab the rendering lock and see if a redraw should be requested.
	SDL_mutexP(renderingLock);
	// If there is no redraw pending, request one.  Otherwise, ignore.
	if (!redraw_pending) {
		SDL_PushEvent(&event);
		redraw_pending = 1;
	}
	SDL_mutexV(renderingLock);
	return(interval);
}

/* general OpenGL initialization function */
int initGL() {
	/* Set the background black */
	tglClearColor( 0.0f, 0.0f, 0.0f, 1.0f );

	/* Depth buffer setup */
	glClearDepth( 1.0f );

	/* The Type Of Depth Test To Do */
	glDepthFunc(GL_LEQUAL);

	glEnable(GL_BLEND);
	glEnable(GL_PROGRAM_POINT_SIZE);	

	glEnableClientState(GL_VERTEX_ARRAY);
	glEnableClientState(GL_TEXTURE_COORD_ARRAY);
	glEnableClientState(GL_COLOR_ARRAY);

	BlendingState::clear();
	BlendingState::push(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

	return( true );
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

	/* Set our perspective */
	//gluPerspective( 45.0f, ratio, 0.1f, 100.0f );
	// glOrtho(0, width / screen_zoom, height / screen_zoom, 0, -1001, 1001);

	/* Make sure we're chaning the model view and not the projection */
	// glMatrixMode( GL_MODELVIEW );

	/* Reset The View */
	// glLoadIdentity( );

//TSDL2	SDL_SetGamma(gamma_correction, gamma_correction, gamma_correction);

	glGetIntegerv(GL_MAX_TEXTURE_SIZE, &max_texture_size);
	printf("OpenGL max texture size: %d\n", max_texture_size);


	return( true );
}

/* @see main.h#resizeNeedsNewWindow */
extern bool resizeNeedsNewWindow(int w, int h, bool fullscreen, bool borderless)
{
	/* Note: w and h currently not a factor */
	bool newWindowNeeded = window && ( (is_borderless && !borderless)
										|| (!is_borderless && borderless) );
	return (newWindowNeeded);
}

/* @see main.h#do_move */
void do_move(int w, int h) {
	/* Save the origin in case a window needs to be remade later. */
	if (!ignore_window_change_pos) {
		start_xpos = w;
		start_ypos = h;
	} else {
		// w = start_xpos;
		h = start_ypos;
	}

	/* Can't move a fullscreen SDL window in one go.*/
	if (is_fullscreen) {
		/* Drop out of fullscreen so we can move the window. */
		SDL_SetWindowFullscreen(window, SDL_FALSE);

	}

	/* Move the window */
	SDL_SetWindowPosition(window, w, h);

	/* Jump back into fullscreen if necessary */
	if (is_fullscreen) {
		if (!SDL_SetWindowFullscreen(window, SDL_TRUE)) {
			/* Fullscreen change successful */
			is_fullscreen = SDL_TRUE;

		} else {
			/* Error switching fullscreen mode */
			printf("[DO MOVE] Unable to return window"
					" to fullscreen mode:  %s\n", SDL_GetError());
			SDL_ClearError();
		}

	}

}

void GLAPIENTRY openglDebugCallbackFunction(GLenum source, GLenum type, GLuint id, GLenum severity, GLsizei length, const GLchar* message, const void* userParam) {
	if (type == GL_DEBUG_TYPE_OTHER) return ;
	printf("\x1b[33m---------------------opengl-callback-start------------\n");
	printf("message: %s\n", message);
	printf("type: ");
	switch (type) {
	case GL_DEBUG_TYPE_ERROR:
		printf("ERROR");
		break;
	case GL_DEBUG_TYPE_DEPRECATED_BEHAVIOR:
		printf("DEPRECATED_BEHAVIOR");
		break;
	case GL_DEBUG_TYPE_UNDEFINED_BEHAVIOR:
		printf("UNDEFINED_BEHAVIOR");
		break;
	case GL_DEBUG_TYPE_PORTABILITY:
		printf("PORTABILITY");
		break;
	case GL_DEBUG_TYPE_PERFORMANCE:
		printf("PERFORMANCE");
		break;
	case GL_DEBUG_TYPE_OTHER:
		printf("OTHER");
		break;
	}
	printf("\n");
 
	printf("id: %d\n", id);
	printf("severity: ");
	switch (severity){
	case GL_DEBUG_SEVERITY_LOW:
		printf("LOW");
		break;
	case GL_DEBUG_SEVERITY_MEDIUM:
		printf("MEDIUM");
		break;
	case GL_DEBUG_SEVERITY_HIGH:
		printf("HIGH");
		break;
	}
	printf("\n---------------------opengl-callback-end--------------\x1b[0m\n");
}

static void imgui_save_settings() {
	imgui_io->WantSaveIniSettings = false;
	size_t len;
	const char* ini = ImGui::SaveIniSettingsToMemory(&len);

	string oldwrite(PHYSFS_getWriteDir());
	
	lua_getglobal(L, "engine");
	lua_pushliteral(L, "homepath");
	lua_gettable(L, -2);
	const char* homepath = lua_tostring(L, -1); lua_pop(L, 1);
	PHYSFS_setWriteDir(homepath);

	auto f = PHYSFS_openWrite("/imgui_settings.ini");
	PHYSFS_write(f, ini, sizeof(char), len);
	PHYSFS_close(f);

	PHYSFS_setWriteDir(oldwrite.c_str());
}

static void imgui_load_settings() {
	imgui_loaded = true;

	auto f = PHYSFS_openRead("/imgui_settings.ini");
	if (!f) return;

	long n = ~((size_t)0);
	size_t rlen;  /* how much to read */
	size_t nr;  /* number of chars actually read */
	luaL_Buffer b;
	luaL_buffinit(L, &b);
	rlen = LUAL_BUFFERSIZE;  /* try to read that much each time */
	do {
		char *p = luaL_prepbuffer(&b);
		if (rlen > n) rlen = n;  /* cannot read more than asked */
		nr = PHYSFS_read(f, p, sizeof(char), rlen);
		luaL_addsize(&b, nr);
		n -= nr;  /* still have to read `n' chars */
	} while (n > 0 && nr == rlen);  /* until end of count or eof */
	luaL_pushresult(&b);  /* close buffer */
	
	if (n == 0 || lua_objlen(L, -1) > 0) {
		size_t len;
		const char* ini = lua_tolstring(L, -1, &len);
		ImGui::LoadIniSettingsFromMemory(ini, len);
	}
	lua_pop(L, 1);

	PHYSFS_close(f);
}

extern void interface_resize(int w, int h); // From Interface.cpp

/* @see main.h#do_resize */
void do_resize(int w, int h, bool fullscreen, bool borderless, float zoom)
{
	/* Temporary width, height (since SDL might reject our resize) */
	int aw, ah;
	int mustPushEvent = 0;
	int mustCreateIconSurface = 0;
	SDL_Event fsEvent;

	screen_zoom = zoom;

	if (locked_w && locked_h) {
		printf("[DO RESIZE] locking size to %dx%d\n", locked_w, locked_h);
		w = locked_w; h = locked_h;
	}

	printf("[DO RESIZE] Requested: %dx%d (%d, %d); zoom %d%%\n", w, h, fullscreen, borderless, (int)(zoom * 100));

	/* See if we need to reinitialize the window */
	if (resizeNeedsNewWindow(w, h, fullscreen, borderless)) {
		/* Destroy the current window */
		SDL_GL_DeleteContext(maincontext);
		SDL_DestroyWindow(window);
		maincontext = 0;
		window = 0;
		screen = 0;
		/* Clean up the old window icon */
		SDL_FreeSurface(windowIconSurface);
		windowIconSurface = 0;
		/* Signal a new icon needs to be created. */
		mustCreateIconSurface = 1;
	}

	/* If there is no current window, we have to make one and initialize */
	if (!window) {
		SDL_GL_SetAttribute(SDL_GL_DEPTH_SIZE, 16);
		if (enable_gl_debug_log) SDL_GL_SetAttribute(SDL_GL_CONTEXT_FLAGS, SDL_GL_CONTEXT_DEBUG_FLAG);
		// if (SDL_GL_SetSwapInterval(-1)) SDL_GL_SetSwapInterval(1);
		
		window = SDL_CreateWindow("TE4",
				(start_xpos == -1) ? SDL_WINDOWPOS_CENTERED : start_xpos,
				(start_ypos == -1) ? SDL_WINDOWPOS_CENTERED : start_ypos, w, h,
				SDL_WINDOW_SHOWN | SDL_WINDOW_OPENGL
				| (!borderless ? SDL_WINDOW_RESIZABLE : 0)
				| (fullscreen ? SDL_WINDOW_FULLSCREEN : 0)
				| (borderless ? SDL_WINDOW_BORDERLESS : 0)
		);
		if (window==NULL) {
			printf("error opening screen: %s\n", SDL_GetError());
			exit(1);
		}
		is_fullscreen = fullscreen;
		is_borderless = borderless;
		screen = SDL_GetWindowSurface(window);
		// SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 3);
		// SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, 3);
		maincontext = SDL_GL_CreateContext(window);
		SDL_GL_MakeCurrent(window, maincontext);
		glewInit();
		printf ("OpenGL version: %s\n", glGetString(GL_VERSION));

		ImGui::CreateContext();
		ImGuiIO& io = ImGui::GetIO();
		imgui_io = &io;
		io.IniFilename = nullptr;
		io.ConfigFlags |= ImGuiConfigFlags_NavEnableKeyboard;     // Enable Keyboard Controls
		io.ConfigFlags |= ImGuiConfigFlags_NoMouseCursorChange;     // Enable Keyboard Controls
		ImGui::StyleColorsDark();
		ImGui_ImplSDL2_InitForOpenGL(window, maincontext);
		ImGui_ImplOpenGL3_Init("#version 130");

		/* Set the window icon. */
		windowIconSurface = IMG_Load_RW(PHYSFSRWOPS_openRead(WINDOW_ICON_PATH)
				, true);
		SDL_SetWindowIcon(window, windowIconSurface);
		if (offscreen_render) SDL_HideWindow(window);

		if (enable_gl_debug_log) {
			if (glDebugMessageCallback) {
				printf("Register OpenGL debug callback\n");
				glEnable(GL_DEBUG_OUTPUT_SYNCHRONOUS);
				glDebugMessageCallback((GLDEBUGPROC)openglDebugCallbackFunction, nullptr);
				GLuint unusedIds = 0;
				glDebugMessageControl(GL_DONT_CARE, GL_DONT_CARE, GL_DONT_CARE, 0, &unusedIds, true);
			}
			else printf("glDebugMessageCallback not available\n");
		}
		if (!desktop_gamma_set) {
			desktop_gamma = SDL_GetWindowBrightness(window);
			desktop_gamma_set = TRUE;
			printf("[GAMMA] Getting desktop gamma of %f\n", desktop_gamma);
		}
	} else {

		/* SDL won't allow a fullscreen resolution change in one go.  Check. */
		if (is_fullscreen) {
			/* Drop out of fullscreen so we can change resolution. */
			SDL_SetWindowFullscreen(window, SDL_FALSE);
			is_fullscreen = 0;
			mustPushEvent = 1; /* Actually just a maybe for now, confirmed later */

		}

		/* Update window size */
		SDL_SetWindowSize(window, w, h);

		/* Jump [back] into fullscreen if requested */
		if (fullscreen) {
			if (!SDL_SetWindowFullscreen(window, SDL_TRUE)) {
				/* Fullscreen change successful */
				is_fullscreen = SDL_TRUE;

			} else {
				/* Error switching fullscreen mode */
				printf("[DO RESIZE] Unable to switch window"
						" to fullscreen mode:  %s\n", SDL_GetError());
				SDL_ClearError();
			}

		} else if (mustPushEvent) {
			/* Handle fullscreen -> nonfullscreen transition */
			/*
			 * Our changes will get clobbered by an automatic event from
			 * setWindowFullscreen.  Push an event to the event loop to make
			 * sure these changes are applied after whatever that other
			 * event throws.
			 */
			/* Create an event to push */
			fsEvent.type = SDL_WINDOWEVENT;
			fsEvent.window.timestamp = SDL_GetTicks();
			fsEvent.window.windowID = SDL_GetWindowID(window);
			// windowId
			fsEvent.window.event = SDL_WINDOWEVENT_RESIZED;
			fsEvent.window.data1 = w;
			fsEvent.window.data2 = h;

			/* Push the event, but don't bother waiting */
			SDL_PushEvent(&fsEvent);
			printf("[DO RESIZE]: pushed fullscreen compensation event\n");

		}

		/* Finally, update the screen info */
		screen = SDL_GetWindowSurface(window);

	}

	/* Check and see if SDL honored our resize request */
	SDL_GetWindowSize(window, &aw, &ah);
	printf("[DO RESIZE] Got: %dx%d (%d, %d)\n", aw, ah, is_fullscreen, borderless);
	SDL_GL_MakeCurrent(window, maincontext);
	resizeWindow(aw, ah);

	interface_resize(aw, ah);
}

static void close_state() {
	kill_audio();
	core_mouse_close();
	refcleaner_clean(L);
	core_loader_waitall();
	lua_particles_system_clean();
	lua_gc(L, LUA_GCCOLLECT, 0);
	lua_close(L);
	refcleaner_reset();
	PHYSFS_deinit();
	font_cleanup();
}

void bootstrap_lua_state(lua_State *L, int argc, char **argv) {
	const char *selfexe;

	/***************** Physfs Init *****************/
	PHYSFS_init(argv[0]);

	bool bootstrap_mounted = false;
	selfexe = get_self_executable(argc, argv);
	if (selfexe && PHYSFS_mount(selfexe, "/", 1)) {
	}
	else {
		printf("NO SELFEXE: bootstrapping from CWD\n");
		PHYSFS_mount("bootstrap", "/bootstrap", 1);
		bootstrap_mounted = true;
	}

	// Tell the boostrapping code the selfexe path
	if (selfexe)
		lua_pushstring(L, selfexe);
	else
		lua_pushnil(L);
	lua_setglobal(L, "__SELFEXE");

	// Will be useful
#ifdef __APPLE__
	lua_pushboolean(L, true);
	lua_setglobal(L, "__APPLE__");
#endif

	// Run bootstrapping
	if (!luaL_loadfile(L, "/bootstrap/boot.lua")) {
		docall(L, 0, 0);
	}
	// Could not load bootstrap! Try to mount the engine from working directory as last resort
	else {
		lua_pop(L, 1);
		printf("WARNING: No bootstrap code found, defaulting to working directory for engine code!\n");
		PHYSFS_mount("game/thirdparty", "/", 1);
		PHYSFS_mount("game/", "/", 1);
		luaL_loadstring(L,
			"fs.setPathAllowed(fs.getRealPath('/addons/', true)) " \
			"if fs.getRealPath('/dlcs/') then fs.setPathAllowed(fs.getRealPath('/dlcs/', true)) end " \
			"fs.setPathAllowed(fs.getRealPath('/modules/', true)) "
		);
		lua_pcall(L, 0, 0, 0);
	}

	if (bootstrap_mounted) {
		PHYSFS_removeFromSearchPath("bootstrap");
	}

	// And run the lua engine pre init scripts
	if (!luaL_loadfile(L, "/loader/pre-init.lua"))
		docall(L, 0, 0);
	else
		lua_pop(L, 1);
}

void boot_lua(int state, bool rebooting, int argc, char *argv[]) {
	core_def->corenum = 0;

	if (state == 1)
	{
		/* When rebooting we destroy the lua state to free memory and we reset physfs */
		if (rebooting)
		{
			current_mousehandler = LUA_NOREF;
			current_keyhandler = LUA_NOREF;
			current_game = LUA_NOREF;

			close_state();			
		}

		/***************** Lua Init *****************/
		L = lua_open();  /* create state */
		luaL_openlibs(L);  /* open libraries */
		luaopen_physfs(L);
		luaopen_core(L);
		luaopen_core_mouse(L);
		luaopen_core_gamepad(L);
		luaopen_loader(L);
		luaopen_colors(L);
		luaopen_font(L);
		luaopen_fov(L);
		luaopen_socket_core(L);
		luaopen_mime_core(L);
		luaopen_struct(L);
		luaopen_profiler(L);
		luaopen_bit(L);
		luaopen_lpeg(L);
		luaopen_lxp(L);
		luaopen_md5_core(L);
		luaopen_renderer(L);
		luaopen_map2d(L);
		luaopen_particles(L);
		luaopen_particles_system(L);
		luaopen_sound(L);
		luaopen_noise(L);
		luaopen_diamond_square(L);
		luaopen_shaders(L);
		luaopen_serial(L);
		luaopen_profile(L);
		luaopen_zlib(L);
		luaopen_bit(L);
		luaopen_wait(L);
		luaopen_clipper(L);
		luaopen_navmesh(L);
		luaopen_wfc(L);
		luaopen_binpack(L);

		// Disable automatic GC, we'l do it when we want
		lua_gc(L, LUA_GCSTOP, 0);

		physfs_reset_dir_allowed(L);

#ifdef STEAM_TE4
		if (!no_steam) te4_steam_lua_init(L);
#endif
#ifdef DISCORD_TE4
		luaopen_discord(L);
#endif
		printf("===top %d\n", lua_gettop(L));
//		exit(0);

		// Override "print" if requested
		if (no_debug)
		{
			lua_pushcfunction(L, noprint);
			lua_setglobal(L, "print");
		}

		// Make the uids repository
		lua_newtable(L);
		lua_setglobal(L, "__uids");

		bootstrap_lua_state(L, argc, argv);

		if (te4_web_init) te4_web_init(L);

		create_particles_thread();
	}
	else if (state == 2)
	{
		SDL_SetWindowTitle(window, "T-Engine4");

		// Now we can open lua lanes, the physfs paths are set and it can load it's lanes-keeper.lua file
		//		luaopen_lanes(L);

		printf("Running lua loader code...\n");

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

// Let some platforms use a different entry point
#ifdef USE_TENGINE_MAIN
#ifdef main
#undef main
#endif
#define main tengine_main
#endif

/* Cleans up a timer lock.  See function declaration for more info. */
void cleanupTimerLock(SDL_mutex *lock, SDL_TimerID *timer
	, int *timerFlag)
{
	// Grab the lock and start cleaning up
	SDL_mutexP(lock);
		// Cancel the timer (if it is running)
		if (*timer) SDL_RemoveTimer(*timer);
		*timer = 0;
		*timerFlag = -1;

	SDL_mutexV(lock);

	/*
	 * Need to get lock once more just in case a timer call was stuck waiting on
	 * the lock when we altered the variables.
	 */
	SDL_mutexP(lock);
	SDL_mutexV(lock);

	// Can now safely destroy the lock.
	SDL_DestroyMutex(lock);
}

/* Handles game idle transition.  See function declaration for more info. */
void handleIdleTransition(int goIdle)
{
	if (forbid_idle_mode) return;
	if (!requested_fps) return;

	if (goIdle) {
		/* Make sure this isn't an idle->idle transition */
		if (requested_fps != requested_fps_idle) {
			requested_fps_idle_saved = requested_fps;
			setupDisplayTimer(requested_fps_idle);
		}

	} else if (requested_fps_idle_saved && (requested_fps != requested_fps_idle_saved)) {
		/* Made sure this wasn't a nonidle->nonidle */
		setupDisplayTimer(requested_fps_idle_saved);
	}

	if (current_game != LUA_NOREF)
	{
		lua_rawgeti(L, LUA_REGISTRYINDEX, current_game);
		lua_pushliteral(L, "idling");
		lua_gettable(L, -2);
		lua_remove(L, -2);
		lua_rawgeti(L, LUA_REGISTRYINDEX, current_game);
		lua_pushboolean(L, !goIdle);
		docall(L, 2, 0);
	}
}

void event_loop_realtime() {
	SDL_Event event;

	// This is liekly super wrong, but we dont care much about unbound mode anyway
	if (!requested_fps) {
		on_redraw();
		// printf("===!! %f\n", (float)(SDL_GetPerformanceCounter()-ticks) /max_ticks);

		on_tick();

		/* handle the events in the queue */
		if (SDL_PollEvent(&event)) on_event(&event);
	} else {
		int ticks = SDL_GetTicks();
		uint64 max_time = SDL_GetPerformanceFrequency() / requested_fps;
		uint64 ms1 = SDL_GetPerformanceFrequency() / 1000;
		uint64 max_time1  = ms1 * (1000 / requested_fps - 1); // Sinde SDL_Delay resolution is far from perfect, we require one less millisecond for it, and we'll busy-wait the last ms ourselves
		uint64 time = SDL_GetPerformanceCounter();
		on_redraw();
		// printf("===!! %f\n", (float)(SDL_GetPerformanceCounter()-ticks) /max_ticks);

		while (true) {
			on_tick();

			/* handle the events in the queue */
			while (SDL_PollEvent(&event))
			{
				if (on_event(&event)) {
					tickPaused = false;
				}
				if (SDL_GetPerformanceCounter()-time >= max_time1) break;
			}
			if (tickPaused) break; // No more ticks to process
			if (SDL_GetPerformanceCounter()-time >= max_time1) break;
		}
		// printf("== %ld :: %ld\n", max_ticks1, max_ticks);
		while (SDL_GetPerformanceCounter()-time < max_time1) SDL_Delay(1);
		while (SDL_GetPerformanceCounter()-time < max_time); // Now, we busywait the remaining ms or so

		ticks_per_frame = SDL_GetTicks() - ticks;
	}
}

void event_loop_tickbased() {
	SDL_Event event;

	static int ticks = SDL_GetTicks();

	if (tickPaused) SDL_WaitEvent(NULL);

	/* handle the events in the queue */
	while (SDL_PollEvent(&event)) {
		if (event.type == SDL_USEREVENT && event.user.code == 0) {
			on_redraw();
			int now_ticks = SDL_GetTicks();
			ticks_per_frame = now_ticks - ticks;
			ticks = now_ticks;
			SDL_mutexP(renderingLock);
			redraw_pending = 0;
			SDL_mutexV(renderingLock);
			break;
		} else {
			if (on_event(&event)) {
				tickPaused = false;
			}
			break;
		}
	}

	if (!tickPaused) {
		on_tick();
	}
}

void (*event_loop)() = event_loop_tickbased;

// Setup realtime / turnbased
void setupRealtime(float freq)
{
	if (!freq) {
		event_loop = event_loop_tickbased;
		printf("[ENGINE] Switching to turn based\n");
	} else {
		event_loop = event_loop_realtime;
		printf("[ENGINE] Switching to realtime\n");
	}
	
	// Make sure we upadte the display event timer if needed
	setupDisplayTimer(requested_fps);
}

void setupDisplayTimer(int fps)
{
	requested_fps = fps;
	if (requested_fps) {
		max_ms_per_frame = 1000 / fps;
		// event_loop = event_loop_realtime;
		printf("[ENGINE] Setting requested FPS to %d (%d ms)\n", fps, 1000 / fps);
	} else {
		max_ms_per_frame = 0;
		event_loop = event_loop_realtime;
		printf("[ENGINE] Setting requested FPS to unbound, forcing to realtime\n");
	}

	// We only use the display timer in tickbased event loop
	SDL_mutexP(renderingLock);
	redraw_pending = 0;
	if (event_loop == event_loop_tickbased) {
		if (display_timer_id) SDL_RemoveTimer(display_timer_id);
		display_timer_id = SDL_AddTimer(max_ms_per_frame, redraw_timer, NULL);
		
	} else {
		if (display_timer_id) SDL_RemoveTimer(display_timer_id);
		display_timer_id = 0;
	}
	SDL_mutexV(renderingLock);
}

extern "C" void cimgui_forcelink();
extern "C" void cimplot_forcelink();
extern "C" void te4_imgui_forcelink();

/**
 * Core entry point.
 */
int main(int argc, char *argv[])
{
	te4_imgui_forcelink();
	cimgui_forcelink();
	cimplot_forcelink();

	core_def = (core_boot_type*)calloc(1, sizeof(core_boot_type));
	core_def->define = &define_core;
	core_def->define(core_def, "te4core", -1, NULL, NULL, NULL, NULL, 0, NULL);

	g_argc = argc;
	g_argv = argv;

	bool logtofile = false;
	bool is_zygote = false;
	bool os_autoflush = false;
	bool no_web = false;
	FILE *logfile = NULL;

	// Handle "utilities"
	if ((argc > 2) && !strncmp(argv[1], "--utility", 9)) {
		if (!strncmp(argv[2], "spritesheet-generator", 21)) utility_spritesheet_generator(argc, argv);
		exit(0);
		return 0;
	}

	// Parse arguments
	int i;
	for (i = 1; i < argc; i++)
	{
		char *arg = argv[i];
		if (!strncmp(arg, "-M", 2)) core_def->reboot_module = strdup(arg+2);
		if (!strncmp(arg, "-u", 2)) core_def->reboot_name = strdup(arg+2);
		if (!strncmp(arg, "-E", 2)) core_def->reboot_einfo = strdup(arg+2);
		if (!strncmp(arg, "-n", 2)) core_def->reboot_new = 1;
		if (!strncmp(arg, "--flush-stdout", 14))
		{
			setbuf(stdout, nullptr);
#ifdef SELFEXE_WINDOWS
			os_autoflush = true;
#endif
		}
		if (!strncmp(arg, "--no-debug", 10)) no_debug = true;
		if (!strncmp(arg, "--xpos", 6)) start_xpos = strtol(argv[++i], NULL, 10);
		if (!strncmp(arg, "--ypos", 6)) start_ypos = strtol(argv[++i], NULL, 10);
		if (!strncmp(arg, "--ignore-window-change-pos", 26)) ignore_window_change_pos = true;
		if (!strncmp(arg, "--safe-mode", 11)) safe_mode = true;
		if (!strncmp(arg, "--home", 6)) override_home = strdup(argv[++i]);
		if (!strncmp(arg, "--no-steam", 10)) no_steam = true;
		if (!strncmp(arg, "--type=zygote", 13)) is_zygote = true;
		if (!strncmp(arg, "--type=renderer", 15)) is_zygote = true;
		if (!strncmp(arg, "--no-sandbox", 12)) is_zygote = true;
		if (!strncmp(arg, "--logtofile", 11)) logtofile = true;
		if (!strncmp(arg, "--no-web", 8)) no_web = true;
		if (!strncmp(arg, "--offscreen", 11)) offscreen_render = true;
		if (!strncmp(arg, "--debug-gl", 10)) enable_gl_debug_log = true;
		if (!strncmp(arg, "--lock-size", 11)) {
			char *arg = argv[++i];
			char *next;
			locked_w = strtol(arg, &next, 10);
			locked_h = strtol(++next, NULL, 10);
		}
	}

#ifdef SELFEXE_WINDOWS
	logtofile = true;
#endif
	if (!is_zygote && logtofile) {
		logfile = freopen("te4_log.txt", "w", stdout);
		if (os_autoflush) setvbuf(logfile, NULL, _IONBF, 2);
	}
#ifdef SELFEXE_MACOSX
	if (!is_zygote) {
		const char *logname = "/tmp/te4_log.txt";
		logfile = freopen(logname, "w", stdout);
		if (os_autoflush) setlinebuf(logfile);
	}
#endif

	if (!no_web) te4_web_load();

	// Get cpu cores
	nb_cpus = get_number_cpus();
	printf("[CPU] Detected %d CPUs\n", nb_cpus);

#ifdef STEAM_TE4
	if (!no_steam) te4_steam_init();
#endif

	// RNG init
	init_gen_rand(time(NULL));

	int vid_drv;
	for (vid_drv = 0; vid_drv < SDL_GetNumVideoDrivers(); vid_drv++)
	{
		printf("Available video driver: %s\n", SDL_GetVideoDriver(vid_drv));
	}

	// initialize engine and set up resolution and depth
	Uint32 flags=SDL_INIT_TIMER | SDL_INIT_JOYSTICK | SDL_INIT_GAMECONTROLLER;
	if (SDL_Init (flags) < 0) {
		printf("cannot initialize SDL: %s\n", SDL_GetError ());
		return 1;
	}

	if (SDL_VideoInit(NULL) != 0) {
		printf("Error initializing SDL video:  %s\n", SDL_GetError());
		return 2;
	}

	for (i = 0; i < SDL_NumJoysticks(); i++) {
		if (SDL_IsGameController(i)) {
			gamepad = SDL_GameControllerOpen(i);
			gamepadjoy = SDL_GameControllerGetJoystick(gamepad);
			gamepad_instance_id = SDL_JoystickInstanceID(gamepadjoy);

			printf("Found gamepad, enabling support: %s\n", SDL_GameControllerMapping(gamepad));
		}
	}

	init_sounds();

	// Filter events, to catch the quit event
	SDL_SetEventFilter(event_filter, NULL);

	boot_lua(1, false, argc, argv);

	do_resize(WIDTH, HEIGHT, false, false, screen_zoom);
	if (screen==NULL) {
		printf("error opening screen: %s\n", SDL_GetError());
		return 3;
	}

	SDL_SetWindowTitle(window, "T4Engine");

	/* Sets up OpenGL double buffering */
	resizeWindow(WIDTH, HEIGHT);

	// Allow screensaver to work
	SDL_EnableScreenSaver();
	SDL_StartTextInput();

	// Get OpenGL capabilities
	multitexture_active = true;
	shaders_active = true;
	fbo_active = true;
	if (!multitexture_active) shaders_active = false;
	if (!GLEW_VERSION_2_1)
	{
		printf("OpenGL 2.1 required.\n");
		return 9;
	}
	if (safe_mode) printf("Safe mode activated\n");

	init_blank_surface();

	boot_lua(2, false, argc, argv);

	pass_command_args(argc, argv);

	threaded_runner_start();

	imgui_load_settings();

	// yes its duplicated I know
	init_blank_surface();

	while (!exit_engine)
	{
		event_loop();
		if (imgui_io->WantSaveIniSettings) imgui_save_settings();

		/* Reboot the lua engine */
		if (core_def->corenum)
		{
			// Just reboot the lua VM
			if (core_def->corenum == TE4CORE_VERSION)
			{
				tickPaused = false;
				setupRealtime(0);
				reset_physic_simulation();
				boot_lua(1, true, argc, argv);
				boot_lua(2, true, argc, argv);
			}
			// Clean up and tell the runner to run a different core
			else
			{
				close_state();
				free_particles_thread();
				free_profile_thread();
				break;
			}
		}
	}

	// Clean up locks.
	printf("Cleaning up!\n");
	cleanupTimerLock(renderingLock, &display_timer_id, &redraw_pending);
	
	printf("Terminating!\n");
	te4_web_terminate();
	printf("Webcore shutdown complete\n");
	// Restore default gamma on exit.
	if (desktop_gamma_set) SDL_SetWindowBrightness(window, desktop_gamma);
//	SDL_Quit();
	printf("SDL shutdown complete\n");
	deinit_sounds();
	printf("SoLoud shutdown complete\n");
	printf("Thanks for having fun!\n");

#ifdef SELFEXE_WINDOWS
	TerminateProcess( GetCurrentProcess(),0);
	fclose(stdout);
#endif
#ifdef SELFEXE_MACOSX
	fclose(stdout);
#endif
	return 0;
}
