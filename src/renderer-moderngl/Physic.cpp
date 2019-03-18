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

#include "display.hpp"
extern "C" {
#include "lua.h"
#include "lauxlib.h"
#include "types.h"
#include "physfs.h"
#include "physfsrwops.h"
#include "main.h"
}

#include "renderer-moderngl/Physic.hpp"

/*************************************************************************
 ** Debug
 *************************************************************************/
extern int gl_tex_white;
class WorldDebug : public b2Draw, public RendererGL {
public:
	WorldDebug() : RendererGL(VBOMode::STREAM) {
		char *name = strdup("world debug renderer");
		setRendererName(name, false);
		setManualManagement(true);
		SetFlags(e_shapeBit | e_jointBit | e_aabbBit | e_pairBit | e_centerOfMassBit);
	}

	void resetDebug() {
		resetDisplayLists();
		setChanged(true);
	}

	/// Draw a closed polygon provided in CCW order.
	virtual void DrawPolygon(const b2Vec2* vertices, int32 vertexCount, const b2Color& color) {
		for (int32 i = 1; i <= vertexCount; i++) {
			const b2Vec2 *p1 = &vertices[i-1];
			const b2Vec2 *p2 = &vertices[(i == vertexCount) ? 0 : i];

			float p1x = p1->x * PhysicSimulator::unit_scale; float p1y = -p1->y * PhysicSimulator::unit_scale;
			float p2x = p2->x * PhysicSimulator::unit_scale; float p2y = -p2->y * PhysicSimulator::unit_scale;

			auto dl = getDisplayList(this, {(GLuint)gl_tex_white, 0, 0}, NULL, VERTEX_MAP_INFO, RenderKind::LINES);
			dl->list.push_back({{p1x, p1y, 0, 1}, {0, 0}, {color.r, color.g, color.b, color.a}});
			dl->list.push_back({{p2x, p2y, 0, 1}, {0, 0}, {color.r, color.g, color.b, color.a}});
		}
	}

	/// Draw a solid closed polygon provided in CCW order.
	virtual void DrawSolidPolygon(const b2Vec2* vertices, int32 vertexCount, const b2Color& color) {
		for (int32 i = 1; i < vertexCount - 1; ++i)
		{
			float p1x = vertices[0  ].x * PhysicSimulator::unit_scale; float p1y = -vertices[0  ].y * PhysicSimulator::unit_scale;
			float p2x = vertices[i  ].x * PhysicSimulator::unit_scale; float p2y = -vertices[i  ].y * PhysicSimulator::unit_scale;
			float p3x = vertices[i+1].x * PhysicSimulator::unit_scale; float p3y = -vertices[i+1].y * PhysicSimulator::unit_scale;

			auto dl = getDisplayList(this, {(GLuint)gl_tex_white, 0, 0}, NULL, VERTEX_MAP_INFO, RenderKind::TRIANGLES);
			dl->list.push_back({{p1x, p1y, 0, 1}, {0, 0}, {color.r, color.g, color.b, color.a * 0.7}});
			dl->list.push_back({{p2x, p2y, 0, 1}, {0, 0}, {color.r, color.g, color.b, color.a * 0.7}});
			dl->list.push_back({{p3x, p3y, 0, 1}, {0, 0}, {color.r, color.g, color.b, color.a * 0.7}});
		}

		for (int32 i = 1; i <= vertexCount; i++) {
			const b2Vec2 *p1 = &vertices[i-1];
			const b2Vec2 *p2 = &vertices[(i == vertexCount) ? 0 : i];

			float p1x = p1->x * PhysicSimulator::unit_scale; float p1y = -p1->y * PhysicSimulator::unit_scale;
			float p2x = p2->x * PhysicSimulator::unit_scale; float p2y = -p2->y * PhysicSimulator::unit_scale;

			auto dl = getDisplayList(this, {(GLuint)gl_tex_white, 0, 0}, NULL, VERTEX_MAP_INFO, RenderKind::LINES);
			dl->list.push_back({{p1x, p1y, 0, 1}, {0, 0}, {color.r, color.g, color.b, color.a}});
			dl->list.push_back({{p2x, p2y, 0, 1}, {0, 0}, {color.r, color.g, color.b, color.a}});
		}
	}

