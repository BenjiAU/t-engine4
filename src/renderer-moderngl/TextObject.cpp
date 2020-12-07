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
#include "lauxlib.h"
#include "display.h"
#include "types.h"
#include "physfs.h"
#include "physfsrwops.h"
#include "main.h"
#include "utf8proc/utf8proc.h"
}
#include <cctype>

#include "renderer-moderngl/Renderer.hpp"
#include "renderer-moderngl/TextObject.hpp"
#include "colors.hpp"

shader_type *DORText::default_shader = NULL;
float DORText::default_outline = 0;
vec4 DORText::default_outline_color = vec4(0, 0, 0, 1);

void DORText::cloneInto(DisplayObject* _into) {
	DisplayObject::cloneInto(_into);
	DORText *into = dynamic_cast<DORText*>(_into);

	// Clone reference
	if (L && font_lua_ref) {
		lua_rawgeti(L, LUA_REGISTRYINDEX, font_lua_ref);
		into->font_lua_ref = luaL_ref(L, LUA_REGISTRYINDEX);
	}

	into->shader = shader;
	into->font = font;
	into->font_color = font_color;
	into->line_max_width = line_max_width;
	into->max_lines = max_lines;
	into->no_linefeed = no_linefeed;
	into->setText(text);
}

void DORText::setShader(shader_type *s) {
	shader = s ? s : nullptr;
}

void DORText::setFrom(DORText *prev) {
	font_color = prev->used_color;
	font_last_color = prev->used_last_color;
	default_style = prev->used_font_style;
}

void DORText::setTextStyle(font_style style) {
	default_style = style;
	used_font_style = style;
	parseText();
}
void DORText::setTextColor(float r, float g, float b, float a) {
	font_color.r = r; font_color.g = g; font_color.b = b; font_color.a = a;
	font_last_color.r = r; font_last_color.g = g; font_last_color.b = b; font_last_color.a = a;
	used_color = font_color;
	used_last_color = font_last_color;
	parseText();
}
void DORText::setTextSmallCaps(bool v) {
	small_caps = v;
	parseText();
}

