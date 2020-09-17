-- TE4 - T-Engine 4
-- Copyright (C) 2009 - 2018 Nicolas Casalini
--
-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with this program.  If not, see <http://www.gnu.org/licenses/>.
--
-- Nicolas Casalini "DarkGod"
-- darkgod@te4.org

require "engine.class"
local KeyBind = require "engine.KeyBind"
local FontPackage = require "engine.FontPackage"
local BigNews = require "engine.BigNews"
local Dialog = require "engine.ui.Dialog"
local Checkbox = require "engine.ui.Checkbox"
local Textbox = require "engine.ui.Textbox"
local Numberbox = require "engine.ui.Numberbox"
local Textzone = require "engine.ui.Textzone"
local Dropdown = require "engine.ui.Dropdown"
local NumberSlider = require "engine.ui.NumberSlider"
local Separator = require "engine.ui.Separator"
local ColorPicker = require "engine.ui.ColorPicker"
local DisplayObject = require "engine.ui.DisplayObject"
local ImageList = require "engine.ui.ImageList"
local List = require "engine.ui.List"
local Button = require "engine.ui.Button"
local Shader = require "engine.Shader"
local PC = core.particlescompose
local ig = require "engine.imgui"
local ffi = require "ffi"

--- Particles editor
-- @classmod engine.dialogs.ParticlesComposeEditor
module(..., package.seeall, class.inherit(Dialog))

-- Override paths if editing a module
local filesprefix = ""
local fileswritepath = nil
if __module_extra_info.editmodule then
	local mrpath = fs.getRealPath('/modules/'..__module_extra_info.editmodule..'/')
	if mrpath then
		fs.mount(mrpath, "/editmodule")
		filesprefix = "/editmodule"
		fileswritepath = mrpath
	end
end

local new_default_linear_emitter = {PC.LinearEmitter, {
	{PC.BasicTextureGenerator},
	{PC.FixedColorGenerator, color_stop={1.000000, 1.000000, 1.000000, 0.000000}, color_start={1.000000, 1.000000, 1.000000, 1.000000}},
	{PC.DiskPosGenerator, radius=50.000000},
	{PC.BasicSizeGenerator, max_size=30.000000, min_size=10.000000},
	{PC.DiskVelGenerator, max_vel=150.000000, min_vel=50.000000},
	{PC.LifeGenerator, min=1.000000, max=3.000000},
}, duration=-1.000000, startat=0.000000, nb=10.000000, rate=0.030000 }

local new_default_burst_emitter = {PC.BurstEmitter, {
	{PC.BasicTextureGenerator},
	{PC.FixedColorGenerator, color_stop={1.000000, 1.000000, 1.000000, 0.000000}, color_start={1.000000, 1.000000, 1.000000, 1.000000}},
	{PC.DiskPosGenerator, radius=50.000000},
	{PC.BasicSizeGenerator, max_size=30.000000, min_size=10.000000},
	{PC.DiskVelGenerator, max_vel=150.000000, min_vel=50.000000},
	{PC.LifeGenerator, min=1.000000, max=3.000000},
}, duration=-1.000000, startat=0.000000, nb=10.000000, rate=0.50000, burst=0.15 }

local new_default_buildup_emitter = {PC.BuildupEmitter, {
	{PC.BasicTextureGenerator},
	{PC.FixedColorGenerator, color_stop={1.000000, 1.000000, 1.000000, 0.000000}, color_start={1.000000, 1.000000, 1.000000, 1.000000}},
	{PC.DiskPosGenerator, radius=50.000000},
	{PC.BasicSizeGenerator, max_size=30.000000, min_size=10.000000},
	{PC.DiskVelGenerator, max_vel=150.000000, min_vel=50.000000},
	{PC.LifeGenerator, min=1.000000, max=3.000000},
}, duration=-1.000000, startat=0.000000, nb=10.000000, rate=0.50000, nb_sec=5.000000, rate_sec=-0.150000 }

local new_default_system = {
	max_particles = 100, blend=PC.DefaultBlend, type=PC.RendererPoint,
	texture = "/data/gfx/particle.png",
	emitters = { new_default_linear_emitter },
	updaters = {
		{PC.BasicTimeUpdater},
		{PC.LinearColorUpdater},
		{PC.EulerPosUpdater, global_acc={0.000000, 0.000000}, global_vel={0.000000, 0.000000}},
	},
}

local pdef_history = {}
local pdef_history_pos = 0
local particle_speed = 1
local particle_zoom = 1

