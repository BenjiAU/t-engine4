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
#include "fov/fov.h"
#include "lauxlib.h"
#include "lualib.h"
#include "auxiliar.h"
#include "script.h"
#include "display.h"
#include "physfs.h"
#include "physfsrwops.h"
#include "SFMT.h"
#include "mzip.h"
#include "zlib.h"
#include "main.h"
#include "useshader.h"
#include "utf8proc/utf8proc.h"
#include "sdm.h"
#include <math.h>
#include <time.h>
#include <locale.h>

#ifdef __APPLE__
#include <libpng/png.h>
#else
#include <png.h>
#endif
}

#include "texture_holder.hpp"
#include "core_lua.hpp"
extern SDL_Window *window;

#define SDL_SRCALPHA        0x00010000
int SDL_SetAlpha(SDL_Surface * surface, Uint32 flag, Uint8 value)
{
    if (flag & SDL_SRCALPHA) {
        /* According to the docs, value is ignored for alpha surfaces */
        if (surface->format->Amask) {
            value = 0xFF;
        }
        SDL_SetSurfaceAlphaMod(surface, value);
        SDL_SetSurfaceBlendMode(surface, SDL_BLENDMODE_BLEND);
    } else {
        SDL_SetSurfaceAlphaMod(surface, 0xFF);
        SDL_SetSurfaceBlendMode(surface, SDL_BLENDMODE_NONE);
    }
    SDL_SetSurfaceRLE(surface, (flag & SDL_RLEACCEL));

    return 0;
}

SDL_Surface *SDL_DisplayFormatAlpha(SDL_Surface *surface)
{
	SDL_Surface *image;
	SDL_Rect area;
	Uint8  saved_alpha;
	SDL_BlendMode saved_mode;

	image = SDL_CreateRGBSurface(
			SDL_SWSURFACE,
			surface->w, surface->h,
			32,
#if SDL_BYTEORDER == SDL_LIL_ENDIAN /* OpenGL RGBA masks */
			0x000000FF,
			0x0000FF00,
			0x00FF0000,
			0xFF000000
#else
			0xFF000000,
			0x00FF0000,
			0x0000FF00,
			0x000000FF
#endif
			);
	if ( image == NULL ) {
		return 0;
	}

	/* Save the alpha blending attributes */
	SDL_GetSurfaceAlphaMod(surface, &saved_alpha);
	SDL_SetSurfaceAlphaMod(surface, 0xFF);
	SDL_GetSurfaceBlendMode(surface, &saved_mode);
	SDL_SetSurfaceBlendMode(surface, SDL_BLENDMODE_NONE);

	/* Copy the surface into the GL texture image */
	area.x = 0;
	area.y = 0;
	area.w = surface->w;
	area.h = surface->h;
	SDL_BlitSurface(surface, &area, image, &area);

	/* Restore the alpha blending attributes */
	SDL_SetSurfaceAlphaMod(surface, saved_alpha);
	SDL_SetSurfaceBlendMode(surface, saved_mode);

	return image;
}

typedef struct SDL_VideoInfo
{
    Uint32 hw_available:1;
    Uint32 wm_available:1;
    Uint32 UnusedBits1:6;
    Uint32 UnusedBits2:1;
    Uint32 blit_hw:1;
    Uint32 blit_hw_CC:1;
    Uint32 blit_hw_A:1;
    Uint32 blit_sw:1;
    Uint32 blit_sw_CC:1;
    Uint32 blit_sw_A:1;
    Uint32 blit_fill:1;
    Uint32 UnusedBits3:16;
    Uint32 video_mem;

    SDL_PixelFormat *vfmt;

    int current_w;
    int current_h;
} SDL_VideoInfo;

static int
GetVideoDisplay()
{
    const char *variable = SDL_getenv("SDL_VIDEO_FULLSCREEN_DISPLAY");
    if ( !variable ) {
        variable = SDL_getenv("SDL_VIDEO_FULLSCREEN_HEAD");
    }
    if ( variable ) {
        return SDL_atoi(variable);
    } else {
        return 0;
    }
}

const SDL_VideoInfo *SDL_GetVideoInfo(void)
{
    static SDL_VideoInfo info;
    SDL_DisplayMode mode;

    /* Memory leak, compatibility code, who cares? */
    if (!info.vfmt && SDL_GetDesktopDisplayMode(GetVideoDisplay(), &mode) == 0) {
        info.vfmt = SDL_AllocFormat(mode.format);
        info.current_w = mode.w;
        info.current_h = mode.h;
    }
    return &info;
}

SDL_Rect **
SDL_ListModes(const SDL_PixelFormat * format, Uint32 flags)
{
    int i, nmodes;
    SDL_Rect **modes;

/*    if (!SDL_GetVideoDevice()) {
        return NULL;
    }
  */
/*    if (!(flags & SDL_FULLSCREEN)) {
        return (SDL_Rect **) (-1);
    }
*/
    if (!format) {
        format = SDL_GetVideoInfo()->vfmt;
    }

    /* Memory leak, but this is a compatibility function, who cares? */
    nmodes = 0;
    modes = NULL;
    for (i = 0; i < SDL_GetNumDisplayModes(GetVideoDisplay()); ++i) {
        SDL_DisplayMode mode;
        int bpp;

        SDL_GetDisplayMode(GetVideoDisplay(), i, &mode);
        if (!mode.w || !mode.h) {
            return (SDL_Rect **) (-1);
        }

        /* Copied from src/video/SDL_pixels.c:SDL_PixelFormatEnumToMasks */
        if (SDL_BYTESPERPIXEL(mode.format) <= 2) {
            bpp = SDL_BITSPERPIXEL(mode.format);
        } else {
            bpp = SDL_BYTESPERPIXEL(mode.format) * 8;
        }

        if (bpp != format->BitsPerPixel) {
            continue;
        }
        if (nmodes > 0 && modes[nmodes - 1]->w == mode.w
            && modes[nmodes - 1]->h == mode.h) {
            continue;
        }

        modes = (SDL_Rect**)SDL_realloc(modes, (nmodes + 2) * sizeof(*modes));
        if (!modes) {
            return NULL;
        }
        modes[nmodes] = (SDL_Rect *) SDL_malloc(sizeof(SDL_Rect));
        if (!modes[nmodes]) {
            return NULL;
        }
        modes[nmodes]->x = 0;
        modes[nmodes]->y = 0;
        modes[nmodes]->w = mode.w;
        modes[nmodes]->h = mode.h;
        ++nmodes;
    }
    if (modes) {
        modes[nmodes] = NULL;
    }
    return modes;
}


/***** Helpers *****/
GLenum sdl_gl_texture_format(SDL_Surface *s) {
	// get the number of channels in the SDL surface
	GLint nOfColors = s->format->BytesPerPixel;
	GLenum texture_format;
	if (nOfColors == 4)	 // contains an alpha channel
	{
#if SDL_BYTEORDER == SDL_BIG_ENDIAN
		if (s->format->Rmask == 0xff000000)
#else
		if (s->format->Rmask == 0x000000ff)
#endif
			texture_format = GL_RGBA;
		else
			texture_format = GL_BGRA;
	} else if (nOfColors == 3)	 // no alpha channel
	{
#if SDL_BYTEORDER == SDL_BIG_ENDIAN
		if (s->format->Rmask == 0x00ff0000)
#else
		if (s->format->Rmask == 0x000000ff)
#endif
			texture_format = GL_RGB;
		else
			texture_format = GL_BGR;
	} else if (nOfColors == 1) {
		texture_format = GL_RED;
	} else {
		printf("warning: the image is not truecolor..  this will probably break %d\n", nOfColors);
		// this error should not go unhandled
	}

	return texture_format;
}