int DORText::addCharQuad(const char *str, size_t len, font_style style, int bx, int by, float r, float g, float b, float a) {
	int x = 0, y = by;
	ssize_t off = 1;
	int32_t c;
	float italic = 0;
	float base_scale = font->scale;
	if (style == FONT_STYLE_ITALIC) { style = FONT_STYLE_NORMAL; italic = 0.3; }
	while (off > 0) {
		off = utf8proc_iterate((const uint8_t*)str, len, &c);
		str += off;
		len -= off;
		float scale = base_scale;
		if (small_caps) {
			if (!isupper(c)) {
				scale *= 0.75;
				c = toupper(c);
			}
		}

		// font->kind->font->outline_thickness = 0;
		// font->kind->font->rendermode = ftgl::RENDER_SIGNED_DISTANCE_FIELD;
		auto dr = font->kind->getGlyph(c);
		auto d = get<0>(dr);
		if (d) {
			float kerning = 0;
			if (last_glyph) {
				kerning = texture_glyph_get_kerning(d, last_glyph) * scale;
			}
			x += texture_glyph_get_kerning(d, last_glyph) * scale;
			last_glyph = c;

		        // printf("Glyph: %c : %f + %f : %d : %d\n", c, kerning, d->advance_x, d->offset_x, d->width);
			
			float x0  = bx + x + d->offset_x * scale;
			float x1  = x0 + d->width * scale;
			float italicx = d->advance_x * scale * italic;
			float y0 = by + (font->kind->font->ascender - d->offset_y) * scale + d->height * (base_scale - scale);
			float y1 = y0 + (d->height) * scale;
			positions.push_back({x0, y});

			if (shadow_x || shadow_y) {
				float mode = (style == FONT_STYLE_BOLD ? 1.0f : 0.0f);
				auto &rc = getRenderTable(TextLayer::BACK, get<1>(dr));
				rc.push_back({{shadow_x+x0, shadow_y+y0}, {shadow_x+x1, shadow_y+y1}, italicx, {d->s0, d->t0}, {d->s1, d->t1}, shadow_color, mode});
			}

			// Much trickery, such dev
			if (style == FONT_STYLE_UNDERLINED) {
				auto ulr = font->kind->getGlyph('_');
				auto ul = get<0>(ulr);
				if (ul) {

					if (outline) {
						font->kind->font->outline_thickness = 2;
						font->kind->font->rendermode = ftgl::RENDER_OUTLINE_EDGE;
						auto doutliner = font->kind->getGlyph('_');
						auto doutline = get<0>(doutliner);
						if (doutline) {
							float x0  = bx + x;
							float x1  = x0 + d->advance_x * scale;
							float y0 = by + (font->kind->font->ascender * 1.05 - doutline->offset_y) * scale;
							float y1 = y0 + (doutline->height) * scale;
							float s2 = (doutline->s1 - doutline->s0) / 1.5;

							float mode = (style == FONT_STYLE_BOLD ? 3.0f : 2.0f);
							auto &rc = getRenderTable(TextLayer::BACK, get<1>(doutliner));
							rc.push_back({{x0, y0}, {x1, y1}, italicx, {doutline->s0 + s2, doutline->t0}, {doutline->s1 - s2, doutline->t1}, outline_color, mode});
						}
						font->kind->font->outline_thickness = 0;
						font->kind->font->rendermode = ftgl::RENDER_SIGNED_DISTANCE_FIELD;
					}

					float x0  = bx + x;
					float x1  = x0 + d->advance_x * scale;
					float y0 = by + (font->kind->font->ascender * 1.05 - ul->offset_y) * scale;
					float y1 = y0 + (ul->height) * scale;
					float s2 = (ul->s1 - ul->s0) / 1.5;
					auto &rc = getRenderTable(TextLayer::FRONT, get<1>(ulr));
					rc.push_back({{x0, y0}, {x1, y1}, italicx, {ul->s0 + s2, ul->t0}, {ul->s1 - s2, ul->t1}, {r, g, b, a}, style == FONT_STYLE_BOLD ? 1.0f : 0.0f});
				}
			}			

			if (outline) {
				font->kind->font->outline_thickness = 2;
				font->kind->font->rendermode = ftgl::RENDER_OUTLINE_EDGE;
				auto doutliner = font->kind->getGlyph(c);
				auto doutline = get<0>(doutliner);
				if (doutline) {
					float x0  = bx + x + doutline->offset_x * scale;
					float x1  = x0 + doutline->width * scale;
					float italicx = doutline->advance_x * scale * italic;
					float y0 = by + (font->kind->font->ascender - doutline->offset_y) * scale + d->height * (base_scale - scale);
					float y1 = y0 + (doutline->height) * scale;

					float mode = (style == FONT_STYLE_BOLD ? 3.0f : 2.0f);
					auto &rc = getRenderTable(TextLayer::BACK, get<1>(doutliner));
					rc.push_back({{x0, y0}, {x1, y1}, italicx, {doutline->s0, doutline->t0}, {doutline->s1, doutline->t1}, outline_color, mode});
				}
				font->kind->font->outline_thickness = 0;
				font->kind->font->rendermode = ftgl::RENDER_SIGNED_DISTANCE_FIELD;
			}

			float mode = (style == FONT_STYLE_BOLD ? 1.0f : 0.0f);
			auto &rc = getRenderTable(TextLayer::FRONT, get<1>(dr));
			rc.push_back({{x0, y0}, {x1, y1}, italicx, {d->s0, d->t0}, {d->s1, d->t1}, {r, g, b, a}, mode});

			x += d->advance_x * scale;
			// if (style == FONT_STYLE_BOLD) x += d->width * scale * 0.1;
		}
	}
	return x;
}