local pdef = {
--[[
	parameters = { ty=1.000000, size=100.000000, tx=0.000000 },
	{
		max_particles = 5, blend=PC.ShinyBlend, type=PC.RendererPoint, compute_only=false,
		texture = "/data/gfx/particle.png",
		shader = "particles/glow",
		emitters = {
			{PC.LinearEmitter, {
				{PC.BasicTextureGenerator},
				{PC.LifeGenerator, max=10.000000, duration=10.000000, min=10.000000},
				{PC.CirclePosGenerator, width="size/10", max_angle=6.283185, base_point={0.000000, 0.000000}, radius="size", min_angle=0.000000},
				{PC.DiskVelGenerator, max_vel=30.000000, min_vel=30.000000},
				{PC.BasicSizeGenerator, max_size="sqrt(size)", min_size="sqrt(size)/2"},
				{PC.BasicRotationGenerator, min_rot=0.000000, max_rot=6.283185},
				{PC.FixedColorGenerator, color_stop={0.000000, 1.000000, 0.000000, 0.000000}, color_start={1.000000, 0.843137, 0.000000, 1.000000}},
			}, dormant=false, startat=0.000000, events = { stopping = PC.EventSTOP }, rate=0.030000, triggers = { die = PC.TriggerDELETE }, display_name="active", nb=20.000000, duration=-1.000000 },
			{PC.LinearEmitter, {
				{PC.BasicTextureGenerator},
				{PC.LifeGenerator, max=3.000000, duration=10.000000, min=0.300000},
				{PC.CirclePosGenerator, width=20.000000, max_angle=6.283185, base_point={0.000000, 0.000000}, radius="size+200", min_angle=0.000000},
				{PC.BasicSizeGenerator, max_size=70.000000, min_size=25.000000},
				{PC.BasicRotationGenerator, min_rot=0.000000, max_rot=6.283185},
				{PC.StartStopColorGenerator, min_color_start={0.000000, 0.000000, 0.890196, 1.000000}, max_color_start={0.498039, 1.000000, 0.831373, 1.000000}, max_color_stop={0.000000, 1.000000, 0.000000, 0.000000}, min_color_stop={0.000000, 0.525490, 0.270588, 0.000000}},
				{PC.OriginPosGenerator},
				{PC.DirectionVelGenerator, min_vel=-150.000000, max_vel=-300.000000, from={0.000000, 0.000000}, min_rot=0.000000, max_rot=0.000000},
			}, startat=0.000000, duration=0.000000, rate=0.010000, dormant=true, events = { dying = PC.EventSTART }, triggers = { die = PC.TriggerWAKEUP }, display_name="dying", nb=500.000000, hide=true },
		},
		updaters = {
			{PC.BasicTimeUpdater},
			{PC.BoidPosUpdater, steering_to={"tx", "ty"}},
		},
	},
--]]
--[[
	parameters = { size=300.000000 },
	{
		max_particles = 2000, blend=PC.ShinyBlend,
		texture = "/data/gfx/particle.png",
		shader = "particles/glow",
		emitters = {
			{PC.LinearEmitter, {
				{PC.BasicTextureGenerator},
				{PC.LifeGenerator, max=1.000000, duration=10.000000, min=0.300000},
				{PC.CirclePosGenerator, radius="size", width="size/10"},
				{PC.DiskVelGenerator, max_vel=100.000000, min_vel=30.000000},
				{PC.BasicSizeGenerator, max_size="sqrt(size)*4", min_size="sqrt(size)"},
				{PC.BasicRotationGenerator, min_rot=0.000000, max_rot=6.283185},
				{PC.StartStopColorGenerator, min_color_start={1.000000, 0.843137, 0.000000, 1.000000}, max_color_start={1.000000, 0.466667, 0.000000, 1.000000}, min_color_stop={0.000000, 0.525490, 0.270588, 0.000000}, max_color_stop={0.000000, 1.000000, 0.000000, 0.000000}},
			}, startat=0.000000, dormant=false, duration=-1.000000, rate=0.030000, triggers = { die = PC.TriggerDELETE }, display_name="active", nb=20.000000, events = { stopping = PC.EventSTOP } },
			{PC.LinearEmitter, {
				{PC.BasicTextureGenerator},
				{PC.LifeGenerator, max=3.000000, duration=10.000000, min=0.300000},
				{PC.CirclePosGenerator, radius="size+200", width=20.000000},
				{PC.BasicSizeGenerator, max_size=70.000000, min_size=25.000000},
				{PC.BasicRotationGenerator, min_rot=0.000000, max_rot=6.283185},
				{PC.StartStopColorGenerator, min_color_start={0.000000, 0.000000, 0.890196, 1.000000}, max_color_start={0.498039, 1.000000, 0.831373, 1.000000}, min_color_stop={0.000000, 0.525490, 0.270588, 0.000000}, max_color_stop={0.000000, 1.000000, 0.000000, 0.000000}},
				{PC.OriginPosGenerator},
				{PC.DirectionVelGenerator, max_vel=-300.000000, from={0.000000, 0.000000}, min_vel=-150.000000},
			}, dormant=true, startat=0.000000, duration=0.000000, rate=0.010000, triggers = { die = PC.TriggerWAKEUP }, display_name="dying", nb=500.000000, events = { dying = PC.EventSTART } },
		},
		updaters = {
			{PC.BasicTimeUpdater},
			{PC.LinearColorUpdater, bilinear=true},
			{PC.EulerPosUpdater, global_vel={30.000000, -120.000000}, global_acc={0.000000, 0.000000}},
		},
	},
--]]
--[[
	{
		max_particles = 100, blend=PC.DefaultBlend, type=PC.RendererPoint,
		texture = "/data/gfx/particle.png",
		emitters = {
			{PC.LinearEmitter, {
				{PC.BasicTextureGenerator},
				{PC.FixedColorGenerator, color_stop={0.010336, 0.898438, 0.311387, 0.000000}, color_start={0.274297, 0.871094, 0.040645, 1.000000}},
				{PC.BasicSizeGenerator, max_size=1.000000, min_size=1.000000},
				{PC.LifeGenerator, min=1.000000, max=1.000000},
				{PC.LinePosGenerator, base_point={0.000000, -150.000000}, p1={-300.000000, 0.000000}, p2={300.000000, 0.000000}},
			}, startat=0.000000, duration=-1.000000, rate=0.030000, nb=10.000000, dormant=false },
		},
		updaters = {
			{PC.BasicTimeUpdater},
			{PC.LinearColorUpdater, bilinear=false},
			{PC.EulerPosUpdater, global_acc={0.000000, 0.000000}, global_vel={0.000000, 0.000000}},
		},
	},
	{
		display_name = "unnamed (duplicated)",
		max_particles = 1000, blend=PC.DefaultBlend, type=PC.RendererPoint,
		texture = "/data/gfx/particle.png",
		emitters = {
			{PC.LinearEmitter, {
				{PC.BasicTextureGenerator},
				{PC.FixedColorGenerator, color_stop={0.949219, 0.876301, 0.088785, 0.000000}, color_start={0.890625, 0.079826, 0.079826, 1.000000}},
				{PC.BasicSizeGenerator, max_size=1.000000, min_size=1.000000},
				{PC.LifeGenerator, min=1.000000, max=1.000000},
				{PC.LinePosGenerator, base_point={0.000000, 150.000000}, p1={-300.000000, 0.000000}, p2={300.000000, 0.000000}},
			}, startat=0.000000, duration=-1.000000, rate=0.030000, nb=10.000000, dormant=false },
		},
		updaters = {
			{PC.BasicTimeUpdater},
			{PC.LinearColorUpdater, bilinear=false},
			{PC.EulerPosUpdater, global_vel={0.000000, 0.000000}, global_acc={0.000000, 0.000000}},
		},
	},
	{
		max_particles = 100000, blend=PC.AdditiveBlend, type=PC.RendererLine,
		texture = "/data/gfx/particles_textures/line2.png",
		shader = "particles/linenormal",
		emitters = {
			{PC.LinearEmitter, {
				{PC.BasicTextureGenerator},
				{PC.BasicSizeGenerator, max_size=30.000000, min_size=10.000000},
				{PC.LifeGenerator, min=0.500000, max=0.500000},
				{PC.JaggedLineBetweenGenerator, sway=80.000000, source_system2=2.000000, close_tries=0.000000, copy_color=true, strands=1.000000, repeat_times=1.000000, source_system1=1.000000, copy_pos=true},
			}, startat=0.000000, duration=-1.000000, rate=0.300000, nb=10.000000, dormant=false },
		},
		updaters = {
			{PC.BasicTimeUpdater},
			{PC.LinearColorUpdater, bilinear=false},
			{PC.EulerPosUpdater, global_acc={0.000000, 0.000000}, global_vel={0.000000, 0.000000}},
		},
	},
--]]
--[[
	parameters = { ty=0.000000, size=300.000000, tx=500.000000 },
	{
		max_particles = 10000, blend=PC.AdditiveBlend, type=PC.RendererLine,
		texture = "/data/gfx/particles_textures/line2.png",
		shader = "particles/lineglow",
		emitters = {
			{PC.LinearEmitter, {
				{PC.BasicTextureGenerator},
				{PC.LifeGenerator, max=1.000000, duration=10.000000, min=1.000000},
				{PC.JaggedLinePosGenerator, sway=80.000000, p1={0.000000, 0.000000}, base_point={0.000000, 0.000000}, strands=1.000000, p2={400.000000, 0.000000}},
				{PC.DiskVelGenerator, max_vel=1.000000, min_vel=1.000000},
				{PC.BasicSizeGenerator, max_size=10.000000, min_size=10.000000},
				{PC.StartStopColorGenerator, min_color_start={1.000000, 0.843137, 0.000000, 1.000000}, max_color_start={1.000000, 0.466667, 0.000000, 1.000000}, min_color_stop={0.088228, 0.984375, 0.549677, 1.000000}, max_color_stop={0.000000, 1.000000, 0.000000, 1.000000}},
			}, startat=0.000000, duration=-1.000000, rate=2.000000, dormant=false, events = { stopping = PC.EventSTOP }, triggers = { die = PC.TriggerDELETE }, display_name="active", nb=20.000000, hide=false },
		},
		updaters = {
			{PC.BasicTimeUpdater},
			{PC.LinearColorUpdater, bilinear=false},
		},
	},
--]]
-- [[
	parameters = { tx=600, ty=0, angle=0, size=600 },
	{
		display_name = "buildup",
		max_particles = 100, blend=PC.AdditiveBlend,
		texture = "/data/gfx/particles_textures/directional_particle.png",
		shader = "particles/glow",
		emitters = {
			{PC.LinearEmitter, {
				{PC.BasicTextureGenerator},
				{PC.FixedColorGenerator, color_stop={0.968750, 0.927885, 0.041418, 0.000000}, color_start={0.914062, 0.307196, 0.053362, 1.000000}},
				{PC.BasicSizeGenerator, max_size=8.000000, min_size=4.000000},
				{PC.LifeGenerator, min=0.200000, max=0.600000},
				{PC.RotationByVelGenerator, min_rot=0.000000, max_rot=0.000000},
				{PC.CirclePosGenerator, width=20.000000, max_angle="angle+pi*0.7", base_point={0.000000, 0.000000}, radius=150.000000, min_angle="angle-pi*0.7"},
				{PC.DirectionVelGenerator, max_vel=-190.000000, from={0.000000, 0.000000}, min_vel=-160.000000},
				{PC.OriginPosGenerator},
			}, startat=0.000000, duration=-1.000000, rate=0.030000, triggers = { die = PC.TriggerDELETE }, nb=10.000000, dormant=false },
		},
		updaters = {
			{PC.BasicTimeUpdater},
			{PC.LinearColorUpdater, bilinear=true},
			{PC.EulerPosUpdater, global_acc={0.000000, 0.000000}, global_vel={0.000000, 0.000000}},
			{PC.NoisePosUpdater, amplitude={200.000000, 200.000000}, noise="/data/gfx/particles_textures/noises/turbulent.png", traversal_speed=1.000000},
		},
	},
	{
		display_name = "beam",
		max_particles = 250, blend=PC.AdditiveBlend,
		texture = "/data/gfx/particles_textures/particle_boom_anim.png",
		shader = "particles/glow",
		emitters = {
			{PC.LinearEmitter, {
				{PC.BasicTextureGenerator},
				{PC.FixedColorGenerator, color_stop={0.953125, 0.510159, 0.051919, 0.000000}, color_start={0.933594, 0.735687, 0.473890, 1.000000}},
				{PC.LifeGenerator, min=0.400000, max=0.800000},
				{PC.LinePosGenerator, p2={"tx", "ty"}, p1={"ty/sqrt(tx*tx+ty*ty)*15", "-tx/sqrt(tx*tx+ty*ty)*15"}, base_point={0, 0}},
				{PC.DirectionVelGenerator, max_vel=150.000000, from={20.000000, 0.000000}, min_vel=50.000000},
				{PC.StartStopSizeGenerator, min_start_size=20.000000, min_stop_size=1.000000, max_stop_size=3.000000, max_start_size=30.000000},
			}, startat=0.000000, duration=-1.000000, rate=0.030000, triggers = { die = PC.TriggerDELETE }, display_name="top arm", nb=7.000000, dormant=false },
			{PC.LinearEmitter, {
				{PC.BasicTextureGenerator},
				{PC.FixedColorGenerator, color_stop={0.953125, 0.510159, 0.051919, 0.000000}, color_start={0.933594, 0.735687, 0.473890, 1.000000}},
				{PC.LifeGenerator, min=0.400000, max=0.800000},
				{PC.LinePosGenerator, p2={"tx", "ty"}, p1={"-ty/sqrt(tx*tx+ty*ty)*15", "tx/sqrt(tx*tx+ty*ty)*15"}, base_point={0, 0}},
				{PC.DirectionVelGenerator, max_vel=150.000000, from={20.000000, 0.000000}, min_vel=50.000000},
				{PC.StartStopSizeGenerator, min_start_size=20.000000, min_stop_size=1.000000, max_stop_size=3.000000, max_start_size=30.000000},
			}, dormant=false, duration=-1.000000, rate=0.030000, startat=0.000000, display_name="bottom arm", nb=7.000000, triggers = { die = PC.TriggerDELETE } },
		},
		updaters = {
			{PC.BasicTimeUpdater},
			{PC.LinearColorUpdater, bilinear=false},
			{PC.EulerPosUpdater, global_acc={0.000000, 0.000000}, global_vel={0.000000, 0.000000}},
			{PC.AnimatedTextureUpdater, splity=5.000000, repeat_over_life=1.000000, splitx=5.000000, firstframe=0.000000, lastframe=22.000000},
			{PC.EasingSizeUpdater, easing="inCubic"},
		},
	},
--]]
--[[
	parameters = { ty=0.000000, size=300.000000, tx=500.000000 },
	{
		max_particles = 2000, blend=PC.DefaultBlend, type=PC.RendererPoint,
		texture = "/data/gfx/particle.png",
		emitters = {
			{PC.LinearEmitter, {
				{PC.BasicTextureGenerator},
				{PC.FixedColorGenerator, color_stop={1.000000, 1.000000, 1.000000, 0.000000}, color_start={1.000000, 1.000000, 1.000000, 1.000000}},
				{PC.BasicSizeGenerator, max_size=0.000010, min_size=0.000010},
				{PC.DiskVelGenerator, max_vel=5.000000, min_vel=5.000000},
				{PC.LifeGenerator, min=0.100000, max=0.100000},
				{PC.CirclePosGenerator, width=20.000000, max_angle=6.283185, base_point={0.000000, 0.000000}, radius=60.000000, min_angle=0.000000},
			}, startat=0.000000, duration=-1.000000, rate=0.010000, nb=10.000000, dormant=false },
		},
		updaters = {
			{PC.BasicTimeUpdater},
			{PC.LinearColorUpdater, bilinear=false},
			{PC.EulerPosUpdater, global_vel={0.000000, 0.000000}, global_acc={0.000000, 0.000000}},
		},
	},
	{
		max_particles = 10000, blend=PC.AdditiveBlend, type=PC.RendererLine,
		texture = "/data/gfx/particles_textures/line2.png",
		shader = "particles/lineglow",
		emitters = {
			{PC.LinearEmitter, {
				{PC.BasicTextureGenerator},
				{PC.LifeGenerator, max=0.300000, duration=10.000000, min=0.300000},
				{PC.DiskVelGenerator, max_vel=40.000000, min_vel=0.000000},
				{PC.BasicSizeGenerator, max_size=10.000000, min_size=1.000000},
				{PC.StartStopColorGenerator, min_color_start={0.000000, 0.938983, 1.000000, 1.000000}, max_color_start={0.000000, 1.000000, 0.898305, 1.000000}, min_color_stop={0.088228, 0.947922, 0.984375, 0.003086}, max_color_stop={0.000000, 0.776271, 1.000000, 0.003086}},
				{PC.JaggedLineBetweenGenerator, sway=80.000000, copy_pos=true, copy_color=true, source_system1=1.000000, source_system2=1.000000},
			}, startat=0.000000, duration=-1.000000, rate=0.010000, dormant=false, events = { stopping = PC.EventSTOP }, triggers = { die = PC.TriggerDELETE }, display_name="active", nb=20.000000, hide=false },
			-- {PC.LinearEmitter, {
			-- 	{PC.BasicTextureGenerator},
			-- 	{PC.LifeGenerator, max=0.300000, duration=10.000000, min=0.300000},
			-- 	{PC.DiskVelGenerator, max_vel=0.000000, min_vel=40.000000},
			-- 	{PC.BasicSizeGenerator, max_size=10.000000, min_size=1.000000},
			-- 	{PC.StartStopColorGenerator, min_color_start={1.000000, 0.142373, 0.000000, 1.000000}, max_color_stop={1.000000, 0.335593, 0.000000, 0.003086}, min_color_stop={0.984375, 0.598576, 0.088228, 0.003086}, max_color_start={1.000000, 0.466667, 0.000000, 1.000000}},
			-- 	{PC.JaggedLineBetweenGenerator, sway=80.000000, copy_pos=true, source_system1=1.000000, source_system2=1.000000, copy_color=true},
			-- }, startat=0.000000, duration=-1.000000, rate=0.010000, dormant=false, events = { stopping = PC.EventSTOP }, triggers = { die = PC.TriggerDELETE }, display_name="active (duplicated)", nb=20.000000, hide=false },
		},
		updaters = {
			{PC.BasicTimeUpdater},
			{PC.LinearColorUpdater, bilinear=true},
			{PC.EulerPosUpdater, global_acc={0.000000, 0.000000}, global_vel={0.000000, 0.000000}},
		},
	},
--]]
--[[
	parameters = { ty=0.000000, size=300.000000, tx=500.000000 },
	{
		display_name = "ring source",
		max_particles = 2000, blend=PC.DefaultBlend, type=PC.RendererPoint,
		texture = "/data/gfx/particle.png",
		emitters = {
			{PC.LinearEmitter, {
				{PC.BasicTextureGenerator},
				{PC.FixedColorGenerator, color_stop={1.000000, 1.000000, 1.000000, 0.000000}, color_start={1.000000, 1.000000, 1.000000, 1.000000}},
				{PC.BasicSizeGenerator, max_size=0.000010, min_size=0.000010},
				{PC.DiskVelGenerator, max_vel=5.000000, min_vel=5.000000},
				{PC.LifeGenerator, min=0.100000, max=0.100000},
				{PC.CirclePosGenerator, width=20.000000, max_angle=6.283185, base_point={0.000000, 0.000000}, radius=150.000000, min_angle=0.000000},
			}, startat=0.000000, duration=-1.000000, rate=0.010000, nb=10.000000, dormant=false },
		},
		updaters = {
			{PC.BasicTimeUpdater},
			{PC.LinearColorUpdater, bilinear=false},
			{PC.EulerPosUpdater, global_vel={0.000000, 0.000000}, global_acc={0.000000, 0.000000}},
		},
	},
	{
		display_name = "center source",
		max_particles = 2000, blend=PC.DefaultBlend, type=PC.RendererPoint,
		texture = "/data/gfx/particle.png",
		emitters = {
			{PC.LinearEmitter, {
				{PC.BasicTextureGenerator},
				{PC.FixedColorGenerator, color_stop={1.000000, 1.000000, 1.000000, 0.000000}, color_start={1.000000, 1.000000, 1.000000, 1.000000}},
				{PC.BasicSizeGenerator, max_size=0.000010, min_size=0.000010},
				{PC.DiskVelGenerator, max_vel=5.000000, min_vel=5.000000},
				{PC.LifeGenerator, min=0.100000, max=0.100000},
				{PC.CirclePosGenerator, width=10.000000, max_angle=6.283185, base_point={0.000000, 0.000000}, radius=80.000000, min_angle=0.000000},
			}, startat=0.000000, duration=-1.000000, rate=0.010000, nb=10.000000, dormant=false },
		},
		updaters = {
			{PC.BasicTimeUpdater},
			{PC.LinearColorUpdater, bilinear=false},
			{PC.EulerPosUpdater, global_acc={0.000000, 0.000000}, global_vel={0.000000, 0.000000}},
		},
	},
	{
		display_name = "lightnings",
		max_particles = 10000, blend=PC.AdditiveBlend, type=PC.RendererLine,
		texture = "/data/gfx/particles_textures/line2.png",
		shader = "particles/lineglow",
		emitters = {
			{PC.LinearEmitter, {
				{PC.BasicTextureGenerator},
				{PC.LifeGenerator, max=0.300000, duration=10.000000, min=0.300000},
				{PC.DiskVelGenerator, max_vel=40.000000, min_vel=0.000000},
				{PC.BasicSizeGenerator, max_size=10.000000, min_size=1.000000},
				{PC.StartStopColorGenerator, min_color_start={0.000000, 0.938983, 1.000000, 1.000000}, max_color_start={0.000000, 1.000000, 0.898305, 1.000000}, min_color_stop={0.088228, 0.947922, 0.984375, 0.003086}, max_color_stop={0.000000, 0.776271, 1.000000, 0.003086}},
				{PC.JaggedLineBetweenGenerator, sway=80.000000, copy_pos=true, source_system1=2.000000, strands=1.000000, copy_color=true, source_system2=1.000000},
			}, startat=0.000000, duration=-1.000000, rate=0.010000, dormant=false, events = { stopping = PC.EventSTOP }, triggers = { die = PC.TriggerDELETE }, display_name="active", nb=20.000000, hide=false },
			{PC.LinearEmitter, {
				{PC.BasicTextureGenerator},
				{PC.LifeGenerator, max=0.300000, duration=10.000000, min=0.300000},
				{PC.DiskVelGenerator, max_vel=40.000000, min_vel=0.000000},
				{PC.BasicSizeGenerator, max_size=10.000000, min_size=1.000000},
				{PC.StartStopColorGenerator, min_color_start={0.788235, 0.000000, 0.000000, 1.000000}, max_color_stop={0.843137, 0.421569, 0.000000, 1.000000}, min_color_stop={1.000000, 0.514469, 0.089628, 1.000000}, max_color_start={0.862745, 0.000000, 0.172549, 1.000000}},
				{PC.JaggedLineBetweenGenerator, sway=80.000000, copy_pos=true, source_system1=2.000000, strands=1.000000, source_system2=1.000000, copy_color=true},
			}, startat=0.000000, duration=-1.000000, rate=0.010000, dormant=false, events = { stopping = PC.EventSTOP }, triggers = { die = PC.TriggerDELETE }, display_name="active (duplicated)", nb=20.000000, hide=false },
		},
		updaters = {
			{PC.BasicTimeUpdater},
			{PC.LinearColorUpdater, bilinear=true},
			{PC.EulerPosUpdater, global_acc={0.000000, 0.000000}, global_vel={0.000000, 0.000000}},
		},
	},
--]]
--[[
	{
		max_particles = 10000, blend=PC.DefaultBlend, type=PC.RendererPoint,
		texture = "/data/gfx/particle.png",
		emitters = {
			{PC.LinearEmitter, {
				{PC.BasicTextureGenerator},
				{PC.FixedColorGenerator, color_stop={1.000000, 1.000000, 1.000000, 0.000000}, color_start={1.000000, 1.000000, 1.000000, 1.000000}},
				{PC.BasicSizeGenerator, max_size=1.000000, min_size=1.000000},
				{PC.DiskVelGenerator, max_vel=0.000000, min_vel=0.000000},
				{PC.LifeGenerator, min=0.100000, max=1.000000},
				{PC.ImagePosGenerator, base_point={0.000000, 0.000000}},
			}, startat=0.000000, duration=-1.000000, rate=0.010000, nb=10.000000, dormant=false },
		},
		updaters = {
			{PC.BasicTimeUpdater},
			{PC.LinearColorUpdater, bilinear=false},
			{PC.EulerPosUpdater, global_acc={0.000000, 0.000000}, global_vel={0.000000, 0.000000}},
		},
	},
--]]
--[[
	parameters = { h=1020.000000, intensity=1.000000, w=1920.000000 },
	{
		max_particles = 800, blend=PC.ShinyBlend, type=PC.RendererPoint, compute_only=false,
		texture = "/data/gfx/particles_textures/lens_flare.png",
		emitters = {
			{PC.LinearEmitter, {
				{PC.BasicTextureGenerator},
				{PC.BasicSizeGenerator, max_size=20.000000, min_size=3.000000},
				{PC.LifeGenerator, min=20.000000, max=20.000000},
				{PC.LinePosGenerator, base_point={"w/2", "-h/2"}, p1={0.000000, 0.000000}, p2={1.000000, "h"}},
				{PC.DirectionVelGenerator, min_vel="-w/20", max_vel="-w/20-150", from={-10000.000000, 0.000000}, min_rot=0.000000, max_rot=0.000000},
				{PC.FixedColorGenerator, color_stop={0.968783, 0.984375, 0.968783, 1.000000}, color_start={0.984375, 0.980723, 0.961092, 1.000000}},
				{PC.ParametrizerGenerator, name="intensity", expr="rng(1,10)"},
			}, startat=0.000000, duration=-1.000000, rate=0.100000, nb=3.000000, dormant=false },
		},
		updaters = {
			{PC.BasicTimeUpdater},
			{PC.LinearColorUpdater, bilinear=false},
			{PC.EulerPosUpdater, global_vel={0.000000, 0.000000}, global_acc={0.000000, 0.000000}},
		},
	},
--]]
--[[
	{
		max_particles = 100, blend=PC.DefaultBlend, type=PC.RendererPoint, compute_only=false,
		texture = "/data/gfx/particle.png",
		emitters = {
			{PC.LinearEmitter, {
				{PC.BasicTextureGenerator},
				{PC.FixedColorGenerator, color_stop={1.000000, 1.000000, 1.000000, 0.000000}, color_start={1.000000, 1.000000, 1.000000, 1.000000}},
				{PC.DiskPosGenerator, base_point={0.000000, 0.000000}, max_angle=6.283185, radius=5.000000, min_angle=0.000000},
				{PC.BasicSizeGenerator, max_size=30.000000, min_size=10.000000},
				{PC.LifeGenerator, min=1.000000, max=1.000000},
				{PC.DirectionVelGenerator, min_vel=200.000000, max_vel=200.000000, from={-10000.000000, 0.000000}, min_rot=0.000000, max_rot=0.000000},
				{PC.OriginPosGenerator},
			}, startat=0.000000, duration=-1.000000, rate=0.030000, nb=1.000000, dormant=false },
		},
		updaters = {
			{PC.BasicTimeUpdater},
			{PC.LinearColorUpdater, bilinear=false},
			{PC.MathPosUpdater, expr_x="t*dx", expr_y="t*dy"},
		},
	},
--]]
}