	/// Draw a circle.
	virtual void DrawCircle(const b2Vec2& _center, float32 radius, const b2Color& color) {
		b2Vec2 center(_center.x * PhysicSimulator::unit_scale, -_center.y * PhysicSimulator::unit_scale);
		radius *= PhysicSimulator::unit_scale;
		const float32 k_segments = 16.0f;
		const float32 k_increment = 2.0f * b2_pi / k_segments;
		float32 sinInc = sinf(k_increment);
		float32 cosInc = cosf(k_increment);
		b2Vec2 r1(1.0f, 0.0f);
		b2Vec2 v1 = center + radius * r1;
		auto dl = getDisplayList(this, {(GLuint)gl_tex_white, 0, 0}, NULL, VERTEX_MAP_INFO, RenderKind::LINES);
		for (int32 i = 0; i < k_segments; ++i)
		{
			// Perform rotation to avoid additional trigonometry.
			b2Vec2 r2;
			r2.x = cosInc * r1.x - sinInc * r1.y;
			r2.y = sinInc * r1.x + cosInc * r1.y;
			b2Vec2 v2 = center + radius * r2;
			dl->list.push_back({{v1.x, v1.y, 0, 1}, {0, 0}, {color.r, color.g, color.b, color.a}});
			dl->list.push_back({{v2.x, v2.y, 0, 1}, {0, 0}, {color.r, color.g, color.b, color.a}});
			r1 = r2;
			v1 = v2;
		}
	}
	
	/// Draw a solid circle.
	virtual void DrawSolidCircle(const b2Vec2& _center, float32 radius, const b2Vec2& axis, const b2Color& color) {
		b2Vec2 center(_center.x * PhysicSimulator::unit_scale, -_center.y * PhysicSimulator::unit_scale);
		radius *= PhysicSimulator::unit_scale;
		const float32 k_segments = 16.0f;
		const float32 k_increment = 2.0f * b2_pi / k_segments;
		float32 sinInc = sinf(k_increment);
		float32 cosInc = cosf(k_increment);
		b2Vec2 r1(1.0f, 0.0f);
		b2Vec2 v1 = center + radius * r1;
		b2Vec2 v0 = center;

		auto dl = getDisplayList(this, {(GLuint)gl_tex_white, 0, 0}, NULL, VERTEX_MAP_INFO, RenderKind::TRIANGLES);
		for (int32 i = 0; i < k_segments; ++i)
		{
			// Perform rotation to avoid additional trigonometry.
			b2Vec2 r2;
			r2.x = cosInc * r1.x - sinInc * r1.y;
			r2.y = sinInc * r1.x + cosInc * r1.y;
			b2Vec2 v2 = center + radius * r2;
			dl->list.push_back({{v0.x, v0.y, 0, 1}, {0, 0}, {color.r, color.g, color.b, color.a * 0.7}});
			dl->list.push_back({{v1.x, v1.y, 0, 1}, {0, 0}, {color.r, color.g, color.b, color.a * 0.7}});
			dl->list.push_back({{v2.x, v2.y, 0, 1}, {0, 0}, {color.r, color.g, color.b, color.a * 0.7}});
			r1 = r2;
			v1 = v2;
		}

		r1.Set(1.0f, 0.0f);
		v1 = center + radius * r1;
		dl = getDisplayList(this, {(GLuint)gl_tex_white, 0, 0}, NULL, VERTEX_MAP_INFO, RenderKind::LINES);
		for (int32 i = 0; i < k_segments; ++i)
		{
			// Perform rotation to avoid additional trigonometry.
			b2Vec2 r2;
			r2.x = cosInc * r1.x - sinInc * r1.y;
			r2.y = sinInc * r1.x + cosInc * r1.y;
			b2Vec2 v2 = center + radius * r2;
			dl->list.push_back({{v1.x, v1.y, 0, 1}, {0, 0}, {color.r, color.g, color.b, color.a}});
			dl->list.push_back({{v2.x, v2.y, 0, 1}, {0, 0}, {color.r, color.g, color.b, color.a}});
			r1 = r2;
			v1 = v2;
		}
	}
	
