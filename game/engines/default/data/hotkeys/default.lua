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

newKind{
	kind = "talent",
	setup = function(self, actor, page, bi, i, x, y)
		self.last_pre_use_check = 10000
		self.checkPreUseTalent = function(self, actor, t, nb_keyframes)
			self.last_pre_use_check = self.last_pre_use_check + nb_keyframes
			if self.last_pre_use_check >= 10 then
				self.last_pre_use_check = 0
				local ret = actor:preUseTalent(t, true, true)
				self.last_pre_use_ret = ret
				return ret
			else
				return self.last_pre_use_ret
			end
		end
	end,
	display_data = function(self, actor, nb_keyframes) local t = actor:getTalentFromId(self.data) if t then
		local display_entity = t.display_entity
		local pie_color, pie_angle = {1, 1, 1, 0}, 360
		local frame = "ok"
		local txt = nil
		if actor:isTalentCoolingDown(t) then
			if not self:checkPreUseTalent(actor, t, nb_keyframes) then
				pie_color = {0.745,0.745,0.745,0.4}
				frame = "disabled"
			else
				frame = "cooldown"
				pie_color = {1,0,0,0.4}
			end
			pie_angle = 360 * (1 - (actor.talents_cd[t.id] / actor:getTalentCooldown(t)))
			txt = tostring(math.ceil(actor:isTalentCoolingDown(t)))
		elseif actor:isTalentActive(t.id) then
			pie_color = {1,1,0,0.4}
			pie_angle = 0
			frame = "sustain"
		elseif not self:checkPreUseTalent(actor, t, nb_keyframes) then
			pie_color = {0.745,0.745,0.745,0.4}
			pie_angle = 0
			frame = "disabled"
		end
		return display_entity, pie_color, pie_angle, frame, txt
	end end,
	drag_display_object = function(self, actor)
		local t = actor:getTalentFromId(self.data)
		return t.display_entity:getDO(64, 64)
	end,
	use = function(self, actor)
		actor:useTalent(self.data)
	end,
}

newKind{
	kind = "inventory",
	setup = function(self, actor, page, bi, i, x, y)
		self.last_pre_use_check = 10
		self.getMyObject = function(self, actor, nb_keyframes)
			self.last_pre_use_check = self.last_pre_use_check + nb_keyframes
			if self.last_pre_use_check >= 10 then
				self.last_pre_use_check = 0
				local o = actor:findInAllInventories(self.data, {no_add_name=true, force_id=true, no_count=true})
				self.last_pre_use_ret = o
				return o
			else
				return self.last_pre_use_ret
			end
		end
	end,
	display_data = function(self, actor, nb_keyframes)
		local display_entity
		local pie_color, pie_angle = {1, 1, 1, 0}, 360
		local frame = "ok"
		local txt = nil

		local o = self:getMyObject(actor, nb_keyframes)
		local cnt = 0
		if o then cnt = o:getNumber() end
		if cnt == 0 then
			pie_color = {0.745,0.745,0.745,0.4}
			frame = "disabled"
		end
		display_entity = o
		if o and o.use_talent and o.use_talent.id then
			local t = actor:getTalentFromId(o.use_talent.id)
			display_entity = t.display_entity
		end
		if o and o.talent_cooldown then
			local t = actor:getTalentFromId(o.talent_cooldown)
			pie_angle = 360
			if actor:isTalentCoolingDown(t) then
				pie_color = {1,0,0,0.4}
				pie_angle = 360 * (1 - (actor.talents_cd[t.id] / actor:getTalentCooldown(t)))
				frame = "cooldown"
				txt = tostring(math.ceil(actor:isTalentCoolingDown(t)))
			end
		elseif o and (o.use_talent or o.use_power) then
			pie_angle = 360 * ((o.power / o.max_power))
			pie_color = {1,0,0,0.4}
			local cd = o:getObjectCooldown(actor)
			if cd and cd > 0 then
				frame = "cooldown"
				txt = tostring(math.ceil(cd))
			elseif not cd then
				frame = "disabled"
			end
		end
		if o and o.wielded then
			frame = "sustain"
		end
		if o and o.wielded and o.use_talent and o.use_talent.id then
			local t = actor:getTalentFromId(o.use_talent.id)
			if not actor:preUseTalent(t, true, true, true) then
				pie_angle = 0
				pie_color = {0.74,0.74,0.74,0.4}
				frame = "disabled"
			end
		end
		return display_entity, pie_color, pie_angle, frame, txt
	end,
	drag_display_object = function(self, actor)
		local o = actor:findInAllInventories(self.data, {no_add_name=true, force_id=true, no_count=true})
		if o then return o:getDO(64, 64) end
	end,
	use = function(self, actor)
		-- local o, item, inven = actor:findInAllInventories(self.data)
		local o, item, inven = actor:findInAllInventories(self.data, {no_add_name=true, force_id=true, no_count=true})
		if not o then require("engine.ui.Dialog"):simplePopup("Item not found", "You do not have any "..self.data..".")
		else actor:playerUseItem(o, item, inven)
		end
	end,
}
