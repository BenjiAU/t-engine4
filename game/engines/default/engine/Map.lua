-- TE4 - T-Engine 4
-- Copyright (C) 2009, 2010 Nicolas Casalini
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
local Entity = require "engine.Entity"
local Tiles = require "engine.Tiles"
local Particles = require "engine.Particles"
local Faction = require "engine.Faction"
local DamageType = require "engine.DamageType"

--- Represents a level map, handles display and various low level map work
module(..., package.seeall, class.make)

--- The map vertical depth storage
zdepth = 18

--- The place of a terrain entity in a map grid
TERRAIN = 1
--- The place of a terrain entity in a map grid
TRAP = 50
--- The place of an actor entity in a map grid
ACTOR = 100
--- The place of a projectile entity in a map grid
PROJECTILE = 500
--- The place of an object entity in a map grid
OBJECT = 1000

--- The order of checks for checkAllEntities
searchOrder = { ACTOR, TERRAIN, PROJECTILE, TRAP, OBJECT }
searchOrderSort = function(a, b)
	if a == ACTOR then return true
	elseif b == ACTOR then return false
	elseif a == TERRAIN then return true
	elseif b == TERRAIN then return false
	elseif a == PROJECTILE then return true
	elseif b == PROJECTILE then return false
	elseif a == TRAP then return true
	elseif b == TRAP then return false
	elseif a == OBJECT then return true
	elseif b == OBJECT then return false
	else return a < b end
end

color_shown   = { 1, 1, 1, 1 }
color_obscure = { 0.6, 0.6, 0.6, 1 }
smooth_scroll = 0

--- Sets the viewport size
-- Static
-- @param x screen coordinate where the map will be displayed (this has no impact on the real display). This is used to compute mouse clicks
-- @param y screen coordinate where the map will be displayed (this has no impact on the real display). This is used to compute mouse clicks
-- @param w width
-- @param h height
-- @param tile_w width of a single tile
-- @param tile_h height of a single tile
-- @param fontname font parameters, can be nil
-- @param fontsize font parameters, can be nil
function _M:setViewPort(x, y, w, h, tile_w, tile_h, fontname, fontsize, allow_backcolor)
	self.allow_backcolor = allow_backcolor
	self.display_x, self.display_y = math.floor(x), math.floor(y)
	self.viewport = {width=math.floor(w), height=math.floor(h), mwidth=math.floor(w/tile_w), mheight=math.floor(h/tile_h)}
	self.tile_w, self.tile_h = tile_w, tile_h
	self.fontname, self.fontsize = fontname, fontsize
	self:resetTiles()
	self.zoom = 1
end

--- Sets zoom level
-- @param zoom nil to reset to default, otherwise a number to increment the zoom with
-- @param tmx make sure this coords are visible after zoom (can be nil)
-- @param tmy make sure this coords are visible after zoom (can be nil)
function _M:setZoom(zoom, tmx, tmy)
	self.changed = true
	_M.zoom = util.bound(_M.zoom + zoom, 0.1, 4)
	self.viewport.mwidth = math.floor(self.viewport.width / (self.tile_w * _M.zoom))
	self.viewport.mheight = math.floor(self.viewport.height / (self.tile_h * _M.zoom))
	print("[MAP] setting zoom level", _M.zoom, self.viewport.mwidth, self.viewport.mheight)

	self._map:setZoom(
		self.tile_w * self.zoom,
		self.tile_h * self.zoom,
		self.viewport.mwidth,
		self.viewport.mheight
	)
	if tmx and tmy then
		self:centerViewAround(tmx, tmy)
	else
		self:checkMapViewBounded()
	end
end

--- Defines the "obscure" factor of unseen map
-- By default it is 0.6, 0.6, 0.6, 1
function _M:setObscure(r, g, b, a)
	self.color_obscure = {r, g, b, a}
	-- If we are used on a real map, set it locally
	if self._map then self._map:setObscure(unpack(self.color_obscure)) end
end

--- Defines the "shown" factor of seen map
-- By default it is 1, 1, 1, 1
function _M:setShown(r, g, b, a)
	self.color_shown = {r, g, b, a}
	-- If we are used on a real map, set it locally
	if self._map then self._map:setShown(unpack(self.color_shown)) end
end

--- Create the tile repositories
function _M:resetTiles()
	Entity:invalidateAllMO()
	self.tiles = Tiles.new(self.tile_w, self.tile_h, self.fontname, self.fontsize, true, self.allow_backcolor)
	self.tilesSurface = Tiles.new(self.tile_w, self.tile_h, self.fontname, self.fontsize, false, false)
	self.tilesTactic = Tiles.new(self.tile_w, self.tile_h, self.fontname, self.fontsize, true, false)
	self.tilesEffects = Tiles.new(self.tile_w, self.tile_h, self.fontname, self.fontsize, true, true)
