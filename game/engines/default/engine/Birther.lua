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
require "engine.Dialog"

module(..., package.seeall, class.inherit(engine.Dialog))

_M.birth_descriptor_def = {}
_M.birth_auto = {}
_M.step_names = {}

--- Defines birth descriptors
-- Static!
function _M:loadDefinition(file)
	local f, err = loadfile(file)
	if not f and err then error(err) os.exit() end
	setfenv(f, setmetatable({
		ActorTalents = require("engine.interface.ActorTalents"),
		newBirthDescriptor = function(t) self:newBirthDescriptor(t) end,
		setAuto = function(type, v) self.birth_auto[type] = v end,
		setStepNames = function(names) self.step_names = names end,
		load = function(f) self:loadDefinition(f) end
	}, {__index=_G}))
	f()
end

--- Defines one birth descriptor
-- Static!
function _M:newBirthDescriptor(t)
	assert(t.name, "no birth name")
	assert(t.type, "no birth type")
	t.short_name = t.short_name or t.name
	t.short_name = t.short_name:upper():gsub("[ ]", "_")
	t.display_name = t.display_name or t.name
	assert(t.desc, "no birth description")
	if type(t.desc) == "table" then t.desc = table.concat(t.desc, "\n") end
	t.desc = t.desc:gsub("\n\t+", "\n")
	t.descriptor_choices = t.descriptor_choices or {}

	table.insert(self.birth_descriptor_def, t)
	t.id = #self.birth_descriptor_def
	self.birth_descriptor_def[t.type] = self.birth_descriptor_def[t.type] or {}
	self.birth_descriptor_def[t.type][t.name] = t
	table.insert(self.birth_descriptor_def[t.type], t)
end


