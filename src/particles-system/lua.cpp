/*
    TE4 - T-Engine 4
    Copyright (C) 2009 - 2017 Nicolas Casalini

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
#include "renderer-moderngl/Particles.hpp"
#include "particles-system/system.hpp"

extern "C" {
#include "auxiliar.h"
}
#include "core_loader.hpp"
#include "renderer-moderngl/easing.hpp" // This imports the code... yeah I know

using namespace particles;

static unordered_map<string, easing_ptr> easings_map({
	{"linear", easing::linear},
	{"inQuad", easing::quadraticIn},
	{"outQuad", easing::quadraticOut},
	{"inOutQuad", easing::quadraticInOut},
	{"inCubic", easing::cubicIn},
	{"outCubic", easing::cubicOut},
	{"inOutCubic", easing::cubicInOut},
	{"inQuart", easing::quarticIn},
	{"outQuart", easing::quarticOut},
	{"inOutQuart", easing::quarticInOut},
	{"inQuint", easing::quinticIn},
	{"outQuint", easing::quinticOut},
	{"inOutQuint", easing::quinticInOut},
	{"inSine", easing::sinusoidalIn},
	{"outSine", easing::sinusoidalOut},
	{"inOutSine", easing::sinusoidalInOut},
	{"inExpo", easing::exponentialIn},
	{"outExpo", easing::exponentialOut},
	{"inOutExpo", easing::exponentialInOut},
	{"inCirc", easing::circularIn},
	{"outCirc", easing::circularOut},
	{"inOutCirc", easing::circularInOut},
	{"inElastic", easing::elasticIn},
	{"outElastic", easing::elasticOut},
	{"inOutElastic", easing::elasticInOut},
	{"inBack", easing::backIn},
	{"outBack", easing::backOut},
	{"inOutBack", easing::backInOut},
	{"inBounce", easing::bounceIn},
	{"outBounce", easing::bounceOut},
	{"inOutBounce", easing::bounceInOut},
});

static int p_default_shader(lua_State *L)
{
	const char *shader_str = lua_tostring(L, 1);
	default_particlescompose_shader = Ensemble::getShader(L, shader_str);
	return 0;
}

static int p_gc_textures(lua_State *L)
{
	Ensemble::gcTextures();
	return 0;
}

static int p_free(lua_State *L)
{
	Ensemble **ee = (Ensemble**)auxiliar_checkclass(L, "particles{compose}", 1);
	// (*ee)->prepareDeath();
	delete *ee;
	lua_pushnumber(L, 1);
	return 1;
}

static int p_shift(lua_State *L)
{
	Ensemble **ee = (Ensemble**)auxiliar_checkclass(L, "particles{compose}", 1);
	(*ee)->shift(lua_tonumber(L, 2), lua_tonumber(L, 3), lua_toboolean(L, 4));
	return 0;
}

static int p_zoom(lua_State *L)
{
	Ensemble **ee = (Ensemble**)auxiliar_checkclass(L, "particles{compose}", 1);
	(*ee)->setZoom(lua_tonumber(L, 2));
	return 0;
}

static int p_speed(lua_State *L)
{
	Ensemble **ee = (Ensemble**)auxiliar_checkclass(L, "particles{compose}", 1);
	(*ee)->setSpeed(lua_tonumber(L, 2));
	return 0;
}

static int p_is_dead(lua_State *L)
{
	Ensemble **ee = (Ensemble**)auxiliar_checkclass(L, "particles{compose}", 1);
	lua_pushboolean(L, (*ee)->isDead());
	return 1;
}

static int p_count_alive(lua_State *L)
{
	Ensemble **ee = (Ensemble**)auxiliar_checkclass(L, "particles{compose}", 1);
	lua_pushnumber(L, (*ee)->countAlive());
	return 1;
}

static int p_trigger(lua_State *L)
{
	Ensemble **ee = (Ensemble**)auxiliar_checkclass(L, "particles{compose}", 1);
	string name((const char*)lua_tostring(L, 2));
	(*ee)->fireTrigger(name);
	return 0;
}

static int p_events_cb(lua_State *L)
{
	Ensemble **ee = (Ensemble**)auxiliar_checkclass(L, "particles{compose}", 1);
	if (lua_isfunction(L, 2)) {
		lua_pushvalue(L, 2);
		(*ee)->setEventsCallback(luaL_ref(L, LUA_REGISTRYINDEX));
	} else {
		(*ee)->setEventsCallback(LUA_NOREF);		
	}
	return 0;
}

static int p_toscreen(lua_State *L)
{
	Ensemble **ee = (Ensemble**)auxiliar_checkclass(L, "particles{compose}", 1);
	(*ee)->draw(lua_tonumber(L, 2), lua_tonumber(L, 3));
	return 0;
}

static inline float lua_float(lua_State *L, int table_idx, uint8_t field, float def) {
	float ret = def;
	lua_pushnumber(L, field);
	lua_rawget(L, table_idx < 0 ? (table_idx-1) : table_idx);
	if (lua_isnumber(L, -1)) ret = lua_tonumber(L, -1);
	lua_pop(L, 1);
	return ret;
}

static inline bool lua_bool(lua_State *L, int table_idx, const char *field, bool def) {
	bool ret = def;
	lua_pushstring(L, field);
	lua_rawget(L, table_idx < 0 ? (table_idx-1) : table_idx);
	if (lua_isboolean(L, -1)) ret = lua_toboolean(L, -1);
	lua_pop(L, 1);
	return ret;
}

static inline const char* lua_string(lua_State *L, int table_idx, const char *field, const char* def) {
	const char* ret = def;
	lua_pushstring(L, field);
	lua_rawget(L, table_idx < 0 ? (table_idx-1) : table_idx);
	if (lua_isstring(L, -1)) ret = lua_tostring(L, -1);
	lua_pop(L, 1);
	return ret;
}


static inline float lua_float(lua_State *L, bool allow_param, int table_idx, const char *field, float def) {
	float ret = def;
	lua_pushstring(L, field);
	lua_rawget(L, table_idx < 0 ? (table_idx-1) : table_idx);
	if (lua_isnumber(L, -1)) ret = lua_tonumber(L, -1);
	else if (allow_param && lua_isstring(L, -1)) {
		const char *expr = lua_tostring(L, -1);
		ret = Ensemble::getExpression(L, expr, 2);
	}
	lua_pop(L, 1);
	return ret;
}

static inline vec2 lua_vec2(lua_State *L, bool allow_param, int table_idx, const char *field, vec2 def) {
	vec2 ret = def;
	lua_pushstring(L, field);
	lua_rawget(L, table_idx < 0 ? (table_idx-1) : table_idx);
	if (lua_istable(L, -1)) {
		lua_rawgeti(L, -1, 1);
		lua_rawgeti(L, -2, 2);

		if (lua_isnumber(L, -2)) ret.x = lua_tonumber(L, -2);
		else ret.x = Ensemble::getExpression(L, lua_tostring(L, -2), 2);
		if (lua_isnumber(L, -1)) ret.y = lua_tonumber(L, -1);
		else ret.y = Ensemble::getExpression(L, lua_tostring(L, -1), 2);
		lua_pop(L, 2);
	}
	lua_pop(L, 1);
	return ret;
}

static inline vec4 lua_vec4(lua_State *L, bool allow_param, int table_idx, const char *field, vec4 def) {
	vec4 ret = def;
	lua_pushstring(L, field);
	lua_rawget(L, table_idx < 0 ? (table_idx-1) : table_idx);
	if (lua_istable(L, -1)) {
		lua_rawgeti(L, -1, 1);
		lua_rawgeti(L, -2, 2);
		lua_rawgeti(L, -3, 3);
		lua_rawgeti(L, -4, 4);
		if (lua_isnumber(L, -4)) ret.r = lua_tonumber(L, -4);
		else ret.r = Ensemble::getExpression(L, lua_tostring(L, -4), 2);
		if (lua_isnumber(L, -3)) ret.g = lua_tonumber(L, -3);
		else ret.g = Ensemble::getExpression(L, lua_tostring(L, -3), 2);
		if (lua_isnumber(L, -2)) ret.b = lua_tonumber(L, -2);
		else ret.b = Ensemble::getExpression(L, lua_tostring(L, -2), 2);
		if (lua_isnumber(L, -1)) ret.a = lua_tonumber(L, -1);
		else ret.a = Ensemble::getExpression(L, lua_tostring(L, -1), 2);
		lua_pop(L, 4);
	}
	lua_pop(L, 1);
	return ret;
}

static int p_new(lua_State *L) {
	float speed = 1, zoom = 1;
	if (lua_isnumber(L, 3)) speed = lua_tonumber(L, 3);
	if (lua_isnumber(L, 4)) zoom = lua_tonumber(L, 4);
	bool morph = lua_toboolean(L, 5);

	// We are given a filename load it, possibly from cache
	if (lua_isstring(L, 1)) {
		const char *def_name = lua_tostring(L, 1);
		int def = Ensemble::getDefinition(L, def_name);
		lua_rawgeti(L, LUA_REGISTRYINDEX, def);
		lua_replace(L, 1);
	}

	// Bad params table, replace with empty table
	if (!lua_istable(L, 2)) {
		lua_newtable(L);
		lua_replace(L, 2);
	}

	// Setup math as env for the parameters table, so complex math works
	lua_rawgeti(L, LUA_REGISTRYINDEX, math_mt_lua_ref);
	lua_setmetatable(L, 2);

	// If we have a default params table, copy it
	lua_pushliteral(L, "parameters");
	lua_rawget(L, 1);
	if (lua_istable(L, -1)) {
		lua_pushnil(L);
		while (lua_next(L, -2) != 0) {
			// Check existing
			bool exists = false;
			lua_pushvalue(L, -2); // Copy the key
			lua_rawget(L, 2); 
			exists = !lua_isnil(L, -1);
			lua_pop(L, 1);

			// Copy
			if (!exists) {
				lua_pushvalue(L, -2);
				lua_pushvalue(L, -2);
				lua_rawset(L, 2);
			}

			lua_pop(L, 1);
		}
	}
	lua_pop(L, 1);


	Ensemble *e = new Ensemble();
	e->setSpeed(speed);
	e->setZoom(zoom);
	int nb_systems = lua_objlen(L, 1);
	for (int i = 1; i <= nb_systems; i++) {		
		lua_rawgeti(L, 1, i);
		System *sys = new System(lua_float(L, false, -1, "max_particles", 10), (RendererBlend)((uint8_t)lua_float(L, false, -1, "blend", static_cast<uint8_t>(RendererBlend::DefaultBlend))));

		const char *tex_str = lua_string(L, -1, "texture", NULL);
		if (tex_str){
			spTextureHolder th = Ensemble::getTexture(tex_str);
			sys->setTexture(th);
		}

		const char *shader_str = lua_string(L, -1, "shader", NULL);
		if (shader_str){
			spShaderHolder sh = Ensemble::getShader(L, shader_str);
			sys->setShader(sh);
		}

		/** Emitters **/
		lua_pushliteral(L, "emitters");
		lua_rawget(L, -2);
		int nb_emitters = lua_objlen(L, -1);
		for (int ei = 1; ei <= nb_emitters; ei++) {
			lua_rawgeti(L, -1, ei);
			EmittersList e_id = (EmittersList)((uint8_t)lua_float(L, -1, 1, 0));
			Emitter *em;
			switch (e_id) {
				case EmittersList::LinearEmitter:
					em = new LinearEmitter(lua_float(L, true, -1, "startat", -1), lua_float(L, true, -1, "duration", -1), lua_float(L, true, -1, "rate", 0.1), lua_float(L, true, -1, "nb", 10));
					break;
				default:
					lua_pushliteral(L, "Unknown particles emitter"); lua_error(L);
					break;
			}

			if (lua_bool(L, -1, "dormant", false)) {
				em->setDormant(true);
			}

			
			/** Triggers **/
			lua_pushliteral(L, "triggers");
			lua_rawget(L, -2);
			if (lua_istable(L, -1)) {
				lua_pushnil(L);
				while (lua_next(L, -2) != 0) {
					string name(lua_tostring(L, -2));
					TriggerableKind kind = static_cast<TriggerableKind>((uint8_t)lua_tonumber(L, -1));
					em->triggerOnName(name, kind);
					lua_pop(L, 1);
				}
			}
			lua_pop(L, 1);


			
			/** Events **/
			lua_pushliteral(L, "events");
			lua_rawget(L, -2);
			if (lua_istable(L, -1)) {
				lua_pushnil(L);
				while (lua_next(L, -2) != 0) {
					string name(lua_tostring(L, -2));
					EventKind kind = static_cast<EventKind>((uint8_t)lua_tonumber(L, -1));
					em->defineEvent(e, kind, name);
					lua_pop(L, 1);
				}
			}
			lua_pop(L, 1);


			/** Generators **/
			lua_pushnumber(L, 2);
			lua_rawget(L, -2);
			int nb_generators = lua_objlen(L, -1);
			for (int gi = 1; gi <= nb_generators; gi++) {
				lua_rawgeti(L, -1, gi);
				GeneratorsList g_id = (GeneratorsList)((uint8_t)lua_float(L, -1, 1, 0));
				Generator *g;
				switch (g_id) {
					case GeneratorsList::LifeGenerator:
						g = new LifeGenerator(lua_float(L, true, -1, "min", 0.3), lua_float(L, true, -1, "max", 3));
						break;
					case GeneratorsList::BasicTextureGenerator:
						g = new BasicTextureGenerator();
						break;
					case GeneratorsList::OriginPosGenerator:
						g = new OriginPosGenerator();
						break;
					case GeneratorsList::DiskPosGenerator:
						g = new DiskPosGenerator(lua_float(L, true, -1, "radius", 100));
						g->basePos(lua_float(L, true, -1, "sx", 0), lua_float(L, true, -1, "sy", 0));
						break;
					case GeneratorsList::CirclePosGenerator:
						g = new CirclePosGenerator(lua_float(L, true, -1, "radius", 100), lua_float(L, true, -1, "width", 10));
						g->basePos(lua_float(L, true, -1, "sx", 0), lua_float(L, true, -1, "sy", 0));
						break;
					case GeneratorsList::TrianglePosGenerator:
						g = new TrianglePosGenerator(lua_vec2(L, true, -1, "p1", vec2(0, 0)), lua_vec2(L, true, -1, "p2", vec2(0, 0)), lua_vec2(L, true, -1, "p3", vec2(0, 0)));
						g->basePos(lua_float(L, true, -1, "sx", 0), lua_float(L, true, -1, "sy", 0));
						break;
					case GeneratorsList::LinePosGenerator:
						g = new LinePosGenerator(lua_vec2(L, true, -1, "p1", vec2(0, 0)), lua_vec2(L, true, -1, "p2", vec2(0, 0)));
						g->basePos(lua_float(L, true, -1, "sx", 0), lua_float(L, true, -1, "sy", 0));
						break;
					case GeneratorsList::DiskVelGenerator:
						g = new DiskVelGenerator(lua_float(L, true, -1, "min_vel", 5), lua_float(L, true, -1, "max_vel", 10));
						break;
					case GeneratorsList::DirectionVelGenerator:
						g = new DirectionVelGenerator(lua_vec2(L, true, -1, "from", {0, 0}), lua_float(L, true, -1, "min_vel", 5), lua_float(L, true, -1, "max_vel", 10));
						g->basePos(lua_float(L, true, -1, "sx", 0), lua_float(L, true, -1, "sy", 0));
						break;
					case GeneratorsList::BasicSizeGenerator:
						g = new BasicSizeGenerator(lua_float(L, true, -1, "min_size", 10), lua_float(L, true, -1, "max_size", 30));
						break;
					case GeneratorsList::StartStopSizeGenerator:
						g = new StartStopSizeGenerator(lua_float(L, true, -1, "min_start_size", 10), lua_float(L, true, -1, "max_start_size", 30), lua_float(L, true, -1, "min_stop_size", 1), lua_float(L, true, -1, "max_stop_size", 3));
						break;
					case GeneratorsList::BasicRotationGenerator:
						g = new BasicRotationGenerator(lua_float(L, true, -1, "min_rot", 0), lua_float(L, true, -1, "max_rot", M_PI*2));
						break;
					case GeneratorsList::RotationByVelGenerator:
						g = new RotationByVelGenerator(lua_float(L, true, -1, "min_rot", 0), lua_float(L, true, -1, "max_rot", 0));
						break;
					case GeneratorsList::BasicRotationVelGenerator:
						g = new BasicRotationVelGenerator(lua_float(L, true, -1, "min_rot", 0), lua_float(L, true, -1, "max_rot", M_PI*2));
						break;
					case GeneratorsList::StartStopColorGenerator:
						g = new StartStopColorGenerator(lua_vec4(L, true, -1, "min_color_start", vec4(1, 0, 0, 1)), lua_vec4(L, true, -1, "max_color_start", vec4(0, 1, 0, 1)), lua_vec4(L, true, -1, "min_color_stop", vec4(1, 0, 0, 0)), lua_vec4(L, true, -1, "max_color_stop", vec4(0, 1, 0, 0)));
						break;
					case GeneratorsList::FixedColorGenerator:
						g = new FixedColorGenerator(lua_vec4(L, true, -1, "color_start", vec4(1, 0, 0, 1)), lua_vec4(L, true, -1, "color_stop", vec4(0, 1, 0, 1)));
						break;
					case GeneratorsList::CopyGenerator: {
						System *source_system = e->getRawSystem(lua_float(L, true, -1, "source_system", 1) - 1);
						g = new CopyGenerator(source_system, lua_bool(L, -1, "copy_pos", true), lua_bool(L, -1, "copy_color", true));
						break; }
					default:
						lua_pushliteral(L, "Unknown particles Generator"); lua_error(L);
						break;
				}
				em->addGenerator(sys, g);
				lua_pop(L, 1);
			}
			lua_pop(L, 1);


			sys->addEmitter(em);
			lua_pop(L, 1);
		}
		lua_pop(L, 1);


		/** Updaters **/
		lua_pushliteral(L, "updaters");
		lua_rawget(L, -2);
		int nb_updaters = lua_objlen(L, -1);
		for (int ui = 1; ui <= nb_updaters; ui++) {
			lua_rawgeti(L, -1, ui);
			UpdatersList u_id = (UpdatersList)((uint8_t)lua_float(L, -1, 1, 0));
			Updater *u;
			switch (u_id) {
				case UpdatersList::LinearColorUpdater:
					u = new LinearColorUpdater(lua_bool(L, -1, "bilinear", false));
					break;
				case UpdatersList::EasingColorUpdater: {
					easing_ptr easing = easing::linear;
					const char *easing_str = lua_string(L, -1, "easing", NULL);
					if (easing_str) {
						auto it = easings_map.find(easing_str);
						if (it != easings_map.end()) {
							easing = it->second;
						}
					}
					u = new EasingColorUpdater(lua_bool(L, -1, "bilinear", false), easing);
					break;}
				case UpdatersList::LinearSizeUpdater:
					u = new LinearSizeUpdater();
					break;
				case UpdatersList::EasingSizeUpdater: {
					easing_ptr easing = easing::linear;
					const char *easing_str = lua_string(L, -1, "easing", NULL);
					if (easing_str) {
						auto it = easings_map.find(easing_str);
						if (it != easings_map.end()) {
							easing = it->second;
						}
					}
					u = new EasingSizeUpdater(easing);
					break;}
				case UpdatersList::BasicTimeUpdater:
					u = new BasicTimeUpdater();
					break;
				case UpdatersList::AnimatedTextureUpdater:
					u = new AnimatedTextureUpdater(lua_float(L, true, -1, "splitx", 1), lua_float(L, true, -1, "splity", 1), lua_float(L, true, -1, "firstframe", 0), lua_float(L, true, -1, "lastframe", 0), lua_float(L, true, -1, "repeat_over_life", 1));
					break;
				case UpdatersList::EulerPosUpdater:
					u = new EulerPosUpdater(lua_vec2(L, true, -1, "global_vel", vec2(0, 0)), lua_vec2(L, true, -1, "global_acc", vec2(0, 0)));
					break;
				case UpdatersList::EasingPosUpdater: {
					easing_ptr easing = easing::linear;
					const char *easing_str = lua_string(L, -1, "easing", NULL);
					if (easing_str) {
						auto it = easings_map.find(easing_str);
						if (it != easings_map.end()) {
							easing = it->second;
						}
					}
					u = new EasingPosUpdater(easing);
					break;}
				case UpdatersList::NoisePosUpdater: {
					const char * noise_str = lua_string(L, -1, "noise", NULL);
					spNoiseHolder nh = Ensemble::getNoise(noise_str);
					u = new NoisePosUpdater(nh, lua_vec2(L, true, -1, "amplitude", vec2(5, 5)), lua_float(L, true, -1, "traversal_speed", 400));
					break;}
				case UpdatersList::LinearRotationUpdater:
					u = new LinearRotationUpdater();
					break;
				case UpdatersList::EasingRotationUpdater: {
					easing_ptr easing = easing::linear;
					const char *easing_str = lua_string(L, -1, "easing", NULL);
					if (easing_str) {
						auto it = easings_map.find(easing_str);
						if (it != easings_map.end()) {
							easing = it->second;
						}
					}
					u = new EasingRotationUpdater(easing);
					break;}
				default:
					lua_pushliteral(L, "Unknown particles updater"); lua_error(L);
					break;
			}
			sys->addUpdater(u);
			lua_pop(L, 1);
		}
		lua_pop(L, 1);

		sys->finish();
		e->add(sys);
		lua_pop(L, 1);
	}

	if (!morph) {
		Ensemble **ee = (Ensemble**)lua_newuserdata(L, sizeof(Ensemble*));
		auxiliar_setclass(L, "particles{compose}", -1);
		*ee = e;
	} else {
		DORParticles *pdo = new DORParticles();
		pdo->setParticlesOwn(e);

		DisplayObject **v = (DisplayObject**)lua_newuserdata(L, sizeof(DisplayObject*));
		*v = pdo;
		auxiliar_setclass(L, "gl{particles}", -1);
	}
	return 1;
}

