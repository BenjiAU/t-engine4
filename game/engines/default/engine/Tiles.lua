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

require "engine.class"

--- Handles tiles
-- Used by engine.Map to reduce processing needed. Module authors wont use it directly mostly.
-- @classmod engine.Tiles
module(..., package.seeall, class.make)

prefix = "/data/gfx/"
base_prefix = "/data/gfx/"
use_images = true
force_back_color = nil
sharp_scaling = nil

tilesets = {}
tilesets_texs = {}
function _M:loadTileset(file)
	if config.settings.disable_tilesets then return end
	if not fs.exists(file) then print("Tileset file "..file.." does not exists.") return end
	local f, err = loadfile(file)
	if err then error(err) end
	local env = {}
	local ts = {}
	setfenv(f, setmetatable(ts, {__index={_G=ts}}))
	local ok, err = pcall(f)
	if not ok then error(err) end
	if ts.__width > core.display.glMaxTextureSize() or ts.__height > core.display.glMaxTextureSize() then
		print("[TILESET] Refusing tileset "..file.." due to texture size "..ts.__width.."x"..ts.__height.." over max of "..core.display.glMaxTextureSize())
		return
	end
	for k, e in pairs(ts) do self.tilesets[k] = e end
end

function _M:init(w, h, fontname, fontsize, texture, allow_backcolor)
	if not texture then
		error("[Tiles] ERROR: Tiles.new does not support non-texture anymore")
	end

	self.allow_backcolor = allow_backcolor
	self.w, self.h = w, h
	self.font = core.display.newFont(fontname or "/data/font/DroidSansMono.ttf", fontsize or 14)
	self.repo = {}
	self.texture_store = {}
end

function concatPrefix(prefix, image_file)
	if image_file:sub(1, 1) == "/" then
		return image_file
	else
		return prefix..image_file
	end
end

function baseImageFile(image_file)
	local _, _, addon, rfile = image_file:find("^([^+]+)%+(.+)$")
	if addon and rfile then
		return "/data-"..addon.."/gfx/"..rfile
	else
		return concatPrefix(base_prefix, image_file)
	end
end

function _M:loadImage(image)
	local s = core.display.loadImage(concatPrefix(self.prefix, image))
	if not s then s = core.display.loadImage(baseImageFile(image)) end
	return s
end

function _M:loadTexture(image)
	local s = {core.loader.png(concatPrefix(self.prefix, image))}
	if not s[1] then s = {core.loader.png(baseImageFile(image))} end
	return unpack(s)
end

function _M:checkTileset(image, base)
	local f
	if not base then f = concatPrefix(self.prefix, image)
	else f = baseImageFile(image) end
	if not self.tilesets[f] then
		if not base then return self:checkTileset(image, true) end
		return
	end
	local d = self.tilesets[f]
	-- print("Loading tile from tileset", f, "=>", d.factorx, d.factory, d.x, d.y, d.w, d.h)
	local tex = self.tilesets_texs[d.set]
	if not tex then
		tex = core.loader.png(d.set)
		self.tilesets_texs[d.set] = tex
		print("Loading tileset", d.set)
	end
	return tex, d.factorx, d.factory, d.x, d.y, d.w, d.h, d.trim_x1, d.trim_y1, d.trim_x2, d.trim_y2, d.trim_ow, d.trim_oh
end