local typemodes = {
	{name="RendererPoint", type=PC.RendererPoint},
	{name="RendererLine", type=PC.RendererLine},
}
local type_by_id = table.map(function(k, v) return v.type, v.name end, typemodes)

local blendmodes = {
	{name="DefaultBlend", blend=PC.DefaultBlend},
	{name="AdditiveBlend", blend=PC.AdditiveBlend},
	{name="MixedBlend", blend=PC.MixedBlend},
	{name="ShinyBlend", blend=PC.ShinyBlend},
}
local blend_by_id = table.map(function(k, v) return v.blend, v.name end, blendmodes)

local triggermodes = {
	{name="Delete", trigger=PC.TriggerDELETE, kind="TriggerDELETE"},
	{name="Wakeup", trigger=PC.TriggerWAKEUP, kind="TriggerWAKEUP"},
	{name="Force emit", trigger=PC.TriggerFORCE, kind="TriggerFORCE"},
}
local trigger_by_id = table.map(function(k, v) return v.trigger, v.name end, triggermodes)
local triggerkind_by_id = table.map(function(k, v) return v.trigger, v.kind end, triggermodes)


local eventmodes = {
	{name="On Start", event=PC.EventSTART, kind="EventSTART"},
	{name="On Emit", event=PC.EventEMIT, kind="EventEMIT"},
	{name="On Stop", event=PC.EventSTOP, kind="EventSTOP"},
}
local event_by_id = table.map(function(k, v) return v.event, v.name end, eventmodes)
local eventkind_by_id = table.map(function(k, v) return v.event, v.kind end, eventmodes)

local easings = {
	{name="linear"},
	{name="inQuad"},
	{name="outQuad"},
	{name="inOutQuad"},
	{name="inCubic"},
	{name="outCubic"},
	{name="inOutCubic"},
	{name="inQuart"},
	{name="outQuart"},
	{name="inOutQuart"},
	{name="inQuint"},
	{name="outQuint"},
	{name="inOutQuint"},
	{name="inSine"},
	{name="outSine"},
	{name="inOutSine"},
	{name="inExpo"},
	{name="outExpo"},
	{name="inOutExpo"},
	{name="inCirc"},
	{name="outCirc"},
	{name="inOutCirc"},
	{name="inElastic"},
	{name="outElastic"},
	{name="inOutElastic"},
	{name="inBack"},
	{name="outBack"},
	{name="inOutBack"},
	{name="inBounce"},
	{name="outBounce"},
	{name="inOutBounce"},
}