// allocate memory for a texture without copying pixels in
// caller binds texture
static char *largest_black = NULL;
static int largest_size = 0;
void make_texture_for_surface(SDL_Surface *s, int *fw, int *fh, bool clamp, bool exact_size) {
	// Paramétrage de la texture.
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, clamp ? GL_CLAMP_TO_EDGE : GL_REPEAT);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, clamp ? GL_CLAMP_TO_EDGE : GL_REPEAT);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);

	// get the number of channels in the SDL surface
	GLint nOfColors = s->format->BytesPerPixel;
	GLenum texture_format = sdl_gl_texture_format(s);

	// In case we can't support NPOT textures round up to nearest POT
	int realw=1;
	int realh=1;

	if (exact_size) {
		realw = s->w;
		realh = s->h;
	} else {
		while (realw < s->w) realw *= 2;
		while (realh < s->h) realh *= 2;
	}

	if (fw) *fw = realw;
	if (fh) *fh = realh;
	//printf("request size (%d,%d), producing size (%d,%d)\n",s->w,s->h,realw,realh);

	if (!largest_black || largest_size < realw * realh * 4) {
		if (largest_black) free(largest_black);
		largest_black = (char*)calloc(realh*realw*4, sizeof(char));
		largest_size = realh*realw*4;
		printf("Upgrading black texture to size %d\n", largest_size);
	}
	glTexImage2D(GL_TEXTURE_2D, 0, nOfColors == 4 ? GL_RGBA : GL_RGB, realw, realh, 0, texture_format, GL_UNSIGNED_BYTE, largest_black);

#ifdef _DEBUG
	GLenum err = glGetError();
	if (err != GL_NO_ERROR) {
		printf("make_texture_for_surface: glTexImage2D : %s\n",gluErrorString(err));
	}
#endif
}

// copy pixels into previous allocated surface
void copy_surface_to_texture(SDL_Surface *s) {
	GLenum texture_format = sdl_gl_texture_format(s);

	glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, s->w, s->h, texture_format, GL_UNSIGNED_BYTE, s->pixels);

#ifdef _DEBUG
	GLenum err = glGetError();
	if (err != GL_NO_ERROR) {
		printf("copy_surface_to_texture : glTexSubImage2D : %s\n",gluErrorString(err));
	}
#endif
}

/******************************************************************
 ******************************************************************
 *                              Keys                              *
 ******************************************************************
 ******************************************************************/
extern int current_keyhandler;
static int lua_set_current_keyhandler(lua_State *L)
{
	refcleaner(&current_keyhandler);

	if (lua_isnil(L, 1))
		current_keyhandler = LUA_NOREF;
	else
		current_keyhandler = luaL_ref(L, LUA_REGISTRYINDEX);

	return 0;
}
static int lua_get_mod_state(lua_State *L)
{
	const char *mod = luaL_checkstring(L, 1);
	SDL_Keymod smod = SDL_GetModState();

	if (!strcmp(mod, "shift")) lua_pushboolean(L, smod & KMOD_SHIFT);
	else if (!strcmp(mod, "ctrl")) lua_pushboolean(L, smod & KMOD_CTRL);
	else if (!strcmp(mod, "alt")) lua_pushboolean(L, smod & KMOD_ALT);
	else if (!strcmp(mod, "meta")) lua_pushboolean(L, smod & KMOD_GUI);
	else if (!strcmp(mod, "caps")) lua_pushboolean(L, smod & KMOD_CAPS);
	else lua_pushnil(L);

	return 1;
}
static int lua_get_scancode_name(lua_State *L)
{
	SDL_Scancode code = (SDL_Scancode)luaL_checknumber(L, 1);
	lua_pushstring(L, SDL_GetScancodeName(code));

	return 1;
}
static int lua_flush_key_events(lua_State *L)
{
	SDL_FlushEvents(SDL_KEYDOWN, SDL_TEXTINPUT);
	return 0;
}

static int lua_key_unicode(lua_State *L)
{
	if (lua_isboolean(L, 1)) SDL_StartTextInput();
	else SDL_StopTextInput();
	return 0;
}

static int lua_key_set_clipboard(lua_State *L)
{
	const char *str = luaL_checkstring(L, 1);
	SDL_SetClipboardText(str);
	return 0;
}

static int lua_key_get_clipboard(lua_State *L)
{
	if (SDL_HasClipboardText())
	{
		char *str = SDL_GetClipboardText();
		if (str)
		{
			lua_pushstring(L, str);
			SDL_free(str);
		}
		else
			lua_pushnil(L);
	}
	else
		lua_pushnil(L);
	return 1;
}

static const struct luaL_Reg keylib[] =
{
	{"set_current_handler", lua_set_current_keyhandler},
	{"modState", lua_get_mod_state},
	{"symName", lua_get_scancode_name},
	{"flush", lua_flush_key_events},
	{"unicodeInput", lua_key_unicode},
	{"getClipboard", lua_key_get_clipboard},
	{"setClipboard", lua_key_set_clipboard},
	{NULL, NULL},
};

/******************************************************************
 ******************************************************************
 *                              Game                              *
 ******************************************************************
 ******************************************************************/
extern int current_game;
static int lua_set_current_game(lua_State *L)
{
	refcleaner(&current_game);

	if (lua_isnil(L, 1))
		current_game = LUA_NOREF;
	else
		current_game = luaL_ref(L, LUA_REGISTRYINDEX);

	return 0;
}
extern bool exit_engine;
static int lua_exit_engine(lua_State *L)
{
	exit_engine = TRUE;
	return 0;
}
static int lua_reboot_lua(lua_State *L)
{
	core_def->define(
		core_def,
		luaL_checkstring(L, 1),
		luaL_checknumber(L, 2),
		luaL_checkstring(L, 3),
		luaL_checkstring(L, 4),
		luaL_checkstring(L, 5),
		luaL_checkstring(L, 6),
		lua_toboolean(L, 7),
		luaL_checkstring(L, 8)
		);

	// By default reboot the same core -- this skips some initializations
	if (core_def->corenum == -1) core_def->corenum = TE4CORE_VERSION;

	return 0;
}
static int lua_get_time(lua_State *L)
{
	lua_pushnumber(L, SDL_GetTicks());
	return 1;
}
static int lua_get_frame_time(lua_State *L)
{
	lua_pushnumber(L, cur_frame_tick);
	return 1;
}
static int lua_set_realtime(lua_State *L)
{
	float freq = luaL_checknumber(L, 1);
	setupRealtime(freq);
	return 0;
}
static int lua_set_fps(lua_State *L)
{
	float freq = luaL_checknumber(L, 1);
	setupDisplayTimer(freq);
	return 0;
}
static int lua_forbid_idle_mode(lua_State *L)
{
	forbid_idle_mode = lua_toboolean(L, 1);
	return 0;
}
static int lua_sleep(lua_State *L)
{
	int ms = luaL_checknumber(L, 1);
	SDL_Delay(ms);
	return 0;
}

static int lua_check_error(lua_State *L)
{
	if (!last_lua_error_head) return 0;

	int n = 1;
	lua_newtable(L);
	lua_err_type *cur = last_lua_error_head;
	while (cur)
	{
		if (cur->err_msg) lua_pushfstring(L, "Lua Error: %s", cur->err_msg);
		else lua_pushfstring(L, "  At %s:%d %s", cur->file, cur->line, cur->func);
		lua_rawseti(L, -2, n++);
		cur = cur->next;
	}

	del_lua_error();
	return 1;
}

static char *reboot_message = NULL;
static int lua_set_reboot_message(lua_State *L)
{
	const char *msg = luaL_checkstring(L, 1);
	if (reboot_message) { free(reboot_message); }
	reboot_message = strdup(msg);
	return 0;
}
static int lua_get_reboot_message(lua_State *L)
{
	if (reboot_message) {
		lua_pushstring(L, reboot_message);
		free(reboot_message);
		reboot_message = NULL;
	} else lua_pushnil(L);
	return 1;
}

static int lua_reset_locale(lua_State *L)
{
	setlocale(LC_NUMERIC, "C");
	return 0;
}

extern bool tickPaused;
static int lua_force_next_tick(lua_State *L)
{
	tickPaused = FALSE;
	return 0;
}

static int lua_disable_connectivity(lua_State *L)
{
	no_connectivity = TRUE;
	return 0;
}

