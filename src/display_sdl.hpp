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
#ifndef DISPLAY_SDL_H
#define DISPLAY_SDL_H

extern "C" {
#include "tSDL.h"
#include "glew.h"
}
#include "tgl.hpp"

#define sdlLock(surface) do {\
	if (SDL_MUSTLOCK(surface)) SDL_LockSurface(surface);\
	} while (0)

#define sdlUnlock(surface) do {\
		if (SDL_MUSTLOCK(surface)) SDL_UnlockSurface(surface);\
	} while (0)

extern SDL_Surface *screen;

#endif
