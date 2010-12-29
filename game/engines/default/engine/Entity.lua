
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

--- A game entity
-- An entity is anything that goes on a map, terrain features, objects, monsters, player, ...
-- Usually there is no need to use it directly, and it is betetr to use specific engine.Grid, engine.Actor or engine.Object
-- classes. Most modules will want to subclass those anyway to add new comportments
local Shader = require "engine.Shader"

module(..., package.seeall, class.make)

local next_uid = 1
local entities_load_functions = {}

_M.__mo_repo = {}
_M.__mo_final_repo = {}
_M._no_save_fields = {}
_M.__position_aware = false -- Subclasses can change it to know where they are on the map

-- Setup the uids & MO repository as a weak value table, when the entities are no more used anywhere else they disappear from there too
setmetatable(__uids, {__mode="v"})
setmetatable(_M.__mo_repo, {__mode="k"})
setmetatable(_M.__mo_final_repo, {__mode="k"})

--- Invalidates the whole MO repository
function _M:invalidateAllMO()
	for mo, _ in pairs(_M.__mo_repo) do
		mo:invalidate()
	end
	_M.__mo_repo = {}
	setmetatable(_M.__mo_repo, {__mode="k"})
	setmetatable(_M.__mo_final_repo, {__mode="k"})
end

local function copy_recurs(dst, src, deep)
	for k, e in pairs(src) do
		if type(e) == "table" and e.__CLASSNAME then
			dst[k] = e
		elseif not dst[k] then
			if deep then
				dst[k] = {}
				copy_recurs(dst[k], e, deep)
			else
				dst[k] = e
			end
		elseif type(dst[k]) == "table" and type(e) == "table" and not e.__CLASSNAME then
			copy_recurs(dst[k], e, deep)
		end
	end
end

--- Initialize an entity
-- Any subclass MUST call this constructor
-- @param t a table defining the basic properties of the entity
-- @usage Entity.new{display='#', color_r=255, color_g=255, color_b=255}
function _M:init(t, no_default)
	t = t or {}
	self.uid = next_uid
	__uids[self.uid] = self

	for k, e in pairs(t) do
		if k ~= "__CLASSNAME" then
			local ee = e
			if type(e) == "table" and not e.__CLASSNAME then ee = table.clone(e, true) end
			self[k] = ee
		end
	end

	if self.color then
		self.color_r = self.color.r
		self.color_g = self.color.g
		self.color_b = self.color.b
		self.color = nil
	end
	if self.back_color then
		self.color_br = self.back_color.r
		self.color_bg = self.back_color.g
		self.color_bb = self.back_color.b
		self.back_color = nil
	end
	if self.tint then
		self.tint_r = self.tint.r / 255
		self.tint_g = self.tint.g / 255
		self.tint_b = self.tint.b / 255
		self.tint = nil
	end

	if not no_default then
		self.image = self.image or nil
		self.display = self.display or '.'
		self.color_r = self.color_r or 0
		self.color_g = self.color_g or 0
		self.color_b = self.color_b or 0
		self.color_br = self.color_br or -1
		self.color_bg = self.color_bg or -1
		self.color_bb = self.color_bb or -1
		self.tint_r = self.tint_r or 1
		self.tint_g = self.tint_g or 1
		self.tint_b = self.tint_b or 1
	end

	if self.unique and type(self.unique) ~= "string" then self.unique = self.name end

	next_uid = next_uid + 1

	self.changed = true
	self.__particles = self.__particles or {}
end

--- If we are cloned we need a new uid
function _M:cloned(src)
	self.uid = next_uid
	__uids[self.uid] = self
	next_uid = next_uid + 1

	self.changed = true
end

_M.__autoload = {}
_M.loadNoDelay = true
--- If we are loaded we need a new uid
function _M:loaded()
	local ouid = self.uid
	self.uid = next_uid
	__uids[self.uid] = self
	next_uid = next_uid + 1

	self.changed = true

	-- hackish :/
	if self.autoLoadedAI then self:autoLoadedAI() end
