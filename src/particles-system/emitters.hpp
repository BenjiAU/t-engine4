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
using namespace std;
using namespace glm;

enum class EmittersList : uint8_t { LinearEmitter };

class System;
class Emitter : public Triggerable, public Event {
	friend class System;
protected:
	bool dormant = false;
	bool active = true;
	bool first_tick = true;
	uint16_t next_tick_force_generate = false;
	vector<uGenerator> generators;
	void generate(ParticlesData &p, uint32_t nb);
public:
	inline bool isActive() { return active; };
	inline bool isActiveNotDormant() { return active && !dormant; };
	void setDormant(bool d) { dormant = d; };
	void shift(float x, float y, bool absolute);
	void addGenerator(System *sys, Generator *gen);
	virtual void emit(ParticlesData &p, float dt) = 0;
	virtual void triggered(TriggerableKind kind);
};

class LinearEmitter : public Emitter {
private:
	uint32_t nb;
	float rate;
	float duration;
	float startat;
	float accumulator = 0;
public:
	LinearEmitter(float startat, float duration, float rate, uint32_t nb) : startat(startat), duration(duration), rate(rate), nb(nb) { accumulator = rate; };
	virtual void emit(ParticlesData &p, float dt);
};