	/// Draw a line segment.
	virtual void DrawSegment(const b2Vec2& p1, const b2Vec2& p2, const b2Color& color) {
		float p1x = p1.x * PhysicSimulator::unit_scale; float p1y = -p1.y * PhysicSimulator::unit_scale;
		float p2x = p2.x * PhysicSimulator::unit_scale; float p2y = -p2.y * PhysicSimulator::unit_scale;

		auto dl = getDisplayList(this, {(GLuint)gl_tex_white, 0, 0}, NULL, VERTEX_MAP_INFO, RenderKind::LINES);
		dl->list.push_back({{p1x, p1y, 0, 1}, {0, 0}, {color.r, color.g, color.b, color.a}});
		dl->list.push_back({{p2x, p2y, 0, 1}, {0, 0}, {color.r, color.g, color.b, color.a}});
	}

	/// Draw a transform. Choose your own length scale.
	/// @param xf a transform.
	virtual void DrawTransform(const b2Transform& xf) {
		const float32 k_axisScale = 0.4f * PhysicSimulator::unit_scale;
		b2Color red(1.0f, 0.0f, 0.0f);
		b2Color green(0.0f, 1.0f, 0.0f);
		b2Vec2 p1(xf.p.x * PhysicSimulator::unit_scale, -xf.p.y * PhysicSimulator::unit_scale);
		b2Vec2 p2;

		auto dl = getDisplayList(this, {(GLuint)gl_tex_white, 0, 0}, NULL, VERTEX_MAP_INFO, RenderKind::LINES);
		dl->list.push_back({{p1.x, p1.y, 0, 1}, {0, 0}, {red.r, red.g, red.b, 1.0}});
		p2 = p1 + k_axisScale * xf.q.GetXAxis();
		dl->list.push_back({{p2.x, p2.y, 0, 1}, {0, 0}, {red.r, red.g, red.b, 1.0}});

		dl->list.push_back({{p1.x, p1.y, 0, 1}, {0, 0}, {green.r, green.g, green.b, 1.0}});
		p2 = p1 + k_axisScale * xf.q.GetYAxis();
		dl->list.push_back({{p2.x, p2.y, 0, 1}, {0, 0}, {green.r, green.g, green.b, 1.0}});
	}

	/// Draw a point.
	virtual void DrawPoint(const b2Vec2& p, float32 size, const b2Color& color) {
		float px = p.x * PhysicSimulator::unit_scale, py = -p.y * PhysicSimulator::unit_scale;
		size *= PhysicSimulator::unit_scale;
		auto dl = getDisplayList(this, {(GLuint)gl_tex_white, 0, 0}, NULL, VERTEX_MAP_INFO, RenderKind::POINTS);
		dl->list.push_back({{px, py, 0, 1}, {0, 0}, {color.r, color.g, color.b, color.a}});
	}
};

/*************************************************************************
 ** DORPhysic
 *************************************************************************/
static int physic_obj_count = 0;
DORPhysic::DORPhysic(DisplayObject *d) {
	physic_obj_count++;
	me = d;
}

void DORPhysic::define(b2BodyDef &bodyDef) {
	if (bodyDef.type != b2_staticBody) staticbodies = false;
	bodyDef.angle = me->rot_z;
	bodyDef.position.Set(me->x / PhysicSimulator::unit_scale, -me->y / PhysicSimulator::unit_scale);
	bodyDef.userData = me;
	body = PhysicSimulator::current->world.CreateBody(&bodyDef);
}

b2Fixture *DORPhysic::addFixture(b2FixtureDef &fixtureDef) {
	fixtureDef.userData = me;
	return body->CreateFixture(&fixtureDef);
}

void DORPhysic::removeFixture(int id) {
	int did = 0;
	for (b2Fixture* f = body->GetFixtureList(); f; f = f->GetNext(), did++) {
		if (id == did) {
			body->DestroyFixture(f);
			return;
		}
	}
}

DORPhysic::~DORPhysic() {
	if (body) {
		PhysicSimulator::current->world.DestroyBody(body);
		body = NULL;
	}
	physic_obj_count--;
}

void DORPhysic::setPos(float x, float y) {
	body->SetTransform(b2Vec2(x / PhysicSimulator::unit_scale, -y / PhysicSimulator::unit_scale), me->rot_z);
}