void DORText::parseText() {
	clear();
	centered = false;
	setChanged(true);

	// printf("-- '%s'\n", text);
	// printf("==CUREC  %fx%fx%fx%f\n", font_color.r, font_color.g, font_color.b, font_color.a);
	// printf("==USEDC  %fx%fx%fx%f\n", used_color.r, used_color.g, used_color.b, used_color.a);


	if (!font) return;
	
	size_t len = strlen(text);
	if (!len) {
		used_color = font_color;
		used_last_color = font_last_color;
		used_font_style = default_style;
		return;
	}
	const char *str = text;
	float r = font_color.r, g = font_color.g, b = font_color.b, a = font_color.a;
	float lr = font_last_color.r, lg = font_last_color.g, lb = font_last_color.b, la = font_last_color.a;
	int max_width = line_max_width;
	int bx = 0, by = 0;

	int font_h = font->getHeight();
	int nb_lines = 1;
	int id_real_line = 1;
	char *line_data = NULL;
	int line_data_size = 0;
	char *start = (char*)str, *stop = (char*)str, *next = (char*)str;
	int max_size = 0;
	int size = 0;
	bool is_separator = false;
	int i;
	bool force_nl = false;
	font_style style = default_style;

	last_glyph = 0;

	// DGDGDGDG: handle draw_string_split_anywhere for I18N needs

	while (true)
	{
		if ((*next == '\n') || (*next == ' ') || (*next == '\0') || (*next == '#'))
		{
			bool inced = false;
			if (*next == ' ' && *(next+1))
			{
				inced = true;
				stop = next;
				next++;
			}
			else stop = next - 1;

			// Make a surface for the word
			int len = next - start;
			int future_size = (font->textSize(start, len, style)).x;

			// If we must do a newline, flush the previous word and the start the new line
			if (!no_linefeed && (force_nl || (future_size && max_width && (size + future_size > max_width))))
			{
				if (size > max_size) max_size = size;
				size = 0;
				last_glyph = 0;

				// Stop?
				if (nb_lines >= max_lines) break;

				// Push it & reset the surface
				is_separator = false;
//				printf("Ending previous line at size %d\n", size);
				nb_lines++;
				if (force_nl)
				{
					id_real_line++;
					if (line_data) { line_data = NULL; }
				}
				force_nl = false;
			}

			if (len)
			{
				// Detect separators
				if ((*start == '-') && (*(start+1) == '-') && (*(start+2) == '-') && !(*(start+3))) is_separator = true;

//				printf("Drawing word '%s'\n", start);
				size += addCharQuad(start, len, style, bx + size, by + (nb_lines-1) * font_h, r, g, b, a);
			}
			if (inced) next--;
			start = next + 1;

			// Force a linefeed
			if (*next == '\n') force_nl = true;

			// Handle special codes
			else if (*next == '#')
			{
				char *codestop = next + 1;
				while (*codestop && *codestop != '#') codestop++;
				// Font style
				if (*(next+1) == '{') {
					if (*(next+2) == 'n') style = FONT_STYLE_NORMAL;
					else if (*(next+2) == 'b') style = FONT_STYLE_BOLD;
					else if (*(next+2) == 'i') style = FONT_STYLE_ITALIC;
					else if (*(next+2) == 'u') style = FONT_STYLE_UNDERLINED;
				}
				// Entity UID
				else if ((codestop - (next+1) > 4) && (*(next+1) == 'U') && (*(next+2) == 'I') && (*(next+3) == 'D') && (*(next+4) == ':')) {
					// Grab the entity
					lua_getglobal(L, "__get_uid_entity");
					char *colon = next + 5;
					while (*colon && *colon != ':') colon++;
					lua_pushlstring(L, next+5, colon - (next+5));
					lua_call(L, 1, 1);
					if (lua_istable(L, -1))
					{
						// Grab the method
						lua_pushliteral(L, "getEntityDisplayObject");
						lua_gettable(L, -2);
						// Add parameters
						lua_pushvalue(L, -2);
						lua_pushnil(L);
						lua_pushnumber(L, font_h);
						lua_pushnumber(L, font_h);
						lua_pushboolean(L, false);
						lua_pushboolean(L, false);
						// Call method to get the DO
						lua_call(L, 6, 1);

						DisplayObject *c = userdata_to_DO(L, -1);
						if (c) {
							entities_container_refs.push_back(luaL_ref(L, LUA_REGISTRYINDEX));
							c->translate(bx + size, by + (nb_lines-1) * font_h, -1, false);
							entities_container.add(c);
						} else {
							lua_pop(L, 1);
						}
						size += font_h;
					}
					lua_pop(L, 1);
				}
				// Extra data
				else if (*(next+1) == '&') {
					line_data = next + 2;
					line_data_size = codestop - (next+2);
				}
				// Color
				else {
					if ((codestop - (next+1) == 4) && (*(next+1) == 'L') && (*(next+2) == 'A') && (*(next+3) == 'S') && (*(next+4) == 'T'))
					{
						r = lr;
						g = lg;
						b = lb;
						a = la;
						goto endcolor;
					}

					string cname(next+1, (size_t)(codestop - (next+1)));
					Color *color = Color::find(cname);
					if (color) {
						vec4 rgba = color->get1();
						lr = r; lg = g; lb = b; la = a;
						r = rgba.r; g = rgba.g; b = rgba.b; a = rgba.a;
					// Hexacolor
					} else if (codestop - (next+1) == 6) {
						lr = r;
						lg = g;
						lb = b;
						la = a;

						int rh = 0, gh = 0, bh = 0;

						if ((*(next+1) >= '0') && (*(next+1) <= '9')) rh += 16 * (*(next+1) - '0');
						else if ((*(next+1) >= 'a') && (*(next+1) <= 'f')) rh += 16 * (10 + *(next+1) - 'a');
						else if ((*(next+1) >= 'A') && (*(next+1) <= 'F')) rh += 16 * (10 + *(next+1) - 'A');
						if ((*(next+2) >= '0') && (*(next+2) <= '9')) rh += (*(next+2) - '0');
						else if ((*(next+2) >= 'a') && (*(next+2) <= 'f')) rh += (10 + *(next+2) - 'a');
						else if ((*(next+2) >= 'A') && (*(next+2) <= 'F')) rh += (10 + *(next+2) - 'A');

						if ((*(next+3) >= '0') && (*(next+3) <= '9')) gh += 16 * (*(next+3) - '0');
						else if ((*(next+3) >= 'a') && (*(next+3) <= 'f')) gh += 16 * (10 + *(next+3) - 'a');
						else if ((*(next+3) >= 'A') && (*(next+3) <= 'F')) gh += 16 * (10 + *(next+3) - 'A');
						if ((*(next+4) >= '0') && (*(next+4) <= '9')) gh += (*(next+4) - '0');
						else if ((*(next+4) >= 'a') && (*(next+4) <= 'f')) gh += (10 + *(next+4) - 'a');
						else if ((*(next+4) >= 'A') && (*(next+4) <= 'F')) gh += (10 + *(next+4) - 'A');

						if ((*(next+5) >= '0') && (*(next+5) <= '9')) bh += 16 * (*(next+5) - '0');
						else if ((*(next+5) >= 'a') && (*(next+5) <= 'f')) bh += 16 * (10 + *(next+5) - 'a');
						else if ((*(next+5) >= 'A') && (*(next+5) <= 'F')) bh += 16 * (10 + *(next+5) - 'A');
						if ((*(next+6) >= '0') && (*(next+6) <= '9')) bh += (*(next+6) - '0');
						else if ((*(next+6) >= 'a') && (*(next+6) <= 'f')) bh += (10 + *(next+6) - 'a');
						else if ((*(next+6) >= 'A') && (*(next+6) <= 'F')) bh += (10 + *(next+6) - 'A');

						r = (float)rh / 255;
						g = (float)gh / 255;
						b = (float)bh / 255;
						a = 1;
					}
				}
endcolor:

				char old = *codestop;
				*codestop = '\0';
//				printf("Found code: %s\n", next+1);
				*codestop = old;

				start = codestop + 1;
				next = codestop; // The while will increment it, so we dont so it here
			}
		}
		if (*next == '\0') break;
		next++;
	}

	if (size > max_size) max_size = size;

	used_font_style = style;
	used_color = vec4(r, g, b, a);
	used_last_color = vec4(lr, lg, lb, la);

	this->nb_lines = nb_lines;
	this->w = max_size;
	this->h = nb_lines * font_h;

	checkSortability(); // Check if we start and end with the same texture
	font->kind->updateAtlas(); // Make sure any texture changes are upload to the GPU
}

