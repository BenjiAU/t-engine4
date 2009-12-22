require "engine.class"
local Map = require "engine.Map"
require "engine.Generator"
module(..., package.seeall, class.inherit(engine.Generator))

function _M:init(zone, map, level)
	engine.Generator.init(self, zone, map)
	self.level = level
	local data = level.data.generator.object

	-- Setup the entities list
	level:setEntitiesList("object", zone:computeRarities(zone.object_list, level.level, data.ood, nil))

	if data.adjust_level_to_player and game:getPlayer() then
		self.adjust_level_to_player = {base=game:getPlayer().level, min=data.adjust_level_to_player[1], max=data.adjust_level_to_player[2]}
	end
	self.nb_object = data.nb_object or {10, 20}
	self.level_range = data.level_range or {level, level}
end

function _M:generate()
	for i = 1, rng.range(self.nb_object[1], self.nb_object[2]) do
		local o = self.zone:makeEntity(self.level, "object")
		if o then
			local x, y = rng.range(0, self.map.w), rng.range(0, self.map.h)
			local tries = 0
			while (self.map:checkEntity(x, y, Map.TERRAIN, "block_move") or self.map(x, y, Map.OBJECT)) and tries < 100 do
				x, y = rng.range(0, self.map.w-1), rng.range(0, self.map.h-1)
				tries = tries + 1
			end
			if tries < 100 then
				self.map(x, y, Map.OBJECT, o)
			end
		end
	end
end