void DORPhysic::setAngle(float a) {
	body->SetTransform(b2Vec2(me->x / PhysicSimulator::unit_scale, -me->y / PhysicSimulator::unit_scale), a);
}

void DORPhysic::applyForce(float fx, float fy, float apply_x, float apply_y) {
	body->ApplyForce(b2Vec2(fx, -fy), b2Vec2(apply_x / PhysicSimulator::unit_scale, -apply_y / PhysicSimulator::unit_scale), true);
}
void DORPhysic::applyForce(float fx, float fy) {
	body->ApplyForceToCenter(b2Vec2(fx, -fy), true);
}
void DORPhysic::applyLinearImpulse(float fx, float fy, float apply_x, float apply_y) {
	body->ApplyLinearImpulse(b2Vec2(fx, -fy), b2Vec2(apply_x / PhysicSimulator::unit_scale, -apply_y / PhysicSimulator::unit_scale), true);
}
void DORPhysic::applyLinearImpulse(float fx, float fy) {
	body->ApplyLinearImpulseToCenter(b2Vec2(fx, -fy), true);
}
void DORPhysic::setLinearVelocity(float fx, float fy) {
	body->SetLinearVelocity(b2Vec2(fx, -fy));
}

void DORPhysic::applyTorque(float t) {
	body->ApplyTorque(t, true);
}

void DORPhysic::applyAngularImpulse(float t) {
	body->ApplyAngularImpulse(t, true);
}

void DORPhysic::sleep(bool v) {
	body->SetAwake(!v);
}

vec2 DORPhysic::getLinearVelocity() {
	b2Vec2 v = body->GetLinearVelocity();
	return {v.x * PhysicSimulator::unit_scale, -v.y * PhysicSimulator::unit_scale};
}

void DORPhysic::onKeyframe(float nb_keyframes) {
	if (staticbodies) return;
	b2Vec2 position = body->GetPosition();
	float32 angle = body->GetAngle();
	float unit_scale = PhysicSimulator::unit_scale;

	// printf("%4.2f %4.2f %4.2f\n", position.x * unit_scale, position.y * unit_scale, angle);
	me->translate(floor(position.x * unit_scale), -floor(position.y * unit_scale), me->z, true);
	me->rotate(me->rot_x, me->rot_y, angle, true);
}

/*************************************************************
 ** Raycasting
 *************************************************************/
struct Hit {
	DisplayObject *d;
	vec2 point, normal;
	float dist;
};
struct Subhit {
	b2Fixture *fixture;
	vec2 point, normal;
	float dist;
};

static bool sort_hits(const Hit &a, const Hit &b) {
	return a.dist < b.dist;
}
static bool sort_subhits(const Subhit &a, const Subhit &b) {
	return a.dist < b.dist;
}

class RayCastCallbackList : public b2RayCastCallback
{
protected:
	uint16 mask_bits;
	float sx, sy;
public:
	RayCastCallbackList(float sx, float sy, uint16 mask_bits) : sx(sx), sy(sy), mask_bits(mask_bits) {};
	vector<Subhit> hits;
	float32 ReportFixture(b2Fixture* fixture, const b2Vec2& point, const b2Vec2& normal, float32 fraction) {
		float x = (point.x * PhysicSimulator::unit_scale) - sx, y = (-point.y * PhysicSimulator::unit_scale) - sy;
		hits.push_back({
			fixture,
			{point.x, point.y},
			{normal.x, normal.y},
			sqrt(x*x + y*y)
		});
		return 1;
	};
};

