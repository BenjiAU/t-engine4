/*
    TE4 - T-Engine 4
    Copyright (C) 2009, 2010 Nicolas Casalini

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
#ifndef _MAIN_H_
#define _MAIN_H_

extern int resizeWindow(int width, int height);
extern void do_resize(int w, int h, bool fullscreen);
extern void setupRealtime(float freq);
extern void setupDisplayTimer(int fps);
extern bool fbo_active;
extern bool multitexture_active;
extern long total_keyframes;

#endif

