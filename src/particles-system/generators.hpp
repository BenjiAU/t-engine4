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

enum class GeneratorsList : uint8_t {
	LifeGenerator,
	BasicTextureGenerator,
	OriginPosGenerator, DiskPosGenerator, SquarePosGenerator, CirclePosGenerator, TrianglePosGenerator, LinePosGenerator, JaggedLinePosGenerator, ImagePosGenerator,
	DiskVelGenerator, DirectionVelGenerator,
	BasicSizeGenerator, StartStopSizeGenerator,
	BasicRotationGenerator, RotationByVelGenerator, BasicRotationVelGenerator, SwapPosByVelGenerator,
	StartStopColorGenerator, FixedColorGenerator,
	CopyGenerator, JaggedLineBetweenGenerator,
	ParametrizerGenerator,
	SoundGenerator,
};

class Generator {
protected:
	vec2 shift_pos = vec2(0, 0), final_pos = vec2(0, 0);

public:
	vec2 base_pos = vec2(0, 0);
	bool use_limiter = false;
	virtual uint32_t weight() const { return 100; };
	void shift(float x, float y, bool absolute);
	void updateField(string &name, float value);
	virtual void useSlots(ParticlesData &p) {}
	virtual void finish() {}
	virtual void generate(ParticlesData &p, uint32_t start, uint32_t end) = 0;
	virtual uint32_t generateLimit(ParticlesData &p, uint32_t start, uint32_t end) {}
	virtual GeneratorsList getID() = 0;
};
typedef unique_ptr<Generator> uGenerator;

/********************************************************************
 ** Misc Utilities
 ********************************************************************/
class JaggedLineGeneratorBase : public Generator {
public:
	float strands;
	float sway;
	virtual void generateStrands(ParticlesData &p, uint32_t &start, uint32_t &end, vec2 p1, vec2 p2, float spread, vec4 &c1, vec4 &c2);
};

/********************************************************************
 ** Life
 ********************************************************************/
class LifeGenerator : public Generator {
public:
	float min, max;
	virtual void useSlots(ParticlesData &p) { p.initSlot4(LIFE); };
	virtual void generate(ParticlesData &p, uint32_t start, uint32_t end);
	virtual GeneratorsList getID() { return GeneratorsList::LifeGenerator; }
};

/********************************************************************
 ** Texture
 ********************************************************************/
class BasicTextureGenerator : public Generator {
public:
	virtual void useSlots(ParticlesData &p) { p.initSlot4(TEXTURE); };
	virtual void generate(ParticlesData &p, uint32_t start, uint32_t end);
	virtual GeneratorsList getID() { return GeneratorsList::BasicTextureGenerator; }
};

/********************************************************************
 ** Positions
 ********************************************************************/
class OriginPosGenerator : public Generator {
public:
	virtual uint32_t weight() const { return 100000; };
	virtual void useSlots(ParticlesData &p) { p.initSlot4(POS); p.initSlot2(ORIGIN_POS); };
	virtual void generate(ParticlesData &p, uint32_t start, uint32_t end);
	virtual GeneratorsList getID() { return GeneratorsList::OriginPosGenerator; }
};

class SquarePosGenerator : public Generator {
public:
	float min_x, max_x, min_y, max_y;
	virtual void useSlots(ParticlesData &p) { p.initSlot4(POS); };
	virtual void generate(ParticlesData &p, uint32_t start, uint32_t end);
	virtual GeneratorsList getID() { return GeneratorsList::SquarePosGenerator; }
};

class DiskPosGenerator : public Generator {
public:
	float radius;
	float min_angle, max_angle;
	virtual void useSlots(ParticlesData &p) { p.initSlot4(POS); };
	virtual void generate(ParticlesData &p, uint32_t start, uint32_t end);
	virtual GeneratorsList getID() { return GeneratorsList::DiskPosGenerator; }
};

class CirclePosGenerator : public Generator {
public:
	float radius;
	float width;
	float min_angle, max_angle;
	virtual void useSlots(ParticlesData &p) { p.initSlot4(POS); };
	virtual void generate(ParticlesData &p, uint32_t start, uint32_t end);
	virtual GeneratorsList getID() { return GeneratorsList::CirclePosGenerator; }
};

class TrianglePosGenerator : public Generator {
	vec2 u, v, start_pos;
public:
	vec2 p1, p2, p3;
	virtual void finish();
	virtual void useSlots(ParticlesData &p) { p.initSlot4(POS); };
	virtual void generate(ParticlesData &p, uint32_t start, uint32_t end);
	virtual GeneratorsList getID() { return GeneratorsList::TrianglePosGenerator; }
};