static int p_get_do(lua_State *L)
{
	Ensemble **ee = (Ensemble**)auxiliar_checkclass(L, "particles{compose}", 1);
	if (!lua_istable(L, 2)) {
		lua_pushliteral(L, "2nd argument is not an engine.Particles");
		lua_error(L);
		return 0;
	}

	DORParticles *pdo = new DORParticles();
	lua_pushvalue(L, 2);
	pdo->setParticles(*ee, luaL_ref(L, LUA_REGISTRYINDEX));

	DisplayObject **v = (DisplayObject**)lua_newuserdata(L, sizeof(DisplayObject*));
	*v = pdo;
	auxiliar_setclass(L, "gl{particles}", -1);
	return 1;
}

static const struct luaL_Reg pcompose[] =
{
	{"__gc", p_free},
	{"shift", p_shift},
	{"dead", p_is_dead},
	{"zoom", p_zoom},
	{"speed", p_speed},
	{"trigger", p_trigger},
	{"onEvents", p_events_cb},
	{"countAlive", p_count_alive},
	{"getDO", p_get_do},
	{"toScreen", p_toscreen},
	{NULL, NULL},
};

static const struct luaL_Reg plib[] =
{
	{"gcTextures", p_gc_textures},
	{"defaultShader", p_default_shader},
	{"new", p_new},
	{NULL, NULL},
};

