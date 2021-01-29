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

--- Handles music in the game
-- @classmod engine.generator.interface.GameMusic
module(..., package.seeall, class.make)

_M.music_fade_time = 1.2

--- Initializes musics
function _M:init()
	self.playing_musics = {}
end

function _M:loaded()
	self.playing_musics = self.playing_musics or {}
end

function _M:playMusic(name)
	if not name then
		for _, name in pairs(self.playing_musics) do self:playMusic(name) end
		return
	end
	if not name:find("^/") then name = "/data/music/"..name end
	local m = core.music.play(name, self.music_fade_time)
	if not m then return end
	self.playing_musics = core.music.list()
end

function _M:stopMusic()
	core.music.stopCurrent(self.music_fade_time)
	self.playing_musics = core.music.list()
	print("[MUSIC] stoping all")
end

function _M:playAndStopMusic(...)
	local keep = table.map(function(_, v) return "/data/music/"..v, true end, {...})
	core.music.stopCurrent(self.music_fade_time, keep)
	for name, status in pairs(keep) do if status ~= "playing" then self:playMusic(name) end end
end

function _M:volumeMusic(vol)
	vol = util.bound(vol, 0, 100)
	if vol then
		config.settings.audio = config.settings.audio or {}
		config.settings.audio.music_volume = vol
		game:audioSaveSettings()
	end
	core.music.volume(vol / 100)
end

function _M:audioSaveSettings()
	self:saveSettings("audio", ([[audio.music_volume = %d
audio.effects_volume = %d
audio.enable = %s
]]):
	format(config.settings.audio.music_volume,
		config.settings.audio.effects_volume,
		tostring(config.settings.audio.enable)
	))
end