static int lua_getclasstable(lua_State *L) {
	const char *classname = luaL_checkstring(L, 1);
	bool raw = lua_toboolean(L, 2);
	luaL_getmetatable(L, classname);
	if (!raw) {
		lua_pushliteral(L, "__index");
		lua_gettable(L, -2);
	}
	return 1;
}

static int lua_gettype(lua_State *L) {
	if (lua_type(L, 1) == LUA_TUSERDATA) {
		int oldtop = lua_gettop(L);
		if (!lua_getmetatable(L, 1)) {
			lua_settop(L, oldtop);
			lua_pushstring(L, "[metatable-less userdata]");
			return 1;
		}
		lua_pushstring(L, "__index");
		lua_gettable(L, -2);
		if (!lua_istable(L, -1)) {
			lua_settop(L, oldtop);
			lua_pushstring(L, "[metatable witout index userdata]");
			return 1;
		}
		lua_pushstring(L, "class");
		lua_gettable(L, -2);
		if (!lua_isstring(L, -1)) {
			lua_settop(L, oldtop);
			lua_pushstring(L, "[unknown class name userdata]");
			return 1;
		}
	} else {
		lua_pushstring(L, lua_typename(L, lua_type(L, 1)));
	}
	return 1;
}

#ifdef TE4_PROFILING
static bool cprofiler_running = FALSE;
static int lua_cprofiler(lua_State *L) {
	if (cprofiler_running) {
		ProfilerStop();
		printf("[CProfiler] Stopped\n");
	} else {
		const char *filename = luaL_checkstring(L, 1);
		ProfilerStart(filename);
		cprofiler_running = TRUE;
		printf("[CProfiler] Started %s\n", filename);
	}
	return 0;
}
#endif

static int lua_stdout_write(lua_State *L)
{
	int i = 1;
	while (i <= lua_gettop(L)) {
		const char *s = lua_tostring(L, i);
		printf("%s", s);
		i++;
	}
	return 0;
}

static int lua_open_browser(lua_State *L)
{
#if defined(SELFEXE_LINUX) || defined(SELFEXE_BSD)
	const char *command = "xdg-open \"%s\"";
#elif defined(SELFEXE_WINDOWS)
	const char *command = "rundll32 url.dll,FileProtocolHandler \"%s\"";
#elif defined(SELFEXE_MACOSX)
	const char *command = "open  \"%s\"";
#else
	{ return 0; }
#endif
	char buf[2048];
	size_t len;
	char *path = strdup(luaL_checklstring(L, 1, &len));
	size_t i;
	for (i = 0; i < len; i++) if (path[i] == '"') path[i] = '_'; // Just dont put " in there
	snprintf(buf, 2047, command, path);
	lua_pushboolean(L, system(buf) == 0);
	
	return 1;
}

static const struct luaL_Reg gamelib[] =
{
	{"getType", lua_gettype},
	{"getCClass", lua_getclasstable},
	{"setRebootMessage", lua_set_reboot_message},
	{"getRebootMessage", lua_get_reboot_message},
	{"reboot", lua_reboot_lua},
	{"set_current_game", lua_set_current_game},
	{"exit_engine", lua_exit_engine},
	{"getTime", lua_get_time},
	{"getFrameTime", lua_get_frame_time},
	{"sleep", lua_sleep},
	{"setRealtime", lua_set_realtime},
	{"setFPS", lua_set_fps},
	{"forbidIdleMode", lua_forbid_idle_mode},
	{"requestNextTick", lua_force_next_tick},
	{"checkError", lua_check_error},
	{"resetLocale", lua_reset_locale},
	{"stdout_write", lua_stdout_write},	
	{"openBrowser", lua_open_browser},
	{"disableConnectivity", lua_disable_connectivity},
#ifdef TE4_PROFILING
	{"CProfiler", lua_cprofiler},
#endif
	{NULL, NULL},
};

/******************************************************************
 ******************************************************************
 *                           Display                              *
 ******************************************************************
 ******************************************************************/

extern bool is_fullscreen;
extern bool is_borderless;
static int sdl_screen_size(lua_State *L)
{
	lua_pushnumber(L, screen->w / screen_zoom);
	lua_pushnumber(L, screen->h / screen_zoom);
	lua_pushboolean(L, is_fullscreen);
	lua_pushboolean(L, is_borderless);
	lua_pushnumber(L, screen->w);
	lua_pushnumber(L, screen->h);
	return 6;
}

static int sdl_window_pos(lua_State *L)
{
	int x, y;
	SDL_GetWindowPosition(window, &x, &y);
	lua_pushnumber(L, x);
	lua_pushnumber(L, y);
	return 2;
}

static int sdl_new_surface(lua_State *L)
{
	int w = luaL_checknumber(L, 1);
	int h = luaL_checknumber(L, 2);

	SDL_Surface **s = (SDL_Surface**)lua_newuserdata(L, sizeof(SDL_Surface*));
	auxiliar_setclass(L, "sdl{surface}", -1);

	Uint32 rmask, gmask, bmask, amask;
#if SDL_BYTEORDER == SDL_BIG_ENDIAN
	rmask = 0xff000000;
	gmask = 0x00ff0000;
	bmask = 0x0000ff00;
	amask = 0x000000ff;
#else
	rmask = 0x000000ff;
	gmask = 0x0000ff00;
	bmask = 0x00ff0000;
	amask = 0xff000000;
#endif

	*s = SDL_CreateRGBSurface(
		SDL_SWSURFACE,
		w,
		h,
		32,
		rmask, gmask, bmask, amask
		);

	if (s == NULL)
		printf("ERROR : SDL_CreateRGBSurface : %s\n",SDL_GetError());

	return 1;
}

static int gl_texture_id(lua_State *L)
{
	texture_lua *t = texture_lua::from_state(L, 1);
	lua_pushnumber(L, t->texture_id);
	return 1;
}

static int gl_texture_to_sdl(lua_State *L)
{
	texture_lua *t = texture_lua::from_state(L, 1);

	SDL_Surface **s = (SDL_Surface**)lua_newuserdata(L, sizeof(SDL_Surface*));
	auxiliar_setclass(L, "sdl{surface}", -1);

	// Bind the texture to read
	tglBindTexture(GL_TEXTURE_2D, t->texture_id);

	// Get texture size
	GLint w = t->w, h = t->h;
//	printf("Making surface from texture %dx%d\n", w, h);
	// Get texture data
	GLubyte *tmp = (GLubyte*)calloc(w*h*4, sizeof(GLubyte));
	glGetTexImage(GL_TEXTURE_2D, 0, GL_BGRA, GL_UNSIGNED_BYTE, tmp);

	// Make sdl surface from it
	*s = SDL_CreateRGBSurfaceFrom(tmp, w, h, 32, w*4, 0,0,0,0);

	return 1;
}

static int gl_texture_alter_sdm(lua_State *L) {
	texture_lua *t = texture_lua::from_state(L, 1);
	bool doubleheight = lua_toboolean(L, 2);

	// Bind the texture to read
	tglBindTexture(GL_TEXTURE_2D, t->texture_id);

	// Get texture size
	GLint w = t->w, h = t->h, dh;
	dh = doubleheight ? h * 2 : h;
	GLubyte *tmp = (GLubyte*)calloc(w*h*4, sizeof(GLubyte));
	glGetTexImage(GL_TEXTURE_2D, 0, GL_RGBA, GL_UNSIGNED_BYTE, tmp);

	GLubyte *sdm = (GLubyte*)calloc(w*dh*4, sizeof(GLubyte));
	build_sdm_ex(tmp, w, h, sdm, w, dh, 0, doubleheight ? h : 0);

	texture_lua *st = new(L) texture_lua();

	st->w = w; st->h = dh; st->no_free = FALSE;
	glGenTextures(1, &st->texture_id);
	tfglBindTexture(GL_TEXTURE_2D, st->texture_id);
	glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MIN_FILTER,GL_LINEAR);
	glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MAG_FILTER,GL_LINEAR);
	glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, w, dh, 0, GL_RGBA, GL_UNSIGNED_BYTE, sdm);

	free(tmp);
	free(sdm);

	lua_pushnumber(L, 1);
	lua_pushnumber(L, 1);

	return 3;
}