extern "C" int luaopen_particles_system(lua_State *L) {
	auxiliar_newclass(L, "particles{compose}", pcompose);
	luaL_openlib(L, "core.particlescompose", plib, 0);

	// Grab it, used to load from files
	lua_pushvalue(L, -1);
	particles::PC_lua_ref = luaL_ref(L, LUA_REGISTRYINDEX);

	// Make a metatable using math.* as its env, for expression parsing
	lua_newtable(L);
	lua_pushliteral(L, "__index");
	lua_getglobal(L, "math");
	lua_rawset(L, -3);
	particles::math_mt_lua_ref = luaL_ref(L, LUA_REGISTRYINDEX);

	lua_pushliteral(L, "DefaultBlend"); lua_pushnumber(L, static_cast<uint8_t>(RendererBlend::DefaultBlend)); lua_rawset(L, -3);
	lua_pushliteral(L, "AdditiveBlend"); lua_pushnumber(L, static_cast<uint8_t>(RendererBlend::AdditiveBlend)); lua_rawset(L, -3);
	lua_pushliteral(L, "MixedBlend"); lua_pushnumber(L, static_cast<uint8_t>(RendererBlend::MixedBlend)); lua_rawset(L, -3);
	lua_pushliteral(L, "ShinyBlend"); lua_pushnumber(L, static_cast<uint8_t>(RendererBlend::ShinyBlend)); lua_rawset(L, -3);

	lua_pushliteral(L, "LinearEmitter"); lua_pushnumber(L, static_cast<uint8_t>(EmittersList::LinearEmitter)); lua_rawset(L, -3);

	lua_pushliteral(L, "LinearColorUpdater"); lua_pushnumber(L, static_cast<uint8_t>(UpdatersList::LinearColorUpdater)); lua_rawset(L, -3);
	lua_pushliteral(L, "EasingColorUpdater"); lua_pushnumber(L, static_cast<uint8_t>(UpdatersList::EasingColorUpdater)); lua_rawset(L, -3);
	lua_pushliteral(L, "LinearSizeUpdater"); lua_pushnumber(L, static_cast<uint8_t>(UpdatersList::LinearSizeUpdater)); lua_rawset(L, -3);
	lua_pushliteral(L, "EasingSizeUpdater"); lua_pushnumber(L, static_cast<uint8_t>(UpdatersList::EasingSizeUpdater)); lua_rawset(L, -3);
	lua_pushliteral(L, "BasicTimeUpdater"); lua_pushnumber(L, static_cast<uint8_t>(UpdatersList::BasicTimeUpdater)); lua_rawset(L, -3);
	lua_pushliteral(L, "AnimatedTextureUpdater"); lua_pushnumber(L, static_cast<uint8_t>(UpdatersList::AnimatedTextureUpdater)); lua_rawset(L, -3);
	lua_pushliteral(L, "EulerPosUpdater"); lua_pushnumber(L, static_cast<uint8_t>(UpdatersList::EulerPosUpdater)); lua_rawset(L, -3);
	lua_pushliteral(L, "EasingPosUpdater"); lua_pushnumber(L, static_cast<uint8_t>(UpdatersList::EasingPosUpdater)); lua_rawset(L, -3);
	lua_pushliteral(L, "NoisePosUpdater"); lua_pushnumber(L, static_cast<uint8_t>(UpdatersList::NoisePosUpdater)); lua_rawset(L, -3);
	lua_pushliteral(L, "LinearRotationUpdater"); lua_pushnumber(L, static_cast<uint8_t>(UpdatersList::LinearRotationUpdater)); lua_rawset(L, -3);
	lua_pushliteral(L, "EasingRotationUpdater"); lua_pushnumber(L, static_cast<uint8_t>(UpdatersList::EasingRotationUpdater)); lua_rawset(L, -3);

	lua_pushliteral(L, "LifeGenerator"); lua_pushnumber(L, static_cast<uint8_t>(GeneratorsList::LifeGenerator)); lua_rawset(L, -3);
	lua_pushliteral(L, "BasicTextureGenerator"); lua_pushnumber(L, static_cast<uint8_t>(GeneratorsList::BasicTextureGenerator)); lua_rawset(L, -3);
	lua_pushliteral(L, "OriginPosGenerator"); lua_pushnumber(L, static_cast<uint8_t>(GeneratorsList::OriginPosGenerator)); lua_rawset(L, -3);
	lua_pushliteral(L, "DiskPosGenerator"); lua_pushnumber(L, static_cast<uint8_t>(GeneratorsList::DiskPosGenerator)); lua_rawset(L, -3);
	lua_pushliteral(L, "CirclePosGenerator"); lua_pushnumber(L, static_cast<uint8_t>(GeneratorsList::CirclePosGenerator)); lua_rawset(L, -3);
	lua_pushliteral(L, "TrianglePosGenerator"); lua_pushnumber(L, static_cast<uint8_t>(GeneratorsList::TrianglePosGenerator)); lua_rawset(L, -3);
	lua_pushliteral(L, "LinePosGenerator"); lua_pushnumber(L, static_cast<uint8_t>(GeneratorsList::LinePosGenerator)); lua_rawset(L, -3);
	lua_pushliteral(L, "DiskVelGenerator"); lua_pushnumber(L, static_cast<uint8_t>(GeneratorsList::DiskVelGenerator)); lua_rawset(L, -3);
	lua_pushliteral(L, "DirectionVelGenerator"); lua_pushnumber(L, static_cast<uint8_t>(GeneratorsList::DirectionVelGenerator)); lua_rawset(L, -3);
	lua_pushliteral(L, "BasicSizeGenerator"); lua_pushnumber(L, static_cast<uint8_t>(GeneratorsList::BasicSizeGenerator)); lua_rawset(L, -3);
	lua_pushliteral(L, "StartStopSizeGenerator"); lua_pushnumber(L, static_cast<uint8_t>(GeneratorsList::StartStopSizeGenerator)); lua_rawset(L, -3);
	lua_pushliteral(L, "BasicRotationGenerator"); lua_pushnumber(L, static_cast<uint8_t>(GeneratorsList::BasicRotationGenerator)); lua_rawset(L, -3);
	lua_pushliteral(L, "RotationByVelGenerator"); lua_pushnumber(L, static_cast<uint8_t>(GeneratorsList::RotationByVelGenerator)); lua_rawset(L, -3);
	lua_pushliteral(L, "BasicRotationVelGenerator"); lua_pushnumber(L, static_cast<uint8_t>(GeneratorsList::BasicRotationVelGenerator)); lua_rawset(L, -3);
	lua_pushliteral(L, "StartStopColorGenerator"); lua_pushnumber(L, static_cast<uint8_t>(GeneratorsList::StartStopColorGenerator)); lua_rawset(L, -3);
	lua_pushliteral(L, "FixedColorGenerator"); lua_pushnumber(L, static_cast<uint8_t>(GeneratorsList::FixedColorGenerator)); lua_rawset(L, -3);
	lua_pushliteral(L, "CopyGenerator"); lua_pushnumber(L, static_cast<uint8_t>(GeneratorsList::CopyGenerator)); lua_rawset(L, -3);

	lua_pushliteral(L, "TriggerDELETE"); lua_pushnumber(L, static_cast<uint8_t>(TriggerableKind::DESTROY)); lua_rawset(L, -3);
	lua_pushliteral(L, "TriggerWAKEUP"); lua_pushnumber(L, static_cast<uint8_t>(TriggerableKind::WAKEUP)); lua_rawset(L, -3);
	lua_pushliteral(L, "TriggerFORCE"); lua_pushnumber(L, static_cast<uint8_t>(TriggerableKind::FORCE)); lua_rawset(L, -3);

	lua_pushliteral(L, "EventSTART"); lua_pushnumber(L, static_cast<uint8_t>(EventKind::START)); lua_rawset(L, -3);
	lua_pushliteral(L, "EventEMIT"); lua_pushnumber(L, static_cast<uint8_t>(EventKind::EMIT)); lua_rawset(L, -3);
	lua_pushliteral(L, "EventSTOP"); lua_pushnumber(L, static_cast<uint8_t>(EventKind::STOP)); lua_rawset(L, -3);

	lua_settop(L, 0);
	return 1;
}

extern "C" void lua_particles_system_clean() {
	Ensemble::gcTextures();
}
