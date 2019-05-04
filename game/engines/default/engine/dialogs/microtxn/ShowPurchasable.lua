-- TE4 - T-Engine 4
-- Copyright (C) 2009 - 2017 Nicolas Casalini
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
local Module = require "engine.Module"
local Downloader = require "engine.dialogs.Downloader"
local Entity = require "engine.Entity"
local Dialog = require "engine.ui.Dialog"
local Image = require "engine.ui.Image"
local Textzone = require "engine.ui.Textzone"
local Separator = require "engine.ui.Separator"
local TextzoneList = require "engine.ui.TextzoneList"
local ListColumns = require "engine.ui.ListColumns"
local VariableList = require "engine.ui.VariableList"
local Button = require "engine.ui.Button"
local WebView = require "engine.ui.WebView"

module(..., package.seeall, class.inherit(Dialog))

local bonus_vault_slots_text = "#{italic}##UMBER#Bonus vault slots from this order: #ROYAL_BLUE#%d#{normal}#"
local bonus_vault_slots_tooltip = "For every purchase of #{italic}##GREY#%s#LAST##{normal}# you gain a permanent additional vault slot.\n#GOLD##{italic}#Because why not!#{normal}#"

local coins_balance_text = "#{italic}##UMBER#Voratun Coins available from your donations: #ROYAL_BLUE#%d#{normal}#"
local coins_balance_tooltip = "For every donations you've ever made you have earned voratun coins. These can be spent purchasing expansions or options on the online store. This is the amount you have left, if your purchase total is below this number you'll instantly get your purchase validated, if not you'll need to donate some more first.\n#GOLD##{italic}#Thanks for your support, every little bit helps the game survive for years on!#{normal}#"

_M.force_ui_inside = "microtxn"

function _M:init(mode)
	if not mode then mode = core.steam and "steam" or "te4" end
	self.mode = mode

	self.cart = {}


	self.base_title_text = game.__mod_info.long_name.." #GOLD#Online Store#LAST#"
	Dialog.init(self, self.base_title_text, game.w * 0.8, game.h * 0.8)

	game.tooltip:generate()

	self.categories_icons = {
		pay2die = "/data/gfx/microtxn-ui/category_pay2die.png",
		community = "/data/gfx/microtxn-ui/category_community.png",
		cosmetic = "/data/gfx/microtxn-ui/category_cosmetic.png",
		misc = "/data/gfx/microtxn-ui/category_misc.png",
	}
	local in_cart_icon = Entity.new{image="/data/gfx/microtxn-ui/in_cart.png"}
	-- local icon_frame = Entity.new{image="/data/gfx/microtxn-ui/icon_frame.png"}

	self.list = {}
	self.purchasables = {}
	self.recap = {}

	local vsep = Separator.new{dir="horizontal", size=self.ih - 10}

	self.c_waiter = Textzone.new{auto_width=1, auto_height=1, text="#YELLOW#-- connecting to server... --"}

	self.c_list = VariableList.new{width=self.iw - 350 - vsep.w, max_height=self.ih, scrollbar=true, sortable=true,
		direct_draw=function(item, x, y, get_size)
			if get_size then return 132 end
			item.img:toScreen(nil, x+2, y+2, 128, 128)
			if self.cart[item.id_purchasable] and item.nb_purchase > 0 then
				in_cart_icon:toScreen(nil, x+2, y+2, 128, 128)
				if item.nb_purchase > 1 and item.p_txt then
					item.p_txt._tex:toScreenFull(x + 106 - item.p_txt.w / 2 + 2, y + 106 - item.p_txt.h / 2 + 2, item.p_txt.w, item.p_txt.h, item.p_txt._tex_w, item.p_txt._tex_h, 0, 0, 0, 1)
					item.p_txt._tex:toScreenFull(x + 106 - item.p_txt.w / 2, y + 106 - item.p_txt.h / 2, item.p_txt.w, item.p_txt.h, item.p_txt._tex_w, item.p_txt._tex_h)
				end
			end
			item.txt:display(x+10+130, y+2 + (128 - item.txt.h) / 2, 0)
		end,
	list=self.list, all_clicks=true, fct=function(item, _, button) self:use(item, button) end, select=function(item, sel) self:onSelectItem(item) end}
	-- self.c_list = ListColumns.new{width=self.iw - 350 - vsep.w, height=self.ih, item_height=132, hide_columns=true, scrollbar=true, sortable=true, columns={
	-- 	{name="", width=100, display_prop="", direct_draw=function(item, x, y)
	-- 		item.img:toScreen(nil, x+2, y+2, 128, 128)
	-- 		if self.cart[item.id_purchasable] and item.nb_purchase > 0 then in_cart_icon:toScreen(nil, x+2, y+2, 128, 128) end
	-- 		item.txt:display(x+10+130, y+2 + (128 - item.txt.h) / 2, 0)
	-- 	end},
	-- }, list=self.list, all_clicks=true, fct=function(item, _, button) self:use(item, button) end, select=function(item, sel) self:onSelectItem(item) end}
	self.c_list.on_focus_change = function(_, v) if not v then game:tooltipHide() end end

	self.c_bonus_vault_slots = Textzone.new{has_box=true, width=340, auto_height=1, text=bonus_vault_slots_text:format(0), can_focus=true}
	self.c_bonus_vault_slots.on_focus_change = function(_, v)
		if v then
			local txt = self:getUIElement(self.c_bonus_vault_slots)
			game:tooltipDisplayAtMap(txt.x, txt.y, (bonus_vault_slots_tooltip):format(self:currencyDisplay(2)))
		else
			game:tooltipHide()
		end
	end

	self.c_coins_available = Textzone.new{has_box=true, width=340, auto_height=1, text=coins_balance_text:format(0), can_focus=true}
	self.c_coins_available.on_focus_change = function(_, v)
		if v then
			local txt = self:getUIElement(self.c_coins_available)
			game:tooltipDisplayAtMap(txt.x, txt.y, (coins_balance_tooltip):format())
		else
			game:tooltipHide()
		end
	end

	self.c_do_purchase = Button.new{text="Purchase", fct=function() self:doPurchase() end}

	self.c_recap = ListColumns.new{width=350, height=self.ih - self.c_do_purchase.h - 15 - math.max(self.c_bonus_vault_slots.h, self.c_coins_available.h), scrollbar=true, columns={
		{name="Name", width=50, display_prop="recap_name"},
		{name="Price", width=35, display_prop="recap_price"},
		{name="Qty", width=15, display_prop="recap_qty"},
	}, list=self.recap, all_clicks=true, fct=function(item, _, button)
		if item.total then return end
		if button == "left" then button = "right"
		elseif button == "right" then button = "left" end
		self:use(item.item, button)
	end, select=function(item, sel) end}

