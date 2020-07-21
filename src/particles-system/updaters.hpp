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
#include <unordered_map>
#include <cmath>

#define PI2 6.28318530717958647692

using namespace std;
using namespace glm;

enum class UpdatersList : uint8_t {
	LinearColorUpdater, BiLinearColorUpdater, EasingColorUpdater,
	BasicTimeUpdater,
	AnimatedTextureUpdater,
	EulerPosUpdater, EasingPosUpdater, MathPosUpdater, PosUpdater, NoisePosUpdater, BoidPosUpdater,
	LinearSizeUpdater, EasingSizeUpdater,
	LinearRotationUpdater, EasingRotationUpdater,
};

typedef float (*easing_ptr)(float,float,float);

class Updater {
public:
	virtual void useSlots(ParticlesData &p) {};
	virtual void update(ParticlesData &p, float dt) = 0;
};

class LinearColorUpdater : public Updater {
	bool bilinear = false;
public:
	LinearColorUpdater(bool bilinear) : bilinear(bilinear) {};
	virtual void useSlots(ParticlesData &p) { p.initSlot4(LIFE); p.initSlot4(COLOR); p.initSlot4(COLOR_START); p.initSlot4(COLOR_STOP); };
	virtual void update(ParticlesData &p, float dt);
};

class EasingColorUpdater : public Updater {
private:
	bool bilinear = false;
	easing_ptr easing;
public:
	EasingColorUpdater(bool bilinear, easing_ptr easing) : bilinear(bilinear), easing(easing) {};
	virtual void useSlots(ParticlesData &p) { p.initSlot4(COLOR); p.initSlot4(COLOR_START); p.initSlot4(COLOR_STOP); p.initSlot4(LIFE); };
	virtual void update(ParticlesData &p, float dt);
};

class LinearRotationUpdater : public Updater {
public:
	virtual void useSlots(ParticlesData &p) {p.initSlot4(POS); p.initSlot2(ROT_VEL); };
	virtual void update(ParticlesData &p, float dt);
};

class EasingRotationUpdater : public Updater {
private:
	easing_ptr easing;
public:
	EasingRotationUpdater(easing_ptr easing) : easing(easing) {};
	virtual void useSlots(ParticlesData &p) { p.initSlot4(LIFE); p.initSlot4(POS); p.initSlot2(ROT_VEL); };
	virtual void update(ParticlesData &p, float dt);
};

class BasicTimeUpdater : public Updater {
public:
	virtual void useSlots(ParticlesData &p) { p.initSlot4(LIFE); };
	virtual void update(ParticlesData &p, float dt);
};

class AnimatedTextureUpdater : public Updater {
private:
	float repeat_over_life;
	uint16_t max;
	vector<vec4> frames;
public:
	AnimatedTextureUpdater(uint8_t splitx, uint8_t splity, uint8_t firstframe, uint8_t lastframe, float repeat_over_life);
	virtual void useSlots(ParticlesData &p) { p.initSlot4(LIFE); p.initSlot4(TEXTURE); };
	virtual void update(ParticlesData &p, float dt);
};

class LinearSizeUpdater : public Updater {
public:
	virtual void useSlots(ParticlesData &p) { p.initSlot4(POS); p.initSlot4(LIFE); p.initSlot2(SIZE); };
	virtual void update(ParticlesData &p, float dt);
};

class EasingSizeUpdater : public Updater {
private:
	easing_ptr easing;
public:
	EasingSizeUpdater(easing_ptr easing) : easing(easing) {};
	virtual void useSlots(ParticlesData &p) { p.initSlot4(POS); p.initSlot4(LIFE); p.initSlot2(SIZE); };
	virtual void update(ParticlesData &p, float dt);
};

class EulerPosUpdater : public Updater {
private:
	vec2 global_vel = vec2(0.0, 0.0);
	vec2 global_acc = vec2(0.0, 0.0);
public:
	EulerPosUpdater(vec2 global_vel = vec2(0, 0), vec2 global_acc = vec2(0, 0)) : global_vel(global_vel), global_acc(global_acc) {};
	virtual void useSlots(ParticlesData &p) { p.initSlot4(POS); p.initSlot2(VEL); p.initSlot2(ACC); };
	virtual void update(ParticlesData &p, float dt);
};