end

--- Change the entity's uid
-- <strong>*WARNING*</strong>: ONLY DO THIS IF YOU KNOW WHAT YOU ARE DOING!. YOU DO NOT !
function _M:changeUid(newuid)
	__uids[self.uid] = nil
	self.uid = newuid
	__uids[self.uid] = self
end

--- Create the "map object" representing this entity
-- Do not touch unless you *KNOW* what you are doing.<br/>
-- You do *NOT* need this, this is used by the engine.Map class automatically.<br/>
-- *DO NOT TOUCH!!!*
function _M:makeMapObject(tiles, idx)
	if idx > 1 and not tiles.use_images then return nil end
	if idx > 1 then
		if not self.add_displays or not self.add_displays[idx-1] then return nil end
		return self.add_displays[idx-1]:makeMapObject(tiles, 1)
	else
		if self._mo and self._mo:isValid() then return self._mo, self.z end
	end

	-- Create the map object with 1 + additional textures
	self._mo = core.map.newObject(self.uid,
		1 + (tiles.use_images and self.textures and #self.textures or 0),
		self:check("display_on_seen"),
		self:check("display_on_remember"),
		self:check("display_on_unknown"),
		self:check("display_x") or 0,
		self:check("display_y") or 0,
		self:check("display_scale") or 1
	)
	_M.__mo_repo[self._mo] = true

	-- Setup tint
	self._mo:tint(self.tint_r, self.tint_g, self.tint_b)

	-- Texture 0 is always the normal image/ascii tile
	self._mo:texture(0, tiles:get(self.display, self.color_r, self.color_g, self.color_b, self.color_br, self.color_bg, self.color_bb, self.image, self._noalpha and 255, self.ascii_outline))

	-- Setup additional textures
	if tiles.use_images and self.textures then
		for i = 1, #self.textures do
			local t = self.textures[i]
			if type(t) == "function" then local tex, is3d = t(self, tiles); if tex then self._mo:texture(i, tex, is3d) tiles.texture_store[tex] = true end
			elseif type(t) == "table" then
				if t[1] == "image" then local tex = tiles:get('', 0, 0, 0, 0, 0, 0, t[2]); self._mo:texture(i, tex, false) tiles.texture_store[tex] = true
				end
			end
		end
	end

	-- Setup shader
	if tiles.use_images and core.shader.active() and self.shader then
		local shad = Shader.new(self.shader, self.shader_args)
		if shad.shad then self._mo:shader(shad.shad) end
	end

	return self._mo, self.z
end

--- Get all "map objects" representing this entity
-- Do not touch unless you *KNOW* what you are doing.<br/>
-- You do *NOT* need this, this is used by the engine.Map class automatically.<br/>
-- *DO NOT TOUCH!!!*
function _M:getMapObjects(tiles, mos, z)
	local i = -1
	local mo, dz
	repeat
		i = i + 1
		mo, dz = self:makeMapObject(tiles, 1+i)
		if mo then
			mos[dz or z+i] = mo
		end
	until not mo
end

--- Setup movement animation for the entity
-- The entity is supposed to posses a correctly set x and y pair of fields - set to the current (new) position
-- @param oldx the coords from where the animation will seem to come from
-- @param oldy the coords from where the animation will seem to come from
-- @param speed the number of frames the animation lasts (frames are normalized to 30/sec no matter the actual FPS)
-- @param blur apply a motion blur effect of this number of frames
function _M:setMoveAnim(oldx, oldy, speed, blur)
	if not self._mo then return end
	self._mo:setMoveAnim(oldx, oldy, self.x, self.y, speed, blur)

	if not self.add_displays then return end

	for i = 1, #self.add_displays do
		if self.add_displays[i]._mo then
			self.add_displays[i]._mo:setMoveAnim(oldx, oldy, self.x, self.y, speed, blur)
		end
	end
end

--- Reset movement animation for the entity - removes any anim
function _M:resetMoveAnim()
	if not self._mo then return end
	self._mo:resetMoveAnim()

	if not self.add_displays then return end

	for i = 1, #self.add_displays do
		if self.add_displays[i]._mo then
			self.add_displays[i]._mo:resetMoveAnim()
		end
	end
end

--- Get the entity image as an sdl surface and texture for the given tiles and size
-- @param tiles a Tiles instance that will handle the tiles (usualy pass it the current Map.tiles)
-- @param w the width
-- @param h the height
-- @return the sdl surface and the texture
function _M:getEntityFinalSurface(tiles, w, h)
	local id = w.."x"..h
	if _M.__mo_final_repo[self] and _M.__mo_final_repo[self][id] then return _M.__mo_final_repo[self][id].surface, _M.__mo_final_repo[self][id].tex end

	local Map = require "engine.Map"

	local mos = {}
	local list = {}
	self:getMapObjects(tiles, mos, 1)
	for i = 1, Map.zdepth do
		if mos[i] then list[#list+1] = mos[i] end
	end
	local tex = core.map.mapObjectsToTexture(w, h, unpack(list))
	if not tex then return nil end
	_M.__mo_final_repo[self] = _M.__mo_final_repo[self] or {}
	_M.__mo_final_repo[self][id] = {surface=tex:toSurface(), tex=tex}
	return _M.__mo_final_repo[self][id].surface, _M.__mo_final_repo[self][id].tex
end

--- Get a string that will display in text the texture of this entity
function _M:getDisplayString(tstr)
	if tstr then
		if core.display.FBOActive() then
			return tstring{{"uid", self.uid}}
		else
			return tstring{}
		end
	else
		if core.display.FBOActive() then
			return "#UID:"..self.uid..":0#"
		else
			return ""
		end
	end
end

--- Displays an entity somewhere on screen, outside the map
-- @param tiles a Tiles instance that will handle the tiles (usualy pass it the current Map.tiles, it will if this is null)
-- @param w the width
-- @param h the height
-- @return the sdl surface and the texture
function _M:toScreen(tiles, x, y, w, h)
	local Map = require "engine.Map"
	tiles = tiles or Map.tiles

	local mos = {}
	local list = {}
	self:getMapObjects(tiles, mos, 1)
	for i = 1, Map.zdepth do
		if mos[i] then list[#list+1] = mos[i] end
	end
	core.map.mapObjectsToScreen(x, y, w, h, unpack(list))
end

--- Resolves an entity
-- This is called when generatingthe final clones of an entity for use in a level.<br/>
-- This can be used to make random enchants on objects, random properties on actors, ...<br/>
-- by default this only looks for properties with a table value containing a __resolver field
function _M:resolve(t, last, on_entity)
	t = t or self
	for k, e in pairs(t) do
		if type(e) == "table" and e.__resolver and (not e.__resolve_last or last) then
			t[k] = resolvers.calc[e.__resolver](e, on_entity or self, self, t, k)
		elseif type(e) == "table" and not e.__CLASSNAME then
			self:resolve(e, last, on_entity)
		end
	end

	-- Finish resolving stuff
	if on_entity then return end
	if t == self then
		if last then
			if self.resolveLevel then self:resolveLevel() end

			if self.unique and type(self.unique) == "boolean" then
				self.unique = self.name
			end
		else
			-- Handle ided if possible
			if self.resolveIdentify then self:resolveIdentify() end
		end
	end
end

--- Call when the entity is actually added to a level/whatever
-- This helps ensuring uniqueness of uniques
function _M:added()
	if self.unique then
		game.uniques[self.__CLASSNAME.."/"..self.unique] = (game.uniques[self.__CLASSNAME.."/"..self.unique] or 0) + 1
		print("Added unique", self.__CLASSNAME.."/"..self.unique, "::", game.uniques[self.__CLASSNAME.."/"..self.unique])
	end
end

--- Call when the entity is actually removed from existance
-- This helps ensuring uniqueness of uniques.
-- This recursively remvoes inventories too, if you need anythign special, overload this
function _M:removed()
	if self.inven then
		for _, inven in pairs(self.inven) do
			for i, o in ipairs(inven) do
				o:removed()
			end
		end
	end

	if self.unique then
		game.uniques[self.__CLASSNAME.."/"..self.unique] = (game.uniques[self.__CLASSNAME.."/"..self.unique] or 0) - 1
		if game.uniques[self.__CLASSNAME.."/"..self.unique] <= 0 then game.uniques[self.__CLASSNAME.."/"..self.unique] = nil end
		print("Removed unique", self.__CLASSNAME.."/"..self.unique, "::", game.uniques[self.__CLASSNAME.."/"..self.unique])
	end
end

--- Check for an entity's property
-- If not a function it returns it directly, otherwise it calls the function
-- with the extra parameters
-- @param prop the property name to check
function _M:check(prop, ...)
	if type(self[prop]) == "function" then return self[prop](self, ...)
	else return self[prop]
	end
end

--- Loads a list of entities from a definition file
-- @param file the file to load from
-- @param no_default if true then no default values will be assigned
-- @param res the table to load into, defaults to a new one
-- @param mod an optional function to which will be passed each entity as they are created. Can be used to adjust some values on the fly
-- @usage MyEntityClass:loadList("/data/my_entities_def.lua")
function _M:loadList(file, no_default, res, mod, loaded)
	if type(file) == "table" then
		res = res or {}
		for i, f in ipairs(file) do
			self:loadList(f, no_default, res, mod)
		end
		return res
	end

	no_default = no_default and true or false
	res = res or {}

	local f, err = nil, nil
	if entities_load_functions[file] and entities_load_functions[file][no_default] then
		print("Loading entities file from memory", file)
		f = entities_load_functions[file][no_default]
	elseif fs.exists(file) then
		f, err = loadfile(file)
		print("Loading entities file from file", file)
		entities_load_functions[file] = entities_load_functions[file] or {}
		entities_load_functions[file][no_default] = f
	else
		-- No data
		f = function() end
	end
	if err then error(err) end

	loaded = loaded or {}
	loaded[file] = true

	local newenv newenv = {
		class = self,
		loaded = loaded,
		resolvers = resolvers,
		DamageType = require "engine.DamageType",
		entity_mod = mod,
		rarity = function(add, mult) add = add or 0; mult = mult or 1; return function(e) if e.rarity then e.rarity = math.ceil(e.rarity * mult + add) end end end,
		newEntity = function(t)
			-- Do we inherit things ?
			if t.base then
				-- Append array part
				for i = 1, #res[t.base] do
					local b = res[t.base][i]
					if type(b) == "table" and not b.__CLASSNAME then b = table.clone(b, true)
					elseif type(b) == "table" and b.__CLASSNAME then b = b:clone()
					end
					table.insert(t, b)
				end

				for k, e in pairs(res[t.base]) do
					if k ~= "define_as" and type(k) ~= "number" then
						if type(t[k]) == "table" and type(e) == "table" then
							copy_recurs(t[k], e)
						elseif not t[k] and type(t[k]) ~= "boolean" then
							t[k] = e
						end
					end
				end
				t.base = nil
			end

			local e = newenv.class.new(t, no_default)

			if mod then mod(e) end

			res[#res+1] = e
			if t.define_as then res[t.define_as] = e end
		end,
		importEntity = function(t)
			local e = t:cloneFull()
			if mod then mod(e) end
			res[#res+1] = e
			if t.define_as then res[t.define_as] = e end
		end,
		load = function(f, new_mod)
			self:loadList(f, no_default, res, new_mod or mod, loaded)
		end,
		loadList = function(f, new_mod)
			return self:loadList(f, no_default, nil, new_mod or mod, nil)
		end,
	}
	setfenv(f, setmetatable(newenv, {__index=_G}))
	f()

	return res
end
