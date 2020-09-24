-- TE4 - T-Engine 4
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

require "engine.class"

--- Handles sounds in the game
-- @classmod engine.generator.interface.GameSound
module(..., package.seeall, class.make)

_M.max_simultanous_sounds = 50

--- Initializes
function _M:init()
	self:loaded()
end

function _M:loaded()
	core.sound.maxSounds(self.max_simultanous_sounds)
end

function _M:playSound(name, pos)
	local set_vol = nil
	if type(name) == "table" then
		if name[2] and name[3] then name[1] = name[1]:format(rng.range(name[2], name[3])) end
		-- if name.pitch then pitch = name.pitch end
		if name.vol then set_vol = name.vol end
		name = name[1]
	end
	local h = core.sound.play(name, pos)
	if set_vol then h:volume(set_vol) end
	return h
end

function _M:volumeSoundEffects(vol)
	vol = util.bound(vol, 0, 100)
	if vol then
		config.settings.audio = config.settings.audio or {}
		config.settings.audio.effects_volume = vol
		game:audioSaveSettings()
	end
	core.sound.globalVolume(vol / 100)
end