void PhysicSimulator::rayCast(float x1, float y1, float x2, float y2, uint16 mask_bits) {
	b2Vec2 point1(x1 / unit_scale, -y1 / unit_scale);
	b2Vec2 point2(x2 / unit_scale, -y2 / unit_scale);
	b2Vec2 r = point2 - point1;
	
	// We are called with a table in the lua top stack to store the results
	RayCastCallbackList callback(x1, y1, mask_bits);
	if (r.LengthSquared() > 0.0f) world.RayCast(&callback, point1, point2);
	sort(callback.hits.begin(), callback.hits.end(), sort_subhits);
	
	int i = 1;
	lua_rawgeti(L, LUA_REGISTRYINDEX, DisplayObject::weak_registry_ref);
	for (auto &it : callback.hits) {
		lua_newtable(L);

		DisplayObject *d = static_cast<DisplayObject*>(it.fixture->GetUserData());
		lua_pushliteral(L, "d");
		lua_rawgeti(L, -3, d->getWeakSelfRef());
		lua_rawset(L, -3);

		lua_pushliteral(L, "x");
		lua_pushnumber(L, it.point.x * unit_scale);
		lua_rawset(L, -3);

		lua_pushliteral(L, "y");
		lua_pushnumber(L, -it.point.y * unit_scale);
		lua_rawset(L, -3);

		lua_pushliteral(L, "nx");
		lua_pushnumber(L, it.normal.x * unit_scale);
		lua_rawset(L, -3);

		lua_pushliteral(L, "ny");
		lua_pushnumber(L, -it.normal.y * unit_scale);
		lua_rawset(L, -3);

		lua_pushliteral(L, "dist");
		lua_pushnumber(L, it.dist);
		lua_rawset(L, -3);

		lua_rawseti(L, -3, i++);

		// Awww we hit a wall, too bad let's stop now
		if (it.fixture->GetFilterData().categoryBits & mask_bits) break;
	}
	lua_pop(L, 1); // Pop the weak registry table
}

/*************************************************************
 ** Circlecasting
 *************************************************************/
class CircleCastCallbackList : public b2QueryCallback, public b2RayCastCallback
{
protected:
	uint16 mask_bits;
	b2Vec2 src;
	float radius, radius2;
	vector<Subhit> subhits;
public:
	CircleCastCallbackList(float sx, float sy, float radius, uint16 mask_bits) : src(sx, sy), radius(radius), mask_bits(mask_bits) {};
	vector<Hit> hits;

	// Callback for QueryAABB
	// For each body found we make a raycast from the center to ensure that they both fit in the circle and are in LOS set by mask
	bool ReportFixture(b2Fixture* fixture) {
		radius2 = radius * radius;
		subhits.clear();
		b2Body *cur_body = fixture->GetBody();
		PhysicSimulator::current->world.RayCast(this, src, cur_body->GetPosition());
		sort(subhits.begin(), subhits.end(), sort_subhits);

		for (auto &it : subhits) {
			// Awww we hit a wall, too bad let's stop now
			if (it.fixture->GetFilterData().categoryBits & mask_bits) break;
			// We hit our body, yay
			if (it.fixture->GetBody() == cur_body) {
				DisplayObject *d = static_cast<DisplayObject*>(fixture->GetUserData());
				hits.push_back({
					d,
					it.point,
					it.normal,
					sqrt(it.dist)
				});
				break;
			}
		}
		return true;
	}
	// Callback for internal raycasting
	float32 ReportFixture(b2Fixture* fixture, const b2Vec2& point, const b2Vec2& normal, float32 fraction) {
		float x = point.x - src.x, y = point.y - src.y;
		float dist2 = x*x + y*y;
		if (dist2 <= radius2) {
			subhits.push_back({
				fixture,
				{point.x, point.y},
				{normal.x, normal.y},
				dist2 // Just for sorting, no need to square it
			});
		}
		return 1;
	};
};

void PhysicSimulator::circleCast(float x, float y, float radius, uint16 mask_bits) {
	// We are called with a table in the lua top stack to store the results
	x = x / unit_scale; y = -y / unit_scale; radius = radius / unit_scale;
	CircleCastCallbackList callback(x, y, radius, mask_bits);
	b2AABB aabb;
	aabb.lowerBound = b2Vec2(x - radius, y - radius);
	aabb.upperBound = b2Vec2(x + radius, y + radius);
	world.QueryAABB(&callback, aabb);
	// sort(callback.hits.begin(), callback.hits.end(), sort_hits);
	
	int i = 1;
	lua_rawgeti(L, LUA_REGISTRYINDEX, DisplayObject::weak_registry_ref);
	for (auto &it : callback.hits) {
		lua_newtable(L);

		lua_pushliteral(L, "d");
		lua_rawgeti(L, -3, it.d->getWeakSelfRef());
		lua_rawset(L, -3);

		lua_pushliteral(L, "x");
		lua_pushnumber(L, it.point.x * unit_scale);
		lua_rawset(L, -3);

		lua_pushliteral(L, "y");
		lua_pushnumber(L, -it.point.y * unit_scale);
		lua_rawset(L, -3);

		lua_pushliteral(L, "nx");
		lua_pushnumber(L, it.normal.x * unit_scale);
		lua_rawset(L, -3);

		lua_pushliteral(L, "ny");
		lua_pushnumber(L, -it.normal.y * unit_scale);
		lua_rawset(L, -3);

		lua_pushliteral(L, "dist");
		lua_pushnumber(L, it.dist * unit_scale);
		lua_rawset(L, -3);

		lua_rawseti(L, -3, i++);
	}
	lua_pop(L, 1); // Pop the weak regisry table
}

