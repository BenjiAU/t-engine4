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
local path_sel_color = ig.ImVec4(0x55/255, 0xa3/255, 0x47/255, 1)
local string_color = ig.ImVec4(colors.hex1alphaunpack("e7d559"))
local number_color = ig.ImVec4(colors.hex1alphaunpack("a37ffe"))
local tbool_color = ig.ImVec4(colors.hex1alphaunpack("3dad7d"))
local fbool_color = ig.ImVec4(colors.hex1alphaunpack("ad663d"))
local table_color = ig.ImVec4(colors.hex1alphaunpack("c791d0"))
local comment_color = ig.ImVec4(colors.hex1alphaunpack("706c4d"))
local default_val_color = ig.ImVec4(colors.hex1alphaunpack("ffffff"))

_M.history = ([[
<<<<<------------------------------------------------------------------------------------->>>>>
<                          Welcome to the T-Engine Lua Console                                >
<--------------------------------------------------------------------------------------------->
< You have access to the T-Engine global namespace.                                           >
< To execute commands, simply type them and hit Enter.                                        >
< To see the return values of a command, start the line off with a "=" character.             >
< For a table, this will not show keys inherited from a metatable (usually class functions).  >
<--------------------------------------------------------------------------------------------->
< Here are some useful keyboard shortcuts:                                                    >
<     Up/down arrows     :=: Move between previous/later executed lines                       >
<     Ctrl+Space         :=: Print help for the function to the left of the cursor            >
<     Ctrl+Shift+Space   :=: Print the entire definition for the function                     >
<     Ctrl+I             :=: Lock the inspector window to the currently displayed table       >
<     Tab                :=: Auto-complete path strings or tables at the cursor               >
<<<<<------------------------------------------------------------------------------------->>>>>
]]):split("\n")

_M.commands = {}
_M.current_command = ""

function _M:init()
	self.first_draw = true
	self.input_buffer = ffi.new("char[100000]", _M.current_command)


	self.inspector_locked = ffi.new("bool[1]", false)
	self.inspector_cur_k = setmetatable({__mode="v"}, {})
	-- self.inspector_list = { {name="<Game>", val=game} }
	-- self.inspector_pos = 1
end

local function set_val_color(v)
	local t = type(v)
	if t == "string" then ig.PushStyleColor(ig.lib.ImGuiCol_Text, string_color)
	elseif t == "number" then ig.PushStyleColor(ig.lib.ImGuiCol_Text, number_color)
	elseif t == "boolean" and v == true then ig.PushStyleColor(ig.lib.ImGuiCol_Text, tbool_color)
	elseif t == "boolean" and v == false then ig.PushStyleColor(ig.lib.ImGuiCol_Text, fbool_color)
	elseif t == "table" then ig.PushStyleColor(ig.lib.ImGuiCol_Text, table_color)
	else ig.PushStyleColor(ig.lib.ImGuiCol_Text, default_val_color)
	end
end