void DORText::parseTextSimple() {
	clear();
	centered = false;
	setChanged(true);

	if (!font) return;
	size_t len = strlen(text);
	if (!len) return;
	const char *str = text;
	float r = font_color.r, g = font_color.g, b = font_color.b, a = font_color.a;

	int font_h = font->getHeight();
	this->w = addCharQuad(str, len, default_style, 0, 0, r, g, b, a);
	this->nb_lines = 1;
	this->h = font_h;

	checkSortability(); // Check if we start and end with the same texture
	font->kind->updateAtlas(); // Make sure any texture changes are upload to the GPU
}

void DORText::setText(const char *text, bool simple) {
	// text = "je suis un lon#BLUE#text loli\n loz #{italic}#AHAH plop je suis un lon#BLUE#text loli\n loz #{italic}#AHAH plop je suis un lon#BLUE#text loli\n loz #{italic}#AHAH plop je suis un lon#BLUE#text loli\n loz #{italic}#AHAH plop je suis un lon#BLUE#text loli\n loz #{italic}#AHAH plop je suis un lon#BLUE#text loli\n loz #{italic}#AHAH plop ";
	// ProfilerStart("nameOfProfile.log");
	// for (int i = 0; i < 10000; i++) {

	free((void*)this->text);
	size_t len = strlen(text);
	this->text = (char*)malloc(len + 1);
	strcpy(this->text, text);
	if (simple) parseTextSimple();
	else parseText();
	
	// }
	// ProfilerStop();
	// exit(0);
}