/*************************************************************
 ** Fat Raycast
 *************************************************************/
class FatRayCastCallbackList : public b2QueryCallback, public b2RayCastCallback
{
protected:
	uint16 mask_bits;
	b2Vec2 point1, point2;
	b2Vec2 src;
	float raysize, raysize2;
	vector<Subhit> subhits;
public:
	FatRayCastCallbackList(b2Vec2 point1, b2Vec2 point2, float raysize, uint16 mask_bits) : point1(point1), point2(point2), raysize(raysize), mask_bits(mask_bits) {};
	vector<Hit> hits;

	inline b2Vec2 getPointOnLine(b2Vec2 p) {
		b2Vec2 c = p - point1;	// Vector from a to Point
		b2Vec2 pd = point2; pd -= point1;
		b2Vec2 v = pd; v.Normalize();	// Unit Vector from a to b
		float d = pd.Length();	// Length of the line segment
		float t = b2Dot(v, c);	// Intersection point Distance from a

		// Check to see if the point is on the line
		if(t < 0) return b2Vec2(-1000, -1000);
		if(t > d) return b2Vec2(-1000, -1000);

		// get the distance to move from point a
		v *= t;

		// move from point a to the nearest point on the segment
		return point1 + v;
	}

	// Callback for QueryAABB
	// For each body found we make a raycast from the center to ensure that they are in LOS set by mask
	bool ReportFixture(b2Fixture* fixture) {
		b2Body *cur_body = fixture->GetBody();

		src = getPointOnLine(cur_body->GetPosition());
		if (src.x == -1000 and src.y == -1000) return true; // Whoops, out of the line entirely

		// Simple!
		if (fixture->TestPoint(src)) {
			DisplayObject *d = static_cast<DisplayObject*>(fixture->GetUserData());
			hits.push_back({
				d,
				{src.x, src.y},
				{src.x, src.y},
				0,
			});
			return true;
		}

		// Less simple
		raysize2 = raysize * raysize;
		b2Vec2 over = cur_body->GetPosition() - src;

		subhits.clear();
		PhysicSimulator::current->world.RayCast(this, src, cur_body->GetPosition());
		sort(subhits.begin(), subhits.end(), sort_subhits);

		for (auto &it : subhits) {
			// Awww we hit a wall, too bad let's stop now
			if (it.fixture->GetFilterData().categoryBits & mask_bits) break;
			// We hit our body, yay
			if (it.fixture->GetBody() == cur_body) {
				DisplayObject *d = static_cast<DisplayObject*>(fixture->GetUserData());
				hits.push_back({
					d,
					it.point,
					it.normal,
					sqrt(it.dist)
				});
				break;
			}
		}
		return true;
	}
	// Callback for internal raycasting
	float32 ReportFixture(b2Fixture* fixture, const b2Vec2& point, const b2Vec2& normal, float32 fraction) {
		float x = point.x - src.x, y = point.y - src.y;
		float dist2 = x*x + y*y;
		if (dist2 <= raysize2) {
			subhits.push_back({
				fixture,
				{point.x, point.y},
				{normal.x, normal.y},
				raysize2 // Just for sorting, no need to square it
			});
		}
		return 1;
	};
};