local function updateBuffer(buf, src)
	for i = 1, #src do
		local c = string.byte(src:sub(i, i))
		buf[i-1] = c 
	end
	buf[#src] = 0
end

function _M:setInspector(name, val)
	if self.inspector_locked[0] then return end

	self.inspector_list = { {name=name, val=val} }
	self.inspector_pos = 1
end

function _M:setCommand(line)
	_M.next_command = line
end

local console_text_cb = ffi.cast("ImGuiInputTextCallback", function(data, self)
	if data.EventFlag == ig.lib.ImGuiInputTextFlags_CallbackHistory then
		if data.EventKey == ig.lib.ImGuiKey_UpArrow then data.BufTextLen = _M:commandHistoryUp(data.Buf) data.CursorPos = data.BufTextLen data.BufDirty = true end
		if data.EventKey == ig.lib.ImGuiKey_DownArrow then data.BufTextLen = _M:commandHistoryDown(data.Buf) data.CursorPos = data.BufTextLen data.BufDirty = true end
	elseif data.EventFlag == ig.lib.ImGuiInputTextFlags_CallbackCompletion then
		local res, pos = _M:autoComplete(ffi.string(data.Buf), data.CursorPos)
		if res then
			updateBuffer(data.Buf, res)
			data.BufTextLen = #res
			data.CursorPos = #res
			data.BufDirty = true
		end
	elseif data.EventFlag == ig.lib.ImGuiInputTextFlags_CallbackAlways then
		if _M.next_command then
			updateBuffer(data.Buf, _M.next_command)
			data.BufTextLen = #_M.next_command
			data.CursorPos = #_M.next_command
			data.BufDirty = true
		end

		_M.current_command_typed = ffi.string(data.Buf)
		_M.current_command_typed_pos = data.CursorPos

		if _M.next_command then _M:showHelpTooltip() end
		_M.next_command = nil
	end
	return 0
end)

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
	-- Inspector
	----------------------------------------------------------------------------------
	if not ig.Begin("Inspector") then ig.End()
	else
		local cur_pos = self.inspector_pos
		for i, d in ipairs(self.inspector_list or {}) do
			if i > 1 then ig.SameLine() end
			if i == cur_pos then ig.PushStyleColor(ig.lib.ImGuiCol_Button, path_sel_color) end
			if ig.Button(d.name.."##ipa"..i) then self.inspector_pos = i end
			if i == cur_pos then ig.PopStyleColor() end
			ig.SameLine()
			ig.TextUnformatted("/")
		end
		ig.SameLine(ig.GetWindowWidth() - 65)
		ig.Checkbox("Lock", self.inspector_locked)
		ig.Separator()

		local id = 1
		ig.BeginChild("Log", nil, nil, ig.lib.ImGuiWindowFlags_HorizontalScrollbar)
		ig.Columns(2, "data")
		if self.inspector_list and self.inspector_list[self.inspector_pos] then
			local d = self.inspector_list[self.inspector_pos]
			if type(d.val) == "table" then for k, v in table.orderedPairs(d.val) do
				id = id + 1

				set_val_color(k)
				if ig.Selectable(tostring(k).."##insp"..id, self.inspector_cur_k.cur == k) and type(k) == "table" then
					while #self.inspector_list > self.inspector_pos do table.remove(self.inspector_list) end
					self.inspector_list[#self.inspector_list+1] = { name="K<"..tostring(k)..">", val=k }
					self.inspector_pos = #self.inspector_list
				end
				if ig.IsItemHovered() then self.inspector_cur_k.cur = k end
				ig.PopStyleColor()
				ig.NextColumn()
				id = id + 1
				set_val_color(v)
				if ig.Selectable(tostring(v).."##insp"..id, self.inspector_cur_k.cur == k) and type(v) == "table" then
					while #self.inspector_list > self.inspector_pos do table.remove(self.inspector_list) end
					self.inspector_list[#self.inspector_list+1] = { name="V<"..tostring(k)..">", val=v }
					self.inspector_pos = #self.inspector_list
				end
				if ig.IsItemHovered() then self.inspector_cur_k.cur = k end
				ig.PopStyleColor()

				ig.NextColumn()
				ig.Separator()
			end end
		end
		ig.Columns(1)
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
			if type(line) == "table" then
				ig.PushStyleColor(ig.lib.ImGuiCol_Text, line[1])
				ig.TextUnformatted(line[2])
				ig.PopStyleColor()
			else
				ig.TextUnformatted(line)
			end
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
		if ig.InputText("", self.input_buffer, ffi.sizeof(self.input_buffer), ig.lib.ImGuiInputTextFlags_EnterReturnsTrue + ig.lib.ImGuiInputTextFlags_CallbackHistory + ig.lib.ImGuiInputTextFlags_CallbackCompletion + ig.lib.ImGuiInputTextFlags_CallbackAlways, console_text_cb) then
			ig.SetKeyboardFocusHere()
			_M.current_command = ffi.string(self.input_buffer)
			self:execCommand()
		end
		if self.first_draw then
			ig.SetItemDefaultFocus()
			ig.SetKeyboardFocusHere()
			self.first_draw = false
		end
		ig.PopItemWidth()

		self:showHelpTooltip()

		if #_M.history ~= self.last_history_size then self.force_scroll = 10 self.last_history_size = #_M.history end
		ig.End()

		if ig.HotkeyEntered(2, engine.Key._SPACE) then self:showFunctionHelp(_M.current_command_typed, _M.current_command_typed_pos) end
		if ig.HotkeyEntered(2, engine.Key._i) then self.inspector_locked[0] = not self.inspector_locked[0] end
	end

	if ig.HotkeyEntered(0, engine.Key._ESCAPE) then game:showDebugConsole(false) end

	-- local b = ffi.new("bool[1]", 1)
	-- ig.ShowDemoWindow(b)
end

function _M:showHelpTooltip()
	if not _M.current_command_typed then return end
	local ok, help = pcall(self.getFunctionHelp, self, _M.current_command_typed, _M.current_command_typed_pos + 1)
	if not ok or not help then return end

	local pos = ig.GetCursorScreenPos()
	local input_size = ig.GetItemRectSize()
	ig.Begin("##input_help", nil, ig.lib.ImGuiWindowFlags_NoInputs + ig.lib.ImGuiWindowFlags_NoTitleBar + ig.lib.ImGuiWindowFlags_NoMove + ig.lib.ImGuiWindowFlags_NoResize + ig.lib.ImGuiWindowFlags_NoFocusOnAppearing + ig.lib.ImGuiWindowFlags_NoSavedSettings + ig.lib.ImGuiWindowFlags_AlwaysAutoResize)
	local tooltip = ig.GetCurrentWindowRead()
	ig.TextUnformatted(help)
	ig.SetWindowPos(pos - ig.ImVec2(0, ig.GetWindowHeight() + input_size.y + 9), ig.lib.ImGuiCond_Always)
	ig.End()
	ig.BringWindowToDisplayFront(tooltip)
end

function _M:remakeBuffer(buf)
	buf = buf or self.input_buffer
	updateBuffer(buf, _M.current_command)
end

function _M:commandHistoryUp(buf)
	if not _M.com_sel then return end
	_M.com_sel = util.bound(_M.com_sel - 1, 0, #_M.commands)
	if _M.commands[_M.com_sel] then
		_M.current_command = _M.commands[_M.com_sel]
	end
	self:remakeBuffer(buf)
	return #_M.current_command
end
function _M:commandHistoryDown(buf)
	if not _M.com_sel then return end
	_M.com_sel = util.bound(_M.com_sel + 1, 1, #_M.commands)
	if _M.commands[_M.com_sel] then
		_M.current_command = _M.commands[_M.com_sel]
	else
		_M.current_command = ""
	end
	self:remakeBuffer(buf)
	return #_M.current_command
end

function _M:execCommand()
	if _M.current_command == "" then return end
	table.insert(_M.commands, _M.current_command)
	_M.com_sel = #_M.commands + 1
	table.insert(_M.history, {string_color, _M.current_command})
	table.iprint(_M.commands)
	-- Handle assignment and simple printing
	local do_inspect = false
	if _M.current_command:match("^=") then _M.current_command = "return ".._M.current_command:sub(2) do_inspect = true end
	local f, err = loadstring(_M.current_command)
	if err then
		table.insert(_M.history, {error_color, err})
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
		if do_inspect then
			table.remove(res, 1) -- Remove the pcall result flag
			self:setInspector("<Results>", (#res == 1 and type(res[1] == "table")) and res[1] or res)
		end
	end
	self.last_history_size = nil

	_M.current_command = ""
	self.inspector_autohelp_last_found_table = nil
	self:remakeBuffer()
end

--- Parses a string for autocompletion
-- @local
-- @string remaining the string to parse, also used for recursion
-- @return[1] nil
-- @return[1] error object
-- @return[2] nil
-- @return[2] "%s does not exist."
-- @return[3] nil
-- @return[3] "%s is not a valid path"
-- @return[4] head
-- @return[4] tail
local function find_base(remaining)
	-- Check if we are in a string by counting quotation marks
	local _, nsinglequote = remaining:gsub("\'", "")
	local _, ndoublequote = remaining:gsub("\"", "")
	if (nsinglequote % 2 ~= 0) or (ndoublequote % 2 ~= 0) then
		-- Only auto-complete paths
		local path_to_complete
		if (nsinglequote % 2 ~= 0) and not (ndoublequote % 2 ~= 0) then
			path_to_complete = remaining:match("[^\']+$")
		elseif (ndoublequote % 2 ~= 0) and not (nsinglequote % 2 ~= 0) then
			path_to_complete = remaining:match("[^\"]+$")
		end
		if path_to_complete and path_to_complete:sub(1, 1) == "/" then
			local tail = path_to_complete:match("[^/]+$") or ""
			local head = path_to_complete:sub(1, #path_to_complete - #tail)
			if fs.exists(head) then
				return head, tail
			else
				return nil, ([[%s is not a valid path]]):format(head)
			end
		else
			return nil, "Cannot auto-complete strings."
		end
	end
	-- Work from the back of the line to the front
	local string_to_complete = remaining:match("[%d%w_%[%]%.:\'\"]+$") or ""
	-- Find the trailing tail
	local tail = string_to_complete:match("[%d%w_]+$") or ""
	local linking_char = string_to_complete:sub(#string_to_complete - #tail, #string_to_complete - #tail)
	-- Only handle numerical keys to auto-complete
	if linking_char == "[" and not tonumber(tail) then
		return find_base(tail)
	end
	-- Drop the linking character
	local head = string_to_complete:sub(1, util.bound(#string_to_complete - #tail - 1, 0))
	if #head > 0 then
		local f, err = loadstring("return " .. head)
		if err then
			return nil, err
		else
			local res = {pcall(f)}
			if res[1] and res[2] then
				return res[2], tail
			else
				return nil, ([[%s does not exist.]]):format(head)
			end
		end
	-- Global namespace if there is no head
	else
		return _G, tail
	end
end

--- Autocomplete the current line  
-- Will handle either tables (eg. mod.cla -> mod.class) or paths (eg. "/mod/cla" -> "/mod/class/")
function _M:autoComplete(line, line_pos)
	local base, to_complete = find_base(line:sub(1, line_pos))
	if not base then
		if to_complete then
			table.insert(_M.history, ([[<<<<< %s >>>>>]]):format(to_complete))
			self.changed = true
		end
		return
	end
	-- Autocomplete a table
	local set = {}
	if type(base) == "table" then
		local recurs_bases
		recurs_bases = function(base)
			if type(base) ~= "table" then return end
			for k, v in pairs(base) do
				-- Need to handle numbers, too
				if type(k) == "number" and tonumber(to_complete) then
					if tostring(k):match("^" .. to_complete) then
						set[tostring(k)] = true
					end
				elseif type(k) == "string" then
					if k:match("^" .. to_complete) then
						set[k] = true
					end
				end
			end
			-- Check the metatable __index
			local mt = getmetatable(base)
			if mt and mt.__index and type(mt.__index) == "table" then
				recurs_bases(mt.__index)
			end
		end
		recurs_bases(base)
	-- Autocomplete a path
	elseif type(base) == "string" then
		-- Make sure the directory exists
		if fs.exists(base) then
			for i, fname in ipairs(fs.list(base)) do
				if fname:sub(1, #to_complete) == to_complete then
					-- Add a "/" to directories
					if fs.isdir(base.."/"..fname) then
						set[fname.."/"] = true
					else
						set[fname] = true
					end
				end
			end
		end
	else
		return
	end
	-- Convert to a sorted array
	local array = {}
	for k, _ in pairs(set) do
		array[#array+1] = k
	end
	table.sort(array, function(a, b) return a < b end)
	-- If there is one possibility, complete it
	if #array == 1 then
		-- Special case for a table...
		if array[1] == to_complete and type(base[to_complete]) == "table" then
			line = line:sub(1, line_pos) .. "." .. line:sub(line_pos + 1)
			line_pos = line_pos + 1
		elseif array[1] == to_complete and type(base[to_complete]) == "function" then
			line = line:sub(1, line_pos) .. "(" .. line:sub(line_pos + 1)
			line_pos = line_pos + 1
		else
			line = line:sub(1, line_pos - #to_complete) .. array[1] .. line:sub(line_pos + 1)
			line_pos = line_pos - #to_complete + #array[1]
		end
	elseif #array > 1 then
		table.insert(_M.history, "<<<<< Auto-complete possibilities: >>>>>")
		self:historyColumns(array)
		-- Find the longest common substring and complete it
		local substring = array[1]:sub(#to_complete+1)
		for i=2,#array do
			local min_len = math.min(#array[i]-#to_complete, #substring)
			for j=1,min_len do
				if substring:sub(j, j) ~= array[i]:sub(#to_complete+j, #to_complete+j) then
					substring = substring:sub(1, util.bound(j-1, 0))
					break
				end
			end
			if #substring == 0 then break end
		end
		-- Complete to the longest common substring
		if #substring > 0 then
			line = line:sub(1, line_pos) .. substring .. line:sub(line_pos + 1)
			line_pos = line_pos + #substring
		end
	else
		table.insert(_M.history, "<<<<< No auto-complete possibilities. >>>>>") 
	end
	return line, line_pos
end


--- Prints comments for a function
-- @func func only works on a function obviously
-- @param[type=boolean] verbose give extra junk
function _M:functionHelp(func, verbose)
	if type(func) ~= "function" then return nil, "Can only give help on functions." end
	local info = debug.getinfo(func, "S")
	-- Check the path exists
	local fpath = string.gsub(info.source,"@","")
	if not fs.exists(fpath) then return nil, ([[%s does not exist.]]):format(fpath) end
	local f = fs.open(fpath, "r")
	local lines = {}
	local line_num = 0
	local line
	while true do
		line = f:readLine()
		if line then
			line_num = line_num + 1
			if line_num == info.linedefined then
				lines[#lines+1] = line
				break
			elseif line:sub(1,2) == "--" then
				lines[#lines+1] = line
			else
				lines = {}
			end
		else
			break
		end
	end
	if verbose then
		for i=info.linedefined+1,info.lastlinedefined do
			line = f:readLine()
			lines[#lines+1] = line
		end
	end
	f:close()
	return lines, info.short_src, info.linedefined
end

function _M:showFunctionHelp(line, line_pos)
	local base, remaining = find_base(line:sub(1, line_pos))
	local func = type(base) == "table" and base[remaining]
	if not func or type(func) ~= "function" then
		table.insert(_M.history, {comment_color, "<<<<< No function found >>>>>"})
		return
	end
	local lines, fname, lnum = self:functionHelp(func)
	if not lines then
		table.insert(_M.history, {comment_color, ([[<<<<< %s >>>>>]]):format(fname)})
		return
	end
	table.insert(_M.history, {comment_color, ([[<<<<< Help found in %s at line %d. >>>>>]]):format(fname, lnum)})
	for _, line in ipairs(lines) do
		table.insert(_M.history, {comment_color, "    " .. line:gsub("\t", "    ")})
	end
end

function _M:getFunctionHelp(line, line_pos)
	if not line then return false end

	-- Find the whole word if we are in the middle of one
	local i, j, what = line:find("[a-zA-Z0-9_]*", line_pos)
	if i == line_pos then line_pos = j end

	line = line:sub(1, line_pos)
	local base, remaining = find_base(line)
	local func = type(base) == "table" and base[remaining]
	local res = {}
	if not func then return false end
	if type(func) == "function" then
		local lines, fname, lnum = self:functionHelp(func)
		if not lines then
			if fname and fname:find("=[C]", 1, 1) then return false end
			table.insert(res, ([[<<<<< %s >>>>>]]):format(fname))
			return table.concat(res, "\n")
		end
		table.insert(res, ([[<<<<< Help found in %s at line %d. >>>>>]]):format(fname, lnum))
		for _, line in ipairs(lines) do
			table.insert(res, line:gsub("\t", "   "))
		end
		return table.concat(res, "\n")
	elseif type(func) == "table" and self.inspector_autohelp_last_found_table ~= func then
		self.inspector_autohelp_last_found_table = func
		self:setInspector(select(3, line:find("([a-zA-Z0-9_]+)$")) or "???", func)

		return false
	end
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
