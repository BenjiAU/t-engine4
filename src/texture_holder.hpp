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
#ifndef TEXTURE_HOLDER_HPP
#define TEXTURE_HOLDER_HPP

extern "C" {
#include "tgl.h"
}

const int DO_MAX_TEX = 3;

// All supported textures types
enum class TextureKind : GLenum { _1D = GL_TEXTURE_1D, _2D = GL_TEXTURE_2D, _3D = GL_TEXTURE_3D, CUBEMAP = GL_TEXTURE_CUBE_MAP }; 

// A single texture holder info, with various textings and convertions
struct texture_info {
	TextureKind kind;
	GLuint texture_id;
	texture_info() : texture_id(0), kind(TextureKind::_2D) {}
	texture_info(GLuint id) : texture_id(id), kind(TextureKind::_2D) {}
	texture_info(GLuint id, TextureKind k) : texture_id(id), kind(k) {}
	inline GLenum native_kind() { return static_cast<GLenum>(kind); }
	inline texture_info& operator=(GLuint id) { texture_id = id; kind = TextureKind::_2D; return *this; }
	inline void set(GLuint id) { texture_id = id; kind = TextureKind::_2D; }
	inline void set(GLuint id, TextureKind k) { texture_id = id; kind = k; }
	operator GLuint() const { return texture_id; }
	operator int() const { return texture_id; }
	operator bool() const { return texture_id != 0; }
};
inline bool operator==(const texture_info &a, const unsigned int b) { return a.texture_id == b; }
inline bool operator==(const texture_info &a, const texture_info &b) { return a.texture_id == b.texture_id; }
inline bool operator!=(const texture_info &a, const texture_info &b) { return a.texture_id != b.texture_id; }
inline bool operator<(const texture_info &a, const texture_info &b) { return a.texture_id < b.texture_id; }
inline bool operator>(const texture_info &a, const texture_info &b) { return a.texture_id > b.texture_id; }
inline bool operator<=(const texture_info &a, const texture_info &b) { return a.texture_id <= b.texture_id; }
inline bool operator>=(const texture_info &a, const texture_info &b) { return a.texture_id >= b.texture_id; }

// A texture holder for lua & other such kinds
struct texture_lua : texture_info {
	uint32_t w = 0, h = 0;
	bool no_free = false;

	~texture_lua() {
		if (!no_free) glDeleteTextures(1, &texture_id);
	}
	texture_info to_info() { return *this; }

	void *operator new(size_t size, lua_State *L) {
		void *ptr = lua_newuserdata(L, size);
		auxiliar_setclass(L, "gl{texture}", -1);
		return ptr;
	}
	static texture_lua* from_state(lua_State *L, int idx) {
		return (texture_lua*)auxiliar_checkclass(L, "gl{texture}", idx);
	}
};

// An array of texture holder infos (of fixed array size), with various textings and convertions
struct textures_array {
	texture_info tex[DO_MAX_TEX];
	textures_array() { tex[0] = 0; tex[1] = 0; tex[2] = 0; }
	textures_array(GLuint id) { tex[0] = id; tex[1] = 0; tex[2] = 0; }
	textures_array(texture_info t) { tex[0] = t; tex[1] = 0; tex[2] = 0; }
	inline texture_info& operator[](int idx) { return tex[idx]; }
	inline textures_array& operator=(GLuint id) { tex[0] = id; tex[1] = 0; tex[2] = 0; return *this; }
	inline textures_array& operator=(texture_info t) { tex[0] = t; tex[1] = 0; tex[2] = 0; return *this; }
	inline uint8_t count() { for (uint8_t idx = 0; idx < DO_MAX_TEX; idx++) { if (!tex[0]) return idx; } return DO_MAX_TEX; }
};
inline bool operator==(const textures_array &a, const textures_array &b) { return (a.tex[0].texture_id == b.tex[0].texture_id) && (a.tex[1].texture_id == b.tex[1].texture_id) && (a.tex[2].texture_id == b.tex[2].texture_id); }
inline bool operator!=(const textures_array &a, const textures_array &b) { return (a.tex[0].texture_id != b.tex[0].texture_id) || (a.tex[1].texture_id != b.tex[1].texture_id) || (a.tex[2].texture_id != b.tex[2].texture_id); }
inline bool operator<(const textures_array &a, const textures_array &b) { return a.tex[0].texture_id < b.tex[0].texture_id; }
inline bool operator>(const textures_array &a, const textures_array &b) { return a.tex[0].texture_id > b.tex[0].texture_id; }
inline bool operator<=(const textures_array &a, const textures_array &b) { return a.tex[0].texture_id <= b.tex[0].texture_id; }
inline bool operator>=(const textures_array &a, const textures_array &b) { return a.tex[0].texture_id >= b.tex[0].texture_id; }

#endif
