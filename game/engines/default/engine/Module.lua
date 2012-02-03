
-- TE4 - T-Engine 4
-- Copyright (C) 2009, 2010, 2011 Nicolas Casalini
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
local lanes = require "lanes"
local Dialog = require "engine.ui.Dialog"
local Savefile = require "engine.Savefile"
require "engine.PlayerProfile"

--- Handles dialog windows
module(..., package.seeall, class.make)

--- Create a version string for the module version
-- Static
function _M:versionString(mod)
	return ("%s-%d.%d.%d"):format(mod.short_name, mod.version[1], mod.version[2], mod.version[3])
end

--- List all available modules
-- Static
function _M:listModules(incompatible, moddir_filter)
	local ms = {}
	local allmounts = fs.getSearchPath(true)
	fs.mount(engine.homepath, "/")

	local knowns = {}
	for i, short_name in ipairs(fs.list("/modules/")) do
		if not moddir_filter or moddir_filter(short_name) then
			local mod = self:createModule(short_name, incompatible)
			if mod then
				if not knowns[mod.short_name] then
					table.insert(ms, {short_name=mod.short_name, name=mod.name, versions={}})
					knowns[mod.short_name] = ms[#ms]
				end
				local v = knowns[mod.short_name].versions
				v[#v+1] = mod
			end
		end
	end

	table.sort(ms, function(a, b)
	print(a.short_name,b.short_name)
		if a.short_name == "tome" then return 1
		elseif b.short_name == "tome" then return nil
		else return a.name < b.name
		end
	end)

	for i, m in ipairs(ms) do
		table.sort(m.versions, function(b, a)
			return a.version[1] * 1000000 + a.version[2] * 1000 + a.version[3] * 1 < b.version[1] * 1000000 + b.version[2] * 1000 + b.version[3] * 1
		end)
		print("* Module: "..m.short_name)
		for i, mod in ipairs(m.versions) do
			print(" ** "..mod.version[1].."."..mod.version[2].."."..mod.version[3])
			ms[mod.version_string] = mod
		end
		ms[m.short_name] = m.versions[1]
	end

	fs.reset()
	fs.mountAll(allmounts)

	return ms
end

function _M:createModule(short_name, incompatible)
	local dir = "/modules/"..short_name
	print("Creating module", short_name, ":: (as dir)", fs.exists(dir.."/init.lua"), ":: (as team)", short_name:find(".team$"), "")
	if fs.exists(dir.."/init.lua") then
		local mod = self:loadDefinition(dir, nil, incompatible)
		if mod and mod.short_name then
			return mod
		end
	elseif short_name:find(".team$") then
		fs.mount(fs.getRealPath(dir), "/testload", false)
		local mod
		if fs.exists("/testload/mod/init.lua") then
			mod = self:loadDefinition("/testload", dir, incompatible)
		end
		fs.umount(fs.getRealPath(dir))
		if mod and mod.short_name then return mod end
	end
end

--- Get a module definition from the module init.lua file
function _M:loadDefinition(dir, team, incompatible)
	local mod_def = loadfile(team and (dir.."/mod/init.lua") or (dir.."/init.lua"))
--	print("Loading module definition from", team and (dir.."/mod/init.lua") or (dir.."/init.lua"))
	if mod_def then
		-- Call the file body inside its own private environment
		local mod = {rng=rng}
		setfenv(mod_def, mod)
		mod_def()
		mod.rng = nil

		if not mod.long_name or not mod.name or not mod.short_name or not mod.version or not mod.starter then
			print("Bad module definition", mod.long_name, mod.name, mod.short_name, mod.version, mod.starter)
			return
		end

		-- Test engine version
		local eng_req = engine.version_string(mod.engine)
		mod.version_string = self:versionString(mod)
		if not __available_engines.__byname[eng_req] then
			print("Module mismatch engine version "..mod.version_string.." using engine "..eng_req)
			if incompatible then mod.incompatible = true
			else return end
		end

		-- Make a function to activate it
		mod.load = function(mode)
			if mode == "setup" then
				core.display.setWindowTitle(mod.long_name)
				self:setupWrite(mod)
				if not team then
					fs.mount(fs.getRealPath(dir), "/mod", false)
					fs.mount(fs.getRealPath(dir).."/data/", "/data", false)
					if fs.exists(dir.."/engine") then fs.mount(fs.getRealPath(dir).."/engine/", "/engine", false) end
				else
					local src = fs.getRealPath(team)
					fs.mount(src, "/", false)

					-- Addional teams
					for i, t in ipairs(mod.teams or {}) do
						local base = team:gsub("/[^/]+$", "/")
						local file = base..t[1]:gsub("#name#", mod.short_name):gsub("#version#", ("%d.%d.%d"):format(mod.version[1], mod.version[2], mod.version[3]))
						if fs.exists(file) then
							print("Mounting additional team file:", file)
							local src = fs.getRealPath(file)
							fs.mount(src, "/", false)
						end
					end
				end

				-- Load moonscript support
				if mod.moonscript then
					require "moonscript"
					require "moonscript.errors"
				end
			elseif mode == "init" then
				local m = require(mod.starter)
				m[1].__session_time_played_start = os.time()
				m[1].__mod_info = mod
				print("[MODULE LOADER] loading module", mod.long_name, "["..mod.starter.."]", "::", m[1] and m[1].__CLASSNAME, m[2] and m[2].__CLASSNAME)
				return m[1], m[2]
			end
		end

		print("Loaded module definition for "..mod.version_string.." using engine "..eng_req)
		return mod
	end
end

--- List all available savefiles
-- Static
function _M:listSavefiles(moddir_filter)
	local allmounts = fs.getSearchPath(true)
	fs.mount(engine.homepath..fs.getPathSeparator(), "/tmp/listsaves")

	local mods = self:listModules(nil, moddir_filter)
	for _, mod in ipairs(mods) do
		local lss = {}
		for i, short_name in ipairs(fs.list("/tmp/listsaves/"..mod.short_name.."/save/")) do
			local dir = "/tmp/listsaves/"..mod.short_name.."/save/"..short_name
			if fs.exists(dir.."/game.teag") then
				local def = self:loadSavefileDescription(dir)
				if def then
					if fs.exists(dir.."/cur.png") then
						def.screenshot = core.display.loadImage(dir.."/cur.png")
					end

					table.insert(lss, def)
				end
			end
		end
		mod.savefiles = lss

		table.sort(lss, function(a, b)
			return a.name < b.name
		end)
	end

	fs.reset()
	fs.mountAll(allmounts)

	return mods
end

--- List all available vault characters
-- Static
function _M:listVaultSaves()
--	fs.mount(engine.homepath, "/tmp/listsaves")

	local mods = self:listModules()
	for _, mod in ipairs(mods) do
		local lss = {}
		for i, short_name in ipairs(fs.list("/"..mod.short_name.."/vault/")) do
			local dir = "/"..mod.short_name.."/vault/"..short_name
			if fs.exists(dir.."/character.teac") then
				local def = self:loadSavefileDescription(dir)
				if def then
					table.insert(lss, def)
				end
			end
		end
		mod.savefiles = lss

		table.sort(lss, function(a, b)
			return a.name < b.name
		end)
	end

--	fs.umount(engine.homepath)

	return mods
end

--- List all available vault characters for the currently running module
-- Static
function _M:listVaultSavesForCurrent()
	local lss = {}
	for i, short_name in ipairs(fs.list("/vault/")) do
		local dir = "/vault/"..short_name
		if fs.exists(dir.."/character.teac") then
			local def = self:loadSavefileDescription(dir)
			if def then
				table.insert(lss, def)
			end
		end
	end

	table.sort(lss, function(a, b)
		return a.name < b.name
	end)
	return lss
end

--- List all available addons
function _M:loadAddons(mod)
	local adds = {}
	local load = function(dir, teaa)
		local add_def = loadfile(dir.."/init.lua")
		if add_def then
			local add = {}
			setfenv(add_def, add)
			add_def()

			if engine.version_string(add.version) == engine.version_string(mod.version) and add.for_module == mod.short_name then
				add.dir = dir
				add.teaa = teaa
				adds[#adds+1] = add
			end
		end
	end

	for i, short_name in ipairs(fs.list("/addons/")) do if short_name:find("^"..mod.short_name.."%-") then
		local dir = "/addons/"..short_name
		print("Checking addon", short_name, ":: (as dir)", fs.exists(dir.."/init.lua"), ":: (as teaa)", short_name:find(".teaa$"), "")
		if fs.exists(dir.."/init.lua") then
			load(dir, nil)
		elseif short_name:find(".teaa$") then
			fs.mount(fs.getRealPath(dir), "/testload", false)
			local mod
			if fs.exists("/testload/init.lua") then
				load("/testload", dir)
			end
			fs.umount(fs.getRealPath(dir))
		end
	end end

	table.sort(adds, function(a, b) return a.weight < b.weight end)

	mod.addons = {}
	for i, add in ipairs(adds) do
		add.version_name = ("%s-%s-%d.%d.%d"):format(mod.short_name, add.short_name, add.version[1], add.version[2], add.version[3])

		print("Binding addon", add.long_name, add.teaa, add.version_name)
		local base, vbase
		if add.teaa then
			fs.mount(fs.getRealPath(add.teaa), "/loaded-addons/"..add.short_name, true)
			base = "bind::/loaded-addons/"..add.short_name
			vbase = "/loaded-addons/"..add.short_name
		else
			base = fs.getRealPath(add.dir)
			fs.mount(base, "/loaded-addons/"..add.short_name, true)
			vbase = "/loaded-addons/"..add.short_name
		end

		if add.data then fs.mount(base.."/data", "/data-"..add.short_name, true) print(" * with data") end
		if add.superload then fs.mount(base.."/superload", "/mod/addons/"..add.short_name.."/superload", true) print(" * with superload") end
		if add.overload then fs.mount(base.."/overload", "/", false) print(" * with overload") end
		if add.hooks then
			fs.mount(base.."/hooks", "/hooks/"..add.short_name, true)
			dofile("/hooks/"..add.short_name.."/load.lua")
			print(" * with hooks")
		end

		-- Compute addon md5
		local md5 = require "md5"
		local md5s = {}
		local function fp(dir)
			for i, file in ipairs(fs.list(dir)) do
				local f = dir.."/"..file
				if fs.isdir(f) then
					fp(f)
				elseif f:find("%.lua$") then
					local fff = fs.open(f, "r")
					if fff then
						local data = fff:read(10485760)
						if data and data ~= "" then
							md5s[#md5s+1] = f..":"..md5.sumhexa(data)
						end
						fff:close()
					end
				end
			end
		end
		local hash_valid, hash_err
		local t = core.game.getTime()
		if config.settings.cheat then
			hash_valid, hash_err = false, "cheat mode skipping addon validation"
		else
			fp(vbase)
			table.sort(md5s)
			table.print(md5s)
			local fmd5 = md5.sumhexa(table.concat(md5s))
			print("[MODULE LOADER] addon ", add.short_name, " MD5", fmd5, "computed in ", core.game.getTime() - t, vbase)
			hash_valid, hash_err = profile:checkAddonHash(mod.short_name, add.version_name, fmd5)
		end

		if hash_err then hash_err = hash_err .. " [addon: "..add.short_name.."]" end
		add.hash_valid, add.hash_err = hash_valid, hash_err

		mod.addons[add.short_name] = add
	end
--	os.exit()
end

--- Make a module loadscreen
function _M:loadScreen(mod)
	core.display.forceRedraw()
	core.wait.enable(10000, function()
		local has_max = mod.loading_wait_ticks
		if has_max then core.wait.addMaxTicks(has_max) end
		local i, max, dir = has_max or 20, has_max or 20, -1

		local bkgs = core.display.loadImage("/data/gfx/background/"..mod.short_name..".png") or core.display.loadImage("/data/gfx/background/tome.png")
		local sw, sh = core.display.size()
		local bw, bh = bkgs:getSize()
		local bkg = {bkgs:glTexture()}

		local logo = {(core.display.loadImage("/data/gfx/background/"..mod.short_name.."-logo.png") or core.display.loadImage("/data/gfx/background/tome-logo.png")):glTexture()}

		local left = {core.display.loadImage("/data/gfx/waiter/left.png"):glTexture()}
		local right = {core.display.loadImage("/data/gfx/waiter/right.png"):glTexture()}
		local middle = {core.display.loadImage("/data/gfx/waiter/middle.png"):glTexture()}
		local bar = {core.display.loadImage("/data/gfx/waiter/bar.png"):glTexture()}

		local font = core.display.newFont("/data/font/Vera.ttf", 12)

		local dw, dh = math.floor(sw / 2), left[7]
		local dx, dy = math.floor((sw - dw) / 2), sh - dh

		return function()
			-- Background
			local x, y = 0, 0
			if bw > bh then
				bh = sw * bh / bw
				bw = sw
				y = (sh - bh) / 2
			else
				bw = sh * bw / bh
				bh = sh
				x = (sw - bw) / 2
			end
			bkg[1]:toScreenFull(x, y, bw, bh, bw * bkg[4], bh * bkg[5])

			-- Logo
			logo[1]:toScreenFull(0, 0, logo[6], logo[7], logo[2], logo[3])

			-- Progressbar
			local x
			if has_max then
				i, max = core.wait.getTicks()
				i = util.bound(i, 0, max)
			else
				i = i + dir
				if dir > 0 and i >= max then dir = -1
				elseif dir < 0 and i <= -max then dir = 1
				end
			end

			local x = dw * (i / max)
			local x2 = x + dw
			x = util.bound(x, 0, dw)
			x2 = util.bound(x2, 0, dw)
			if has_max then x, x2 = 0, x end
			local w, h = x2 - x, dh

			middle[1]:toScreenFull(dx, dy, dw, middle[7], middle[2], middle[3])
			bar[1]:toScreenFull(dx + x, dy, w, bar[7], bar[2], bar[3])
			left[1]:toScreenFull(dx - left[6] + 5, dy + (middle[7] - left[7]) / 2, left[6], left[7], left[2], left[3])
			right[1]:toScreenFull(dx + dw - 5, dy + (middle[7] - right[7]) / 2, right[6], right[7], right[2], right[3])

			if has_max then
				font:setStyle("bold")
				local txt = {core.display.drawStringBlendedNewSurface(font, math.min(100, math.floor(core.wait.getTicks() * 100 / max)).."%", 255, 255, 255):glTexture()}
				font:setStyle("normal")
				txt[1]:toScreenFull(dx + (dw - txt[6]) / 2 + 2, dy + (bar[7] - txt[7]) / 2 + 2, txt[6], txt[7], txt[2], txt[3], 0, 0, 0, 0.6)
				txt[1]:toScreenFull(dx + (dw - txt[6]) / 2, dy + (bar[7] - txt[7]) / 2, txt[6], txt[7], txt[2], txt[3])
			end
		end
	end)
	core.display.forceRedraw()
end


--- Instanciate the given module, loading it and creating a new game / loading an existing one
-- @param mod the module definition as given by Module:loadDefinition()
-- @param name the savefile name
-- @param new_game true if the game must be created (aka new character)
function _M:instanciate(mod, name, new_game, no_reboot)
	if not no_reboot then
		local eng_v = nil
		if not mod.incompatible then eng_v = ("%d.%d.%d"):format(mod.engine[1], mod.engine[2], mod.engine[3]) end
		util.showMainMenu(false, mod.engine[4], eng_v, mod.version_string, name, new_game)
		return
	end

	if mod.short_name == "boot" then profile.hash_valid = true end

	mod.version_name = ("%s-%d.%d.%d"):format(mod.short_name, mod.version[1], mod.version[2], mod.version[3])

	-- Turn based by default
	core.game.setRealtime(0)

	-- FOV Shape
	core.fov.set_vision_shape("circle")
	core.fov.set_permissiveness("square")

	-- Init the module directories
	fs.mount(engine.homepath, "/")
	mod.load("setup")

	-- Check the savefile if possible, to add to the progress bar size
	local savesize = 0
	local save = Savefile.new("")
	savesize = save:loadWorldSize() or 0
	save:close()

	-- Load the savefile if it exists, or create a new one if not (or if requested)
	local save = engine.Savefile.new(name)
	if save:check() and not new_game then
		savesize = savesize + save:loadGameSize()
	end
	save:close()

	-- Display the loading bar
	self:loadScreen(mod)
	core.wait.addMaxTicks(savesize)

	-- Check MD5sum with the server
	local md5 = require "md5"
	local md5s = {}
	local function fp(dir)
		for i, file in ipairs(fs.list(dir)) do
			local f = dir.."/"..file
			if fs.isdir(f) then
				fp(f)
			elseif f:find("%.lua$") then
				local fff = fs.open(f, "r")
				if fff then
					local data = fff:read(10485760)
					if data and data ~= "" then
						md5s[#md5s+1] = f..":"..md5.sumhexa(data)
					end
					fff:close()
				end
			end
		end
	end
	local hash_valid, hash_err
	local t = core.game.getTime()
	if config.settings.cheat then
		hash_valid, hash_err = false, "cheat mode skipping validation"
	else
		if mod.short_name ~= "boot" then
			fp("/mod")
			fp("/data")
			fp("/engine")
			table.sort(md5s)
			local fmd5 = md5.sumhexa(table.concat(md5s))
			print("[MODULE LOADER] module MD5", fmd5, "computed in ", core.game.getTime() - t)
			hash_valid, hash_err = profile:checkModuleHash(mod.version_name, fmd5)
		end
	end

	self:loadAddons(mod)

	-- Check addons
	if hash_valid then
		for name, add in pairs(mod.addons) do
			if not add.hash_valid then
				hash_valid = false
				hash_err = add.hash_err or "?????? unknown ...."
				profile.hash_valid = false
				break
			end
		end
	end

	local addl = {}
	for name, add in pairs(mod.addons) do
		addl[#addl+1] = add.version_name
	end
	mod.full_version_string = mod.version_string.." ["..table.concat(addl, ';').."]"

	profile:addStatFields(unpack(mod.profile_stats_fields or {}))
	profile:setConfigsBatch(true)
	profile:loadModuleProfile(mod.short_name, mod)
	profile:currentCharacter(mod.full_version_string, "game did not tell us")

	-- Init the module code
	local M, W = mod.load("init")
	_G.game = M.new()
	_G.game:setPlayerName(name)

	-- Load the world, or make a new one
	core.wait.enableManualTick(true)
	if W then
		local save = Savefile.new("")
		_G.world = save:loadWorld()
		save:close()
		if not _G.world then
			_G.world = W.new()
		end
		_G.world:run()
	end

	-- Load the savefile if it exists, or create a new one if not (or if requested)
	local save = engine.Savefile.new(_G.game.save_name)
	if save:check() and not new_game then
		local delay
		_G.game, delay = save:loadGame()
		delay()
	else
		save:delete()
	end
	save:close()
	core.wait.enableManualTick(false)

	-- And now run it!
	_G.game:run()

	-- Try to bind some debug keys
	if _G.game.key and _G.game.key.setupRebootKeys then _G.game.key:setupRebootKeys() end

	-- Add user chat if needed
	if mod.allow_userchat and _G.game.key then
		profile.chat:setupOnGame()
		profile.chat:join("global")
		profile.chat:join(mod.short_name)
		profile.chat:join(mod.short_name.."-spoiler")
		profile.chat:selectChannel(mod.short_name)
	end

	-- Disable the profile if ungood
	if mod.short_name ~= "boot" then
		if not hash_valid then
			game.log("#LIGHT_RED#Online profile disabled(switching to offline profile) due to %s.", hash_err or "???")
		end
	end
	print("[MODULE LOADER] done loading module", mod.long_name)

	profile:saveGenericProfile("modules_loaded", {name=mod.short_name, nb={"inc", 1}})
	profile:setConfigsBatch(false)

	-- TODO: Replace this with loading quickhotkeys from the profile.
	if engine.interface.PlayerHotkeys then engine.interface.PlayerHotkeys:loadQuickHotkeys(mod.short_name, Savefile.hotkeys_file) end

	core.wait.disable()

	core.display.resetAllFonts("normal")
end

--- Setup write dir for a module
-- Static
function _M:setupWrite(mod)
	-- Create module directory
	fs.setWritePath(engine.homepath)
	fs.mkdir(mod.short_name)
	fs.mkdir(mod.short_name.."/save")

	-- Enter module directory
	local base = engine.homepath .. fs.getPathSeparator() .. mod.short_name
	fs.setWritePath(base)
	fs.mount(base, "/", false)
	return base
end

--- Get a savefile description from the savefile desc.lua file
function _M:loadSavefileDescription(dir)
	local ls_def = loadfile(dir.."/desc.lua")
	if ls_def then
		-- Call the file body inside its own private environment
		local ls = {}
		setfenv(ls_def, ls)
		ls_def()

		if not ls.name or not ls.description then return end
		ls.dir = dir
		return ls
	end
end

--- Loads a list of modules from te4.org/modules.lualist
-- Calling this function starts a background thread, which can be waited on by the returned lina object
-- @param src the url to load the list from, if nil it will default to te4.org
-- @return a linda object (see lua lanes documentation) which should be waited upon like this <code>local mylist = l:receive("moduleslist")</code>. Also returns a thread handle
function _M:loadRemoteList(src)
	local DownloadDialog = require "engine.dialogs.DownloadDialog"
	local d = DownloadDialog.new("Fetching updates", "http://te4.org/dl/t-engine/t-engine4-windows-1.0.0beta21.zip")
	d:startDownload()
end