--- Instanciates a birther for the given actor
function _M:init(actor, order, at_end, quickbirth, w, h)
	self.quickbirth = quickbirth
	self.actor = actor
	self.order = order
	self.at_end = at_end

	engine.Dialog.init(self, "Character Creation: "..actor.name, w or 600, h or 400)

	self.descriptors = {}

	self.cur_order = 1
	self:next()

	self:keyCommands({
		_BACKSPACE = function() self:prev() end,
	},{
		MOVE_UP = function() self.sel = util.boundWrap(self.sel - 1, 1, #self.list); self.changed = true end,
		MOVE_DOWN = function() self.sel = util.boundWrap(self.sel + 1, 1, #self.list); self.changed = true end,
		ACCEPT = function() self:next() end,
	})
	self:mouseZones{
		{ x=2, y=25, w=350, h=self.h, fct=function(button, x, y, xrel, yrel, tx, ty)
			self.changed = true
			if ty < self.font_h*#self.list then
				self.sel = 1 + math.floor(ty / self.font_h)
				if button == "left" then self:next()
				elseif button == "right" then self:prev()
				end
			end
		end },
	}
end

function _M:on_register()
	if self.quickbirth then
		self:yesnoPopup("Quick Birth", "Do you want to recreate the same character?", function(ret)
			if ret then
				self.do_quickbirth = true
				self:quickBirth()
			end
		end)
	end
end

function _M:quickBirth()
	if not self.do_quickbirth then return end
	-- Aborth quickbirth if stage not found
	if not self.quickbirth[self.current_type] then self.do_quickbirth = false end

	-- Find the corect descriptor
	for i, d in ipairs(self.list) do
		if self.quickbirth[self.current_type] == d.name then
			print("[QUICK BIRTH] using", d.name, "for", self.current_type)
			self.sel = i
			self:next()
			return true
		end
	end

	-- Abord if not found
	self.do_quickbirth = false
end

function _M:selectType(type)
	local default = 1
	self.list = {}
	-- Make up the list
	print("[BIRTHER] selecting type", type)
	for i, d in ipairs(self.birth_descriptor_def[type]) do
		local allowed = true
		print("[BIRTHER] checking allowance for ", d.name)
		for j, od in ipairs(self.descriptors) do
			if od.descriptor_choices[type] then
				local what = util.getval(od.descriptor_choices[type][d.name]) or util.getval(od.descriptor_choices[type].__ALL__)
				if what and what == "allow" then
					allowed = true
				elseif what and (what == "never" or what == "disallow") then
					allowed = false
				elseif what and what == "forbid" then
					allowed = nil
				end
				print("[BIRTHER] test against ", od.name, "=>", what, allowed)
				if allowed == nil then break end
			end
		end

		-- Check it is allowed
		if allowed then
			table.insert(self.list, d)
			if d.selection_default then default = #self.list end
		end
	end
	self.sel = default
	self.current_type = type
end

function _M:prev()
	if self.cur_order == 1 then
		if #self.list == 1 and self.birth_auto[self.current_type] ~= false  then self:next() end
		return
	end
	if not self.list then return end
	self.changed = true
	table.remove(self.descriptors)
	self.cur_order = self.cur_order - 1
	self:selectType(self.order[self.cur_order])
	if #self.list == 1 then
		self:prev()
	end
end

function _M:next()
	self.changed = true
	if self.list then
		table.insert(self.descriptors, self.list[self.sel])
		if self.list[self.sel].on_select then self.list[self.sel]:on_select() end

		self.cur_order = self.cur_order + 1
		if not self.order[self.cur_order] then
			game:unregisterDialog(self)
			self:apply()
			self.at_end()
			return
		end
	end
	self:selectType(self.order[self.cur_order])

	if self:quickBirth() then return end

	if #self.list == 1 and self.birth_auto[self.current_type] ~= false then
		self:next()
	end
end

--- Apply all birth options to the actor
function _M:apply()
	self.actor.descriptor = {}
	for i, d in ipairs(self.descriptors) do
		print("[BIRTH] Applying descriptor "..d.name)
		self.actor.descriptor[d.type] = d.name

		if d.copy then
			local copy = table.clone(d.copy, true)
			-- Append array part
			while #copy > 0 do
				local f = table.remove(copy)
				table.insert(self.actor, f)
			end
			-- Copy normal data
			table.merge(self.actor, copy, true)
		end
		-- Change stats
		if d.stats then
			for stat, inc in pairs(d.stats) do
				self.actor:incStat(stat, inc)
			end
		end
		if d.talents_types then
			for t, v in pairs(d.talents_types) do
				local mastery
				if type(v) == "table" then
					v, mastery = v[1], v[2]
				else
					v, mastery = v, 0
				end
				self.actor:learnTalentType(t, v)
				self.actor.talents_types_mastery[t] = (self.actor.talents_types_mastery[t] or 1) + mastery
				print(t)
			end
		end
		if d.talents then
			for tid, lev in pairs(d.talents) do
				for i = 1, lev do
					self.actor:learnTalent(tid, true)
				end
			end
		end
		if d.experience then self.actor.exp_mod = self.actor.exp_mod * d.experience end
		if d.body then
			self.actor.body = d.body
			self.actor:initBody()
		end
	end
end

function _M:drawDialog(s)
	if not self.list or not self.list[self.sel] then return end

	-- Description part
	self:drawHBorder(s, self.iw / 2, 2, self.ih - 4)
	local birthhelp = ([[Keyboard: #00FF00#up key/down key#FFFFFF# to select an option; #00FF00#Enter#FFFFFF# to accept; #00FF00#Backspace#FFFFFF# to go back.
Mouse: #00FF00#Left click#FFFFFF# to accept; #00FF00#right click#FFFFFF# to go back.
]]):splitLines(self.iw / 2 - 10, self.font)
	for i = 1, #birthhelp do
		s:drawColorStringBlended(self.font, birthhelp[i], self.iw / 2 + 5, 2 + (i-1) * self.font:lineSkip())
	end

	local lines = self.list[self.sel].desc:splitLines(self.iw / 2 - 10, self.font)
	local r, g, b
	for i = 1, #lines do
		r, g, b = s:drawColorStringBlended(self.font, lines[i], self.iw / 2 + 5, 2 + (i + #birthhelp + 1) * self.font:lineSkip(), r, g, b)
	end

	-- Stats
	s:drawColorStringBlended(self.font, "Selecting: "..(self.step_names[self.current_type] or self.current_type:capitalize()), 2, 2)
	self:drawWBorder(s, 2, 20, 200)

	self:drawSelectionList(s, 2, 25, self.font_h, self.list, self.sel, "display_name")
	self.changed = false
end