local specific_uis = {
	emitters = {
		[PC.LinearEmitter] = {name="LinearEmitter", category="emitter", addnew=new_default_linear_emitter, fields={
			{type="number", id="rate", text="Triggers every seconds", min=0, max=600, default=0.033, line=true},
			{type="number", id="nb", text="Particles per trigger", min=0, max=100000, default=30, line=true},
			{type="number", id="startat", text="Start at second", min=0, max=600, default=0, line=true},
			{type="number", id="duration", text="Work for seconds (-1 for infinite)", min=-1, max=600, default=-1, line=true},
			{type="bool", id="dormant", text="Dormant (needs trigger to wakeup)", default=false},
			{type="invisible", id=2, default={}},
		}},
		[PC.BurstEmitter] = {name="BurstEmitter", category="emitter", addnew=new_default_burst_emitter, fields={
			{type="number", id="rate", text="Burst every seconds", min=0, max=600, default=0.5, line=true},
			{type="number", id="burst", text="Burst for seconds", min=0, max=600, default=0.15, line=true},
			{type="number", id="nb", text="Particles per burst", min=0, max=100000, default=10, line=true},
			{type="number", id="startat", text="Start at second", min=0, max=600, default=0, line=true},
			{type="number", id="duration", text="Work for seconds (-1 for infinite)", min=-1, max=600, default=-1, line=true},
			{type="bool", id="dormant", text="Dormant (needs trigger to wakeup)", default=false},
			{type="invisible", id=2, default={}},
		}},
		[PC.BuildupEmitter] = {name="BuildupEmitter", category="emitter", addnew=new_default_buildup_emitter, fields={
			{type="number", id="rate", text="Triggers every seconds", min=0, max=600, default=0.5, line=true},
			{type="number", id="rate_sec", text="Triggers/sec increase/sec", min=-600, max=600, default=0.15, line=true},
			{type="number", id="nb", text="Particles per trigger", min=0, max=100000, default=10, line=true},
			{type="number", id="nb_sec", text="Particles/trig increase/sec", min=-100000, max=100000, default=5, line=true},
			{type="number", id="startat", text="Start at second", min=0, max=600, default=0, line=true},
			{type="number", id="duration", text="Work for seconds (-1 for infinite)", min=-1, max=600, default=-1, line=true},
			{type="bool", id="dormant", text="Dormant (needs trigger to wakeup)", default=false},
			{type="invisible", id=2, default={}},
		}},
	},
	generators = {
		[PC.LifeGenerator] = {name="LifeGenerator", category="life", fields={
			{type="number", id="min", text="Min seconds", min=0.00001, max=600, default=1},
			{type="number", id="max", text="Max seconds", min=0.00001, max=600, default=3},
		}},
		[PC.BasicTextureGenerator] = {name="BasicTextureGenerator", category="texture", fields={}},
		[PC.OriginPosGenerator] = {name="OriginPosGenerator", category="position", fields={}},
		[PC.SquarePosGenerator] = {name="SquarePosGenerator", category="position", fields={
			{type="point", id="base_point", text="Origin", min=-10000, max=10000, default={0, 0}, line=true},
			{type="number", id="min_x", text="MinX", min=-10000, max=10000, default=-100},
			{type="number", id="max_x", text="MaxX", min=-10000, max=10000, default=-100, line=true},
			{type="number", id="min_y", text="MinY", min=-10000, max=10000, default=-100},
			{type="number", id="max_y", text="MaxY", min=-10000, max=10000, default=-100, line=true},
		}},
		[PC.DiskPosGenerator] = {name="DiskPosGenerator", category="position", fields={
			{type="point", id="base_point", text="Origin", min=-10000, max=10000, default={0, 0}, line=true},
			{type="number", id="radius", text="Radius", min=0, max=10000, default=150, line=true},
			{type="number", id="min_angle", text="Min angle", min=-math.pi*2, max=math.pi*2, default=0, from=function(v) return (type(v) == "number" or tonumber(v)) and math.rad(v) or v end, to=function(v) return (type(v) == "number" or tonumber(v)) and math.deg(v) or v end},
			{type="number", id="max_angle", text="Max angle", min=-math.pi*2, max=math.pi*2, default=math.pi*2, from=function(v) return (type(v) == "number" or tonumber(v)) and math.rad(v) or v end, to=function(v) return (type(v) == "number" or tonumber(v)) and math.deg(v) or v end},
		}},
		[PC.CirclePosGenerator] = {name="CirclePosGenerator", category="position", fields={
			{type="point", id="base_point", text="Origin", min=-10000, max=10000, default={0, 0}, line=true},
			{type="number", id="radius", text="Radius", min=0, max=10000, default=150},
			{type="number", id="width", text="Width", min=0, max=10000, default=20, line=true},
			{type="number", id="min_angle", text="Min angle", min=-math.pi*2, max=math.pi*2, default=0, from=function(v) print("!!!!", type(v) == "number", tonumber(v), v) return (type(v) == "number" or tonumber(v)) and math.rad(v) or v end, to=function(v) return (type(v) == "number" or tonumber(v)) and math.deg(v) or v end},
			{type="number", id="max_angle", text="Max angle", min=-math.pi*2, max=math.pi*2, default=math.pi*2, from=function(v) return (type(v) == "number" or tonumber(v)) and math.rad(v) or v end, to=function(v) return (type(v) == "number" or tonumber(v)) and math.deg(v) or v end},
		}},
		[PC.TrianglePosGenerator] = {name="TrianglePosGenerator", category="position", fields={
			{type="point", id="base_point", text="Origin", min=-10000, max=10000, default={0, 0}, line=true},
			{type="point", id="p1", text="P1", min=-10000, max=10000, default={0, 0}, line=true},
			{type="point", id="p2", text="P2", min=-10000, max=10000, default={100, 100}, line=true},
			{type="point", id="p3", text="P3", min=-10000, max=10000, default={-100, 100}},
		}},
		[PC.LinePosGenerator] = {name="LinePosGenerator", category="position", fields={
			{type="point", id="base_point", text="Origin", min=-10000, max=10000, default={0, 0}, line=true},
			{type="point", id="p1", text="P1", min=-10000, max=10000, default={0, 0}, line=true},
			{type="point", id="p2", text="P2", min=-10000, max=10000, default={100, 100}, line=true},
			{type="number", id="spread", text="Spread", min=0, max=10000, default=0},
		}},
		[PC.JaggedLinePosGenerator] = {name="JaggedLinePosGenerator", category="position", fields={
			{type="point", id="base_point", text="Origin", min=-10000, max=10000, default={0, 0}, line=true},
			{type="point", id="p1", text="P1", min=-10000, max=10000, default={0, 0}, line=true},
			{type="point", id="p2", text="P2", min=-10000, max=10000, default={100, 100}, line=true},
			{type="number", id="spread", text="Spread", min=0, max=10000, default=0, line=true},
			{type="number", id="sway", text="Sway", min=0, max=10000, default=80},
			{type="number", id="strands", text="strands", min=1, max=10000, default=1},
		}},
		[PC.ImagePosGenerator] = {name="ImagePosGenerator", category="position", fields={
			{type="file", id="image", text="Image", dir="/data/gfx/particles_masks/", filter="%.png$", default="/data/gfx/particles_masks/tome.png", line=true},
			{type="point", id="base_point", text="Origin", min=-10000, max=10000, default={0, 0}, line=true},
		}},
		[PC.DiskVelGenerator] = {name="DiskVelGenerator", category="movement", fields={
			{type="number", id="min_vel", text="Min velocity", min=0, max=1000, default=50},
			{type="number", id="max_vel", text="Max velocity", min=0, max=1000, default=150},
		}},
		[PC.DirectionVelGenerator] = {name="DirectionVelGenerator", category="movement", fields={
			{type="point", id="from", text="From", min=-10000, max=10000, default={0, 0}, line=true},
			{type="number", id="min_vel", text="Min velocity", min=-1000, max=1000, default=50},
			{type="number", id="max_vel", text="Max velocity", min=-1000, max=1000, default=150, line=true},
			{type="number", id="min_rot", text="Min rotation", min=-math.pi*2, max=math.pi*2, default=0, from=function(v) return (type(v) == "number" or tonumber(v)) and math.rad(v) or v end, to=function(v) return (type(v) == "number" or tonumber(v)) and math.deg(v) or v end},
			{type="number", id="max_rot", text="Max rotation", min=-math.pi*2, max=math.pi*2, default=0, from=function(v) return (type(v) == "number" or tonumber(v)) and math.rad(v) or v end, to=function(v) return (type(v) == "number" or tonumber(v)) and math.deg(v) or v end},
		}},
		[PC.SwapPosByVelGenerator] = {name="SwapPosByVelGenerator", category="movement", fields={
		}},
		[PC.BasicSizeGenerator] = {name="BasicSizeGenerator", category="size", fields={
			{type="number", id="min_size", text="Min size", min=0.00001, max=1000, default=10},
			{type="number", id="max_size", text="Max size", min=0.00001, max=1000, default=30},
		}},
		[PC.StartStopSizeGenerator] = {name="StartStopSizeGenerator", category="size", fields={
			{type="number", id="min_start_size", text="Min start", min=0.00001, max=1000, default=10},
			{type="number", id="max_start_size", text="Max start", min=0.00001, max=1000, default=30, line=true},
			{type="number", id="min_stop_size", text="Min stop", min=0.00001, max=1000, default=1},
			{type="number", id="max_stop_size", text="Max stop", min=0.00001, max=1000, default=3},
		}},
		[PC.BasicRotationGenerator] = {name="BasicRotationGenerator", category="rotation", fields={
			{type="number", id="min_rot", text="Min rotation", min=0, max=math.pi*2, default=0, from=function(v) return (type(v) == "number" or tonumber(v)) and math.rad(v) or v end, to=function(v) return (type(v) == "number" or tonumber(v)) and math.deg(v) or v end},
			{type="number", id="max_rot", text="Max rotation", min=0, max=math.pi*2, default=math.pi*2, from=function(v) return (type(v) == "number" or tonumber(v)) and math.rad(v) or v end, to=function(v) return (type(v) == "number" or tonumber(v)) and math.deg(v) or v end},
		}},
		[PC.RotationByVelGenerator] = {name="RotationByVelGenerator", category="rotation", fields={
			{type="number", id="min_rot", text="Min rotation", min=0, max=math.pi*2, default=0, from=function(v) return (type(v) == "number" or tonumber(v)) and math.rad(v) or v end, to=function(v) return math.deg(v) end},
			{type="number", id="max_rot", text="Max rotation", min=0, max=math.pi*2, default=0, from=function(v) return (type(v) == "number" or tonumber(v)) and math.rad(v) or v end, to=function(v) return math.deg(v) end},
		}},
		[PC.BasicRotationVelGenerator] = {name="BasicRotationVelGenerator", category="rotation", fields={
			{type="number", id="min_rot", text="Min rotation velocity", min=0, max=math.pi*2, default=0, from=function(v) return (type(v) == "number" or tonumber(v)) and math.rad(v) or v end, to=function(v) return (type(v) == "number" or tonumber(v)) and math.deg(v) or v end},
			{type="number", id="max_rot", text="Max rotation velocity", min=0, max=math.pi*2, default=math.pi*2, from=function(v) return (type(v) == "number" or tonumber(v)) and math.rad(v) or v end, to=function(v) return (type(v) == "number" or tonumber(v)) and math.deg(v) or v end},
		}},
		[PC.StartStopColorGenerator] = {name="StartStopColorGenerator", category="color", fields={
			{type="color", id="min_color_start", text="Min start color", default=colors_alphaf.GOLD(1)},
			{type="color", id="max_color_start", text="Max start color", default=colors_alphaf.ORANGE(1), line=true},
			{type="color", id="min_color_stop", text="Min stop color", default=colors_alphaf.GREEN(0)},
			{type="color", id="max_color_stop", text="Max stop color", default=colors_alphaf.LIGHT_GREEN(0)},
		}},
		[PC.FixedColorGenerator	] = {name="FixedColorGenerator", category="color", fields={
			{type="color", id="color_start", text="Start color", default=colors_alphaf.GOLD(1)},
			{type="color", id="color_stop", text="Stop color", default=colors_alphaf.LIGHT_GREEN(0)},
		}},
		[PC.CopyGenerator] = {name="CopyGenerator", category="special", fields={
			{type="number", id="source_system", text="Source system ID", min=1, max=100, default=1},
			{type="bool", id="copy_pos", text="Copy position", default=true},
			{type="bool", id="copy_color", text="Copy color", default=true},
		}},
		[PC.JaggedLineBetweenGenerator] = {name="JaggedLineBetweenGenerator", category="special", fields={
			{type="number", id="source_system1", text="Source system1 ID", min=1, max=100, default=1},
			{type="number", id="source_system2", text="Source system2 ID", min=1, max=100, default=1, line=true},
			{type="bool", id="copy_pos", text="Copy position", default=true},
			{type="bool", id="copy_color", text="Copy color", default=true, line=true},
			{type="number", id="sway", text="Sway", min=0, max=10000, default=80},
			{type="number", id="strands", text="Strands", min=1, max=10000, default=1, line=true},
			{type="number", id="close_tries", text="Pick closer tries", min=0, max=200, default=0},
			{type="number", id="repeat_times", text="Repeat", min=1, max=1000, default=1},
		}},
		[PC.ParametrizerGenerator] = {name="ParametrizerGenerator", category="special", fields={
			{type="string", id="name", text="Parameter name", default="p1", line=true},
			{type="string", id="expr", chars=40, text="Expr", default="rng(1, 10)"},
		}},
	},
	updaters = {
		[PC.BasicTimeUpdater] = {name="BasicTimeUpdater", category="life", fields={}},
		[PC.AnimatedTextureUpdater] = {name="AnimatedTextureUpdater", category="texture", fields={
			{type="number", id="splitx", text="Texture Columns", min=1, max=100, default=1},
			{type="number", id="splity", text="Texture Lines", min=1, max=100, default=1, line=true},
			{type="number", id="firstframe", text="First frame", min=0, max=10000, default=0},
			{type="number", id="lastframe", text="Last frame", min=0, max=10000, default=0, line=true},
			{type="number", id="repeat_over_life", text="Repeat over lifetime", min=0, max=10000, default=1},
		}},
		[PC.MathPosUpdater] = {name="MathPosUpdater", category="position & movement", fields={
			{type="string", chars=40, id="expr_x", text="Expr X", default="t*dx", line=true},
			{type="string", chars=40, id="expr_y", text="Expr Y", default="t*dy"},
		}},
		[PC.EulerPosUpdater] = {name="EulerPosUpdater", category="position & movement", fields={
			{type="point", id="global_vel", text="Velocity", min=-10000, max=10000, default={0, 0}},
			{type="point", id="global_acc", text="Acceleration", min=-10000, max=10000, default={0, 0}},
		}},
		[PC.EasingPosUpdater] = {name="EasingPosUpdater", category="position & movement", fields={
			{type="select", id="easing", text="Easing method", list=easings, default="outQuad"},
		}},
		[PC.BoidPosUpdater] = {name="BoidPosUpdater", category="position & movement", fields={
			{type="number", id="perception_radius", text="Perception Radius", min=-10000, max=10000, default=50, line=true},
			{type="number", id="separation_weight", text="Separation Weight", min=-10000, max=10000, default=1, line=true},
			{type="number", id="alignment_weight", text="Alignment Weight", min=-10000, max=10000, default=1, line=true},
			{type="number", id="cohesion_weight", text="Cohesion Weight", min=-10000, max=10000, default=1, line=true},
			{type="number", id="steering_weight", text="Steering Weight", min=-10000, max=10000, default=0, line=true},
			{type="point", id="steering_to", text="Steering to", min=-10000, max=10000, default={500, 500}, line=true},
			{type="number", id="max_acceleration", text="Max Acceleration", min=-10000, max=10000, default=250, line=true},
			{type="number", id="max_velocity", text="Max Velocity", min=-10000, max=10000, default=100, line=true},
			{type="number", id="blindspot_angle_deg", text="Blindspot Angle(deg)", min=-10000, max=10000, default=20},
		}},
		[PC.NoisePosUpdater] = {name="NoisePosUpdater", category="position & movement", fields={
			{type="file", id="noise", text="Noise", dir="/data/gfx/particles_textures/noises/", filter="%.png$", default="/data/gfx/particles_textures/noises/turbulent.png", line=true},
			{type="point", id="amplitude", text="Movement amplitude", min=-10000, max=10000, default={500, 500}},
			{type="number", id="traversal_speed", text="Noise traversal speed", min=0, max=10000, default=1},
		}},
		[PC.LinearColorUpdater] = {name="LinearColorUpdater", category="color", fields={
			{type="bool", id="bilinear", text="Bilinear (from start to stop to start)", default=false},
		}},
		[PC.EasingColorUpdater] = {name="EasingColorUpdater", category="color", fields={
			{type="bool", id="bilinear", text="Bilinear (from start to stop to start)", default=false, line=true},
			{type="select", id="easing", text="Easing method", list=easings, default="outQuad"},
		}},
		[PC.LinearSizeUpdater] = {name="LinearSizeUpdater", category="size", fields={}},
		[PC.EasingSizeUpdater] = {name="EasingSizeUpdater", category="size", fields={
			{type="select", id="easing", text="Easing method", list=easings, default="outQuad"},
		}},
		[PC.LinearRotationUpdater] = {name="LinearRotationUpdater", category="rotation", fields={}},
		[PC.EasingRotationUpdater] = {name="EasingRotationUpdater", category="rotation", fields={
			{type="select", id="easing", text="Easing method", list=easings, default="outQuad"},
		}},
	},
	systems = {
		[1] = {name="System", category="system", addnew=new_default_system, fields={
			{id=1, default=nil},
			{id="max_particles", default=100},
			{id="blend", default=PC.AdditiveBlend},
			{id="type", default=PC.RendererPoint},
			{id="compute_only", default=false},
			{id="texture", default="/data/gfx/particle.png"},
			{id="emitters", default={}},
			{id="updaters", default={}},
		}},
	}
}