function _M:get(char, fr, fg, fb, br, bg, bb, image, alpha, do_outline, allow_tileset, force_texture_repeat)
	if self.force_back_color then br, bg, bb, alpha = self.force_back_color.r, self.force_back_color.g, self.force_back_color.b, self.force_back_color.a end

	alpha = alpha or 0
	char = char or ''
	local dochar = char
	local fgidx = 65536 * fr + 256 * fg + fb
	local bgidx
	if br and bg and bb and br >= 0 and bg >= 0 and bb >= 0 then
		bgidx = 65536 * br + 256 * bg + bb
	else
		bgidx = "none"
	end

	if (self.use_images or not dochar) and image then char = image end
	if self.repo[char] and self.repo[char][fgidx] and self.repo[char][fgidx][bgidx] then
		local s = self.repo[char][fgidx][bgidx]
		return s[1], s[2], s[3], s[4], s[5], s[6], s[7], s[8], s[9], s[10], s[11], s[12], s[13]
	else
		local s, sw, sh, w, h
		local is_image = false
		if (self.use_images or not dochar) and image and #image > 4 then
			if allow_tileset then
				local ts, fx, fy, tsx, tsy, tw, th, trim_x1, trim_y1, trim_x2, trim_y2, trim_ow, trim_oh = self:checkTileset(image)
				if ts then
					self.repo[char] = self.repo[char] or {}
					self.repo[char][fgidx] = self.repo[char][fgidx] or {}
					self.repo[char][fgidx][bgidx] = {ts, fx, fy, tw, th, tsx, tsy, trim_x1, trim_y1, trim_x2, trim_y2, trim_ow, trim_oh}
					-- print(("------- TILE[%s] = texture (tileset/%s: %fx%f %dx%d)"):format(char, ts:getValue(), fx, fy, tw, th))
					return ts, fx, fy, tw, th, tsx, tsy, trim_x1, trim_y1, trim_x2, trim_y2, trim_ow, trim_oh
				end
			end
			print("Loading tile", image, " even though tileset was", allow_tileset)

			local t, w, h  = core.loader.png(concatPrefix(self.prefix, image), self.sharp_scaling, not force_texture_repeat)
			if not t then t, w, h = core.loader.png(baseImageFile(image), self.sharp_scaling, not force_texture_repeat) end
			local ts, fx, fy, tsx, tsy, tw, th = t, 1, 1, 0, 0, w, h
			if ts then
				self.repo[char] = self.repo[char] or {}
				self.repo[char][fgidx] = self.repo[char][fgidx] or {}
				self.repo[char][fgidx][bgidx] = {ts, fx, fy, tw, th, tsx, tsy}
				-- print(("------- TILE[%s] = texture (tile/%s: %fx%f %dx%d)"):format(char, ts:getValue(), fx, fy, tw, th))
				return ts, fx, fy, tw, th, tsx, tsy
			end
		end

		local pot_width = math.pow(2, math.ceil(math.log(self.w-0.1) / math.log(2.0)))
		local pot_height = math.pow(2, math.ceil(math.log(self.h-0.1) / math.log(2.0)))

		-- We have no image yet, let's jsut try to make an ASCII tile
		local offx, offy = 0, 0
		if not s then
			local w, h = self.font:size(dochar)
			if not self.allow_backcolor or br < 0 then br = nil end
			if not self.allow_backcolor or bg < 0 then bg = nil end
			if not self.allow_backcolor or bb < 0 then bb = nil end
			if not self.allow_backcolor then alpha = 0 end

			s, w, h, sw, sh = self:makeTextTile(pot_width, pot_height, dochar, fr, fg, fb, br or 0, bg or 0, bb or 0, alpha)
		else
			w, h = s:getSize()
			s, sw, sh = s:glTexture(self.sharp_scaling, not force_texture_repeat)
			sw, sh = w / sw, h / sh
			if not is_image and do_outline and false then
				if type(do_outline) == "boolean" then
					s = s:makeOutline(2*pot_width/self.w, 2*pot_height/self.h, pot_width, pot_height, 0, 0, 0, 1) or s
				else
					s = s:makeOutline(do_outline.x*pot_width/self.w, do_outline.y*pot_height/self.h, pot_width, pot_height, do_outline.r, do_outline.g, do_outline.b, do_outline.a) or s
				end
			end
		end

		self.repo[char] = self.repo[char] or {}
		self.repo[char][fgidx] = self.repo[char][fgidx] or {}
		self.repo[char][fgidx][bgidx] = {s, sw, sh, w, h, offx, offy}
		-- print(("------- TILE[%s] = texture (%s: %fx%f %dx%d)"):format(char, s:getValue(), sw, sh, w, h))
		return s, sw, sh, w, h
	end
end

function _M:makeTextTile(w, h, char, fr, fg, fb, br, bg, bb, alpha)
	if not self.ascii_maker then
		self.ascii_maker_text = core.renderer.text(self.font):translate(self.w / 2, self.h / 2)
		self.ascii_maker_rdr = core.renderer.renderer("static"):setRendererName("Tiles:ASCIIMaker")
		self.ascii_maker_bg = core.renderer.colorQuad(0, 0, self.w, self.h, 1, 1, 1, 1):shown(false)
		self.ascii_maker_rdr:add(self.ascii_maker_bg):add(self.ascii_maker_text)
		self.ascii_maker_view = core.renderer.view():ortho(self.w, self.h, false)
		self.ascii_maker = core.renderer.target(self.w, self.h, 1, false):view(self.ascii_maker_view):setAutoRender(self.ascii_maker_rdr)
	end
	if br > 0 or bg > 0 or bb > 0 then
		self.ascii_maker_bg:shown(true):color(br / 255, bg / 255, bb / 255, alpha / 255)
	else
		self.ascii_maker_bg:shown(false)
	end
	self.ascii_maker_text:text(char, true):color(fr / 255, fg / 255, fb / 255, 1):center()
	local tex = self.ascii_maker:compute():extractTexture(0)
	return tex, self.w, self.h, 1, 1
end

function _M:clean()
	self.repo = {}
	self.texture_store = {}
	self.ascii_maker_text = nil
	self.ascii_maker_rdr = nil
	self.ascii_maker = nil
	collectgarbage("collect")
end