class EasingPosUpdater : public Updater {
private:
	easing_ptr easing;
public:
	EasingPosUpdater(easing_ptr easing) : easing(easing) {};
	virtual void useSlots(ParticlesData &p) { p.initSlot4(POS); p.initSlot4(LIFE); p.initSlot2(VEL); p.initSlot2(ORIGIN_POS); };
	virtual void update(ParticlesData &p, float dt);
};

class MathPosUpdater : public Updater {
private:
	float tmp_t = 0, tmp_dx = 0, tmp_dy = 0;
	mu::Parser expr_x, expr_y;
	Ensemble *ee = nullptr;
public:
	MathPosUpdater(Ensemble *ee, const char *expr_x_def, const char *expr_y_def);
	virtual void useSlots(ParticlesData &p) { p.initSlot4(POS); p.initSlot4(LIFE); p.initSlot2(VEL); p.initSlot2(ORIGIN_POS); };
	virtual void update(ParticlesData &p, float dt);
};

class NoisePosUpdater : public Updater {
private:
	spNoiseHolder noise;
	vec2 amplitude;
	float traversal_speed;
public:
	NoisePosUpdater(spNoiseHolder noise, vec2 amplitude, float traversal_speed) : noise(noise), amplitude(amplitude), traversal_speed(traversal_speed) {};
	virtual void useSlots(ParticlesData &p) { p.initSlot4(POS); p.initSlot4(LIFE); p.initSlot2(ORIGIN_POS); };
	virtual void update(ParticlesData &p, float dt);
};

/********************************************
 ** BOIDS!
 ** Code inspired by https://github.com/Cultrarius/Swarmz/blob/master/swarmz.h
 ********************************************/
enum class BoidDistanceType {
	LINEAR, INVERSE_LINEAR, QUADRATIC, INVERSE_QUADRATIC
};

typedef uint32_t Boid;
class BoidPosUpdater : public Updater {
public:
	// Parameters
	float PerceptionRadius = 50;

	float SeparationWeight = 1;
	BoidDistanceType SeparationType = BoidDistanceType::INVERSE_QUADRATIC;

	float AlignmentWeight = 1;
	float CohesionWeight = 1;

	float SteeringWeight = 0;
	vector<vec2> steering_targets = {{0.0f, -0.1f}};
	BoidDistanceType SteeringTargetType = BoidDistanceType::LINEAR;

	float BlindspotAngleDeg = 20;
	float MaxAcceleration = 250;
	float MaxVelocity = 100;

private:
	struct Vec2Hasher {
		typedef std::size_t result_type;

		result_type operator()(vec2 const &v) const {
			result_type const h1(std::hash<float>()(v.x));
			result_type const h2(std::hash<float>()(v.y));
			return h1 * 31 + h2;
		}
	};

	// Internal stuff
	vec4* cur_pos = nullptr;
	vec2* cur_vel = nullptr;
	vector<vec2> accelerations;
	std::unordered_map<vec2, std::vector<Boid>, Vec2Hasher> voxelCache;
	float BlindspotAngleDegCompareValue = 0; // = cos(PI2 * BlindspotAngleDeg / 360)

	struct NearbyBoid {
		Boid boid;
		vec2 direction;
		float distance;
	};

	vec2 getRandomUniform();

	vec2 clampLength(vec2 v, float length) const {
		float l = glm::length(v);
		if (l > length) {
			vec2 p = glm::normalize(v) * length;
			return glm::normalize(v) * length;
		}
		return v;
	}