void PhysicSimulator::fatRayCast(float x1, float y1, float x2, float y2, float raysize, uint16 mask_bits) {
	b2Vec2 point1(x1 / unit_scale, -y1 / unit_scale);
	b2Vec2 point2(x2 / unit_scale, -y2 / unit_scale);
	b2Vec2 r = point2 - point1;
	
	// We are called with a table in the lua top stack to store the results
	FatRayCastCallbackList callback(point1, point2, raysize / unit_scale, mask_bits);
	if (r.LengthSquared() > 0.0f) {
		b2AABB aabb;
		aabb.lowerBound = b2Vec2(fmin(point1.x, point2.x) - raysize / unit_scale, fmin(point1.y, point2.y) - raysize / unit_scale);
		aabb.upperBound = b2Vec2(fmax(point1.x, point2.x) + raysize / unit_scale, fmax(point1.y, point2.y) + raysize / unit_scale);
		world.QueryAABB(&callback, aabb);
	}
	
	int i = 1;
	lua_rawgeti(L, LUA_REGISTRYINDEX, DisplayObject::weak_registry_ref);
	for (auto &it : callback.hits) {
		lua_newtable(L);

		lua_pushliteral(L, "d");
		lua_rawgeti(L, -3, it.d->getWeakSelfRef());
		lua_rawset(L, -3);

		lua_pushliteral(L, "x");
		lua_pushnumber(L, it.point.x * unit_scale);
		lua_rawset(L, -3);

		lua_pushliteral(L, "y");
		lua_pushnumber(L, -it.point.y * unit_scale);
		lua_rawset(L, -3);

		lua_pushliteral(L, "nx");
		lua_pushnumber(L, it.normal.x * unit_scale);
		lua_rawset(L, -3);

		lua_pushliteral(L, "ny");
		lua_pushnumber(L, -it.normal.y * unit_scale);
		lua_rawset(L, -3);

		lua_pushliteral(L, "dist");
		lua_pushnumber(L, it.dist * unit_scale);
		lua_rawset(L, -3);

		lua_rawseti(L, -3, i++);
	}
	lua_pop(L, 1); // Pop the weak regisry table
}

/*************************************************************
 ** Contacts
 *************************************************************/
struct contact_info {
	b2Body *a;
	b2Body *b;
	float velocity;
};
class TE4ContactListener : public b2ContactListener
{
public:
	vector<vector<contact_info>> events;
	TE4ContactListener(int nb_threads) {
		events.resize(nb_threads);
	};

	void BeginContact(b2Contact* contact) {		
		if (contact->IsTouching()) {
			b2Body* bodyA = contact->GetFixtureA()->GetBody();
			b2Body* bodyB = contact->GetFixtureB()->GetBody();
#ifdef BOX2D_MT
			events[b2GetThreadId()].push_back({bodyA, bodyB, 0});
#else
			events[0].push_back({bodyA, bodyB, 0});
#endif
		}
	};
	void EndContact(b2Contact* contact) {};
	void PreSolve(b2Contact* contact, const b2Manifold* oldManifold) {
// 		b2WorldManifold worldManifold;
// 		contact->GetWorldManifold(&worldManifold);
// 		b2PointState state1[2], state2[2];
// 		b2GetPointStates(state1, state2, oldManifold, contact->GetManifold());
// 		if (state2[0] == b2_addState)
// 		{
// 			b2Body* bodyA = contact->GetFixtureA()->GetBody();
// 			b2Body* bodyB = contact->GetFixtureB()->GetBody();
// 			b2Vec2 point = worldManifold.points[0];
// 			b2Vec2 vA = bodyA->GetLinearVelocityFromWorldPoint(point);
// 			b2Vec2 vB = bodyB->GetLinearVelocityFromWorldPoint(point);
// 			float32 approachVelocity = b2Dot(vB - vA, worldManifold.normal);
// #ifdef BOX2D_MT
// 			events[b2GetThreadId()].push_back({bodyA, bodyB, approachVelocity});
// #else
// 			events[0].push_back({bodyA, bodyB, approachVelocity});
// #endif
// 		}
	};
	void PostSolve(b2Contact* contact, const b2ContactImpulse* impulse) {};
};

/*************************************************************************
 ** PhysicSimulator
 *************************************************************************/
