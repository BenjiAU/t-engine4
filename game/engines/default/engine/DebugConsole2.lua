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
local ig = require "engine.imgui"
local ffi = require "ffi"

--- Debug Console
-- @classmod engine.DebugConsole2
module(..., package.seeall, class.make)

local error_color = ig.ImVec4(1, 0, 0, 1)

_M.history = {
	[[<<<<<------------------------------------------------------------------------------------->>>>>]],
	[[<                          Welcome to the T-Engine Lua Console                                >]],
	[[<--------------------------------------------------------------------------------------------->]],
	[[< You have access to the T-Engine global namespace.                                           >]],
	[[< To execute commands, simply type them and hit Enter.                                        >]],
	[[< To see the return values of a command, start the line off with a "=" character.             >]],
	[[< For a table, this will not show keys inherited from a metatable (usually class functions).  >]],
	[[<--------------------------------------------------------------------------------------------->]],
}
_M.commands = {}
_M.current_command = ""

function _M:init()
	self.input_buffer = ffi.new("char[10000]", _M.current_command)
end

function _M:display()
	----------------------------------------------------------------------------------
	-- Print Log
	----------------------------------------------------------------------------------
	if not ig.Begin("Debug Log") then ig.End()
	else
		ig.BeginChild("Log", nil, nil, ig.lib.ImGuiWindowFlags_HorizontalScrollbar)
		truncate_printlog(2000)
		for _, line in ipairs(get_printlog()) do
			local max = 1
			for k, _ in pairs(line) do max = math.max(max, k) end
			local list = {}
			for i = 1, max do list[i] = tostring(line[i]) end
			local l = table.concat(list, "\t")
			if l:lower():find("error", 1, 1) then
				ig.PushStyleColor(ig.lib.ImGuiCol_Text, error_color)
				ig.TextUnformatted(l)
				ig.PopStyleColor()
			else
				ig.TextUnformatted(l)
			end
		end
		ig.SetScrollHereY(1)
		ig.EndChild()	
		ig.End()
	end

	----------------------------------------------------------------------------------
	-- Lua Console
	----------------------------------------------------------------------------------
	if not ig.Begin("Debug Console", nil, ig.lib.ImGuiWindowFlags_NoNavInputs) then ig.End()
	else
		self.console_hovered = ig.IsWindowHovered()
		ig.BeginChild("ConsoleLog", ig.ImVec2(0, -30), nil, ig.lib.ImGuiWindowFlags_NoNav + ig.lib.ImGuiWindowFlags_HorizontalScrollbar + ig.lib.ImGuiWindowFlags_NoFocusOnAppearing)
		ig.PushTextWrapPos(0)
		for i, line in ipairs(_M.history) do
			ig.TextUnformatted(line)
		end
		ig.PopTextWrapPos()
		if self.force_scroll then
			ig.SetScrollHereY(1)
			self.force_scroll = self.force_scroll - 1
			if self.force_scroll <= 0 then self.force_scroll = nil end
		end
		ig.EndChild()

		-- Command line
		ig.Separator()
		ig.PushItemWidth(ig.GetWindowWidth())
		if ig.InputText("", self.input_buffer, ffi.sizeof(self.input_buffer), ig.lib.ImGuiInputTextFlags_EnterReturnsTrue) then
			_M.current_command = ffi.string(self.input_buffer)
			self:execCommand()
		else
			-- _M.current_command = ffi.string(self.input_buffer)
		end
		ig.SetItemDefaultFocus()
		if self.console_hovered then ig.SetKeyboardFocusHere() end
		ig.PopItemWidth()

		if ig.HotkeyEntered(0, engine.Key._UP) then self:commandHistoryUp() end
		if ig.HotkeyEntered(0, engine.Key._DOWN) then self:commandHistoryDown() end


		if #_M.history ~= self.last_history_size then self.force_scroll = 10 self.last_history_size = #_M.history end
		ig.End()
	end
end

function _M:remakeBuffer()
	for i = 1, #_M.current_command do
		local c = string.byte(_M.current_command:sub(i, i))
		self.input_buffer[i-1] = c 
	end
	self.input_buffer[#_M.current_command] = 0
	print("====>>>", ffi.string(self.input_buffer))
end

function _M:commandHistoryUp()
	_M.com_sel = util.bound(_M.com_sel - 1, 0, #_M.commands)
	if _M.commands[_M.com_sel] then
		_M.current_command = _M.commands[_M.com_sel]
	end
	self:remakeBuffer()
end
function _M:commandHistoryDown()
	_M.com_sel = util.bound(_M.com_sel + 1, 1, #_M.commands)
	if _M.commands[_M.com_sel] then
		_M.current_command = _M.commands[_M.com_sel]
	else
		_M.current_command = ""
	end
	self:remakeBuffer()
end

function _M:execCommand()
	if _M.current_command == "" then return end
	table.insert(_M.commands, _M.current_command)
	_M.com_sel = #_M.commands + 1
	table.insert(_M.history, _M.current_command)
	table.iprint(_M.commands)
	-- Handle assignment and simple printing
	if _M.current_command:match("^=") then _M.current_command = "return ".._M.current_command:sub(2) end
	local f, err = loadstring(_M.current_command)
	if err then
		table.insert(_M.history, err)
	else
		local res = {pcall(f)}
		for i, v in ipairs(res) do
			if i > 1 then
				table.insert(_M.history, "    "..(i-1).." :=: "..tostring(v))
				-- Handle printing a table
				if type(v) == "table" then
					local array = {}
					for k, vv in table.orderedPairs(v) do
						array[#array+1] = tostring(k).." :=: "..tostring(vv)
					end
					self:historyColumns(array, 8)
				end
			end
		end
	end
	self.last_history_size = nil

print("-------- EXECUTED", _M.current_command)
	_M.current_command = ""
	self:remakeBuffer()
end

--- Add a list of strings to the history with multiple columns
-- @param[type=table] strings Array of strings to add to the history
-- @int offset Number of spaces to add on the left-hand side
function _M:historyColumns(strings, offset)
	local offset_str = string.rep(" ", offset and offset or 0)
	local ox = tonumber(ig.CalcTextSize(offset_str).x)
	local longest_key = ""
	local width = 0  --
	local max_width = 80 -- Maximum field width to print
	
	for i, k in ipairs(strings) do
		if #k > width then
			longest_key = k
			width = #k
			if width >= max_width then
				width = max_width
				break
			end
		end
	end
	
	local tx = tonumber(ig.CalcTextSize(string.sub(longest_key,1,width) .. "...  ").x)
	local num_columns = math.floor((ig.GetWindowWidth() - ox) / tx)
	local num_rows = math.ceil(#strings / num_columns)

	local line_format = offset_str..string.rep("%-"..tostring(math.min(max_width+5,width+5)).."s ", num_columns) --
	
	for i=1,num_rows do
		vals = {}
		for j=1,num_columns do
			vals[j] = strings[i + (j - 1) * num_rows] or ""
			--Truncate and annotate if too long
			if #vals[j] > width then
				vals[j] = string.sub(vals[j],1,width) .. "..."
			end
		end
		table.insert(_M.history, line_format:format(unpack(vals)))
	end
end