local emitters_by_id = table.map(function(k, v) return k, v.name end, specific_uis.emitters)
local generators_by_id = table.map(function(k, v) return k, v.name end, specific_uis.generators)
local updaters_by_id = table.map(function(k, v) return k, v.name end, specific_uis.updaters)

function _M:showTriggers()
	local triggers = {}
	local list = {}

	for id_system, system in ipairs(pdef) do
		for id_emitter, emitter in ipairs(system.emitters) do
			for name, kind in pairs(emitter.triggers or {}) do
				triggers[name] = true
			end
		end
	end

	for name, _ in pairs(triggers) do table.insert(list, {name=name, id=name}) end
	Dialog:listPopup("Trigger", "Select trigger name:", list, 200, 400, function(item) if item then
		self.pdo:trigger(item.id)
		self.last_trigger = item.id
	end end)
end

local add_parameter_sel = ffi.new("int[1]", 1)
local add_parameter_buffer = ffi.new("char[500]", "")
function _M:addParameter(spe, none)
	if none then
		if ig.Button("New Parameter") then ig.OpenPopup("Add Parameter") end
	else
		ig.SameLine(ig.GetWindowWidth() - 36)
		if ig.Button("+") then ig.OpenPopup("Add Parameter") end
	end

	if ig.BeginPopupModal("Add Parameter", nil, ig.lib.ImGuiWindowFlags_AlwaysAutoResize) then
		ig.InputText("Name", add_parameter_buffer, ffi.sizeof(add_parameter_buffer))
		ig.SetKeyboardFocusHere()
		ig.RadioButtonIntPtr("Number", add_parameter_sel, 1) ig.SameLine() ig.RadioButtonIntPtr("Point", add_parameter_sel, 2)
		ig.Separator()
		if ig.Button("Add") or ig.HotkeyEntered(0, engine.Key._RETURN) then
			local name = ffi.string(add_parameter_buffer)
			if #name > 0 then
				spe.parameters = spe.parameters or {}
				spe.parameters[name] = add_parameter_sel[0] == 1 and 0 or {0, 0}
				self:regenParticle()
				ig.CloseCurrentPopup()
			end
		end
		ig.SameLine()
		if ig.Button("Cancel"..self:getFieldId()) or ig.HotkeyEntered(0, engine.Key._ESCAPE) then ig.CloseCurrentPopup() end
		ig.EndPopup()
	end
end

local add_trigger_sel = 1
local add_trigger_buffer = ffi.new("char[500]", "")
function _M:addTrigger(spe)
	ig.SameLine(ig.GetWindowWidth() - 36)
	if ig.Button("+") then ig.OpenPopup("Add Trigger") end

	if ig.BeginPopupModal("Add Trigger", nil, ig.lib.ImGuiWindowFlags_AlwaysAutoResize) then
		ig.InputText("Name", add_trigger_buffer, ffi.sizeof(add_trigger_buffer))
		ig.SetKeyboardFocusHere()
		for i, t in ipairs(triggermodes) do
			if ig.Selectable(t.name, add_trigger_sel == i, ig.lib.ImGuiSelectableFlags_DontClosePopups) then
				add_trigger_sel = i
			end
		end
		ig.Separator()
		if ig.Button("Add") or ig.HotkeyEntered(0, engine.Key._RETURN) then
			local name = ffi.string(add_trigger_buffer)
			if #name > 0 then
				spe.triggers = spe.triggers or {}
				spe.triggers[name] = triggermodes[add_trigger_sel].trigger
				self:regenParticle()
				ig.CloseCurrentPopup()
			end
		end
		ig.SameLine()
		if ig.Button("Cancel"..self:getFieldId()) or ig.HotkeyEntered(0, engine.Key._ESCAPE) then ig.CloseCurrentPopup() end
		ig.EndPopup()
	end
end

local add_event_sel = 1
local add_event_buffer = ffi.new("char[500]", "")
function _M:addEvent(spe)
	ig.SameLine(ig.GetWindowWidth() - 36)
	if ig.Button("+") then ig.OpenPopup("Add Event") end

	if ig.BeginPopupModal("Add Event", nil, ig.lib.ImGuiWindowFlags_AlwaysAutoResize) then
		ig.InputText("Name", add_event_buffer, ffi.sizeof(add_event_buffer))
		ig.SetKeyboardFocusHere()
		for i, t in ipairs(eventmodes) do
			if ig.Selectable(t.name, add_event_sel == i, ig.lib.ImGuiSelectableFlags_DontClosePopups) then
				add_event_sel = i
			end
		end
		ig.Separator()
		if ig.Button("Add") or ig.HotkeyEntered(0, engine.Key._RETURN) then
			local name = ffi.string(add_event_buffer)
			if #name > 0 then
				spe.events = spe.events or {}
				spe.events[name] = eventmodes[add_event_sel].event
				self:regenParticle()
				ig.CloseCurrentPopup()
			end
		end
		ig.SameLine()
		if ig.Button("Cancel"..self:getFieldId()) or ig.HotkeyEntered(0, engine.Key._ESCAPE) then ig.CloseCurrentPopup() end
		ig.EndPopup()
	end
end

