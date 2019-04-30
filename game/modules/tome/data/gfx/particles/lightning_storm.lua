-- ToME - Tales of Maj'Eyal
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

base_size = 64
can_shift = true

local nb = 0
local nextp = 5

return { blend_mode=core.particles.BLEND_SHINY, generator = function()
	local ad = rng.range(0, 360)
	local a = math.rad(ad)
	local dir = math.rad(ad)
	local r = rng.range(0, 32)

	return {
		life = 100,
		size = rng.range(70, 100), sizev = -0.9, sizea = 0,

		x = r * math.cos(a), xv = 0, xa = 0,
		y = r * math.sin(a), yv = 0, ya = 0,
		dir = 0, dirv = 0, dira = 0,
		vel = 0, velv = 0, vela = 0,

		r = 1,   rv = 0, ra = 0,
		g = 1,   gv = 0, ga = 0,
		b = 1,   gv = 0, ga = 0,
		a = rng.float(0.05, 0.08),   av = 0.0152, aa = -0.001,
	}
end, },
function(self)
	if nb == 0 then self.ps:emit(1) end
	nb = nb + 1
	if nb >= nextp then
		nb = 0
		nextp = rng.range(3, 15)
	end
end,
10, "particles_images/lightning_storm_"..rng.range(1, 5)