end

--- Defines the faction of the person seeing the map
-- Usually this will be the player's faction. If you do not want to use tactical display, dont use it
function _M:setViewerFaction(faction, friend, neutral, enemy)
	self.view_faction = faction
	self.faction_friend = "tactical_friend.png"
	self.faction_neutral = "tactical_neutral.png"
	self.faction_enemy = "tactical_enemy.png"
end

--- Defines the actor that sees the map
-- Usually this will be the player. This is used to determine invisibility/...
function _M:setViewerActor(player)
	self.actor_player = player
end

--- Creates a map
-- @param w width (in grids)
-- @param h height (in grids)
function _M:init(w, h)
	self.mx = 0
	self.my = 0
	self.w, self.h = w, h
	self.map = {}
	self.attrs = {}
	self.lites = {}
	self.seens = {}
	self.infovs = {}
	self.has_seens = {}
	self.remembers = {}
	self.effects = {}
	self.path_strings = {}
	for i = 0, w * h - 1 do self.map[i] = {} end

	self.particles = {}
	self.emotes = {}

	self:loaded()
end

--- Serialization
function _M:save()
	return class.save(self, {
		_check_entities = true,
		_check_entities_store = true,
		_map = true,
		_fovcache = true,
		surface = true,
	})
end

function _M:makeCMap()
	--util.show_backtrace()
	self._map = core.map.newMap(self.w, self.h, self.mx, self.my, self.viewport.mwidth, self.viewport.mheight, self.tile_w, self.tile_h, self.zdepth)
	self._map:setObscure(unpack(self.color_obscure))
	self._map:setShown(unpack(self.color_shown))
	self._fovcache =
	{
		block_sight = core.fov.newCache(self.w, self.h),
		block_esp = core.fov.newCache(self.w, self.h),
		block_sense = core.fov.newCache(self.w, self.h),
		path_caches = {},
	}
	for i, ps in ipairs(self.path_strings) do
		self._fovcache.path_caches[ps] = core.fov.newCache(self.w, self.h)
	end
end