function _M:addNew(kind, into, force_exec)
	local list = {}
	for id, t in pairs(specific_uis[kind]) do
		local t = table.clone(t, true)
		t.id = id
		list[#list+1] = t
	end
	table.sort(list, function(a, b) if a.category == b.category then return a.name < b.name else return a.category < b.category end end)

	local function exec(item) if item and not item.fake then
		local f = {[1]=item.id}
		if not item.addnew then
			for _, field in ipairs(item.fields) do
				if type(field.default) == "table" then f[field.id] = table.clone(field.default, true)
				else f[field.id] = field.default end
			end
		else
			f = table.clone(item.addnew, true)
		end
		table.insert(into, f)
		self:regenParticle()
	end end

	if force_exec then return exec(list[1]) end

	ig.SameLine(ig.GetWindowWidth() - 36)
	if #list == 1 then
		if ig.Button("+") then exec(list[1]) end
		return
	end

	-- Update list with splitters
	local last_cat = nil
	local i = 1
	while i < #list do
		local t = list[i]
		if t.category ~= last_cat and not t.fake then
			table.insert(list, i, {name=t.category, fake=true})
		end
		i = i + 1
		last_cat = t.category
	end

	if ig.Button("+") then ig.OpenPopup("Add "..kind:capitalize()) end
	if ig.BeginPopupModal("Add "..kind:capitalize()) then
		ig.BeginChild(self:getFieldId())
		for i, t in ipairs(list) do
			if t.fake then
				ig.CollapsingHeader(t.name)
			elseif ig.Selectable(t.name) then
				exec(t)
				ig.CloseCurrentPopup()
			end
		end
		ig.EndChild()

		ig.Separator()
		if ig.Button("Cancel"..self:getFieldId()) then ig.CloseCurrentPopup() end
		ig.EndPopup()
	end
end

function _M:displayParameter(name, value)
	if type(value) == "number" then
		local v = ffi.new("float[1]", value)
		if ig.InputFloat(name..self:getFieldId(), v, -100000, 100000, "%.3f") then pdef.parameters[name] = v[0] self:regenParticle() end
	elseif type(value) == "table" and #value == 2 then
		local v = ffi.new("float[2]", value[1], value[2])
		if ig.InputFloat2(name..self:getFieldId(), v, "%.3f") then pdef.parameters[name] = {v[0], v[1]} self:regenParticle() end
	end
	ig.SameLine(ig.GetWindowWidth() - 36)
	if ig.Button("X"..self:getFieldId()) then
		pdef.parameters[name] = nil
		self:regenParticle()
	end
end

function _M:makeStandardContextMenu(spe, parent)
	local finish = false
	local do_delete = false
	if ig.BeginPopupContextItem("System Menu") then
		if ig.Selectable("Rename") then
			Dialog:textboxPopup("Name for this addon's release", "Name", 1, 50, function(name) if name then
				spe.display_name = name finish = true
			end end)
		end
		if ig.Selectable("Duplicate") then
			for i, s in ipairs(parent) do if s == spe then
				local c = table.clone(s, true)
				c.display_name = (c.display_name or "unnamed").." (duplicated)"
				table.insert(parent, i + 1, c)
				finish = true
				break
			end end
		end
		if ig.Selectable("Move Up") then
			for i, s in ipairs(parent) do if s == spe and i > 1 then
				table.remove(parent, i)
				table.insert(parent, i - 1, s)
				finish = true
				break
			end end
		end
		if ig.Selectable("Move Down") then
			for i, s in ipairs(parent) do if s == spe and i < #parent then
				table.remove(parent, i)
				table.insert(parent, i + 1, s)
				finish = true
				break
			end end
		end
		ig.Separator()
		if ig.Selectable("New") then
			self:addNew("systems", pdef, true)
		end
		ig.Separator()
		if ig.Selectable("Delete") then
			do_delete = true
		end
		ig.EndPopup()
	end

	if ig.BeginPopupModal("Delete?", nil, ig.lib.ImGuiWindowFlags_AlwaysAutoResize) then
		ig.Text("Are you sure?")
		if ig.Button("Delete System") or ig.HotkeyEntered(0, engine.Key._RETURN) then table.remove(pdef, id_system) finish = true ig.CloseCurrentPopup() end
		ig.SameLine()
		if ig.Button("Cancel"..self:getFieldId()) or ig.HotkeyEntered(0, engine.Key._ESCAPE) then ig.CloseCurrentPopup() end
		ig.EndPopup()
	end
	if do_delete then ig.OpenPopup("Delete?") end

	return finish
end

local function imcolor(c, a)
	a = a or 1
	local r, g, b = colors.unpack1(colors[c])
	return ig.ImVec4(r, g, b, a)
end
local imcolor_white = imcolor"WHITE"

local function getParametrizedColor(p)
	if not p then return imcolor"CRIMSON" end
	local f, err = loadstring("return "..p)
	if not f then print("Param error", err) return imcolor"LIGHT_RED" end
	local env = table.clone(pdef.parameters or {}, true)
	setmetatable(env, {__index=math})
	setfenv(f, env)
	local ok, err = pcall(f)
	if not ok then print("Param error", err) return imcolor"LIGHT_RED" end
	if type(err) ~= "number" then print("Param return error: not a number") return imcolor"YELLOW" end
	return imcolor"SALMON"
end

local default_converted = {from=function(v) return v end, to=function(v) return v end}

function _M:getFieldId()
	self.next_field_id = self.next_field_id + 1
	return "###ufi"..self.next_field_id
end

function _M:input_checkbox(name, base, k)
	local v = ffi.new("bool[1]", base[k] and true or false)
	if ig.Checkbox(name, v) then base[k] = v[0] self:regenParticle() end
	if ig.IsItemHovered() then ig.SetTooltip(name) end
end

function _M:input_int(name, base, k, min, max, converter)
	converter = converter or default_converted
	local v = ffi.new("int[1]", converter.to(base[k]))
	if ig.DragInt(name, v, 1, converter.to(min), converter.to(max), "%d", ig.lib.ImGuiSliderFlags_ClampOnInput) then base[k] = converter.from(v[0]) self:regenParticle() end
	if ig.IsItemHovered() then ig.SetTooltip(name) end
end

function _M:input_string(name, base, k)
	converter = converter or default_converted
	local color = getParametrizedColor(base[k])
	ig.lib.igPushItemWidth(120)
	local buffer = ffi.new("char[500]", tostring(converter.to(base[k])))
	ig.PushStyleColor(ig.lib.ImGuiCol_Text, color) 
	if ig.InputText(name..self:getFieldId(), buffer, ffi.sizeof(buffer)) then
		local v = ffi.string(buffer)
		base[k] = converter.from(v)
		self:regenParticle()
	end
	if ig.IsItemHovered() then ig.SetTooltip(name) end
	ig.PopStyleColor()
	ig.PopItemWidth()
end

function _M:input_float(name, base, k, min, max, converter)
	converter = converter or default_converted
	local color = imcolor_white
	if not tonumber(base[k]) then color = getParametrizedColor(base[k]) end
	ig.lib.igPushItemWidth(120)
	local buffer = ffi.new("char[500]", tostring(converter.to(base[k])))
	ig.PushStyleColor(ig.lib.ImGuiCol_Text, color) 
	if ig.InputText(name..self:getFieldId(), buffer, ffi.sizeof(buffer)) then
		local v = ffi.string(buffer)
		if tonumber(v) then v = tonumber(v) end
		base[k] = converter.from(v)
		self:regenParticle()
	end
	if ig.IsItemHovered() then ig.SetTooltip(name) end
	ig.PopStyleColor()
	ig.PopItemWidth()
end

function _M:input_vec2(name, base, k, min, max, converter)
	converter = converter or default_converted
	ig.lib.igPushItemWidth(51)
	local color = imcolor_white
	if not tonumber(base[k][1]) then color = getParametrizedColor(base[k][1]) end
	ig.PushStyleColor(ig.lib.ImGuiCol_Text, color) 
	local buffer = ffi.new("char[500]", tostring(converter.to(base[k][1])))
	if ig.InputText("x"..self:getFieldId(), buffer, ffi.sizeof(buffer)) then
		local v = ffi.string(buffer)
		if tonumber(v) then v = tonumber(v) end
		base[k][1] = converter.from(v)
		self:regenParticle()
	end
	if ig.IsItemHovered() then ig.SetTooltip(name) end
	ig.PopStyleColor()

	ig.SameLine()
	local color = imcolor_white
	if not tonumber(base[k][2]) then color = getParametrizedColor(base[k][2]) end
	ig.PushStyleColor(ig.lib.ImGuiCol_Text, color) 
	local buffer = ffi.new("char[500]", tostring(converter.to(base[k][2])))
	if ig.InputText(name..self:getFieldId(), buffer, ffi.sizeof(buffer)) then
		local v = ffi.string(buffer)
		if tonumber(v) then v = tonumber(v) end
		base[k][2] = converter.from(v)
		self:regenParticle()
	end
	if ig.IsItemHovered() then ig.SetTooltip(name) end
	ig.PopItemWidth()
	ig.PopStyleColor()
end

function _M:input_combo(name, base, k, list, d_prop, v_prop)
	local v = ffi.new("int[1]", (table.findValueSub(list, base[k], v_prop) or 1) - 1)
	if ig.ComboStr(name..self:getFieldId(), v, table.concatsub(list, "\0", d_prop), #list) then
		base[k] = list[v[0]+1][v_prop]
		self:regenParticle()
	end
	if ig.IsItemHovered() then ig.SetTooltip(name) end
end

function _M:input_shader(name, base, k)
	local list = {{name = "--", path=nil}}
	for i, file in ipairs(fs.list(filesprefix.."/data/gfx/shaders/particles/")) do if file:find("%.lua$") then
		list[#list+1] = {name=file, path="particles/"..file:gsub("%.lua$", "")}
	end end 
	return self:input_combo(name..self:getFieldId(), base, k, list, "name", "path")
end

function _M:input_file(name, base, k, field)
	local list = {{name = "--", path=nil}}
	for i, file in ipairs(fs.list(filesprefix..field.dir)) do if file:find(field.filter) then
		list[#list+1] = {name=file, path=field.dir..file}
	end end
	return self:input_combo(name..self:getFieldId(), base, k, list, "name", "path")
end

function _M:input_select(name, base, k, field)
	return self:input_combo(name..self:getFieldId(), base, k, field.list, "name", "name")
end

function _M:input_color(name, base, k)
	local pickerid = self:getFieldId()
	local colori = ig.ImVec4(unpack(base[k]))
	if ig.ColorButton(name, colori, ig.lib.ImGuiColorEditFlags_AlphaPreviewHalf) then
		ig.OpenPopup(pickerid)
	end

	if ig.BeginPopup(pickerid) then
		local color = ffi.new("float[4]", unpack(base[k]))
		ig.Text(name)
		ig.Separator()
		if ig.ColorPicker4("##picker", color, ig.lib.ImGuiColorEditFlags_NoSidePreview + ig.lib.ImGuiColorEditFlags_NoSmallPreview) then
			base[k] = {color[0], color[1], color[2], color[3]}
			self:regenParticle()
		end
		ig.SameLine()

		ig.BeginGroup() -- Lock X position
		ig.Text("Current")
		ig.ColorButton("##current", colori, ig.lib.ImGuiColorEditFlags_NoPicker + ig.lib.ImGuiColorEditFlags_AlphaPreviewHalf, ig.ImVec2(60, 40))
		ig.Separator()
		ig.Text("Palette")

		local colors = table.values(colors_simple1)
		table.sort(colors, function (a, b) if a[1] == b[1] then
			if a[2] == b[2] then return a[3] < b[3]
			else return a[2] < b[2] end
		else return a[1] < b[1] end end)
		for n, c in ipairs(colors) do
			local c = c
			ig.PushID(n)
			if (n-1) % 8 ~= 0 then ig.SameLine(0, 4) end

			if ig.ColorButton("##palette", ig.ImVec4(unpack(c)), ig.lib.ImGuiColorEditFlags_NoAlpha + ig.lib.ImGuiColorEditFlags_NoPicker + ig.lib.ImGuiColorEditFlags_NoTooltip, ig.ImVec2(20, 20)) then
				base[k] = {c[1], c[2], c[3], base[k][4]}
				self:regenParticle()
			end
			ig.PopID()
		end
		ig.EndGroup()
		ig.EndPopup()
	end	

	ig.SameLine()
	ig.Text(name)
	if ig.IsItemHovered() then ig.SetTooltip(name) end
end

function _M:input_texture(name, base, k)
	if ig.BeginCombo(self:getFieldId(), base[k]) then
		ig.Columns(math.floor((ig.GetWindowWidth() - 8) / 64), nil, false)
		for i, t in ipairs(self.available_textures) do
			if ig.ImageButton(t.id, ig.ImVec2(64, 64), nil, nil, 0) then
				base[k] = t.path
				self:regenParticle()
				ig.CloseCurrentPopup()
			end
			ig.NextColumn()
		end
		ig.Columns(1)
		ig.EndCombo()
	end
end

function _M:processSpecificUI(kind, spe, color, delete)
	local spe_def = specific_uis[kind][spe[1]]
	if not spe_def then error("unknown def for: "..tostring(spe[1])) end

	ig.PushStyleColor(ig.lib.ImGuiCol_Header, imcolor(color or "STEEL_BLUE", 0.5))
	local open = ffi.new("bool[1]", true)
	if ig.CollapsingHeaderBoolPtr(spe_def.name..self:getFieldId(), open, ig.lib.ImGuiTreeNodeFlags_DefaultOpen) then
		ig.PushStyleVar(ig.lib.ImGuiStyleVar_FrameRounding, 12)
		ig.PushStyleVar(ig.lib.ImGuiStyleVar_ItemSpacing, ig.ImVec2(4, 1))
		ig.Indent(20)
		if #spe_def.fields > 1 then ig.Columns(2) end
		for i, field in ipairs(spe_def.fields) do
			field.from = field.from or function(v) return v end
			field.to = field.to or function(v) return v end
			if field.type == "number" then
				if not spe[field.id] then spe[field.id] = field.default end
				self:input_float(field.text, spe, field.id, field.min, field.max, field)
			elseif field.type == "string" then
				if not spe[field.id] then spe[field.id] = field.default end
				self:input_string(field.text, spe, field.id)
			elseif field.type == "bool" then
				if not spe[field.id] then spe[field.id] = field.default end
				self:input_checkbox(field.text, spe, field.id)
			elseif field.type == "point" then
				if not spe[field.id] then spe[field.id] = table.clone(field.default, true) end
				self:input_vec2(field.text, spe, field.id, field.min, field.max, field)
			elseif field.type == "color" then
				if not spe[field.id] then spe[field.id] = table.clone(field.default, true) end
				self:input_color(field.text, spe, field.id)
			elseif field.type == "select" then
				if not spe[field.id] then spe[field.id] = field.default end
				self:input_select(field.text, spe, field.id, field)
			elseif field.type == "file" then
				if not spe[field.id] then spe[field.id] = field.default end
				self:input_file(field.text, spe, field.id, field)
			end
			-- if not field.line and i < #spe_def.fields then ig.SameLine() end
			if i == #spe_def.fields - 1 then ig.PopStyleVar() end
			ig.NextColumn()
		end
		if #spe_def.fields < 2 then ig.PopStyleVar() end
		if #spe_def.fields > 1 then ig.Columns(1) end
		ig.Unindent(20)
		ig.PopStyleVar()
	end
	if not open[0] then game:onTickEnd(delete) end
	ig.PopStyleColor()
end

function _M:processTriggerEventUI(base, type, name, kind, color)
	local modes = type == "trigger" and triggermodes or eventmodes
	local by_id = type == "trigger" and trigger_by_id or event_by_id
	ig.PushStyleColor(ig.lib.ImGuiCol_Header, imcolor(color or "STEEL_BLUE", 0.5))
	local open = ffi.new("bool[1]", true)
	if ig.CollapsingHeaderBoolPtr(name..self:getFieldId(), open, ig.lib.ImGuiTreeNodeFlags_DefaultOpen) then
		ig.PushStyleVar(ig.lib.ImGuiStyleVar_FrameRounding, 12)
		ig.PushStyleVar(ig.lib.ImGuiStyleVar_ItemSpacing, ig.ImVec2(4, 1))
		ig.Indent(20)
		if ig.BeginCombo(self:getFieldId(), by_id[kind]) then
			for _, m in ipairs(modes) do
				if ig.Selectable(m.name) then
					base[name] = m[type]
					self:regenParticle()
				end
			end
			ig.EndCombo()
		end
		ig.Unindent(20)
		ig.PopStyleVar()
		ig.PopStyleVar()
	end
	if not open[0] then base[name] = nil self:regenParticle() end
	ig.PopStyleColor()
end

function _M:displaySystem(id_system, system)
	if self:makeStandardContextMenu(system, pdef) then self:regenParticle() end

	ig.PushStyleVar(ig.lib.ImGuiStyleVar_FrameRounding, 4)

	self:input_int("Max particles", system, "max_particles", 1, 100000)
	self:input_combo("Blend mode", system, "blend", blendmodes, "name", "blend")
	self:input_combo("Type", system, "type", typemodes, "name", "type")
	self:input_checkbox("Compute only (hidden)", system, "compute_only")
	if not system.compute_only then
		self:input_texture("Texture", system, "texture")
		self:input_shader("Shader", system, "shader")
	end

	ig.Separator()
	if ig.TreeNodeEx("----==== Emitters ====----", ig.lib.ImGuiTreeNodeFlags_DefaultOpen) then
		self:addNew("emitters", system.emitters)
		for id_emitter, emitter in ipairs(system.emitters) do
			local id = id_emitter
			ig.Separator()
			self:processSpecificUI("emitters", emitter, nil, function() table.remove(system.emitters, id) self:regenParticle() end)
			ig.PushStyleColor(ig.lib.ImGuiCol_Text, imcolor"ROYAL_BLUE")
			if ig.TreeNodeEx("---=== Generators ===---"..self:getFieldId(), ig.lib.ImGuiTreeNodeFlags_DefaultOpen) then
				ig.PopStyleColor()
				self:addNew("generators", emitter[2])
				for id_generator, generator in ipairs(emitter[2]) do
					local id = id_generator
					self:processSpecificUI("generators", generator, "ROYAL_BLUE", function() table.remove(emitter[2], id) self:regenParticle() end)
				end
				ig.TreePop()
			else ig.PopStyleColor()
			end

			ig.PushStyleColor(ig.lib.ImGuiCol_Text, imcolor"OLIVE_DRAB")
			if ig.TreeNodeEx("---=== Triggers ===---"..self:getFieldId(), ig.lib.ImGuiTreeNodeFlags_DefaultOpen) then
				ig.PopStyleColor()
				self:addTrigger(emitter)
				if emitter.triggers then
					for name, kind in pairs(emitter.triggers) do
						self:processTriggerEventUI(emitter.triggers, "trigger", name, kind, "OLIVE_DRAB")
					end
				end
				ig.TreePop()
			else ig.PopStyleColor()
			end

			ig.PushStyleColor(ig.lib.ImGuiCol_Text, imcolor"DARK_ORCHID")
			if ig.TreeNodeEx("---=== Events ===---"..self:getFieldId(), ig.lib.ImGuiTreeNodeFlags_DefaultOpen) then
				ig.PopStyleColor()
				self:addEvent(emitter)
				if emitter.events then
					for name, kind in pairs(emitter.events) do
						self:processTriggerEventUI(emitter.events, "event", name, kind, "DARK_ORCHID")
					end
				end
				ig.TreePop()
			else ig.PopStyleColor()
			end
		end
		ig.TreePop()
	end	

	ig.Separator()
	if ig.TreeNodeEx("----==== Updaters ====----", ig.lib.ImGuiTreeNodeFlags_DefaultOpen) then
		self:addNew("updaters", system.updaters)
		for id_updater, updater in ipairs(system.updaters) do
			local id = id_updater
			self:processSpecificUI("updaters", updater, nil, function() table.remove(system.updaters, id_updater) self:regenParticle() end)
		end
		ig.TreePop()
	end

	ig.PopStyleVar()
end

function _M:doLoad(name, path)
	pdef_history={} pdef_history_pos=0
	local ok, f = pcall(loadfile, path)
	if not ok then print("Error loading particle file", f) return end
	setfenv(f, {math=math, colors_alphaf=colors_alphaf, PC=PC})
	local ok, data = pcall(f)
	if not ok then print("Error loading particle file", data) return end
	pdef = data
	self:regenParticle()
	core.display.setWindowTitle("Particles Editor: "..name)
	self.current_filename = name:gsub("%.pc$", "")
end

function _M:doLoadTemp(path)
	if self.cur_temp == path then return end
	self.cur_temp = path
	local ok, f = pcall(loadfile, path)
	if not ok then print("Error loading particle file", f) return end
	setfenv(f, {math=math, colors_alphaf=colors_alphaf, PC=PC})
	local ok, data = pcall(f)
	if not ok then print("Error loading particle file", data) return end
	self.temp_pdo = PC.new(data, nil, 1, 1, true)
	self:regenParticle(true)
end

function _M:defineMenuPopups()
	ig.SetNextWindowSizeConstraints(ig.ImVec2(600, 600), ig.ImVec2(600, 600))
	self.loading_dialog_shown = false
	if ig.BeginPopupModal("Load Particles System") then
		self.loading_dialog_shown = true
		local list = {}
		local max_size = 1
		for i, file in ipairs(fs.list(filesprefix.."/data/gfx/particles/")) do if file:find("%.pc$") then
			list[#list+1] = {name=file, path=filesprefix.."/data/gfx/particles/"..file}
			max_size = math.max(max_size, ig.CalcTextSize(file, nil,false, -1.0).x)
		end end 
		table.sort(list, "name")

		ig.Text("Select file to load:")
		ig.Separator()

		local regionsize = ig.GetContentRegionAvail()
		local desiredY = math.max(regionsize.y - ig.GetFrameHeightWithSpacing()*3,200)
		ig.BeginChild("files", ig.ImVec2(0,desiredY), true, 0)

		ig.Columns(3)
		ig.PushItemWidth(max_size + ig.GetStyle().ItemInnerSpacing.x * 2)
		for i, file in ipairs(list) do
			if ig.Selectable(file.name) then
				self:doLoad(file.name, file.path)
				ig.CloseCurrentPopup()
			end
			if ig.IsItemHovered() then
				self:doLoadTemp(file.path)
			end
			ig.NextColumn()
		end
		ig.PopItemWidth()
		ig.Columns(1)

		ig.EndChild()

		ig.Separator()
		if ig.Button("Cancel"..self:getFieldId()) then ig.CloseCurrentPopup() end
		ig.EndPopup()
	end

	if ig.BeginPopupModal("Clear particles?", nil, ig.lib.ImGuiWindowFlags_NoResize + ig.lib.ImGuiWindowFlags_AlwaysAutoResize) then
		ig.Text("All data will be lost.")
		if ig.Button("Delete all") or ig.HotkeyEntered(0, engine.Key._RETURN) then self:reset() ig.CloseCurrentPopup() end
		ig.SameLine()
		if ig.Button("Cancel"..self:getFieldId()) or ig.HotkeyEntered(0, engine.Key._ESCAPE) then ig.CloseCurrentPopup() end
		ig.EndPopup()
	end

	if ig.BeginPopupModal("Save Particles System", nil, ig.lib.ImGuiWindowFlags_NoResize + ig.lib.ImGuiWindowFlags_AlwaysAutoResize) then
		ig.Text("All data will be lost.")

		if self.current_filename_tmp then
			ig.Text("Confirm to overwrite existing file: "..self.current_filename_tmp)
			if ig.Button("Save & Overwrite") or ig.HotkeyEntered(0, engine.Key._RETURN) then self:saveAs(self.current_filename_tmp, false) self.current_filename_tmp = nil ig.CloseCurrentPopup() end
			ig.SameLine()
			if ig.Button("Cancel"..self:getFieldId()) or ig.HotkeyEntered(0, engine.Key._ESCAPE) then self.current_filename_tmp = nil ig.CloseCurrentPopup() end
		else
			local buffer = ffi.new("char[500]", self.current_filename_tmp or self.current_filename or "")
			if ig.InputText("Filename (without .pc)", buffer, ffi.sizeof(buffer), ig.lib.ImGuiInputTextFlags_EnterReturnsTrue) then
				local fname = ffi.string(buffer)
				if fs.exists("/data/gfx/particles/"..fname..".pc") then
					self.current_filename_tmp = fname
				else
					self:saveAs(fname, false)
					ig.CloseCurrentPopup()
				end
			end
			ig.SetKeyboardFocusHere()
			ig.Separator()
			if ig.Button("Cancel"..self:getFieldId()) or ig.HotkeyEntered(0, engine.Key._ESCAPE) then ig.CloseCurrentPopup() end
		end
		ig.EndPopup()
	end
end

function _M:makeUI()
	local fps, msframe = core.display.getFPS()
	ig.Begin("Stats", nil, ig.lib.ImGuiWindowFlags_NoTitleBar + ig.lib.ImGuiWindowFlags_NoResize + ig.lib.ImGuiWindowFlags_AlwaysAutoResize)
	ig.Text(("Elapsed Time %0.2fs / FPS: %0.1f / %d ms/frame / Active particles: %d / Zoom: %d%% / Speed: %d%%"):format((core.game.getTime() - self.p_date) / 1000, fps, msframe, self.pdo:countAlive(), particle_zoom * 100, particle_speed * 100))
	ig.End()

	self.next_field_id = 1
	local open = ffi.new("bool[1]", true)
	ig.Begin("Particles Editor", open, ig.lib.ImGuiWindowFlags_MenuBar)
	if not open[0] then self:exitEditor() end
	self.is_ui_focus = ig.IsWindowHovered()
	-- ig.PushStyleVarFloat(ig.lib.ImGuiStyleVar_IndentSpacing, 50)
	local def = pdef

	local do_load, do_new, do_save = false, false, false
	if ig.BeginMenuBar() then
		if ig.BeginMenu("File") then
			if ig.MenuItem("New", "CTRL+N") then do_new = true end
			if ig.MenuItem("Load", "CTRL+L") then do_load = true end
			if ig.MenuItem("Save", "CTRL+S") then do_save = true end
			ig.EndMenu()
		end
		ig.EndMenuBar()
	end
	self:defineMenuPopups()
	
	-- Hotkeys
	if ig.HotkeyEntered(ig.lib.KeyModCtrl, engine.Key._n) or do_new then ig.OpenPopup("Clear particles?") end
	if ig.HotkeyEntered(ig.lib.KeyModCtrl, engine.Key._l) or do_load then ig.OpenPopup("Load Particles System") end
	if ig.HotkeyEntered(ig.lib.KeyModCtrl, engine.Key._s) or do_save then ig.OpenPopup("Save Particles System") end

	-- Cleanup
	if not self.loading_dialog_shown and (self.cur_temp or self.temp_pdo) then
		self.cur_temp, self.temp_pdo = nil, nil
		self:regenParticle()
	end

	if def.parameters and ig.TreeNodeEx("Parameters", ig.lib.ImGuiTreeNodeFlags_DefaultOpen) then
		self:addParameter(def)
		for name, value in pairs(def.parameters) do
			self:displayParameter(name, value)
		end
		ig.TreePop()
	else
		self:addParameter(def, true)
	end

	ig.Separator()
	if #def == 0 then
		if ig.Button("Add System") then self:addNew("systems", pdef, true) end
	else
		ig.BeginTabBar("Systems", ig.lib.ImGuiTabBarFlags_TabListPopupButton)
		for id_system, system in ipairs(def) do
			local id = id_system
			if ig.BeginTabItem((system.display_name or "unnamed").."("..id_system..")") then
				self:displaySystem(id_system, system)
				ig.EndTabItem()
			else
				if self:makeStandardContextMenu(system, pdef) then self:regenParticle() end
			end
		end
		ig.EndTabBar()
	end
	
	ig.End()

	local b = ffi.new("bool[1]", 1)
	ig.ShowDemoWindow(b)
end

function _M:setBG(kind)
	local w, h = game.w, game.h
	self.bg:clear()
	if kind == "transparent" then
		-- nothing
	elseif kind == "tome1" then
		self.bg:add(core.renderer.image("/data/gfx/background/tome.png"):shader(self.bg_shader))
	elseif kind == "tome2" then
		self.bg:add(core.renderer.image("/data/gfx/background/tome2.png"):shader(self.bg_shader))
	elseif kind == "tome3" then
		self.bg:add(core.renderer.image("/data/gfx/background/tome3.png"):shader(self.bg_shader))
	elseif type(kind) == "table" then
		self.bg:add(core.renderer.colorQuad(0, 0, w, h, unpack(kind)):shader(self.normal_shader))
	end
end

function _M:init(no_bloom)
	self.bignews = BigNews.new(FontPackage:getFont("bignews"))
	self.bignews:setTextOutline(0.7)

	Dialog.init(self, _t"Particles Editor", 500, game.h * 0.9, game.w - 550)
	self.__showup = false
	self.absolute = true
	self.old_shift_x, self.old_shift_y = (game.w - 550) / 2, game.h / 2

	self.bg_shader = Shader.new("particles/normal", nil, true, "gl2")

	PC.defaultShader("particles/normal")
	self.bg = core.renderer.renderer()

	self.mouse:registerZone(0, 0, game.w, game.h, function(button, mx, my, xrel, yrel, bx, by, event)
		if core.key.modState("ctrl") then
			if event == "button" and (button == "wheelup" or button == "button4") then
				particle_speed = util.bound(particle_speed + 0.05, 0.1, 10)
				self.pdo:speed(particle_speed)
				return true
			elseif event == "button" and (button == "wheeldown" or button == "button5") then
				particle_speed = util.bound(particle_speed - 0.05, 0.1, 10)
				self.pdo:speed(particle_speed)
				return true
			elseif event == "button" and button == "middle" then
				particle_speed = 1
				self.pdo:speed(particle_speed)
				return true
			end
		else
			if event == "button" and (button == "wheelup" or button == "button4") then
				particle_zoom = util.bound(particle_zoom + 0.05, 0.1, 10)
				self.pdo:zoom(particle_zoom)
				self:shift(mx, my)
				return true
			elseif event == "button" and (button == "wheeldown" or button == "button5") then
				particle_zoom = util.bound(particle_zoom - 0.05, 0.1, 10)
				self.pdo:zoom(particle_zoom)
				self:shift(mx, my)
				return true
			elseif event == "button" and button == "middle" then
				particle_zoom = 1
				self.pdo:zoom(particle_zoom)
				self:shift(mx, my)
				return true
			elseif event == "button" and button == "right" and self.last_trigger then
				self.pdo:trigger(self.last_trigger)
			elseif event == "button" and (button == "left" or button == "right") then
				self:showTriggers()
			end
		end

		if core.key.modState("alt") then 
			local a = math.atan2(my - self.old_shift_y, mx - self.old_shift_x)
			local r = math.sqrt((my - self.old_shift_y)^2 + (mx - self.old_shift_x)^2)
			self.pdo:params{size=r, range=r, angle=a, angled=math.deg(a), tx=mx - self.old_shift_x, ty=my - self.old_shift_y}
		else
			self:shift(mx, my)
		end
		return false
	end)

	self.key:setupRebootKeys()
	self.key:addCommands{
		_b = function() self:toggleBloom() end,
		_u = function() self:toggleUI() end,
	}

	self.particle_renderer = core.renderer.renderer()

	local w, h = game.w, game.h
	self.fbomain = core.renderer.target(nil, nil, 2, true)
	self.fbomain:setAutoRender(self.particle_renderer)

	self.blur_shader = Shader.new("rendering/blur") self.blur_shader:setUniform("texSize", {w, h})
	local main_shader = Shader.new("rendering/main_fbo") main_shader:setUniform("texSize", {w, h})
	local finalquad = core.renderer.targetDisplay(self.fbomain, 0, 0)
	self.downsampling = 4
	local bloomquad = core.renderer.targetDisplay(self.fbomain, 1, 0, w/self.downsampling/self.downsampling, h/self.downsampling/self.downsampling)
	local bloomr = core.renderer.renderer("static"):setRendererName("game.bloomr"):add(bloomquad):premultipliedAlpha(true)
	local fbobloomview = core.renderer.view():ortho(w/self.downsampling, h/self.downsampling, false)
	self.fbobloom = core.renderer.target(w/self.downsampling, h/self.downsampling, 1, true):setAutoRender(bloomr):view(fbobloomview)--:translate(0,-h)
	self.initial_blooming = true
	if not no_bloom then self:toggleBloom() end
	self.initial_blooming = false
	if false then -- true to see only the bloom texture
		-- finalquad:textureTarget(self.fbobloom, 0, 0):shader(main_shader)
		self.fborenderer = core.renderer.renderer("static"):setRendererName("game.fborenderer"):add(self.fbobloom)--:premultipliedAlpha(true)
	else
		finalquad:textureTarget(self.fbobloom, 0, 1):shader(main_shader)
		self.fborenderer = core.renderer.renderer("static"):setRendererName("game.fborenderer"):add(finalquad)--:premultipliedAlpha(true)
	end

	self:regenParticle()

	local list = {}
	for i, file in ipairs(fs.list("/data/gfx/particles_textures/")) do if file:find("%.png$") then
		local path = "/data/gfx/particles_textures/"..file
		local t = core.loader.png(path)
		-- Directly storing texture actual GLuint id .. this is very very wrong :<
		list[#list+1] = {name=file, path=path, texture=t, id=ffi.cast("void*", ffi.new("unsigned int", t:toID()))}
	end end
	self.available_textures = list
end

function _M:toggleBloom()
	if not self.blooming then
		self.fbobloom:blurMode(40, self.downsampling, self.blur_shader)
		self.blooming = true
	else
		self.fbobloom:removeMode()
		self.blooming = false
	end
	if not self.initial_blooming then
		self.bignews:saySimple(60, "Bloom effect: "..(self.blooming and "#LIGHT_GREEN#Enabled" or "#LIGHT_RED#Disabled"))
	end
end

function _M:toggleUI()
	self.hide_ui = not self.hide_ui
end

function _M:regenParticle(nosave)
	if not self.particle_renderer then return end
	if not nosave then
		for i = pdef_history_pos + 1, #pdef_history do pdef_history[i] = nil end
		table.insert(pdef_history, table.clone(pdef, true))
		pdef_history_pos = #pdef_history
	end

	if self.temp_pdo then
		self.pdo = self.temp_pdo
	else
		self.pdo = PC.new(pdef, nil, particle_speed, particle_zoom, true)
	end
	self:shift(self.old_shift_x, self.old_shift_y)
	self.p_date = core.game.getTime()

	self.pdo:onEvents(function(name, times)
		self.bignews:saySimple(30, "Event #GOLD#"..name.."#LAST# triggered #LIGHT_GREEN#"..times.."#LAST# times")
		print("Particle Event", name, times)
	end)

	self.particle_renderer:clear():add(self.bg):add(self.pdo)

	self.particle_renderer:tween(30 * 5, "wait", function() self:saveAs("__autosave__", true) end)
	collectgarbage("collect")
end

function _M:shift(x, y)
	self.old_shift_x, self.old_shift_y = x, y
	self.pdo:shift(x, y, true)
end

function _M:toScreen(x, y, nb_keyframes)
	if self.pdo:dead() then
		self.bignews:saySimple(15, "#AQUAMARINE#--END--")
		self:regenParticle(true)
	end

	if self.is_ui_focus then self:shift((game.w - 550) / 2, game.h / 2) end

	if self.blooming then
		self.fbomain:compute()
		self.fbobloom:compute()
		self.fborenderer:toScreen()
	else
		self.particle_renderer:toScreen()
	end
	-- self.p:toScreen(0, 0, nb_keyframes)

	if not self.hide_ui then
		self:makeUI()
		self.bignews:display(nb_keyframes)
	end
end

function _M:undo()
	if pdef_history_pos == 0 then return end
	pdef = table.clone(pdef_history[pdef_history_pos], true)
	pdef_history_pos = pdef_history_pos - 1
	self:regenParticle(true)
end

function _M:reset()
	pdef={}
	pdef_history_pos = 0
	pdef_history = {}
	-- PC.gcTextures()
	self.current_filename = ""
	self:regenParticle(true)
end

function _M:merge(master)
	-- ig.("Load particle effects from /data/gfx/particles/", game.w * 0.6, game.h * 0.6)

	local list = {}
	for i, file in ipairs(fs.list(filesprefix.."/data/gfx/particles/")) do if file:find("%.pc$") then
		list[#list+1] = {name=file, path=filesprefix.."/data/gfx/particles/"..file}
	end end 

	local clist = List.new{font=self.dfont, scrollbar=true, width=d.iw, height=d.ih, list=list, fct=function(item)
		game:unregisterDialog(d)
		local ok, f = pcall(loadfile, item.path)
		if not ok then Dialog:simplePopup("Error loading particle file", f) return end
		setfenv(f, {math=math, colors_alphaf=colors_alphaf, PC=PC})
		local ok, data = pcall(f)
		if not ok then Dialog:simplePopup("Error loading particle file", data) return end
		table.append(pdef, data)
		master:regenParticle()
	end}

	d:loadUI{
		{left=0, top=0, ui=clist}
	}
	d:setupUI(false, false)
	d.key:addBinds{EXIT = function() game:unregisterDialog(d) end}
	game:registerDialog(d)
end

function _M:saveDef(w)
	local function getFormat(v)
		if type(v) == "number" then return "%f"
		elseif type(v) == "string" then return "%q"
		else error("Unsupported format: "..tostring(v))
		end
	end
	local function getData(up, simple)
		local data = {}
		for k, v in pairs(up) do
			if type(k) == "string" and k ~= "triggers" and k ~= "events" then
				if type(v) == "number" then
					data[#data+1] = ("%s=%f"):format(k, v)
				elseif type(v) == "boolean" then
					data[#data+1] = ("%s=%s"):format(k, v and "true" or "false")
				elseif type(v) == "string" then
					data[#data+1] = ("%s=%q"):format(k, v)
				elseif type(v) == "table" and #v == 2 then
					data[#data+1] = (("%%s={%s, %s}"):format(getFormat(v[1]), getFormat(v[2]))):format(k, v[1], v[2])
				elseif type(v) == "table" and #v == 3 then
					data[#data+1] = (("%%s={%s, %s, %s}"):format(getFormat(v[1]), getFormat(v[2]), getFormat(v[3]))):format(k, v[1], v[2], v[3])
				elseif type(v) == "table" and #v == 4 then
					data[#data+1] = (("%%s={%s, %s, %s, %s}"):format(getFormat(v[1]), getFormat(v[2]), getFormat(v[3]), getFormat(v[4]))):format(k, v[1], v[2], v[3], v[4])
				elseif type(v) == "table" and #v == 0 and next(v) then
					data[#data+1] = ("%s={%s}"):format(k, getData(v, true))
				else
					error("Unsupported save parameter: "..tostring(v).." for key "..k)
				end
			elseif k == "triggers" and next(v) then
				local tgs = {}
				for name, id in pairs(v) do
					tgs[#tgs+1] = ("%s = PC.%s"):format(name, triggerkind_by_id[id])
				end
				data[#data+1] = "triggers = { "..table.concat(tgs, ", ").." }"
			elseif k == "events" and next(v) then
				local tgs = {}
				for name, id in pairs(v) do
					tgs[#tgs+1] = ("%s = PC.%s"):format(name, eventkind_by_id[id])
				end
				data[#data+1] = "events = { "..table.concat(tgs, ", ").." }"
			end
		end
		if #data > 0 then data = (not simple and ", " or "")..table.concat(data, ", ") else data = "" end
		return data
	end

	w(0, "return {\n")
	if pdef.parameters then
		w(1, ("parameters = { %s },\n"):format(getData(pdef.parameters, true)))
	end
	for _, system in ipairs(pdef) do
		w(1, "{\n")
		if system.display_name then w(2, ("display_name = %q,\n"):format(system.display_name)) end
		w(2, ("max_particles = %d, blend=PC.%s, type=PC.%s, compute_only=%s,\n"):format(system.max_particles, blend_by_id[system.blend], system.type and type_by_id[system.type] or "RendererPoint", system.compute_only and "true" or "false"))
		w(2, ("texture = %q,\n"):format(system.texture))
		if system.shader then w(2, ("shader = %q,\n"):format(system.shader)) end
		w(2, "emitters = {\n")
		for _, em in ipairs(system.emitters) do
			local data = getData(em)
			w(3, ("{PC.%s, {\n"):format(emitters_by_id[em[1]]))
			for _, g in ipairs(em[2]) do
				local data = getData(g)
				w(4, ("{PC.%s%s},\n"):format(generators_by_id[g[1]], data))
			end
			w(3, ("}%s },\n"):format(data))
		end
		w(2, "},\n")
		w(2, "updaters = {\n")
		for _, up in ipairs(system.updaters) do
			local data = getData(up)
			w(3, ("{PC.%s%s},\n"):format(updaters_by_id[up[1]], data))
		end
		w(2, "},\n")
		w(1, "},\n")
	end
	w(0, "}\n")
end

function _M:saveAs(txt, silent)
	local mod = game.__mod_info

	local basedir = "/data/gfx/particles/"
	local path
	if fileswritepath then
		path = fileswritepath..basedir
	elseif mod.team then
		basedir = "/save/"
		path = fs.getRealPath(basedir)
	else
		path = mod.real_path..basedir
	end
	if not path then return end
	local restore = fs.getWritePath()
	fs.setWritePath(path)
	local f = fs.open("/"..txt..".pc", "w")
	self:saveDef(function(indent, str) f:write(string.rep("\t", indent)..str) end)
	f:close()
	fs.setWritePath(restore)
	if not silent then
		self.bignews:saySimple(60, "#GOLD#Saved to "..tostring(fs.getRealPath(basedir..txt..".pc")))
		core.display.setWindowTitle("Particles Editor: "..txt)
		self.current_filename = txt
	else
		print("AUTOSAVE", txt)
	end
end

function _M:exitEditor()
	game:unregisterDialog(self)
	if game.__mod_info.short_name == "particles_editor" then os.exit() end
end