GLuint gl_tex_white = 0;
int init_blank_surface()
{
	Uint32 rmask, gmask, bmask, amask;
#if SDL_BYTEORDER == SDL_BIG_ENDIAN
	rmask = 0xff000000;
	gmask = 0x00ff0000;
	bmask = 0x0000ff00;
	amask = 0x000000ff;
#else
	rmask = 0x000000ff;
	gmask = 0x0000ff00;
	bmask = 0x00ff0000;
	amask = 0xff000000;
#endif
	SDL_Surface *s = SDL_CreateRGBSurface(
		SDL_SWSURFACE,
		4,
		4,
		32,
		rmask, gmask, bmask, amask
		);
	SDL_FillRect(s, NULL, SDL_MapRGBA(s->format, 255, 255, 255, 255));

	glGenTextures(1, &gl_tex_white);
	tfglBindTexture(GL_TEXTURE_2D, gl_tex_white);
	int fw, fh;
	make_texture_for_surface(s, &fw, &fh, false, false);
	copy_surface_to_texture(s);
	return gl_tex_white;
}

static int sdl_load_image(lua_State *L)
{
	const char *name = luaL_checkstring(L, 1);

	SDL_Surface **s = (SDL_Surface**)lua_newuserdata(L, sizeof(SDL_Surface*));
	auxiliar_setclass(L, "sdl{surface}", -1);

	*s = IMG_Load_RW(PHYSFSRWOPS_openRead(name), TRUE);
	if (!*s) return 0;

	lua_pushnumber(L, (*s)->w);
	lua_pushnumber(L, (*s)->h);

	return 3;
}

static int sdl_load_image_mem(lua_State *L)
{
	size_t len;
	const char *data = luaL_checklstring(L, 1, &len);

	SDL_Surface **s = (SDL_Surface**)lua_newuserdata(L, sizeof(SDL_Surface*));
	auxiliar_setclass(L, "sdl{surface}", -1);

	*s = IMG_Load_RW(SDL_RWFromConstMem(data, len), TRUE);
	if (!*s) return 0;

	lua_pushnumber(L, (*s)->w);
	lua_pushnumber(L, (*s)->h);

	return 3;
}

static int sdl_free_surface(lua_State *L)
{
	SDL_Surface **s = (SDL_Surface**)auxiliar_checkclass(L, "sdl{surface}", 1);
	if (*s)
	{
		if ((*s)->flags & SDL_PREALLOC) free((*s)->pixels);
		SDL_FreeSurface(*s);
	}
	lua_pushnumber(L, 1);
	return 1;
}

static int lua_display_char(lua_State *L)
{
	SDL_Surface **s = (SDL_Surface**)auxiliar_checkclass(L, "sdl{surface}", 1);
	const char *c = luaL_checkstring(L, 2);
	int x = luaL_checknumber(L, 3);
	int y = luaL_checknumber(L, 4);
	int r = luaL_checknumber(L, 5);
	int g = luaL_checknumber(L, 6);
	int b = luaL_checknumber(L, 7);

	display_put_char(*s, c[0], x, y, r, g, b);

	return 0;
}

static int sdl_surface_erase(lua_State *L)
{
	SDL_Surface **s = (SDL_Surface**)auxiliar_checkclass(L, "sdl{surface}", 1);
	int r = lua_tonumber(L, 2);
	int g = lua_tonumber(L, 3);
	int b = lua_tonumber(L, 4);
	int a = lua_isnumber(L, 5) ? lua_tonumber(L, 5) : 255;
	if (lua_isnumber(L, 6))
	{
		SDL_Rect rect;
		rect.x = lua_tonumber(L, 6);
		rect.y = lua_tonumber(L, 7);
		rect.w = lua_tonumber(L, 8);
		rect.h = lua_tonumber(L, 9);
		SDL_FillRect(*s, &rect, SDL_MapRGBA((*s)->format, r, g, b, a));
	}
	else
		SDL_FillRect(*s, NULL, SDL_MapRGBA((*s)->format, r, g, b, a));
	return 0;
}

static int sdl_surface_get_size(lua_State *L)
{
	SDL_Surface **s = (SDL_Surface**)auxiliar_checkclass(L, "sdl{surface}", 1);
	lua_pushnumber(L, (*s)->w);
	lua_pushnumber(L, (*s)->h);
	return 2;
}

static int sdl_surface_update_texture(lua_State *L)
{
	SDL_Surface **s = (SDL_Surface**)auxiliar_checkclass(L, "sdl{surface}", 1);
	texture_lua *t = texture_lua::from_state(L, 2);

	tglBindTexture(GL_TEXTURE_2D, t->texture_id);
	copy_surface_to_texture(*s);

	return 0;
}

GLuint load_image_texture(const char *file) {
	SDL_Surface *s = IMG_Load_RW(PHYSFSRWOPS_openRead(file), TRUE);
	// printf("OPENING %s : %lx\n", file, s);
	if (!s) return 0;

	GLuint t;
	glGenTextures(1, &t);
	tfglBindTexture(GL_TEXTURE_2D, t);

	int fw, fh;
	make_texture_for_surface(s, &fw, &fh, true, true);
	copy_surface_to_texture(s);

	SDL_FreeSurface(s);
	return t;
}

static int sdl_surface_to_texture(lua_State *L)
{
	SDL_Surface **s = (SDL_Surface**)auxiliar_checkclass(L, "sdl{surface}", 1);
	bool nearest = lua_toboolean(L, 2);
	bool norepeat = lua_toboolean(L, 3);
	bool exact_size = lua_toboolean(L, 4);

	texture_lua *t = new(L) texture_lua();

	glGenTextures(1, &t->texture_id);
	tfglBindTexture(GL_TEXTURE_2D, t->texture_id);

	int fw, fh;
	make_texture_for_surface(*s, &fw, &fh, norepeat, exact_size);
	if (nearest) glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
	copy_surface_to_texture(*s);
	t->w = (*s)->w;
	t->h = (*s)->h;
	t->no_free = false;

	lua_pushnumber(L, fw);
	lua_pushnumber(L, fh);
	lua_pushnumber(L, (double)fw / (*s)->w);
	lua_pushnumber(L, (double)fh / (*s)->h);
	lua_pushnumber(L, (*s)->w);
	lua_pushnumber(L, (*s)->h);

	return 7;
}

static int sdl_surface_merge(lua_State *L)
{
	SDL_Surface **dst = (SDL_Surface**)auxiliar_checkclass(L, "sdl{surface}", 1);
	SDL_Surface **src = (SDL_Surface**)auxiliar_checkclass(L, "sdl{surface}", 2);
	int x = luaL_checknumber(L, 3);
	int y = luaL_checknumber(L, 4);
	if (dst && *dst && src && *src)
	{
		sdlDrawImage(*dst, *src, x, y);
	}
	return 0;
}

static int sdl_surface_alpha(lua_State *L)
{
	SDL_Surface **s = (SDL_Surface**)auxiliar_checkclass(L, "sdl{surface}", 1);
	if (lua_isnumber(L, 2))
	{
		int a = luaL_checknumber(L, 2);
		SDL_SetAlpha(*s, /*SDL_SRCALPHA | */SDL_RLEACCEL, (a < 0) ? 0 : (a > 255) ? 255 : a);
	}
	else
	{
		SDL_SetAlpha(*s, 0, 0);
	}
	return 0;
}

static int sdl_free_texture(lua_State *L)
{
	texture_lua *t = texture_lua::from_state(L, 1);
	t->~texture_lua();
	lua_pushnumber(L, 1);
//	printf("freeing texture %d\n", *t);
	return 1;
}