class LinePosGenerator : public Generator {
public:
	vec2 p1, p2;
	float spread;
	virtual void useSlots(ParticlesData &p) { p.initSlot4(POS); };
	virtual void generate(ParticlesData &p, uint32_t start, uint32_t end);
	virtual GeneratorsList getID() { return GeneratorsList::LinePosGenerator; }
};

class JaggedLinePosGenerator : public JaggedLineGeneratorBase {
public:
	vec2 p1, p2;
	float spread;
	JaggedLinePosGenerator() { use_limiter = true; };
	virtual uint32_t weight() const { return 10; };
	virtual void useSlots(ParticlesData &p) { p.initSlot4(POS); p.initSlot2(LINKS); };
	virtual void generate(ParticlesData &p, uint32_t start, uint32_t end) {}
	virtual uint32_t generateLimit(ParticlesData &p, uint32_t start, uint32_t end);
	virtual GeneratorsList getID() { return GeneratorsList::JaggedLinePosGenerator; }
};

class ImagePosGenerator : public Generator {
public:
	spPointsListHolder lph;
	ImagePosGenerator(spPointsListHolder lph);
	virtual uint32_t weight() const { return 10; };
	virtual void useSlots(ParticlesData &p) { p.initSlot4(POS); p.initSlot4(COLOR); p.initSlot4(COLOR_START); p.initSlot4(COLOR_STOP); };
	virtual void generate(ParticlesData &p, uint32_t start, uint32_t end) {}
	virtual uint32_t generateLimit(ParticlesData &p, uint32_t start, uint32_t end);
	virtual GeneratorsList getID() { return GeneratorsList::ImagePosGenerator; }
};


/********************************************************************
 ** Velocities
 ********************************************************************/
class DiskVelGenerator : public Generator {
public:
	float min_vel, max_vel;
	virtual void useSlots(ParticlesData &p) { p.initSlot2(VEL); p.initSlot2(ACC); };
	virtual void generate(ParticlesData &p, uint32_t start, uint32_t end);
	virtual GeneratorsList getID() { return GeneratorsList::DiskVelGenerator; }
};

class DirectionVelGenerator : public Generator {
public:
	float min_vel, max_vel;
	float min_rot, max_rot;
	vec2 from;
	virtual uint32_t weight() const { return 150; };
	virtual void useSlots(ParticlesData &p) { p.initSlot4(POS); p.initSlot4(LIFE); p.initSlot2(VEL); p.initSlot2(ACC); };
	virtual void generate(ParticlesData &p, uint32_t start, uint32_t end);
	virtual GeneratorsList getID() { return GeneratorsList::DirectionVelGenerator; }
};

class SwapPosByVelGenerator : public Generator {
public:
	virtual uint32_t weight() const { return 300; };
	virtual void useSlots(ParticlesData &p) { p.initSlot4(POS); p.initSlot4(LIFE); p.initSlot2(VEL); p.initSlot2(ACC); };
	virtual void generate(ParticlesData &p, uint32_t start, uint32_t end);
	virtual GeneratorsList getID() { return GeneratorsList::SwapPosByVelGenerator; }
};


/********************************************************************
 ** Sizes
 ********************************************************************/
class BasicSizeGenerator : public Generator {
public:
	float min_size, max_size;
	virtual void useSlots(ParticlesData &p) { p.initSlot4(POS); };
	virtual void generate(ParticlesData &p, uint32_t start, uint32_t end);
	virtual GeneratorsList getID() { return GeneratorsList::BasicSizeGenerator; }
};

class StartStopSizeGenerator : public Generator {
public:
	float min_start_size, max_start_size;
	float min_stop_size, max_stop_size;
	virtual void useSlots(ParticlesData &p) { p.initSlot4(POS); p.initSlot2(SIZE); };
	virtual void generate(ParticlesData &p, uint32_t start, uint32_t end);
	virtual GeneratorsList getID() { return GeneratorsList::StartStopSizeGenerator; }
};


/********************************************************************
 ** Rotations
 ********************************************************************/
class BasicRotationGenerator : public Generator {
public:
	float min_rot, max_rot;
	virtual void useSlots(ParticlesData &p) { p.initSlot4(POS); };
	virtual void generate(ParticlesData &p, uint32_t start, uint32_t end);
	virtual GeneratorsList getID() { return GeneratorsList::BasicRotationGenerator; }
};

