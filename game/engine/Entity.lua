--- A game entity
-- An entity is anything that goes on a map, terrain features, objects, monsters, player, ...
-- Usually there is no need to use it directly, and it is betetr to use specific engine.Grid, engine.Actor or engine.Object
-- classes. Most modules will want to subclass those anyway to add new comportments
module(..., package.seeall, class.make)

local next_uid = 1

-- Setup the uids repository as a weak value table, when the entities are no more used anywhere else they disappear from there too
setmetatable(__uids, {__mode="v"})

local function copy_recurs(dst, src, deep)
	for k, e in pairs(src) do
		if not dst[k] then
			if deep then
				dst[k] = {}
				copy_recurs(dst[k], e, deep)
			else
				dst[k] = e
			end
		elseif type(dst[k]) == "table" and type(e) == "table" then
			copy_recurs(dst[k], e, deep)
		end
	end
end

--- Initialize an entity
-- Any subclass MUST call this constructor
-- @param t a table defining the basic properties of the entity
-- @usage Entity.new{display='#', color_r=255, color_g=255, color_b=255}
function _M:init(t)
	t = t or {}
	self.uid = next_uid
	__uids[self.uid] = self

	for k, e in pairs(t) do
		local ee = e
		if type(e) == "table" then ee = table.clone(e, true) end
		self[k] = ee
	end

	self.image = self.image or nil
	self.display = self.display or '.'
	self.color_r = self.color_r or 0
	self.color_g = self.color_g or 0
	self.color_b = self.color_b or 0
	self.color_br = self.color_br or -1
	self.color_bg = self.color_bg or -1
	self.color_bb = self.color_bb or -1

	next_uid = next_uid + 1

	self.changed = true
end

--- If we are cloned we need a new uid
function _M:cloned()
	self.uid = next_uid
	__uids[self.uid] = self
	next_uid = next_uid + 1

	self.changed = true
end

_M.loadNoDelay = true
--- If we are loaded we need a new uid
function _M:loaded()
	local ouid = self.uid
	self.uid = next_uid
	__uids[self.uid] = self
	next_uid = next_uid + 1

	self.changed = true
end

--- Change the entity's uid
-- <strong>*WARNING*</strong>: ONLY DO THIS IF YOU KNOW WHAT YOU ARE DOING!. YOU DO NOT !
function _M:changeUid(newuid)
	__uids[self.uid] = nil
	self.uid = newuid
	__uids[self.uid] = self
end

--- Resolves an entity
-- This is called when generatingthe final clones of an entity for use in a level.<br/>
-- This can be used to make random enchants on objects, random properties on actors, ...<br/>
-- by default this only looks for properties with a table value containing a __resolver field
function _M:resolve(t)
	t = t or self
	for k, e in pairs(t) do
		if type(e) == "table" and e.__resolver then
			t[k] = resolvers.calc[e.__resolver](e, self)
		elseif type(e) == "table" then
			self:resolve(e)
		end
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
-- @param ... the files to load from
-- @usage MyEntityClass:loadList("/data/my_entities_def.lua")
function _M:loadList(...)
	local res = {}

	for i, file in ipairs{...} do
		local f, err = loadfile(file)
		if err then error(err) end

		setfenv(f, setmetatable({
			resolvers = resolvers,
			DamageType = require "engine.DamageType",
			newEntity = function(t)
				-- Do we inherit things ?
				if t.base then
					for k, e in pairs(res[t.base]) do
						if not t[k] then
							t[k] = e
						elseif type(t[k]) == "table" and type(e) == "table" then
							copy_recurs(t[k], e)
						end
					end
					t.base = nil
				end

				local e = self.new(t)
				res[#res+1] = e
				if t.define_as then res[t.define_as] = e end
--				print("new entity", t.name)
				for k, ee in pairs(e) do
--					print("prop:", k, ee)
				end
			end,
			load = function(f)
				local ret = self:loadList(f)
				for i, e in ipairs(ret) do res[#res+1] = e end
			end,
			loadList = function(f)
				return self:loadList(f)
			end,
		}, {__index=_G}))
		f()
	end
	return res
end