static int sdl_texture_set_wrap(lua_State *L)
{
	texture_lua *t = texture_lua::from_state(L, 1);
	tglBindTexture(GL_TEXTURE_2D, t->texture_id);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, !lua_toboolean(L, 2) ? GL_CLAMP_TO_EDGE : GL_REPEAT);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, !lua_toboolean(L, 3) ? GL_CLAMP_TO_EDGE : GL_REPEAT);	
	lua_pushvalue(L, 1);
	return 1;
}

static int sdl_texture_set_filter(lua_State *L)
{
	texture_lua *t = texture_lua::from_state(L, 1);
	tglBindTexture(GL_TEXTURE_2D, t->texture_id);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, !lua_toboolean(L, 2) ? GL_LINEAR : GL_NEAREST);
	lua_pushvalue(L, 1);
	return 1;
}

static int gl_depth_test(lua_State *L)
{
	if (lua_toboolean(L, 1)) glEnable(GL_DEPTH_TEST);
	else glDisable(GL_DEPTH_TEST);
	return 0;
}

static int sdl_texture_bind(lua_State *L)
{
	texture_lua *t = texture_lua::from_state(L, 1);
	int i = luaL_checknumber(L, 2);

	if (i > 0)
	{
		if (multitexture_active && shaders_active)
		{
			tglActiveTexture(GL_TEXTURE0+i);
			tglBindTexture(t->native_kind(), t->texture_id);
			tglActiveTexture(GL_TEXTURE0);
		}
	}
	else
	{
		tglBindTexture(t->native_kind(), t->texture_id);
	}

	return 0;
}
static int sdl_texture_get_size(lua_State *L)
{
	texture_lua *t = texture_lua::from_state(L, 1);
	lua_pushnumber(L, t->w);
	lua_pushnumber(L, t->h);
	return 2;
}
static int sdl_texture_get_value(lua_State *L)
{
	texture_lua *t = texture_lua::from_state(L, 1);
	lua_pushnumber(L, t->texture_id);
	return 1;
}

static int sdl_set_window_title(lua_State *L)
{
	const char *title = luaL_checkstring(L, 1);
	SDL_SetWindowTitle(window, title);
	return 0;
}

static int sdl_set_window_size(lua_State *L)
{
	int w = luaL_checknumber(L, 1);
	int h = luaL_checknumber(L, 2);
	bool fullscreen = lua_toboolean(L, 3);
	bool borderless = lua_toboolean(L, 4);
	float zoom = luaL_checknumber(L, 5);

	printf("Setting resolution to %dx%d (%s, %s)\n", w, h, fullscreen ? "fullscreen" : "windowed", borderless ? "borderless" : "with borders");
	do_resize(w, h, fullscreen, borderless, zoom);

	lua_pushboolean(L, TRUE);
	return 1;
}

static int sdl_set_window_size_restart_check(lua_State *L)
{
	int w = luaL_checknumber(L, 1);
	int h = luaL_checknumber(L, 2);
	bool fullscreen = lua_toboolean(L, 3);
	bool borderless = lua_toboolean(L, 4);

	lua_pushboolean(L, resizeNeedsNewWindow(w, h, fullscreen, borderless));
	return 1;
}

static int sdl_set_window_pos(lua_State *L)
{
	int x = luaL_checknumber(L, 1);
	int y = luaL_checknumber(L, 2);

	do_move(x, y);

	lua_pushboolean(L, TRUE);
	return 1;
}

static bool draw_string_split_anywhere = FALSE;
static int font_display_split_anywhere(lua_State *L) {
	draw_string_split_anywhere = lua_toboolean(L, 1);
	return 0;
}
static int font_display_split_anywhere_get(lua_State *L) {
	lua_pushboolean(L, draw_string_split_anywhere);
	return 1;
}

static int string_find_next_utf(lua_State *L) {
	size_t str_len;
	const char *str = luaL_checklstring(L, 1, &str_len);
	int pos = lua_tonumber(L, 2) - 1;

	int32_t _dummy_;
	ssize_t nextutf = utf8proc_iterate((const uint8_t*)str + pos, str_len - pos, &_dummy_);
	if (nextutf < 1) nextutf = 1;
	if (pos + nextutf >= str_len) lua_pushboolean(L, FALSE);
	else lua_pushnumber(L, 1 + pos + nextutf);
	return 1;
}

extern void on_redraw();
static int sdl_redraw_screen(lua_State *L) {
	redraw_now(redraw_type_normal);
	return 0;
}

static int sdl_redraw_screen_for_screenshot(lua_State *L) {
	bool for_savefile = lua_toboolean(L, 1);
	if (for_savefile) redraw_now(redraw_type_savefile_screenshot);
	else redraw_now(redraw_type_user_screenshot);
	return 0;
}

static int redrawing_for_savefile_screenshot(lua_State *L) {
	lua_pushboolean(L, (get_current_redraw_type() == redraw_type_savefile_screenshot));
	return 1;
}

static int gl_fbo_is_active(lua_State *L)
{
	lua_pushboolean(L, fbo_active);
	return 1;
}

static int gl_fbo_disable(lua_State *L)
{
	return 0;
}

static int is_safe_mode(lua_State *L)
{
	lua_pushboolean(L, safe_mode);
	return 1;
}

static int set_safe_mode(lua_State *L)
{
	safe_mode = TRUE;
	return 0;
}

static int sdl_get_modes_list(lua_State *L)
{
	SDL_PixelFormat format;
	SDL_Rect **modes = NULL;
	int loops = 0;
	int bpp = 0;
	int nb = 1;
	lua_newtable(L);
	do
	{
		//format.BitsPerPixel seems to get zeroed out on my windows box
		switch(loops)
		{
			case 0://32 bpp
				format.BitsPerPixel = 32;
				bpp = 32;
				break;
			case 1://24 bpp
				format.BitsPerPixel = 24;
				bpp = 24;
				break;
			case 2://16 bpp
				format.BitsPerPixel = 16;
				bpp = 16;
				break;
		}

		//get available fullscreen/hardware modes
		modes = SDL_ListModes(&format, 0);
		if (modes)
		{
			int i;
			for(i=0; modes[i]; ++i)
			{
				printf("Available resolutions: %dx%dx%d\n", modes[i]->w, modes[i]->h, bpp/*format.BitsPerPixel*/);
				lua_pushnumber(L, nb++);
				lua_newtable(L);

				lua_pushliteral(L, "w");
				lua_pushnumber(L, modes[i]->w);
				lua_settable(L, -3);

				lua_pushliteral(L, "h");
				lua_pushnumber(L, modes[i]->h);
				lua_settable(L, -3);

				lua_settable(L, -3);
			}
		}
	}while(++loops != 3);
	return 1;
}

extern float gamma_correction;
static int sdl_set_gamma(lua_State *L)
{
	if (lua_isnumber(L, 1)) {
		gamma_correction = lua_tonumber(L, 1);
		SDL_SetWindowBrightness(window, gamma_correction);
	}
	lua_pushnumber(L, gamma_correction);
	return 1;
}

static void screenshot_apply_gamma(png_byte *image, unsigned long width, unsigned long height) {
	// User screenshots (but not saved game screenshots) should have gamma applied.
	if (gamma_correction != 1.0 && get_current_redraw_type() == redraw_type_user_screenshot) 	{
		Uint16 ramp16[256];
		png_byte ramp8[256];
		unsigned long i;

		// This is sufficient for the simple gamma adjustment used above.
		// If that changes, we may need to query the gamma ramp.
		SDL_CalculateGammaRamp(gamma_correction, ramp16);
		for (i = 0; i < 256; i++)
			ramp8[i] = ramp16[i] / 256;

		// Red, green and blue component are all the same for simple gamma.
		for (i = 0; i < width * height * 3; i++)
			image[i] = ramp8[image[i]];
	}
}

static void png_write_data_fn(png_structp png_ptr, png_bytep data, png_size_t length)
{
	luaL_Buffer *B = (luaL_Buffer*)png_get_io_ptr(png_ptr);
	luaL_addlstring(B, (const char*)data, length);
}
static void png_output_flush_fn(png_structp png_ptr)
{
}

