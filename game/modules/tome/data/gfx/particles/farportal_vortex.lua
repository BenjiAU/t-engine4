-- ToME - Tales of Maj'Eyal
-- Copyright (C) 2009 - 2019 Nicolas Casalini
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
size = size or 256

return {
	system_rotation = 0, system_rotationv = rot or 0.5, generator = function()
	
	return {
		life = 100,
		size = size, sizev = 0, sizea = 0,

		x = x or 0, xv = 0, xa = 0,
		y = y or 0, yv = 0, ya = 0,
		dir = 0, dirv = 0, dira = 0,
		vel = 0, velv = 0, vela = 0,

		r = 1,   rv = 0, ra = 0,
		g = 1,   gv = 0, ga = 0,
		b = 1,   bv = 0, ba = 0,
		a = 1,   av = 0, aa = 0,
	}
end
}, function(self)
	self.ps:emit(1)
end, 1, vortex or "shockbolt/terrain/farportal-blue-vortex", true