--	local wv = WebView.new{width=500,height=500, url='https://i.giphy.com/media/uk9A7Mz8Jv4GI/giphy-downsized.gif'}

	local uis = {
		{vcenter=0, hcenter=0, ui=self.c_waiter},
		{left=0, top=0, ui=self.c_list},
		{left=self.c_list, top=0, ui=vsep},
		{right=0, top=0, ui=self.c_recap},
		{right=0, bottom=0, ui=self.c_do_purchase},
--		{left=0, top=0, ui=wv},
	}
	-- Only show those for steam as te4.org purchases require already having a donation up
	if mode == "steam" then
		uis[#uis+1] = {right=0, bottom=self.c_do_purchase.h+15, ui=self.c_bonus_vault_slots}
	elseif mode == "te4" then
		uis[#uis+1] = {right=0, bottom=self.c_do_purchase.h+15, ui=self.c_coins_available}
	end

	self:loadUI(uis)

	self:setupUI(false, false)
	self:toggleDisplay(self.c_list, false)

	self.key:addBinds{
		ACCEPT = "EXIT",
		EXIT = function()
			game:unregisterDialog(self)
			if on_exit then on_exit() end
		end,
	}

	self:checks()

	self:generateList()

	if not config.settings.tome.mtxn_explain_seen then game:onTickEnd(function()
		game:saveSettings("tome.mtxn_explain_seen", ("tome.mtxn_explain_seen = true\n"):format())
		config.settings.tome.mtxn_explain_seen = true

		Dialog:forceNextDialogUI("microtxn")
		self:simpleLongPopup("Online Store", [[Welcome!

I am #{italic}##ANTIQUE_WHITE#DarkGod#LAST##{normal}#, the creator of the game and before you go on your merry way I wish to take a few seconds of your time to explain why there are microtransactions in the game.

Before you run off in terror let me put it plainly: I am very #{bold}#firmly #CRIMSON#against#LAST# pay2win#{normal}# things so rest assured I will not add this kind of stuff.

So why put microtransactions? Tales of Maj'Eyal is a cheap/free game and has no subscription required to play. It is my baby and I love it; I plan to work on it for many years to come (as I do since 2009!) but for it to be viable I must ensure a steady stream of income as this is sadly the state of the world we live in.

As for what kind of purchases are/will be available:
- #GOLD#Cosmetics#LAST#: in addition to the existing racial cosmetics & item shimmers available in the game you can get new packs of purely cosmetic items & skins to look even more dapper!
- #GOLD#Pay2DIE#LAST#: Tired of your character? End it with style!
- #GOLD#Vault space#LAST#: For those that donated they can turn all those "useless" donations into even more online vault slots.
- #GOLD#Community events#LAST#: A few online events are automatically and randomly triggered by the server. With those options you can force one of them to trigger; bonus point they trigger for the whole server so everybody online benefits from them each time!

I hope I've convinced you of my non-evil intentions (ironic for a DarkGod I know ;)). I must say feel dirty even doing microtransactions even as benign as those but I want to find all the ways I can to ensure the game's future.
Thanks, and have fun!]], math.min(900, game.w))
	end) end
end

function _M:unload()
	game.tooltip:generate()
end

-- function _M:innerDisplay(x, y, nb_keyframes)
-- end

function _M:checks() game:onTickEnd(function()
	if not profile.auth then
		game:unregisterDialog(self)
		Dialog:simplePopup("Online Store", "You need to be logged in before using the store. Please go back to the main menu and login.")
		return
	end

	if self.mode == "steam" then
		if not profile.auth.steamid then
			game:unregisterDialog(self)
			Dialog:yesnoPopup("Online Store", "Steam users need to link their profiles to their steam account. This is very easy in just a few clicks. Once this is done, simply restart the game.", function(ret) if ret then
				util.browserOpenUrl("https://te4.org/user/"..profile.auth.drupid.."/steam", {is_external=true})
			end end, "Let's do it! (Opens in your browser)", "Not now")
		end
	elseif self.mode == "te4" then
		-- Handle me more smoothly
		if profile.auth.donated < 6 then
			game:unregisterDialog(self)
			Dialog:yesnoPopup("Online Store", "The Online Store (and expansions) are only purchasable by players that bought the game. Plaese go have a look at the donation page for more explanations.", function(ret) if ret then
				util.browserOpenUrl("https://te4.org/donate", {is_external=true})
			end end, "Let's go! (Opens in your browser)", "Not now")
		end
	end
end) end

function _M:onSelectItem(item)
	if self.in_paying_ui then game:tooltipHide() return end
	if not item then return game:tooltipHide() end

	if self.cur_sel_item then self.cur_sel_item.txt.pingpong = nil self.cur_sel_item.txt.scrollbar.pos = 0 end
	item.txt.pingpong = 0

	if item.last_display_x then
		game:tooltipDisplayAtMap(item.last_display_x + self.c_list.w, item.last_display_y, item.tooltip)
	else
		game:tooltipHide()
	end
	self.cur_sel_item = item
end

function _M:use(item, button)
	if self.in_paying_ui then return end
	if not item then return end
	if button == "right" then
		item.nb_purchase = math.max(0, item.nb_purchase - 1)
		if item.nb_purchase <= 0 then self.cart[item.id] = nil end
	elseif button == "left" then
		if item.can_multiple then
			item.nb_purchase = item.nb_purchase + 1
		else
			item.nb_purchase = math.min(1, item.nb_purchase + 1)
		end
		self.cart[item.id] = true
	end

	self:updateCart()
end

function _M:currencyDisplay(v)
	if self.user_currency then
		return ("%0.2f %s"):format(v, self.user_currency)
	else
		return ("%d coins"):format(v)
	end
end

function _M:updateCart()
	local nb_items, total_sum, total_core_sum = 0, 0, 0
	table.empty(self.recap)

	for id, ok in pairs(self.cart) do if ok then
		local item = self.purchasables[id]
		nb_items = nb_items + item.nb_purchase
		total_sum = total_sum + item.nb_purchase * item.price
		total_core_sum = total_core_sum + item.nb_purchase * item.core_price

		self.recap[#self.recap+1] = {
			sort_name = item.name,
			recap_name = item.img:getDisplayString()..item.name,
			recap_price = self:currencyDisplay(item.price * item.nb_purchase),
			recap_qty = item.nb_purchase,
			item = item,
		}

		if item.nb_purchase > 1 then
			local str = tostring(item.nb_purchase)
			local gen = self.font:draw(str, str:toTString():maxWidth(self.font), 255, 255, 255)
			if gen and gen[1] then item.p_txt = gen[1] table.print(gen[1]) end
		else
			item.p_txt = nil
		end
	end end
	table.sort(self.recap, "sort_name")
	self.recap[#self.recap+1] = {
		recap_name = "#{bold}#TOTAL#{normal}#",
		recap_price = self:currencyDisplay(total_sum),
		recap_qty = nb_items,
		total = true,
	}

	self.c_recap:setList(self.recap, true)
	self:updateTitle(self.base_title_text..("  (%d items in cart, %s)"):format(nb_items, self:currencyDisplay(total_sum)))

	self:toggleDisplay(self.c_do_purchase, nb_items > 0)

	self.c_bonus_vault_slots.text = bonus_vault_slots_text:format(total_core_sum / 20 + (profile.auth.donated % 2) / 2)
	self.c_bonus_vault_slots:generate()
end

function _M:doPurchase()
	if table.count(self.cart) == 0 then self:simplePopup("Cart", "Cart is empty!") return end

	self.in_paying_ui = true
	if core.steam then self:doPurchaseSteam()
	else self:doPurchaseTE4()
	end
end

function _M:installShimmer(item)
	if not core.webview then
		Dialog:simpleLongPopup(item.name, "In-game browser is inoperant or disabled, impossible to auto-install shimmer pack.\nPlease go to https://te4.org/ to download it manually.", 600)
		return
	end

	-- When download is finished, we will try to load the addon dynamically and add it to the current character. We can do taht because cosmetic addons dont require much setup
	local when_done = function()
		local found = false
		local addons = Module:listAddons(game.__mod_info, true)
		for _, add in ipairs(addons) do if add.short_name == "cosmetic-"..item.effect then
			found = true

			local hooks_list = {}
			Module:loadAddon(game.__mod_info, add, {}, hooks_list)

			dofile("/data/gfx/mtx-shimmers/"..item.effect..".lua")

			Dialog:simplePopup(item.name, [[Shimmer pack installed!]])
			break
		end end

		if not found then
			Dialog:simpleLongPopup(item.name, [[Could not dynamically link addon to current character, maybe the installation weng wrong.
You can fix that by manually downloading the shimmer addon from https://te4.org/ and placing it in game/addons/ folder.]], 600)
		end
	end

	local co co = coroutine.create(function()
		local filename = ("/addons/%s-cosmetic-%s.teaa"):format(game.__mod_info.short_name, item.effect)
		print("==> downloading", "https://te4.org/download-mtx/"..item.id_purchasable, filename)
		local d = Downloader.new{title="Downloading cosmetic pack: #LIGHT_GREEN#"..item.name, co=co, dest=filename..".tmp", url="https://te4.org/download-mtx/"..item.id_purchasable, allow_downloads={addons=true}}
		local ok = d:start()
		if ok then
			local wdir = fs.getWritePath()
			local _, _, dir, name = filename:find("(.+/)([^/]+)$")
			if dir then
				fs.setWritePath(fs.getRealPath(dir))
				fs.delete(name)
				fs.rename(name..".tmp", name)
				fs.setWritePath(wdir)

				when_done()
			end
		end
	end)
	print(coroutine.resume(co))
end

function _M:paymentSuccess()
	self.in_paying_ui = false

	local list = {}
	for id, ok in pairs(self.cart) do if ok then
		local item = self.purchasables[id]
		if item.is_shimmer then
			self:installShimmer(item)
			list[#list+1] = ("- #{bold}##ROYAL_BLUE#%s #SLATE#x%d#WHITE##{normal}#: The pack should be downloading or even finished by now."):format(item.name, item.nb_purchase)
		elseif item.self_event or item.community_event then
			list[#list+1] = ("- #{bold}##ROYAL_BLUE#%s #SLATE#x%d#WHITE##{normal}#: You can now trigger it whenever you are ready."):format(item.name, item.nb_purchase)
		elseif item.effect == "vaultspace" then
			list[#list+1] = ("- #{bold}##ROYAL_BLUE#%s #SLATE#x%d#WHITE##{normal}#: Your available vault space has increased."):format(item.name, item.nb_purchase)
		end
	end end

	game:unregisterDialog(self)
	Dialog:simpleLongPopup("Payment", "Payment accepted.\n"..table.concat(list, "\n"), 700)
end

function _M:paymentFailure()
	self.in_paying_ui = false
end

function _M:paymentCancel()
	self.in_paying_ui = false
end

function _M:doPurchaseSteam()
	local popup = Dialog:simplePopup("Connecting to Steam", "Steam Overlay should appear, if it does not please make sure it you have not disabled it.", nil, true)

	local cart = {}
	for id, ok in pairs(self.cart) do if ok then
		local item = self.purchasables[id]
		cart[#cart+1] = {
			id_purchasable = id,
			nb_purchase = item.nb_purchase,
		}
	end end

	local function onMTXResult(id_cart, ok)
		local finalpopup = Dialog:simplePopup("Connecting to Steam", "Finalizing transaction with Steam servers...", nil, true)
		profile:registerTemporaryEventHandler("MicroTxnSteamFinalizeCartResult", function(e)
			game:unregisterDialog(finalpopup)
			if e.success then
				if e.new_donated then profile.auth.donated = e.new_donated end
				self:paymentSuccess()
			else
				Dialog:simplePopup("Payment", "Payment refused, you have not been billed.")
				self:paymentFailure()
			end
		end)
		core.profile.pushOrder(string.format("o='MicroTxn' suborder='steam_finalize_cart' module=%q store=%q id_cart=%q", game.__mod_info.short_name, "steam", id_cart))
	end

	profile:registerTemporaryEventHandler("MicroTxnListCartResult", function(e)
		game:unregisterDialog(popup)
		if e.success then
			core.steam.waitMTXResult(onMTXResult)
		else
			Dialog:simplePopup("Payment", "Payment refused, you have not been billed.")
			self:paymentFailure()
		end
	end)
	core.profile.pushOrder(string.format("o='MicroTxn' suborder='create_cart' module=%q store=%q cart=%q", game.__mod_info.short_name, "steam", table.serialize(cart)))
end

function _M:doPurchaseTE4()
	local popup = Dialog:simplePopup("Connecting to server", "Please wait...", nil, true)

	local cart = {}
	for id, ok in pairs(self.cart) do if ok then
		local item = self.purchasables[id]
		cart[#cart+1] = {
			id_purchasable = id,
			nb_purchase = item.nb_purchase,
		}
	end end

	local function finalizePurchase(id_cart)
		local finalpopup = Dialog:simplePopup("Connecting to server", "Please wait...", nil, true)
		profile:registerTemporaryEventHandler("MicroTxnTE4FinalizeCartResult", function(e)
			game:unregisterDialog(finalpopup)
			if e.success then
				if e.new_donated then profile.auth.donated = e.new_donated end
				self:paymentSuccess()
			else
				Dialog:simplePopup("Payment", "Payment refused, you have not been billed.")
				self:paymentFailure()
			end
		end)
		core.profile.pushOrder(string.format("o='MicroTxn' suborder='te4_finalize_cart' module=%q store=%q id_cart=%q", game.__mod_info.short_name, "te4", id_cart))
	end

	profile:registerTemporaryEventHandler("MicroTxnListCartResult", function(e)
		game:unregisterDialog(popup)
		if e.success and e.info then
			if e.info:prefix("instant_buy:") then
				local id_cart = tonumber(e.info:sub(13))
				Dialog:yesnoPopup("Online Store", "You have enough coins to instantly purchase those options. Confirm?", function(ret) if ret then
					finalizePurchase(id_cart)
				end end, "Purchase", "Cancel")
			elseif e.info:prefix("requires:") then
				local more = tonumber(e.info:sub(10))
				Dialog:yesnoPopup("Online Store", "You need "..more.." more coins to purchase those options. Do you want to go to the donation page now?", function(ret) if ret then
					util.browserOpenUrl("https://te4.org/donate", {is_external=true})
				end end, "Let's go! (Opens in your browser)", "Not now")
				self:paymentCancel()
			end
		else
			Dialog:simplePopup("Payment", "Payment refused, you have not been billed.")
			self:paymentFailure()
		end
	end)
	core.profile.pushOrder(string.format("o='MicroTxn' suborder='create_cart' module=%q store=%q cart=%q", game.__mod_info.short_name, "te4", table.serialize(cart)))
end

function _M:buildTooltip(item)
	local text = {}
	if item.community_event then
		text[#text+1] = [[#{bold}##GOLD#Community Online Event#WHITE##{normal}#: Once you have purchased a community event you will be able to trigger it at any later date, on whichever character you choose.
Community events once triggered will activate for #{bold}#every player currently logged on#{normal}# including yourself. Every player receiving it will know you sent it and thus that you are to thank for it.
To activate it you will need to have your online events option set to "all" (which is the default value).]]
	end
	if item.self_event then
		text[#text+1] = [[#{bold}##GOLD#Event#WHITE##{normal}#: Once you have purchased an event you will be able to trigger it at any later date, on whichever character you choose.
To activate it you will need to have your online events option set to "all" (which is the default value).]]
	end
	if item.non_immediate then
		text[#text+1] = [[#{bold}##GOLD#Non Immediate#WHITE##{normal}#: This events adds new content that you have to find by exploration. If you die before finding it, there can be no refunds.]]
	end
	if item.once_per_character then
		text[#text+1] = [[#{bold}##GOLD#Once per Character#WHITE##{normal}#: This event can only be received #{bold}#once per character#{normal}#. Usualy because it adds a new zone or effect to the game that would not make sense to duplicate.]]
	end
	if item.is_shimmer then
		text[#text+1] = [[#{bold}##GOLD#Shimmer Pack#WHITE##{normal}#: Once purchased the game will automatically install the shimmer pack to your game and enable it for your current character too (you will still need to use the Mirror of Reflection to switch them on).
#LIGHT_GREEN#Bonus perk:#LAST# purchasing any shimmer pack will also give your characters a portable Mirror of Reflection to be able to change your appearance anywhere, anytime!]]
	end
	if item.effect == "vaultspace" then
		text[#text+1] = [[#{bold}##GOLD#Vault Space#WHITE##{normal}#: Once purchased your vault space is permanently increased.]]
	end
	return table.concat(text, '\n')
end

function _M:generateList()
	profile:registerTemporaryEventHandler("MicroTxnListPurchasables", function(e)
		if e.error then
			Dialog:simplePopup("Online Store", e.error:capitalize())
			game:unregisterDialog(self)
			return
		end

		if not e.data then return end
		e.data = e.data:unserialize()

		if e.data.infos.steam then
			self.user_country = e.data.infos.steam.country
			self.user_currency = e.data.infos.steam.currency
		end

		local list = {}
		for _, res in ipairs(e.data.list) do
			res.id_purchasable = res.id
			res.nb_purchase = 0
			res.img = Entity.new{
				image=res.image,
				add_mos={
					{image="/data/gfx/microtxn-ui/icon_frame.png"},
					{image=self.categories_icons[res.category or "misc"] or self.categories_icons.misc},
				},
			}
			res.txt = TextzoneList.new{width=self.iw - 10 - 132 - 350, height=128, pingpong=20, scrollbar=true}
			res.txt:switchItem(true, ("%s (%s)\n#SLATE##{italic}#%s#{normal}#"):format(res.name, self:currencyDisplay(res.price), res.desc))
			res.txt.pingpong = nil
			res.tooltip = self:buildTooltip(res)
			list[#list+1] = res
			self.purchasables[res.id] = res
		end
		self.list = list
		self.c_list:setList(list)
		self:toggleDisplay(self.c_list, true)
		self:toggleDisplay(self.c_waiter, false)
		self:setFocus(self.c_list)

		self.c_coins_available.text = coins_balance_text:format((e.data.infos.balance or 0) * 10)
		self.c_coins_available:generate()
		self.cur_coins_left = e.data.infos.balance or 0
	end)
	core.profile.pushOrder(string.format("o='MicroTxn' suborder='list_purchasables' module=%q store=%q", game.__mod_info.short_name, core.steam and "steam" or "te4"))
end