#ifndef png_infopp_NULL
#define png_infopp_NULL (png_infopp)NULL
#endif
static int sdl_get_png_screenshot(lua_State *L)
{
	unsigned int x = luaL_checknumber(L, 1);
	unsigned int y = luaL_checknumber(L, 2);
	unsigned long width = luaL_checknumber(L, 3);
	unsigned long height = luaL_checknumber(L, 4);
	unsigned long i;
	png_structp png_ptr;
	png_infop info_ptr;
	png_colorp palette;
	png_byte *image;
	png_bytep *row_pointers;
	int aw, ah;

	SDL_GetWindowSize(window, &aw, &ah);

	/* Y coordinate must be reversed for OpenGL. */
	y = ah - (y + height);

	png_ptr = png_create_write_struct(PNG_LIBPNG_VER_STRING, NULL, NULL, NULL);

	if (png_ptr == NULL)
	{
		return 0;
	}

	info_ptr = png_create_info_struct(png_ptr);
	if (info_ptr == NULL)
	{
		png_destroy_write_struct(&png_ptr, png_infopp_NULL);
		return 0;
	}

	if (setjmp(png_jmpbuf(png_ptr)))
	{
		png_destroy_write_struct(&png_ptr, &info_ptr);
		return 0;
	}

	luaL_Buffer B;
	luaL_buffinit(L, &B);
	png_set_write_fn(png_ptr, &B, png_write_data_fn, png_output_flush_fn);

	png_set_IHDR(png_ptr, info_ptr, width, height, 8, PNG_COLOR_TYPE_RGB,
		PNG_INTERLACE_NONE, PNG_COMPRESSION_TYPE_DEFAULT, PNG_FILTER_TYPE_DEFAULT);

	image = (png_byte *)malloc(width * height * 3 * sizeof(png_byte));
	if(image == NULL)
	{
		png_destroy_write_struct(&png_ptr, &info_ptr);
		luaL_pushresult(&B); lua_pop(L, 1);
		return 0;
	}

	row_pointers = (png_bytep *)malloc(height * sizeof(png_bytep));
	if(row_pointers == NULL)
	{
		png_destroy_write_struct(&png_ptr, &info_ptr);
		free(image);
		image = NULL;
		luaL_pushresult(&B); lua_pop(L, 1);
		return 0;
	}

	glPixelStorei(GL_PACK_ALIGNMENT, 1);
	glReadPixels(x, y, width, height, GL_RGB, GL_UNSIGNED_BYTE, (GLvoid *)image);
	screenshot_apply_gamma(image, width, height);

	for (i = 0; i < height; i++)
	{
		row_pointers[i] = (png_bytep)image + (height - 1 - i) * width * 3;
	}

	png_set_rows(png_ptr, info_ptr, row_pointers);
	png_write_png(png_ptr, info_ptr, PNG_TRANSFORM_IDENTITY, NULL);

	png_destroy_write_struct(&png_ptr, &info_ptr);

	free(row_pointers);
	row_pointers = NULL;

	free(image);
	image = NULL;

	luaL_pushresult(&B);

	return 1;
}

static int print_png(lua_State *L, const char *filename, GLubyte *image, int width, int height) {
	unsigned long i;
	png_structp png_ptr;
	png_infop info_ptr;
	png_colorp palette;
	png_bytep *row_pointers;

	png_ptr = png_create_write_struct(PNG_LIBPNG_VER_STRING, NULL, NULL, NULL);

	if (png_ptr == NULL)
	{
		return 0;
	}

	info_ptr = png_create_info_struct(png_ptr);
	if (info_ptr == NULL)
	{
		png_destroy_write_struct(&png_ptr, png_infopp_NULL);
		return 0;
	}

	if (setjmp(png_jmpbuf(png_ptr)))
	{
		png_destroy_write_struct(&png_ptr, &info_ptr);
		return 0;
	}

	luaL_Buffer B;
	luaL_buffinit(L, &B);
	png_set_write_fn(png_ptr, &B, png_write_data_fn, png_output_flush_fn);

	png_set_IHDR(png_ptr, info_ptr, width, height, 8, PNG_COLOR_TYPE_RGBA,
		PNG_INTERLACE_NONE, PNG_COMPRESSION_TYPE_DEFAULT, PNG_FILTER_TYPE_DEFAULT);

	row_pointers = (png_bytep *)malloc(height * sizeof(png_bytep));
	if(row_pointers == NULL)
	{
		png_destroy_write_struct(&png_ptr, &info_ptr);
		luaL_pushresult(&B); lua_pop(L, 1);
		return 0;
	}

	for (i = 0; i < height; i++)
	{
		row_pointers[i] = (png_bytep)image + i * width * 4;
	}

	png_set_rows(png_ptr, info_ptr, row_pointers);
	png_write_png(png_ptr, info_ptr, PNG_TRANSFORM_IDENTITY, NULL);

	png_destroy_write_struct(&png_ptr, &info_ptr);

	free(row_pointers);
	row_pointers = NULL;

	luaL_pushresult(&B);

	size_t len;
	const char* pstr = lua_tolstring(L, -1, &len);
	PHYSFS_File *f = PHYSFS_openWrite(filename);
	PHYSFS_write(f, pstr, sizeof(char), len);
	PHYSFS_close(f);

	lua_pop(L, 1);
}

static int sdl_surface_to_png(lua_State *L) {
	SDL_Surface *s = *(SDL_Surface**)auxiliar_checkclass(L, "sdl{surface}", 1);
	const char *filename = luaL_checkstring(L, 2);

	print_png(L, filename, (GLubyte*)s->pixels, s->w, s->h);

	return 0;
}

static int pause_anims_started = 0;
static int display_pause_anims(lua_State *L) {
	bool new_state = lua_toboolean(L, 1);
	if (new_state == anims_paused) return 0;

	if (new_state) {
		anims_paused = TRUE;
		pause_anims_started = SDL_GetTicks();
	} else {
		anims_paused = FALSE;
		frame_tick_paused_time += SDL_GetTicks() - pause_anims_started;
	}
	printf("[DISPLAY] Animations paused: %d\n", anims_paused);
	return 0;
}

static int gl_get_max_texture_size(lua_State *L) {
	lua_pushnumber(L, max_texture_size);
	return 1;
}

static int gl_counts_draws(lua_State *L) {
	lua_pushnumber(L, nb_draws);
	lua_pushnumber(L, nb_rgl);
	nb_draws = 0;
	nb_rgl = 0;
	return 2;
}

static int gl_get_fps(lua_State *L) {
	lua_pushnumber(L, current_fps);
	lua_pushnumber(L, ticks_per_frame);
	return 2;
}

static const struct luaL_Reg displaylib[] =
{
	{"breakTextAllCharacter", font_display_split_anywhere},
	{"getBreakTextAllCharacter", font_display_split_anywhere_get},
	{"stringNextUTF", string_find_next_utf},
	{"forceRedraw", sdl_redraw_screen},
	{"forceRedrawForScreenshot", sdl_redraw_screen_for_screenshot},
	{"redrawingForSavefileScreenshot", redrawing_for_savefile_screenshot},
	{"size", sdl_screen_size},
	{"windowPos", sdl_window_pos},
	{"newSurface", sdl_new_surface},
	{"FBOActive", gl_fbo_is_active},
	{"safeMode", is_safe_mode},
	{"forceSafeMode", set_safe_mode},
	{"disableFBO", gl_fbo_disable},
	{"loadImage", sdl_load_image},
	{"loadImageMemory", sdl_load_image_mem},
	{"setWindowTitle", sdl_set_window_title},
	{"setWindowSize", sdl_set_window_size},
	{"setWindowSizeRequiresRestart", sdl_set_window_size_restart_check},
	{"setWindowPos", sdl_set_window_pos},
	{"getModesList", sdl_get_modes_list},
	{"setGamma", sdl_set_gamma},
	{"pauseAnims", display_pause_anims},
	{"getScreenshot", sdl_get_png_screenshot},
	{"glDepthTest", gl_depth_test},
	{"glMaxTextureSize", gl_get_max_texture_size},
	{"countDraws", gl_counts_draws},
	{"getFPS", gl_get_fps},
	{NULL, NULL},
};