--- Adds a "path string" to the map
-- "Path strings" are strings defining what terrain an actor can cross. Their format is left to the module to decide (by overloading Actor:getPathString() )<br/>
-- They are totally optional as they re only used to compute A* paths and the likes and even then the algorithms still work without them, only slower<br/>
-- If you use them the block_move function of your Grid class must be able to handle either an actor or a "path string" as their third argument
function _M:addPathString(ps)
	for i, eps in ipairs(self.path_strings) do
		if eps == ps then return end
	end
	self.path_strings[#self.path_strings+1] = ps
	if self._fovcache then self._fovcache.path_caches[ps] = core.fov.newCache(self.w, self.h) end
end

function _M:loaded()
	self:makeCMap()

	local mapseen = function(t, x, y, v)
		if x < 0 or y < 0 or x >= self.w or y >= self.h then return end
		if v ~= nil then
			t[x + y * self.w] = v
			self._map:setSeen(x, y, v)
			if v then self.has_seens[x + y * self.w] = true end
			self.changed = true
		end
		return t[x + y * self.w]
	end
	local mapfov = function(t, x, y, v)
		if x < 0 or y < 0 or x >= self.w or y >= self.h then return end
		if v ~= nil then
			t[x + y * self.w] = v
		end
		return t[x + y * self.w]
	end
	local maphasseen = function(t, x, y, v)
		if x < 0 or y < 0 or x >= self.w or y >= self.h then return end
		if v ~= nil then
			t[x + y * self.w] = v
		end
		return t[x + y * self.w]
	end
	local mapremember = function(t, x, y, v)
		if x < 0 or y < 0 or x >= self.w or y >= self.h then return end
		if v ~= nil then
			t[x + y * self.w] = v
			self._map:setRemember(x, y, v)
			self.changed = true
		end
		return t[x + y * self.w]
	end
	local maplite = function(t, x, y, v)
		if x < 0 or y < 0 or x >= self.w or y >= self.h then return end
		if v ~= nil then
			t[x + y * self.w] = v
			self._map:setLite(x, y, v)
			self.changed = true
		end
		return t[x + y * self.w]
	end
	local mapattrs = function(t, x, y, k, v)
		if x < 0 or y < 0 or x >= self.w or y >= self.h then return end
		if v ~= nil then
			if not t[x + y * self.w] then t[x + y * self.w] = {} end
			t[x + y * self.w][k] = v
		end
		return t[x + y * self.w] and t[x + y * self.w][k]
	end

	getmetatable(self).__call = _M.call
	setmetatable(self.lites, {__call = maplite})
	setmetatable(self.seens, {__call = mapseen})
	setmetatable(self.infovs, {__call = mapfov})
	setmetatable(self.has_seens, {__call = maphasseen})
	setmetatable(self.remembers, {__call = mapremember})
	setmetatable(self.attrs, {__call = mapattrs})

	self._check_entities = {}
	self._check_entities_store = {}

	self.changed = true
	self.finished = true

	self:redisplay()
end

--- Recreate the internal map using new dimensions
function _M:recreate()
	self:makeCMap()
	self.changed = true

	-- Update particles to the correct size
	for e, _ in pairs(self.particles) do
		e:loaded()
	end

	self:redisplay()
end

--- Redisplays the map, storing seen information
function _M:redisplay()
	for i = 0, self.w - 1 do for j = 0, self.h - 1 do
		self._map:setSeen(i, j, self.seens(i, j))
		self._map:setRemember(i, j, self.remembers(i, j))
		self._map:setLite(i, j, self.lites(i, j))
		self:updateMap(i, j)
	end end
end

--- Closes things in the object to allow it to be garbage collected
-- Map objects are NOT automatically garbage collected because they contain FOV C structure, which themselves have a reference
-- to the map. Cyclic references! BAD BAD BAD !<br/>
-- The closing should be handled automatically by the Zone class so no bother for authors
function _M:close()
end

--- Cleans the FOV infos (seens table)
function _M:cleanFOV()
	if not self.clean_fov then return end
	self.clean_fov = false
	for i = 0, self.w * self.h - 1 do self.seens[i] = nil self.infovs[i] = nil end
	self._map:cleanSeen()
end

--- Updates the map on the given spot
-- This updates many things, from the C map object, the FOV caches, the minimap if it exists, ...
function _M:updateMap(x, y)
	-- Update minimap if any
	local mos = {}

	if not self.updateMapDisplay then
		local g = self(x, y, TERRAIN)
		local o = self(x, y, OBJECT)
		local a = self(x, y, ACTOR)
		local t = self(x, y, TRAP)
		local p = self(x, y, PROJECTILE)

		if g then
			-- Update path caches from path strings
			for i = 1, #self.path_strings do
				local ps = self.path_strings[i]
				self._fovcache.path_caches[ps]:set(x, y, g:check("block_move", x, y, ps, false, true))
			end

			g:getMapObjects(self.tiles, mos, 1)
			g:setupMinimapInfo(g._mo, self)
		end
		if t then
			-- Handles trap being known
			if not self.actor_player or t:knownBy(self.actor_player) then
				t:getMapObjects(self.tiles, mos, 4)
				t:setupMinimapInfo(t._mo, self)
			else
				t = nil
			end
		end
		if o then
			o:getMapObjects(self.tiles, mos, 7)
			o:setupMinimapInfo(o._mo, self)
			if self.object_stack_count then
				local mo = o:getMapStackMO(self, x, y)
				if mo then mos[9] = mo end
			end
		end
		if a then
			-- Handles invisibility and telepathy and other such things
			if not self.actor_player or self.actor_player:canSee(a) then
				a:getMapObjects(self.tiles, mos, 10)
				a:setupMinimapInfo(a._mo, self)
			end
		end
		if p then
			p:getMapObjects(self.tiles, mos, 13)
			p:setupMinimapInfo(p._mo, self)
		end
	else
		self:updateMapDisplay(x, y, mos)
	end

	-- Update entities checker for this spot
	-- This is to improve speed, we create a function for each spot that checks entities it knows are there
	-- This avoid a costly for iteration over a pairs() and this allows luajit to compile only code that is needed
	local ce, sort = {}, {}
	local fstr = [[if m[%s] then p = m[%s]:check(what, x, y, ...) if p then return p end end ]]
	ce[#ce+1] = [[return function(self, x, y, what, ...) local p local m = self.map[x + y * self.w] ]]
	for idx, e in pairs(self.map[x + y * self.w]) do sort[#sort+1] = idx end
	table.sort(sort, searchOrderSort)
	for i = 1, #sort do ce[#ce+1] = fstr:format(sort[i], sort[i]) end
	ce[#ce+1] = [[end]]
	local ce = table.concat(ce)
	self._check_entities[x + y * self.w] = self._check_entities_store[ce] or loadstring(ce)()
	self._check_entities_store[ce] = self._check_entities[x + y * self.w]

	-- Cache the map objects in the C map
	self._map:setGrid(x, y, mos)

	-- Update FOV caches
	if self:checkAllEntities(x, y, "block_sight", self.actor_player) then self._fovcache.block_sight:set(x, y, true)
	else self._fovcache.block_sight:set(x, y, false) end
	if self:checkAllEntities(x, y, "block_esp", self.actor_player) then self._fovcache.block_esp:set(x, y, true)
	else self._fovcache.block_esp:set(x, y, false) end
	if self:checkAllEntities(x, y, "block_sense", self.actor_player) then self._fovcache.block_sense:set(x, y, true)
	else self._fovcache.block_sense:set(x, y, false) end
end

--- Sets/gets a value from the map
-- It is defined as the function metamethod, so one can simply do: mymap(x, y, Map.TERRAIN)
-- @param x position
-- @param y position
-- @param pos what kind of entity to set(Map.TERRAIN, Map.OBJECT, Map.ACTOR)
-- @param e the entity to set, if null it will return the current one
function _M:call(x, y, pos, e)
	if x < 0 or y < 0 or x >= self.w or y >= self.h then return end
	if e then
		self.map[x + y * self.w][pos] = e
		if e.__position_aware then e.x = x e.y = y end
		self.changed = true

		self:updateMap(x, y)
	else
		if self.map[x + y * self.w] then
			if not pos then
				return self.map[x + y * self.w]
			else
				return self.map[x + y * self.w][pos]
			end
		end
	end
end

--- Removes an entity
-- @param x position
-- @param y position
-- @param pos what kind of entity to set(Map.TERRAIN, Map.OBJECT, Map.ACTOR)
function _M:remove(x, y, pos)
	if self.map[x + y * self.w] then
		local e = self.map[x + y * self.w][pos]
		self.map[x + y * self.w][pos]= nil
		self:updateMap(x, y)
		self.changed = true
		return e
	end
end

--- Displays the minimap
-- @return a surface containing the drawn map
function _M:minimapDisplay(dx, dy, x, y, w, h, transp)
	self._map:toScreenMiniMap(dx, dy, x, y, w, h, transp or 0.6)
end

--- Displays the map on screen
-- @param x the coord where to start drawing, if null it uses self.display_x
-- @param y the coord where to start drawing, if null it uses self.display_y
-- @param nb_keyframes the number of keyframes elapsed since last draw
-- @param always_show tell the map code to force display unseed entities as remembered (used for smooth FOV shading)
function _M:display(x, y, nb_keyframe, always_show)
	nb_keyframes = nb_keyframes or 1
	local ox, oy = self.display_x, self.display_y
	self.display_x, self.display_y = x or self.display_x, y or self.display_y

	self._map:toScreen(self.display_x, self.display_y, nb_keyframe, always_show)

	-- Tactical display
	if self.view_faction then
		local e
		local z
		local adx, ady
		local friend
		for i = self.mx, self.mx + self.viewport.mwidth do
		for j = self.my, self.my + self.viewport.mheight do
			local z = i + j * self.w

			if self.seens[z] then
				e = self(i, j, ACTOR)
				if e and (not self.actor_player or self.actor_player:canSee(e)) then
					-- Tactical overlay ?
					if e.faction then
						if not self.actor_player then friend = Faction:factionReaction(self.view_faction, e.faction)
						else friend = self.actor_player:reactionToward(e) end
						if e._mo then adx, ady = e._mo:getMoveAnim(self._map, i, j) else adx, ady = 0, 0 end -- Make sure we display on the real screen coords: handle current move anim position
						if friend > 0 then
							self.tilesTactic:get(nil, 0,0,0, 0,0,0, self.faction_friend):toScreen(self.display_x + (adx + i - self.mx) * self.tile_w * self.zoom, self.display_y + (ady + j - self.my) * self.tile_h * self.zoom, self.tile_w * self.zoom, self.tile_h * self.zoom)
						elseif friend < 0 then
							self.tilesTactic:get(nil, 0,0,0, 0,0,0, self.faction_enemy):toScreen(self.display_x + (adx + i - self.mx) * self.tile_w * self.zoom, self.display_y + (ady + j - self.my) * self.tile_h * self.zoom, self.tile_w * self.zoom, self.tile_h * self.zoom)
						else
							self.tilesTactic:get(nil, 0,0,0, 0,0,0, self.faction_neutral):toScreen(self.display_x + (adx + i - self.mx) * self.tile_w * self.zoom, self.display_y + (ady + j - self.my) * self.tile_h * self.zoom, self.tile_w * self.zoom, self.tile_h * self.zoom)
						end
					end
				end
			end
		end end
	end

	self:displayParticles(nb_keyframe)
	self:displayEffects()
	self:displayEmotes(nb_keyframe)

	self.display_x, self.display_y = ox, oy

	-- If nothing changed, return the same surface as before
	if not self.changed then return end
	self.changed = false
	self.clean_fov = true
end

--- Sets checks if a grid lets sight pass through
-- Used by FOV code
function _M:opaque(x, y)
	if x < 0 or x >= self.w or y < 0 or y >= self.h then return false end
	local e = self.map[x + y * self.w][TERRAIN]
	if e and e:check("block_sight") then return true end
end

--- Sets checks if a grid lets ESP pass through
-- Used by FOV ESP code
function _M:opaqueESP(x, y)
	if x < 0 or x >= self.w or y < 0 or y >= self.h then return false end
	local e = self.map[x + y * self.w][TERRAIN]
	if e and e:check("block_esp") then return true end
end

--- Sets a grid as seen and remembered
-- Used by FOV code
function _M:apply(x, y, v)
	if x < 0 or x >= self.w or y < 0 or y >= self.h then return end
	self.infovs[x + y * self.w] = true
	if self.lites[x + y * self.w] then
		self.seens[x + y * self.w] = v or 1
		self.has_seens[x + y * self.w] = true
		self._map:setSeen(x, y, v or 1)
		self.remembers[x + y * self.w] = true
		self._map:setRemember(x, y, true)
	end
end

--- Sets a grid as seen, lited and remembered, if it is in the current FOV
-- Used by FOV code
function _M:applyExtraLite(x, y, v)
	if x < 0 or x >= self.w or y < 0 or y >= self.h then return end
	if not self.infovs[x + y * self.w] then return end
	if self.lites[x + y * self.w] or self:checkEntity(x, y, TERRAIN, "always_remember") then
		self.remembers[x + y * self.w] = true
		self._map:setRemember(x, y, true)
	end
	self.seens[x + y * self.w] = v or 1
	self.has_seens[x + y * self.w] = true
	self._map:setSeen(x, y, v or 1)
end

--- Sets a grid as seen, lited and remembered
-- Used by FOV code
function _M:applyLite(x, y, v)
	if x < 0 or x >= self.w or y < 0 or y >= self.h then return end
	if self.lites[x + y * self.w] or self:checkEntity(x, y, TERRAIN, "always_remember") then
		self.remembers[x + y * self.w] = true
		self._map:setRemember(x, y, true)
	end
	self.seens[x + y * self.w] = v or 1
	self.has_seens[x + y * self.w] = true
	self._map:setSeen(x, y, v or 1)
end

--- Sets a grid as seen if ESP'ed
-- Used by FOV code
function _M:applyESP(x, y, v)
	if not self.actor_player then return end
	if x < 0 or x >= self.w or y < 0 or y >= self.h then return end
	local a = self.map[x + y * self.w][ACTOR]
	if a and self.actor_player:canSee(a, false, 0, true) then
		self.seens[x + y * self.w] = v or 1
		self._map:setSeen(x, y, v or 1)
	end
end

--- Check all entities of the grid for a property until it finds one/returns one
-- This will stop at the first entity with the given property (or if the property is a function, the return of the function that is not false/nil).
-- No guaranty is given about the iteration order
-- @param x position
-- @param y position
-- @param what property to check
function _M:checkAllEntities(x, y, what, ...)
	if x < 0 or x >= self.w or y < 0 or y >= self.h then return end
	if self.map[x + y * self.w] then
		return self._check_entities[x + y * self.w](self, x, y, what, ...)
	end
end

--- Check all entities of the grid for a property, discarding the results
-- This will iterate over all entities without stopping.
-- No guaranty is given about the iteration order
-- @param x position
-- @param y position
-- @param what property to check
-- @return a table containing all return values, indexed by the entities
function _M:checkAllEntitiesNoStop(x, y, what, ...)
	if x < 0 or x >= self.w or y < 0 or y >= self.h then return {} end
	local ret = {}
	local tile = self.map[x + y * self.w]
	if tile then
		-- Collect the keys so we can modify the table while iterating
		local keys = {}
		for k, _ in pairs(tile) do
			table.insert(keys, k)
		end
		-- Now iterate over the stored keys, checking if the entry exists
		for i = 1, #keys do
			local e = tile[keys[i]]
			if e then
				ret[e] = e:check(what, x, y, ...)
			end
		end
	end
	return ret
end

--- Check specified entity position of the grid for a property
-- @param x position
-- @param y position
-- @param pos entity position in the grid
-- @param what property to check
function _M:checkEntity(x, y, pos, what, ...)
	if x < 0 or x >= self.w or y < 0 or y >= self.h then return end
	if self.map[x + y * self.w] then
		if self.map[x + y * self.w][pos] then
			local p = self.map[x + y * self.w][pos]:check(what, x, y, ...)
			if p then return p end
		end
	end
end

--- Lite all grids
function _M:liteAll(x, y, w, h)
	for i = x, x + w - 1 do for j = y, y + h - 1 do
		self.lites(i, j, true)
	end end
end

--- Remember all grids
function _M:rememberAll(x, y, w, h)
	for i = x, x + w - 1 do for j = y, y + h - 1 do
		self.remembers(i, j, true)
	end end
end

--- Sets the current view area with the given coords at the center
function _M:centerViewAround(x, y)
	self.mx = x - math.floor(self.viewport.mwidth / 2)
	self.my = y - math.floor(self.viewport.mheight / 2)
	self.changed = true
	self:checkMapViewBounded()
end

--- Sets the current view area if x and y are out of bounds
function _M:moveViewSurround(x, y, marginx, marginy)
	local omx, omy = self.mx, self.my

	if marginx * 2 > self.viewport.mwidth then
		self.mx = x - math.floor(self.viewport.mwidth / 2)
		self.changed = true
	elseif self.mx + marginx >= x then
		self.mx = x - marginx
		self.changed = true
	elseif self.mx + self.viewport.mwidth - marginx <= x then
		self.mx = x - self.viewport.mwidth + marginx
		self.changed = true
	end
	if marginy * 2 > self.viewport.mheight then
		self.my = y - math.floor(self.viewport.mheight / 2)
		self.changed = true
	elseif self.my + marginy >= y then
		self.my = y - marginy
		self.changed = true
	elseif self.my + self.viewport.mheight - marginy <= y then
		self.my = y - self.viewport.mheight + marginy
		self.changed = true
	end
--[[
	if self.mx + marginx >= x or self.mx + self.viewport.mwidth - marginx <= x then
		self.mx = x - math.floor(self.viewport.mwidth / 2)
		self.changed = true
	end
	if self.my + marginy >= y or self.my + self.viewport.mheight - marginy <= y then
		self.my = y - math.floor(self.viewport.mheight / 2)
		self.changed = true
	end
]]
	self:checkMapViewBounded()
	return self.mx - omx, self.my - omy
end

--- Checks the map is bound to the screen (no "empty space" if the map is big enough)
function _M:checkMapViewBounded()
	if self.mx < 0 then self.mx = 0 self.changed = true end
	if self.my < 0 then self.my = 0 self.changed = true end
	if self.mx > self.w - self.viewport.mwidth then self.mx = self.w - self.viewport.mwidth self.changed = true end
	if self.my > self.h - self.viewport.mheight then self.my = self.h - self.viewport.mheight self.changed = true end

	-- Center if smaller than map viewport
	local centered = false
	if self.w < self.viewport.mwidth then self.mx = math.floor((self.w - self.viewport.mwidth) / 2) centered = true end
	if self.h < self.viewport.mheight then self.my = math.floor((self.h - self.viewport.mheight) / 2) centered = true end

	self._map:setScroll(self.mx, self.my, centered and 0 or self.smooth_scroll)
end

--- Gets the tile under the mouse
function _M:getMouseTile(mx, my)
--	if mx < self.display_x or my < self.display_y or mx >= self.display_x + self.viewport.width or my >= self.display_y + self.viewport.height then return end
	local tmx = math.floor((mx - self.display_x) / (self.tile_w * self.zoom)) + self.mx
	local tmy = math.floor((my - self.display_y) / (self.tile_h * self.zoom)) + self.my
	return tmx, tmy
end

--- Get the screen position corresponding to a tile
function _M:getTileToScreen(tx, ty)
	local x = (tx - self.mx) * self.tile_w * self.zoom + self.display_x
	local y = (ty - self.my) * self.tile_h * self.zoom + self.display_y
	return x, y
end

--- Checks the given coords to see if they are in bound
function _M:isBound(x, y)
	if x < 0 or x >= self.w or y < 0 or y >= self.h then return false end
	return true
end

--- Checks the given coords to see if they are displayed on screen
function _M:isOnScreen(x, y)
	if x >= self.mx and x < self.mx + self.viewport.mwidth and y >= self.my and y < self.my + self.viewport.mheight then
		return true
	end
	return false
end

--- Get the screen offset where to start drawing (upper corner)
function _M:getScreenUpperCorner()
	local sx, sy = self._map:getScroll()
	local x = -self.mx * self.tile_w * self.zoom + self.display_x + sx
	local y = -self.my * self.tile_h * self.zoom + self.display_y + sy
	return x, y
end

--- Import a map into the current one
-- @param map the map to import
-- @param dx coordinate where to import it in the current map
-- @param dy coordinate where to import it in the current map
-- @param sx coordinate where to start importing the map, defaults to 0
-- @param sy coordinate where to start importing the map, defaults to 0
-- @param sw size of the imported map to get, defaults to map size
-- @param sh size of the imported map to get, defaults to map size
function _M:import(map, dx, dy, sx, sy, sw, sh)
	sx = sx or 0
	sy = sy or 0
	sw = sw or map.w
	sh = sh or map.h

	for i = sx, sx + sw - 1 do for j = sy, sy + sh - 1 do
		local x, y = dx + i, dy + j

		self.attrs[x + y * self.w] = map.attrs[i + j * map.w]
		self.map[x + y * self.w] = map.map[i + j * map.w]
		for z, e in pairs(self.map[x + y * self.w]) do
			if e.move then
				e.x = nil e.y = nil e:move(x, y, true)
			end
		end

		if self.room_map then
			self.room_map[x] = self.room_map[x] or {}
			self.room_map[x][y] = map.room_map[i][j]
		end
		self.remembers(x, y, map.remembers(i, j))
		self.seens(x, y, map.seens(i, j))
		self.lites(x, y, map.lites(i, j))


		self:updateMap(x, y)
	end end
	self.changed = true
end

--- Adds a zone (temporary) effect
-- @param src the source actor
-- @param x the epicenter coords
-- @param y the epicenter coords
-- @param duration the number of turns to persist
-- @param damtype the DamageType to apply
-- @param radius the radius of the effect
-- @param dir the numpad direction of the effect, 5 for a ball effect
-- @param overlay either a simple display entity to draw upon the map or a Particle class
-- @param update_fct optional function that will be called each time the effect is updated with the effect itself as parameter. Use it to change radius, move around ....
function _M:addEffect(src, x, y, duration, damtype, dam, radius, dir, angle, overlay, update_fct, friendlyfire)
	if friendlyfire == nil then friendlyfire = true end

	local grids

	-- Handle balls
	if dir == 5 then
		grids = core.fov.circle_grids(x, y, radius, true)
	-- Handle beams
	else
		grids = core.fov.beam_grids(x, y, radius, dir, angle, true)
	end

	local e = {
		src=src, x=x, y=y, duration=duration, damtype=damtype, dam=dam, radius=radius, dir=dir, angle=angle,
		overlay=overlay.__CLASSNAME and overlay,
		grids = grids,
		update_fct=update_fct, friendlyfire=friendlyfire
	}

	if not overlay.__CLASSNAME then
		e.particles = {}
		for lx, ys in pairs(grids) do
			for ly, _ in pairs(ys) do
				e.particles[#e.particles+1] = self:particleEmitter(lx, ly, 1, overlay.type, overlay.args)
			end
		end
	end

	table.insert(self.effects, e)

	self.changed = true
end

--- Display the overlay effects, called by self:display()
function _M:displayEffects()
	local sx, sy = self._map:getScroll()
	for i, e in ipairs(self.effects) do
		-- Dont bother with obviously out of screen stuff
		if e.overlay and e.x + e.radius >= self.mx and e.x - e.radius < self.mx + self.viewport.mwidth and e.y + e.radius >= self.my and e.y - e.radius < self.my + self.viewport.mheight then
			local s = self.tilesEffects:get(e.overlay.display, e.overlay.color_r, e.overlay.color_g, e.overlay.color_b, e.overlay.color_br, e.overlay.color_bg, e.overlay.color_bb, e.overlay.image, e.overlay.alpha)

			-- Now display each grids
			for lx, ys in pairs(e.grids) do
				for ly, _ in pairs(ys) do
					if self.seens(lx, ly) then
						s:toScreen(self.display_x + sx + (lx - self.mx) * self.tile_w * self.zoom, self.display_y + sy + (ly - self.my) * self.tile_h * self.zoom, self.tile_w * self.zoom, self.tile_h * self.zoom)
					end
				end
			end
		end
	end
end

--- Process the overlay effects, call it from your tick function
function _M:processEffects()
	local todel = {}
	for i, e in ipairs(self.effects) do
		-- Now display each grids
		for lx, ys in pairs(e.grids) do
			for ly, _ in pairs(ys) do
				if e.friendlyfire or not (lx == e.src.x and ly == e.src.y) then
					DamageType:get(e.damtype).projector(e.src, lx, ly, e.damtype, e.dam)
				end
			end
		end

		e.duration = e.duration - 1
		if e.duration <= 0 then
			table.insert(todel, i)
		elseif e.update_fct then
			if e:update_fct() then
				if e.dir == 5 then e.grids = core.fov.circle_grids(e.x, e.y, e.radius, true)
				else e.grids = core.fov.beam_grids(e.x, e.y, e.radius, e.dir, e.angle, true) end
				if e.particles then
					for j, ps in ipairs(e.particles) do self:removeParticleEmitter(ps) end
					e.particles = {}
					for lx, ys in pairs(grids) do
						for ly, _ in pairs(ys) do
							e.particles[#e.particles+1] = self:particleEmitter(lx, ly, 1, overlay.type, overlay.args)
						end
					end
				end
			end
		end
	end

	for i = #todel, 1, -1 do
		if self.effects[todel[i]].particles then
			for j, ps in ipairs(self.effects[todel[i]].particles) do self:removeParticleEmitter(ps) end
		end
		table.remove(self.effects, todel[i])
	end
end


-------------------------------------------------------------
-------------------------------------------------------------
-- Object functions
-------------------------------------------------------------
-------------------------------------------------------------
function _M:addObject(x, y, o)
	local i = self.OBJECT
	-- Find the first "hole"
	while self(x, y, i) do i = i + 1 end
	-- Fill it
	self(x, y, i, o)
	return true, i - self.OBJECT + 1
end

function _M:getObject(x, y, i)
	-- Compute the map stack position
	i = i - 1 + self.OBJECT
	return self(x, y, i)
end

function _M:getObjectTotal(x, y)
	-- Compute the map stack position
	local i = 1
	while self:getObject(x, y, i) do i = i + 1 end
	return i - 1
end

function _M:removeObject(x, y, i)
	-- Compute the map stack position
	i = i - 1 + self.OBJECT
	if not self(x, y, i) then return false end
	-- Remove it
	self:remove(x, y, i)

	i = i + 1
	while self(x, y, i) do
		self(x, y, i - 1, self:remove(x, y, i))
		i = i + 1
	end

	return true
end

-------------------------------------------------------------
-------------------------------------------------------------
-- Particle projector
-------------------------------------------------------------
-------------------------------------------------------------

--- Add a new particle emitter
function _M:particleEmitter(x, y, radius, def, args)
	local e = Particles.new(def, radius, args)
	e.x = x
	e.y = y

	self.particles[e] = true
	return e
end

--- Adds an existing particle emitter to the map
function _M:addParticleEmitter(e)
	if self.particles[e] then return false end
	self.particles[e] = true
	return e
end

--- Removes a particle emitter from the map
function _M:removeParticleEmitter(e)
	if not self.particles[e] then return false end
	self.particles[e] = nil
	return true
end

--- Display the particle emitters, called by self:display()
function _M:displayParticles(nb_keyframes)
	nb_keyframes = nb_keyframes or 1
	local adx, ady
	local alive
	local del = {}
	local e = next(self.particles)
	while e do
		if e._mo and e.x and e.y then adx, ady = e._mo:getMoveAnim(self._map, e.x, e.y) else adx, ady = 0, 0 end -- Make sure we display on the real screen coords: handle current move anim position

		if nb_keyframes == 0 and e.x and e.y then
			-- Just display it, not updating, no emitting
			if e.x + e.radius >= self.mx and e.x - e.radius < self.mx + self.viewport.mwidth and e.y + e.radius >= self.my and e.y - e.radius < self.my + self.viewport.mheight then
				e.ps:toScreen(self.display_x + (adx + e.x - self.mx + 0.5) * self.tile_w * self.zoom, self.display_y + (ady + e.y - self.my + 0.5) * self.tile_h * self.zoom, self.seens(e.x, e.y), e.zoom * self.zoom)
			end
		elseif e.x and e.y then
			alive = e.ps:isAlive()

			-- Update more, if needed
			if alive and e.x + e.radius >= self.mx and e.x - e.radius < self.mx + self.viewport.mwidth and e.y + e.radius >= self.my and e.y - e.radius < self.my + self.viewport.mheight then
				e.ps:toScreen(self.display_x + (adx + e.x - self.mx + 0.5) * self.tile_w * self.zoom, self.display_y + (ady + e.y - self.my + 0.5) * self.tile_h * self.zoom, self.seens(e.x, e.y))
			end

			if not alive then
				del[#del+1] = e
				e.dead = true
			end
		else
			del[#del+1] = e
			e.dead = true
		end

		e = next(self.particles, e)
	end
	for i = 1, #del do self.particles[del[i]] = nil end
end

-------------------------------------------------------------
-------------------------------------------------------------
-- Emotes
-------------------------------------------------------------
-------------------------------------------------------------

--- Adds an existing emote to the map
function _M:addEmote(e)
	if self.emotes[e] then return false end
	self.emotes[e] = true
	print("[EMOTE] added", e.text, e.x, e.y)
	return e
end

--- Removes an emote from the map
function _M:removeEmote(e)
	if not self.emotes[e] then return false end
	self.emotes[e] = nil
	return true
end

--- Display the emotes, called by self:display()
function _M:displayEmotes(nb_keyframes)
	local del = {}
	local e = next(self.emotes)
	while e do
		-- Dont bother with obviously out of screen stuff
		if e.x >= self.mx and e.x < self.mx + self.viewport.mwidth and e.y >= self.my and e.y < self.my + self.viewport.mheight and self.seens(e.x, e.y) then
			e.surface:toScreen(
				self.display_x + (e.x - self.mx + 0.5) * self.tile_w * self.zoom,
				self.display_y + (e.y - self.my - 0.9) * self.tile_h * self.zoom
			)
		end

		for i = 1, nb_keyframes do
			if e:update() then
				del[#del+1] = e
				e.dead = true
				break
			end
		end

		e = next(self.emotes, e)
	end
	for i = 1, #del do self.emotes[del[i]] = nil end
end
