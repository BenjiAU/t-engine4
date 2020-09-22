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
using namespace std;
using namespace glm;

struct renderer_vertex {
	vec2 pos;
	vec2 tex;
	vec4 color;
};

enum class RendererBlend : uint8_t {
	DefaultBlend, AdditiveBlend, MixedBlend, ShinyBlend, SubstractBlend, SubstractMixedBlend, SubstractShinyBlend
};
inline void enableBlending(RendererBlend blend) {
	switch (blend) {
		case RendererBlend::DefaultBlend: break;
		case RendererBlend::AdditiveBlend: glBlendFunc(GL_ONE, GL_ONE); break;
		case RendererBlend::MixedBlend: glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA); break;
		case RendererBlend::ShinyBlend: glBlendFunc(GL_SRC_ALPHA,GL_ONE); break;
		case RendererBlend::SubstractBlend: glBlendFunc(GL_ONE, GL_ONE); glBlendEquation(GL_FUNC_REVERSE_SUBTRACT); break;
		case RendererBlend::SubstractMixedBlend: glBlendFuncSeparate(GL_ONE, GL_ONE_MINUS_SRC_ALPHA, GL_ONE, GL_ZERO); glBlendEquation(GL_FUNC_REVERSE_SUBTRACT); break;
		case RendererBlend::SubstractShinyBlend: glBlendFuncSeparate(GL_SRC_ALPHA,GL_ONE, GL_ONE, GL_ZERO); glBlendEquation(GL_FUNC_REVERSE_SUBTRACT); break;
	}
}
inline void disableBlending(RendererBlend blend) {
	switch (blend) {
		case RendererBlend::DefaultBlend: break;
		case RendererBlend::SubstractBlend:
		case RendererBlend::SubstractMixedBlend:
		case RendererBlend::SubstractShinyBlend:
			glBlendEquation(GL_FUNC_ADD); glBlendFunc(GL_SRC_ALPHA,GL_ONE_MINUS_SRC_ALPHA); break;
		default: glBlendFunc(GL_SRC_ALPHA,GL_ONE_MINUS_SRC_ALPHA); break;
	}
}

class Renderer {
protected:
	spShaderHolder shader;
	spTextureHolder tex;
	RendererBlend blend = RendererBlend::DefaultBlend;
	
public:
	virtual ~Renderer() {};
	void setBlend(RendererBlend blend);
	void setShader(spShaderHolder &shader);
	void setTexture(spTextureHolder &tex);
	virtual void setup(ParticlesData &p) = 0;
	virtual void update(ParticlesData &p) = 0;
	virtual void draw(ParticlesData &p, mat4 &model) = 0;
};

class RendererLine : public Renderer {
protected:
	GLuint vbos[2];
	vector<renderer_vertex> vertexes;
	
public:
	virtual void setup(ParticlesData &p);
	virtual ~RendererLine();
	virtual void update(ParticlesData &p);
	virtual void draw(ParticlesData &p, mat4 &model);
};

class RendererGL2 : public Renderer {
protected:
	GLuint vbos[2];
	vector<renderer_vertex> vertexes;
	
public:
	virtual void setup(ParticlesData &p);
	virtual ~RendererGL2();
	virtual void update(ParticlesData &p);
	virtual void draw(ParticlesData &p, mat4 &model);
};

class RendererGL3 : public Renderer {
protected:
	static GLuint vbo_shape;
	GLuint vbo_pos, vbo_color, vbo_texture;
	GLuint vao;
	vector<renderer_vertex> vertexes;

public:
	static void init();

	virtual void setup(ParticlesData &p);
	virtual ~RendererGL3();
	virtual void update(ParticlesData &p);
	virtual void draw(ParticlesData &p, mat4 &model);
};