static const struct luaL_Reg sdl_surface_reg[] =
{
	{"__gc", sdl_free_surface},
	{"close", sdl_free_surface},
	{"erase", sdl_surface_erase},
	{"getSize", sdl_surface_get_size},
	{"merge", sdl_surface_merge},
	{"putChar", lua_display_char},
	{"alpha", sdl_surface_alpha},
	{"glTexture", sdl_surface_to_texture},
	{"updateTexture", sdl_surface_update_texture},
	{"toPNG", sdl_surface_to_png},
	{NULL, NULL},
};

static const struct luaL_Reg sdl_texture_reg[] =
{
	{"__gc", sdl_free_texture},
	{"close", sdl_free_texture},
	{"toID", gl_texture_id},
	{"toSurface", gl_texture_to_sdl},
	{"generateSDM", gl_texture_alter_sdm},
	{"bind", sdl_texture_bind},
	{"getSize", sdl_texture_get_size},
	{"getValue", sdl_texture_get_value},
	{"wrap", sdl_texture_set_wrap},
	{"filter", sdl_texture_set_filter},
	{NULL, NULL},
};

/******************************************************************
 ******************************************************************
 *                              RNG                               *
 ******************************************************************
 ******************************************************************/

static int rng_float(lua_State *L)
{
	float min = luaL_checknumber(L, 1);
	float max = luaL_checknumber(L, 2);
	if (min < max)
		lua_pushnumber(L, genrand_real(min, max));
	else
		lua_pushnumber(L, genrand_real(max, min));
	return 1;
}

static int rng_dice(lua_State *L)
{
	int x = luaL_checknumber(L, 1);
	int y = luaL_checknumber(L, 2);
	int i, res = 0;
	for (i = 0; i < x; i++)
		res += 1 + rand_div(y);
	lua_pushnumber(L, res);
	return 1;
}

static int rng_range(lua_State *L)
{
	int x = luaL_checknumber(L, 1);
	int y = luaL_checknumber(L, 2);
	if (x < y)
	{
		int res = x + rand_div(1 + y - x);
		lua_pushnumber(L, res);
	}
	else
	{
		int res = y + rand_div(1 + x - y);
		lua_pushnumber(L, res);
	}
	return 1;
}

static int rng_avg(lua_State *L)
{
	int x = luaL_checknumber(L, 1);
	int y = luaL_checknumber(L, 2);
	int nb = 2;
	double res = 0;
	int i;
	if (lua_isnumber(L, 3)) nb = luaL_checknumber(L, 3);
	for (i = 0; i < nb; i++)
	{
		int r = x + rand_div(1 + y - x);
		res += r;
	}
	lua_pushnumber(L, res / (double)nb);
	return 1;
}

static int rng_call(lua_State *L)
{
	int x = luaL_checknumber(L, 1);
	if (lua_isnumber(L, 2))
	{
		int y = luaL_checknumber(L, 2);
		if (x < y)
		{
			int res = x + rand_div(1 + y - x);
			lua_pushnumber(L, res);
		}
		else
		{
			int res = y + rand_div(1 + x - y);
			lua_pushnumber(L, res);
		}
	}
	else
	{
		lua_pushnumber(L, rand_div(x));
	}
	return 1;
}

static int rng_seed(lua_State *L)
{
	int seed = luaL_checknumber(L, 1);
	if (seed>=0)
		init_gen_rand(seed);
	else
		init_gen_rand(time(NULL));
	return 0;
}

static int rng_chance(lua_State *L)
{
	int x = luaL_checknumber(L, 1);
	lua_pushboolean(L, rand_div(x) == 0);
	return 1;
}

static int rng_percent(lua_State *L)
{
	int x = luaL_checknumber(L, 1);
	int res = rand_div(100);
	lua_pushboolean(L, res < x);
	return 1;
}

/*
 * The number of entries in the "randnor_table"
 */
#define RANDNOR_NUM	256

/*
 * The standard deviation of the "randnor_table"
 */
#define RANDNOR_STD	64

/*
 * The normal distribution table for the "randnor()" function (below)
 */
static int randnor_table[RANDNOR_NUM] =
{
	206, 613, 1022, 1430, 1838, 2245, 2652, 3058,
	3463, 3867, 4271, 4673, 5075, 5475, 5874, 6271,
	6667, 7061, 7454, 7845, 8234, 8621, 9006, 9389,
	9770, 10148, 10524, 10898, 11269, 11638, 12004, 12367,
	12727, 13085, 13440, 13792, 14140, 14486, 14828, 15168,
	15504, 15836, 16166, 16492, 16814, 17133, 17449, 17761,
	18069, 18374, 18675, 18972, 19266, 19556, 19842, 20124,
	20403, 20678, 20949, 21216, 21479, 21738, 21994, 22245,

	22493, 22737, 22977, 23213, 23446, 23674, 23899, 24120,
	24336, 24550, 24759, 24965, 25166, 25365, 25559, 25750,
	25937, 26120, 26300, 26476, 26649, 26818, 26983, 27146,
	27304, 27460, 27612, 27760, 27906, 28048, 28187, 28323,
	28455, 28585, 28711, 28835, 28955, 29073, 29188, 29299,
	29409, 29515, 29619, 29720, 29818, 29914, 30007, 30098,
	30186, 30272, 30356, 30437, 30516, 30593, 30668, 30740,
	30810, 30879, 30945, 31010, 31072, 31133, 31192, 31249,

	31304, 31358, 31410, 31460, 31509, 31556, 31601, 31646,
	31688, 31730, 31770, 31808, 31846, 31882, 31917, 31950,
	31983, 32014, 32044, 32074, 32102, 32129, 32155, 32180,
	32205, 32228, 32251, 32273, 32294, 32314, 32333, 32352,
	32370, 32387, 32404, 32420, 32435, 32450, 32464, 32477,
	32490, 32503, 32515, 32526, 32537, 32548, 32558, 32568,
	32577, 32586, 32595, 32603, 32611, 32618, 32625, 32632,
	32639, 32645, 32651, 32657, 32662, 32667, 32672, 32677,

	32682, 32686, 32690, 32694, 32698, 32702, 32705, 32708,
	32711, 32714, 32717, 32720, 32722, 32725, 32727, 32729,
	32731, 32733, 32735, 32737, 32739, 32740, 32742, 32743,
	32745, 32746, 32747, 32748, 32749, 32750, 32751, 32752,
	32753, 32754, 32755, 32756, 32757, 32757, 32758, 32758,
	32759, 32760, 32760, 32761, 32761, 32761, 32762, 32762,
	32763, 32763, 32763, 32764, 32764, 32764, 32764, 32765,
	32765, 32765, 32765, 32766, 32766, 32766, 32766, 32767,
};


/*
 * Generate a random integer number of NORMAL distribution
 *
 * The table above is used to generate a psuedo-normal distribution,
 * in a manner which is much faster than calling a transcendental
 * function to calculate a true normal distribution.
 *
 * Basically, entry 64*N in the table above represents the number of
 * times out of 32767 that a random variable with normal distribution
 * will fall within N standard deviations of the mean.  That is, about
 * 68 percent of the time for N=1 and 95 percent of the time for N=2.
 *
 * The table above contains a "faked" final entry which allows us to
 * pretend that all values in a normal distribution are strictly less
 * than four standard deviations away from the mean.  This results in
 * "conservative" distribution of approximately 1/32768 values.
 *
 * Note that the binary search takes up to 16 quick iterations.
 */