#ifdef BOX2D_MT
PhysicSimulator::PhysicSimulator(float x, float y) : world(b2Vec2(x / unit_scale, -y / unit_scale), &tp) {
	printf("[PhysicSimulator] Initiated in multi-threaded mode\n");
	contact_listener = new TE4ContactListener(b2_maxThreads);
	world.SetContactListener(contact_listener);
}
#else
PhysicSimulator::PhysicSimulator(float x, float y) : world(b2Vec2(x / unit_scale, -y / unit_scale)) {
	printf("[PhysicSimulator] Initiated in single-threaded mode\n");
	contact_listener = new TE4ContactListener(1);
	world.SetContactListener(contact_listener);
}
#endif
PhysicSimulator::~PhysicSimulator() {
	refcleaner(&contact_listener_ref);
	delete contact_listener;
}

void PhysicSimulator::use() {
	if (current && !physic_obj_count) {
		printf("[PhysicSimulator] ERROR TRYING TO DEFINE NEW CURRENT WITH %d OBJECTS LEFT\n", physic_obj_count);
		exit(1);
	}
	current = this;
}

int PhysicSimulator::getPhysicsCount() {
	return physic_obj_count;
}

void PhysicSimulator::setGravity(float x, float y) {
	world.SetGravity(b2Vec2(x / unit_scale, -y / unit_scale));
}

void PhysicSimulator::setUnitScale(float scale) {
	unit_scale = scale;
}

void PhysicSimulator::setContactListener(int ref) {
	refcleaner(&contact_listener_ref);
	contact_listener_ref = ref;
}

void PhysicSimulator::sleepAll(bool v) {
	for (b2Body* b = world.GetBodyList(); b; b = b->GetNext()) {
		b->SetAwake(!v);
	}
}

void PhysicSimulator::drawDebug(float x, float y) {
	if (!debug) {
		debug = new WorldDebug();
		world.SetDebugDraw(debug);
	}
	debug->resetDebug();
	world.DrawDebugData();
	glm::mat4 model = glm::mat4();
	model = glm::translate(model, vec3(x, y, 0.f));
	debug->toScreen(model, {1,1,1,1});
}

void PhysicSimulator::step(float nb_keyframes) {
	// Grab weak DO registery
	lua_rawgeti(L, LUA_REGISTRYINDEX, DisplayObject::weak_registry_ref);

	// We do it this way because box2d doc says it realyl doesnt like changing the timestep
	for (int f = 0; f < nb_keyframes * 60.0 / (float)NORMALIZED_FPS; f++) {
		world.Step(1.0f / 60.0f, 6, 2);
		if ((contact_listener_ref != LUA_NOREF) && contact_listener->events.size()) {

			lua_rawgeti(L, LUA_REGISTRYINDEX, contact_listener_ref);
			lua_newtable(L);
			int i = 1;
			for (auto &events : contact_listener->events) {
				for (auto &it : events) {
					DisplayObject *a = static_cast<DisplayObject*>(it.a->GetUserData());
					DisplayObject *b = static_cast<DisplayObject*>(it.b->GetUserData());

					lua_newtable(L);
					
					lua_rawgeti(L, -4, a->getWeakSelfRef()); // The DO
					lua_rawseti(L, -2, 1);
					lua_rawgeti(L, -4, b->getWeakSelfRef()); // The DO
					lua_rawseti(L, -2, 2);
					lua_pushnumber(L, it.velocity);
					lua_rawseti(L, -2, 3);

					lua_rawseti(L, -2, i++); // Store the table in the list
				}
				events.clear();
			}

			if (lua_pcall(L, 1, 0, 0)) {
				printf("Contact Listener callback error: %s\n", lua_tostring(L, -1));
			}
		}
	}

	lua_pop(L, 1); // Pop the weak registry
}

PhysicSimulator *PhysicSimulator::current = NULL;
float PhysicSimulator::unit_scale = 1;

PhysicSimulator *PhysicSimulator::getCurrent() {
	printf("[PhysicSimulator] getCurrent: NO CURRENT ONE !\n");
	return current;
}

extern "C" void run_physic_simulation(float nb_keyframes);
void run_physic_simulation(float nb_keyframes) {
	if (!PhysicSimulator::current || PhysicSimulator::current->paused) return;
	PhysicSimulator::current->step(nb_keyframes);
}

extern "C" void reset_physic_simulation();
void reset_physic_simulation() {
	if (!PhysicSimulator::current) return;
	PhysicSimulator::current->setContactListener(LUA_NOREF);
}