	void updateBoid(Boid b) {
		vec2 separationSum;
		vec2 headingSum;
		vec2 positionSum;
		vec2 po(cur_pos[b].x, cur_pos[b].y);

		auto nearby = getNearbyBoids(b);

		for (NearbyBoid &closeBoid : nearby) {
			if (closeBoid.distance == 0) {
				separationSum += getRandomUniform();
			}
			else {
				float separationFactor = TransformDistance(closeBoid.distance, SeparationType);
				separationSum += -closeBoid.direction * separationFactor;
			}
			headingSum += cur_vel[closeBoid.boid];
			positionSum += vec2(cur_pos[closeBoid.boid].x, cur_pos[closeBoid.boid].y);
		}

		vec2 steeringTarget = po;
		float targetDistance = -1;
		for (auto &target : steering_targets) {
			float distance = TransformDistance(glm::distance(po, target), SteeringTargetType);
			if (targetDistance < 0 || distance < targetDistance) {
				steeringTarget = target;
				targetDistance = distance;
			}
		}

		// Separation: steer to avoid crowding local flockmates
		vec2 separation = nearby.size() > 0 ? separationSum / static_cast<float>(nearby.size()) : separationSum;

		// Alignment: steer towards the average heading of local flockmates
		vec2 alignment = nearby.size() > 0 ? headingSum / static_cast<float>(nearby.size()) : headingSum;

		// Cohesion: steer to move toward the average position of local flockmates
		vec2 avgPosition = nearby.size() > 0 ? positionSum / static_cast<float>(nearby.size()) : po;
		vec2 cohesion = avgPosition - po;

		// Steering: steer towards the nearest target location (like a moth to the light)
		vec2 steering = glm::normalize(steeringTarget - po) * targetDistance;
		
		// calculate boid acceleration
		vec2 acceleration;
		// printf("updateBoid[b] acc += %fx%f * %f\n", separation.x, separation.y, SeparationWeight);
		acceleration += separation * SeparationWeight;
		// printf("updateBoid[b] acc += %fx%f * %f\n", alignment.x, alignment.y, AlignmentWeight);
		acceleration += alignment * AlignmentWeight;
		// printf("updateBoid[b] acc += %fx%f * %f\n", cohesion.x, cohesion.y, CohesionWeight);
		acceleration += cohesion * CohesionWeight;
		// printf("updateBoid[b] acc += %fx%f * %f\n", steering.x, steering.y, SteeringWeight);
		acceleration += steering * SteeringWeight;
		accelerations[b] = clampLength(acceleration, MaxAcceleration);
	}

	vector<NearbyBoid> getNearbyBoids(Boid b) const {
		vector<NearbyBoid> result;
		result.reserve(accelerations.size());

		vec2 voxelPos = getVoxelForBoid(b);
		voxelPos.x -= 1;
		voxelPos.y -= 1;
		for (int x = 0; x < 3; x++) {
			for (int y = 0; y < 3; y++) {
				checkVoxelForBoids(b, result, voxelPos);
				voxelPos.y++;
			}
			voxelPos.y -= 3;
			voxelPos.x++;
		}
		return result;
	}

	void checkVoxelForBoids(Boid b, vector<NearbyBoid> &result, const vec2 &voxelPos) const {
		auto iter = voxelCache.find(voxelPos);
		if (iter != voxelCache.end()) {
			for (Boid test : iter->second) {
				vec2 p1(cur_pos[b].x, cur_pos[b].y);
				vec2 p2(cur_pos[test].x, cur_pos[test].y);
				vec2 vec = p2 - p1;
				float distance = glm::length(vec);

				float compareValue = 0;
				float l1 = distance;
				float l2 = glm::length(cur_vel[b]);
				if (l1 != 0 && l2 != 0) {
					compareValue = glm::dot(-cur_vel[b], vec) / (l1 * l2);
				}

				if (b != test && distance <= PerceptionRadius && (BlindspotAngleDegCompareValue > compareValue || l2 == 0)) {
					NearbyBoid nb;
					nb.boid = test;
					nb.distance = distance;
					nb.direction = vec;
					result.push_back(nb);
				}
			}
		}
	}

	void buildVoxelCache() {
		voxelCache.clear();
		voxelCache.reserve(accelerations.size());
		for (Boid b = 0; b < accelerations.size(); b++) {
			voxelCache[getVoxelForBoid(b)].push_back(b);
		}
	}

	vec2 getVoxelForBoid(Boid b) const {
		float r = std::abs(PerceptionRadius);
		vec2 p(cur_pos[b].x, cur_pos[b].y);
		vec2 voxelPos;
		voxelPos.x = static_cast<int>(p.x / r);
		voxelPos.y = static_cast<int>(p.y / r);
		return voxelPos;
	}

	float TransformDistance(float distance, BoidDistanceType type) {
		if (type == BoidDistanceType::LINEAR) {
			return distance;
		}
		else if (type == BoidDistanceType::INVERSE_LINEAR) {
			return distance == 0 ? 0 : 1 / distance;
		}
		else if (type == BoidDistanceType::QUADRATIC) {
			return std::pow(distance, 2);
		}
		else if (type == BoidDistanceType::INVERSE_QUADRATIC) {
			float quad = std::pow(distance, 2);
			return quad == 0 ? 0 : 1 / quad;
		}
		else {
			return distance; // throw exception instead?
		}
	}

public:
	BoidPosUpdater() {};
	virtual void useSlots(ParticlesData &p) { p.initSlot4(POS); p.initSlot2(VEL); };
	virtual void update(ParticlesData &p, float dt);
};