static int rng_normal(lua_State *L)
{
	int mean = luaL_checknumber(L, 1);
	int stand = luaL_checknumber(L, 2);
	int tmp;
	int offset;

	int low = 0;
	int high = RANDNOR_NUM;

	/* Paranoia */
	if (stand < 1)
	{
		lua_pushnumber(L, mean);
		return 1;
	}

	/* Roll for probability */
	tmp = (int)rand_div(32768);

	/* Binary Search */
	while (low < high)
	{
		long mid = (low + high) >> 1;

		/* Move right if forced */
		if (randnor_table[mid] < tmp)
		{
			low = mid + 1;
		}

		/* Move left otherwise */
		else
		{
			high = mid;
		}
	}

	/* Convert the index into an offset */
	offset = (long)stand * (long)low / RANDNOR_STD;

	/* One half should be negative */
	if (rand_div(100) < 50)
	{
		lua_pushnumber(L, mean - offset);
		return 1;
	}

	/* One half should be positive */
	lua_pushnumber(L, mean + offset);
	return 1;
}

/*
 * Generate a random floating-point number of NORMAL distribution
 *
 * Uses the Box-Muller transform.
 *
 */
static int rng_normal_float(lua_State *L)
{
	static const double TWOPI = 6.2831853071795862;
	static bool stored = FALSE;
	static double z0;
	static double z1;
	double mean = luaL_checknumber(L, 1);
	double std = luaL_checknumber(L, 2);
	double u1;
	double u2;
	if (stored == FALSE)
	{
		u1 = genrand_real1();
		u2 = genrand_real1();
		u1 = sqrt(-2 * log(u1));
		z0 = u1 * cos(TWOPI * u2);
		z1 = u1 * sin(TWOPI * u2);
		lua_pushnumber(L, (z0*std)+mean);
		stored = TRUE;
	}
	else
	{
		lua_pushnumber(L, (z1*std)+mean);
		stored = FALSE;
	}
	return 1;
}

static const struct luaL_Reg rnglib[] =
{
	{"__call", rng_call},
	{"range", rng_range},
	{"avg", rng_avg},
	{"dice", rng_dice},
	{"seed", rng_seed},
	{"chance", rng_chance},
	{"percent", rng_percent},
	{"normal", rng_normal},
	{"normalFloat", rng_normal_float},
	{"float", rng_float},
	{NULL, NULL},
};


/******************************************************************
 ******************************************************************
 *                             Line                               *
 ******************************************************************
 ******************************************************************/
typedef struct {
	int stepx;
	int stepy;
	int e;
	int deltax;
	int deltay;
	int origx;
	int origy;
	int destx;
	int desty;
} line_data;

/* ********** bresenham line drawing ********** */
static int lua_line_init(lua_State *L)
{
	int xFrom = luaL_checknumber(L, 1);
	int yFrom = luaL_checknumber(L, 2);
	int xTo = luaL_checknumber(L, 3);
	int yTo = luaL_checknumber(L, 4);
	bool start_at_end = lua_toboolean(L, 5);

	line_data *data = (line_data*)lua_newuserdata(L, sizeof(line_data));
	auxiliar_setclass(L, "core{line}", -1);

	data->origx=xFrom;
	data->origy=yFrom;
	data->destx=xTo;
	data->desty=yTo;
	data->deltax=xTo - xFrom;
	data->deltay=yTo - yFrom;
	if ( data->deltax > 0 ) {
		data->stepx=1;
	} else if ( data->deltax < 0 ){
		data->stepx=-1;
	} else data->stepx=0;
	if ( data->deltay > 0 ) {
		data->stepy=1;
	} else if ( data->deltay < 0 ){
		data->stepy=-1;
	} else data->stepy = 0;
	if ( data->stepx*data->deltax > data->stepy*data->deltay ) {
		data->e = data->stepx*data->deltax;
		data->deltax *= 2;
		data->deltay *= 2;
	} else {
		data->e = data->stepy*data->deltay;
		data->deltax *= 2;
		data->deltay *= 2;
	}

	if (start_at_end)
	{
		data->origx=xTo;
		data->origy=yTo;
	}

	return 1;
}

static int lua_line_step(lua_State *L)
{
	line_data *data = (line_data*)auxiliar_checkclass(L, "core{line}", 1);
	bool dont_stop_at_end = lua_toboolean(L, 2);

	if ( data->stepx*data->deltax > data->stepy*data->deltay ) {
		if (!dont_stop_at_end && data->origx == data->destx ) return 0;
		data->origx+=data->stepx;
		data->e -= data->stepy*data->deltay;
		if ( data->e < 0) {
			data->origy+=data->stepy;
			data->e+=data->stepx*data->deltax;
		}
	} else {
		if (!dont_stop_at_end && data->origy == data->desty ) return 0;
		data->origy+=data->stepy;
		data->e -= data->stepx*data->deltax;
		if ( data->e < 0) {
			data->origx+=data->stepx;
			data->e+=data->stepy*data->deltay;
		}
	}
	lua_pushnumber(L, data->origx);
	lua_pushnumber(L, data->origy);
	return 2;
}

static int lua_free_line(lua_State *L)
{
	(void)auxiliar_checkclass(L, "core{line}", 1);
	lua_pushnumber(L, 1);
	return 1;
}

static const struct luaL_Reg linelib[] =
{
	{"new", lua_line_init},
	{NULL, NULL},
};

static const struct luaL_Reg line_reg[] =
{
	{"__gc", lua_free_line},
	{"__call", lua_line_step},
	{NULL, NULL},
};

/******************************************************************
 ******************************************************************
 *                            ZLIB                                *
 ******************************************************************
 ******************************************************************/

static int lua_zlib_compress(lua_State *L)
{
	uLongf len;
	const char *data = luaL_checklstring(L, 1, (size_t*)&len);
	uLongf reslen = len * 1.1 + 12;
#ifdef __APPLE__
	unsigned
#endif
	char *res = (char*)malloc(reslen);
	z_stream zi;

	zi.next_in = (z_const Bytef*)data;
	zi.avail_in = len;
	zi.total_in = 0;

	zi.total_out = 0;

	zi.zalloc = NULL;
	zi.zfree = NULL;
	zi.opaque = NULL;

	deflateInit2(&zi, Z_BEST_COMPRESSION, Z_DEFLATED, 15 + 16, 8, Z_DEFAULT_STRATEGY);

	int deflateStatus;
	do {
		zi.next_out = (Bytef*)res + zi.total_out;

		// Calculate the amount of remaining free space in the output buffer
		// by subtracting the number of bytes that have been written so far
		// from the buffer's total capacity
		zi.avail_out = reslen - zi.total_out;

		/* deflate() compresses as much data as possible, and stops/returns when
		 the input buffer becomes empty or the output buffer becomes full. If
		 deflate() returns Z_OK, it means that there are more bytes left to
		 compress in the input buffer but the output buffer is full; the output
		 buffer should be expanded and deflate should be called again (i.e., the
		 loop should continue to rune). If deflate() returns Z_STREAM_END, the
		 end of the input stream was reached (i.e.g, all of the data has been
		 compressed) and the loop should stop. */
		deflateStatus = deflate(&zi, Z_FINISH);
	}
	while (deflateStatus == Z_OK);

	if (deflateStatus == Z_STREAM_END)
	{
		lua_pushlstring(L, (char *)res, zi.total_out);
		free(res);
		return 1;
	}
	else
	{
		free(res);
		return 0;
	}
}


static const struct luaL_Reg zliblib[] =
{
	{"compress", lua_zlib_compress},
	{NULL, NULL},
};

int luaopen_core(lua_State *L)
{
	auxiliar_newclass(L, "core{line}", line_reg);
	auxiliar_newclass(L, "gl{texture}", sdl_texture_reg);
	auxiliar_newclass(L, "sdl{surface}", sdl_surface_reg);
	luaL_openlib(L, "core.display", displaylib, 0);
	luaL_openlib(L, "core.key", keylib, 0);
	luaL_openlib(L, "core.zlib", zliblib, 0);

	luaL_openlib(L, "core.game", gamelib, 0);
	lua_pushliteral(L, "VERSION");
	lua_pushnumber(L, TE4CORE_VERSION);
	lua_settable(L, -3);

	luaL_openlib(L, "rng", rnglib, 0);
	luaL_openlib(L, "bresenham", linelib, 0);

	lua_settop(L, 0);
	return 1;
}