class RotationByVelGenerator : public Generator {
public:
	float min_rot, max_rot;
	virtual uint32_t weight() const { return 200; };
	virtual void useSlots(ParticlesData &p) { p.initSlot4(POS); p.initSlot2(VEL); };
	virtual void generate(ParticlesData &p, uint32_t start, uint32_t end);
	virtual GeneratorsList getID() { return GeneratorsList::RotationByVelGenerator; }
};

class BasicRotationVelGenerator : public Generator {
public:
	float min_rot, max_rot;
	virtual uint32_t weight() const { return 10000; };
	virtual void useSlots(ParticlesData &p) { p.initSlot4(POS); p.initSlot2(ROT_VEL); };
	virtual void generate(ParticlesData &p, uint32_t start, uint32_t end);
	virtual GeneratorsList getID() { return GeneratorsList::BasicRotationVelGenerator; }
};


/********************************************************************
 ** Colors
 ********************************************************************/
class StartStopColorGenerator : public Generator {
public:
	vec4 min_color_start, min_color_stop; 
	vec4 max_color_start, max_color_stop; 
	virtual void useSlots(ParticlesData &p) { p.initSlot4(COLOR); p.initSlot4(COLOR_START); p.initSlot4(COLOR_STOP); };
	virtual void generate(ParticlesData &p, uint32_t start, uint32_t end);
	virtual GeneratorsList getID() { return GeneratorsList::StartStopColorGenerator; }
};

class FixedColorGenerator : public Generator {
public:
	vec4 color_start;
	vec4 color_stop;
	virtual void useSlots(ParticlesData &p) { p.initSlot4(COLOR); p.initSlot4(COLOR_START); p.initSlot4(COLOR_STOP); };
	virtual void generate(ParticlesData &p, uint32_t start, uint32_t end);
	virtual GeneratorsList getID() { return GeneratorsList::FixedColorGenerator; }
};


/********************************************************************
 ** Complex & Strange ones
 ********************************************************************/
class CopyGenerator : public Generator {
	System *source_system; // Nasty, not a shared_ptr because systems are stored as unique_ptr, but the way things are guaranties it wont be destroyed under us so ... meh
	bool copy_pos;
	bool copy_color;
public:
	CopyGenerator(System *source_system, bool copy_pos, bool copy_color) : source_system(source_system), copy_pos(copy_pos), copy_color(copy_color) { use_limiter = true; };
	virtual uint32_t weight() const { return 1; };
	virtual void useSlots(ParticlesData &p);
	virtual void generate(ParticlesData &p, uint32_t start, uint32_t end) {};
	virtual uint32_t generateLimit(ParticlesData &p, uint32_t start, uint32_t end);
	virtual GeneratorsList getID() { return GeneratorsList::CopyGenerator; }
};

class JaggedLineBetweenGenerator : public JaggedLineGeneratorBase {
	System *source_system1; // Nasty, not a shared_ptr because systems are stored as unique_ptr, but the way things are guaranties it wont be destroyed under us so ... meh
	System *source_system2; // Nasty, not a shared_ptr because systems are stored as unique_ptr, but the way things are guaranties it wont be destroyed under us so ... meh
	bool copy_pos;
	bool copy_color;
public:
	float close_tries;
	float repeat_times;
	JaggedLineBetweenGenerator(System *source_system1, System *source_system2, bool copy_pos, bool copy_color) : source_system1(source_system1), source_system2(source_system2), copy_pos(copy_pos), copy_color(copy_color) { use_limiter = true; };
	virtual uint32_t weight() const { return 1; };
	virtual void useSlots(ParticlesData &p);
	virtual void generate(ParticlesData &p, uint32_t start, uint32_t end) {};
	virtual uint32_t generateLimit(ParticlesData &p, uint32_t start, uint32_t end);
	virtual GeneratorsList getID() { return GeneratorsList::JaggedLineBetweenGenerator; }
};

class ParametrizerGenerator : public Generator {
	float *val = nullptr;
	mu::Parser expr;
	Ensemble *ee = nullptr;
	System *system = nullptr;
public:
	ParametrizerGenerator(Ensemble *ee, System *s, const char *name, const char *expr_def);
	virtual uint32_t weight() const { return 0; };
	virtual void useSlots(ParticlesData &p) {}
	virtual void generate(ParticlesData &p, uint32_t start, uint32_t end);
	virtual GeneratorsList getID() { return GeneratorsList::ParametrizerGenerator; }
};


class SoundGenerator : public Generator {
protected:
	string name;
	bool loaded = false;
public:
	bool once = true;
	SoundGenerator(string name, bool once);
	virtual void generate(ParticlesData &p, uint32_t start, uint32_t end);
	virtual GeneratorsList getID() { return GeneratorsList::SoundGenerator; }
};
