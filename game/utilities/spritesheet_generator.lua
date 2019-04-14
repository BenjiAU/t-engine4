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

require "engines.default.engine.utils"

local args = {...}
local ok, err = pcall(function()

fs.reset()

local dirs_to_parse = {}
local files_to_parse = {}
local excludes = {}
local write_to = nil
local sheetname = "ts-unnamed-sheet"
local max_w = 4096
local max_h = 4096
local padding_mode = core.binpack.PADDING_NONE
local padding_size = 0

local i = 1
while i <= #args do
	local arg = args[i]
	
	if arg == "--mount" then
		fs.mount(args[i+1], "/")
		i = i + 1
	elseif arg == "--add-dir-recurs" then
		dirs_to_parse[args[i+1]] = true
		i = i + 1
	elseif arg == "--add-dir-norecurs" then
		dirs_to_parse[args[i+1]] = false
		i = i + 1
	elseif arg == "--exclude" then
		excludes[args[i+1]] = true
		i = i + 1
	elseif arg == "--add-file" then
		files_to_parse[args[i+1]] = true
		i = i + 1
	elseif arg == "--write-to" then
		write_to = args[i+1]
		i = i + 1
	elseif arg == "--name" then
		sheetname = args[i+1]
		i = i + 1
	elseif arg == "--max-w" then
		max_w = tonumber(args[i+1])
		i = i + 1
	elseif arg == "--max-h" then
		max_h = tonumber(args[i+1])
		i = i + 1
	elseif arg == "--padding" then
		local pdata = args[i+1]
		if pdata:prefix("NONE") then padding_mode = core.binpack.PADDING_NONE; padding_size = 0
		elseif pdata:prefix("ALPHA0") then padding_mode = core.binpack.PADDING_ALPHA0; padding_size = tonumber(pdata:sub(8)) or 1
		elseif pdata:prefix("IMAGE") then padding_mode = core.binpack.PADDING_IMAGE; padding_size = tonumber(pdata:sub(7)) or 1
		end
		i = i + 1
	end

	i = i + 1
end

if not write_to then
	print("Require a --write-to parameter")
	return
end
fs.setWritePath(write_to)
	
table.print(fs.getSearchPath(true))

local list = {}

local function is_allowed(fpath)
	for echeck, _ in pairs(excludes) do
		if fpath:find(echeck) then return false end
	end
	return true
end

local function findfiles(path, allow_recurs)
	if not path:suffix("/") then path = path.."/" end
	for f in fs.iterate(path) do
		local fpath = path..f
		if fs.isdir(fpath) and allow_recurs then
			findfiles(fpath.."/", true)
		elseif fpath:find("%.png$") then
			if is_allowed(fpath) then list[#list+1] = fpath end
		end
	end
end

for dir, allow_recurs in pairs(dirs_to_parse) do
	findfiles(dir, allow_recurs)
end
for file, _ in pairs(files_to_parse) do
	if fs.exists(file) then list[#list+1] = file end
end

table.sort(list)
table.print(list)

local sheet, images = core.binpack.generateSpritesheet(sheetname, max_w, max_h, list, {padding_mode, padding_size}, true)

-- table.print(sheet)
-- print("---")
-- table.print(images)

for file in fs.iterate("/data/gfx/", function(f) return f:find("%.png") and f:prefix(sheetname) end) do
	fs.delete("/"..file)
end

for filename, image in pairs(images) do
	image:toPNG(filename:gsub("/data/gfx/", "/"))
end

print("TOTAL", table.count(sheet))
local f = fs.open("/"..sheetname..".lua", "w")
f:write(table.serialize(sheet))
f:close()

end)
if not ok then print(err) end
