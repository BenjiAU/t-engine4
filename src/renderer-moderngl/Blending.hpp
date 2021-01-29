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
#ifndef DO_BLENDING_H
#define DO_BLENDING_H

extern "C" {
#include "tgl.h"
}

#include <stack>

/****************************************************************************
 ** Handler of blending state across all the engine
 ****************************************************************************/

struct BlendingState {
 	GLenum mode;
	GLenum srcRGB;
 	GLenum dstRGB;
 	GLenum srcAlpha;
 	GLenum dstAlpha;

	BlendingState(GLenum srcRGB, GLenum dstRGB, GLenum srcAlpha, GLenum dstAlpha, GLenum mode) : srcRGB(srcRGB), dstRGB(dstRGB), srcAlpha(srcAlpha), dstAlpha(dstAlpha), mode(mode) {}
	
	void activate(BlendingState *prev = nullptr) {
		glBlendFuncSeparate(srcRGB, dstRGB, srcAlpha, dstAlpha);
		if ((!prev) || (prev && prev->mode != mode)) glBlendEquation(mode);
	}

	static stack<BlendingState> states;
	static void push(GLenum srcRGB, GLenum dstRGB) {
		return push(srcRGB, dstRGB, srcRGB, dstRGB, GL_FUNC_ADD);
	}
	static void push(GLenum srcRGB, GLenum dstRGB, GLenum mode) {
		return push(srcRGB, dstRGB, srcRGB, dstRGB, mode);
	}
	static void push(GLenum srcRGB, GLenum dstRGB, GLenum srcAlpha, GLenum dstAlpha) {
		return push(srcRGB, dstRGB, srcAlpha, dstAlpha, GL_FUNC_ADD);
	}
	static void push(GLenum srcRGB, GLenum dstRGB, GLenum srcAlpha, GLenum dstAlpha, GLenum mode) {
		if (!states.empty()) {
			auto p = states.top();
			states.emplace(srcRGB, dstRGB, srcAlpha, dstAlpha, mode);
			states.top().activate(&p);
		} else {
			states.emplace(srcRGB, dstRGB, srcAlpha, dstAlpha, mode);
			states.top().activate();
		}
	}
	static void pop() {
		auto p = states.top();
		states.pop();
		if (!states.empty()) {
			states.top().activate(&p);
		}
	}
	static void clear() {
		while (!states.empty()) states.pop();
	}
};

#endif