void DORText::center() {
	if (!w || !h) return;
	if (centered) return;
	centered = true;
	
	// We dont use translate() to now make other translate fail, we move the actual center
	float hw = w / 2, hh = h / 2;
	for (auto &layer : rendered_chars) { 
		for (auto &rc : layer) { 
			for (auto &it : rc) {
				it.p0.x -= hw;
				it.p0.y -= hh;
				it.p1.x -= hw;
				it.p1.y -= hh;
			}
		}
	}
	entities_container.translate(-hw, -hh, (float)0, false);
	setChanged();
}

vec2 DORText::getLetterPosition(int idx) {
	idx = idx - 1;
	if (positions.empty() || idx < 0) return {0, 0};
	if (idx > positions.size()) idx = positions.size();
	return positions[idx];
}

void DORText::clear() {
	setChanged();
	entities_container.clear();
	for (auto ref : entities_container_refs) {
		refcleaner(&ref);
	}
	entities_container_refs.clear();
	positions.clear();
	for (auto &rc : rendered_chars) rc.clear();
}

void DORText::render(RendererGL *container, mat4& cur_model, vec4& cur_color, bool cur_visible) {
	if (!visible || !cur_visible) return;
	mat4 vmodel = cur_model * model;
	vec4 vcolor = cur_color * color;

	for (auto &layer : rendered_chars) { 
		uint8_t id = 0;
		for (auto &rc : layer) { 
			if (rc.size()) {
				auto dl = getDisplayList(container, font->kind->getAtlasTexture(id), shader, VERTEX_BASE + VERTEX_KIND_INFO, RenderKind::QUADS);

				// Make sure we do not have to reallocate each step
				int nb = rc.size() * 4;
				int startat = dl->list.size();
				dl->list.reserve(startat + nb);
				dl->list_kind_info.reserve(startat + nb);

				for (auto &c : rc) {
					vec4 color = vcolor * c.color;
					vec4 p0(c.p0.x + c.italicx, c.p0.y, 0, 1);
					vec4 p1(c.p1.x + c.italicx, c.p0.y, 0, 1);
					vec4 p2(c.p1.x, 	    c.p1.y, 0, 1);
					vec4 p3(c.p0.x, 	    c.p1.y, 0, 1);
					// printf("==== char: %fx%f : %fx%f ::: %fx%f : %fx%f ::: %f, %f, %f, %f ::: %f\n", c.p0.x, c.p0.y, c.p1.x, c.p1.y, c.tex0.x, c.tex0.y, c.tex1.x, c.tex1.y, color.r, color.g, color.b, color.a, c.mode);

					dl->list.push_back({vmodel * p0, {c.tex0.x, c.tex0.y}, color});
					dl->list.push_back({vmodel * p1, {c.tex1.x, c.tex0.y}, color});
					dl->list.push_back({vmodel * p2, {c.tex1.x, c.tex1.y}, color});
					dl->list.push_back({vmodel * p3, {c.tex0.x, c.tex1.y}, color});
					dl->list_kind_info.push_back({c.mode});
					dl->list_kind_info.push_back({c.mode});
					dl->list_kind_info.push_back({c.mode});
					dl->list_kind_info.push_back({c.mode});
				}
			}
			id++;
		}
	}

	resetChanged();

	// Add the sub entities we need to display
	entities_container.render(container, vmodel, vcolor, true);
}

void DORText::sortCoords(RendererGL *container, mat4& cur_model) {
	mat4 vmodel = cur_model * model;

	sort_coords = vmodel * sort_center;
	sort_shader = shader;
	if (is_sortable > -1) {
		sort_tex = font->kind->atlas[is_sortable]->id;
	} else {
		sort_tex = 0;
	}
	container->sorted_dos.push_back(this);
}

DORText::DORText() : rendered_chars(2) { // Init rendered_chars to 2 size for TextLayer BACK & FRONT
	text = (char*)malloc(1);
	text[0] = '\0';
	font_color = {1, 1, 1, 1};
	entities_container.setParent(this);
	if (default_shader) setShader(default_shader);
	setOutline(default_outline, default_outline_color);
};

DORText::~DORText() {
	free((void*)text);
	refcleaner(&font_lua_ref);
	for (auto ref : entities_container_refs) {
		refcleaner(&ref);
	}
};
