#ifndef __USESHADER_H__
#define __USESHADER_H__

struct s_shader_reset_uniform {
	enum{UNIFORM_NUMBER, UNIFORM_VEC2, UNIFORM_VEC3, UNIFORM_VEC4} kind;
	GLint p;
	union {
		GLfloat number;
		GLfloat vec2[2];
		GLfloat vec3[3];
		GLfloat vec4[4];
	} data;
	struct s_shader_reset_uniform *next;
};
typedef struct s_shader_reset_uniform shader_reset_uniform;

typedef struct {
	bool clone;
	char *name;
	GLuint shader;
	GLint p_tick, p_color, p_mapcoord, p_texsize, p_texcoord, p_tex, p_mvp;
	GLint vertex_attrib, texcoord_attrib, color_attrib, texcoorddata_attrib, mapcoord_attrib, kind_attrib;
	struct s_shader_reset_uniform *reset_uniforms;
} shader_type;

extern shader_type *default_shader;
extern shader_type *current_shader;

extern bool shaders_active;
extern void useShader(shader_type *p, int x, int y, int w, int h, float tx, float ty, float tw, float th, float r, float g, float b, float a);
extern void useNoShader();

#endif
