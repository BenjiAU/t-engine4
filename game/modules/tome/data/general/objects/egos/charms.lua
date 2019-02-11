-- ToME - Tales of Maj'Eyal
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

-- modify the power and cooldown of charm powers
-- This makes adjustments after zone:finishEntity is finished, which handles any egos added via e.addons
local function modify_charm(e, e, zone, level)
	for i, c_mod in ipairs(e.charm_power_mods) do
		c_mod(e, e, zone, level)
	end
	if e._old_finish and e._old_finish ~= e._modify_charm then return e._old_finish(e, e, zone, level) end
end

newEntity{
	name = "quick ", prefix=true,
	keywords = {quick=true},
	level_range = {1, 50},
	rarity = 15,
	cost = 5,
	_modify_charm = modify_charm,
	resolvers.genericlast(function(e)
		if e.finish ~= e._modify_charm then e._old_finish = e.finish end
		e.finish = e._modify_charm
		e.charm_power_mods = e.charm_power_mods or {}
		table.insert(e.charm_power_mods, function(e, e, zone, level)
			if e.charm_power and e.use_power and e.use_power.power then
				print("\t Applying quick ego changes.")
				e.use_power.power = math.ceil(e.use_power.power * rng.float(0.6, 0.8))
				e.charm_power = math.ceil(e.charm_power * rng.float(0.6, 0.9))
			else
				print("\tquick ego changes aborted.")
			end
		end)
	end),
}

newEntity{
	name = "supercharged ", prefix=true,
	keywords = {['super.c']=true},
	level_range = {1, 50},
	rarity = 15,
	cost = 5,
	_modify_charm = modify_charm,
	resolvers.genericlast(function(e)
		if e.finish ~= e._modify_charm then e._old_finish = e.finish end
		e.finish = e._modify_charm
		e.charm_power_mods = e.charm_power_mods or {}
		table.insert(e.charm_power_mods, function(e, e, zone, level)
			if e.charm_power and e.use_power and e.use_power.power then
				print("\t Applying supercharged ego changes.")
				e.use_power.power = math.ceil(e.use_power.power * rng.float(1.1, 1.3))
				e.charm_power = math.ceil(e.charm_power * rng.float(1.3, 1.5))
			else
				print("\tsupercharged ego changes aborted.")
			end
		end)
	end),
}

newEntity{
	name = "overpowered ", prefix=true,
	keywords = {['overpower']=true},
	level_range = {1, 50},
	rarity = 16,
	cost = 5,
	_modify_charm = modify_charm,
	resolvers.genericlast(function(e)
		if e.finish ~= e._modify_charm then e._old_finish = e.finish end
		e.finish = e._modify_charm
		e.charm_power_mods = e.charm_power_mods or {}
		table.insert(e.charm_power_mods, function(e, e, zone, level)
			if e.charm_power and e.use_power and e.use_power.power then
				print("\t Applying overpowered ego changes.")
				e.use_power.power = math.ceil(e.use_power.power * rng.float(1.2, 1.5))
				e.charm_power = math.ceil(e.charm_power * rng.float(1.6, 1.9))
			else
				print("\toverpowered ego changes aborted.")
			end
		end)
	end),
}

newEntity{
	name = "focusing ", prefix=true,
	keywords = {focusing=true},
	level_range = {1, 50},
	greater_ego = 1,
	unique_ego = 1,
	rarity = 12,
	cost = 5,
	focusing_amt = resolvers.mbonus_material(2, 1),
	charm_on_use = {
		{100, function(self, who) return ("reduce %d talent cooldowns by 2"):format(self.focusing_amt, self.focusing_reduction) end, function(self, who)
			who:talentCooldownFilter(nil, self.focusing_amt, 2, true)
		end},
	},
	use_power = {tactical = {BUFF = 0.2}}
}

newEntity{
	name = "extending ", prefix=true,
	keywords = {extending=true},
	level_range = {1, 50},
	greater_ego = 1,
	unique_ego = 1,
	rarity = 12,
	cost = 5,
	extending_amt = resolvers.mbonus_material(2, 1),
	extending_dur = resolvers.mbonus_material(1.5, 1),

	charm_on_use = {
		{100, function(self, who) return ("increase the duration of %d beneficial effects by %d"):format(self.extending_amt, self.extending_dur) end, function(self, who)
			local effs = self:effectsFilter(function(eff)
				if eff.status == "beneficial" and eff.type ~= "other" then return true end
			end)
			if #effs <= 0 then return end
			for i = 1, math.floor(self.extending_amt) do
				local eff = rng.tableRemove(effs)
				eff.dur = eff.dur + math.floor(self.extending_amt)
			end
		end},
	},
	use_power = {tactical = {BUFF = 0.2}}
}

newEntity{
	name = "evasive ", prefix=true,
	keywords = {evasive=true},
	level_range = {1, 50},
	greater_ego = 1,
	unique_ego = 1,
	rarity = 12,
	cost = 5,
	evasive_chance = resolvers.mbonus_material(30, 10),
	charm_on_use = {
		{100, function(self, who) return ("gain a %d%% chance to evade weapon attacks for 2 turns"):format(self.evasive_chance) end, function(self, who)
			who:setEffect(who.EFF_ITEM_CHARM_EVASIVE, 2, {chance = self.evasive_chance})
		end},
	},
	use_power = {tactical = {DEFEND = 0.2}}
}

newEntity{
	name = "soothing ", prefix=true,
	keywords = {soothing=true},
	level_range = {1, 50},
	rarity = 12,
	cost = 5,
	--greater_ego = 1,
	soothing_heal = resolvers.mbonus_material(80, 30),
	charm_on_use = {
		{100, function(self, who) return ("heal for %d"):format(self.soothing_heal) end, function(self, who)
			who:attr("allow_on_heal", 1)
			who:heal(who:mindCrit(self.soothing_heal), who)
			who:attr("allow_on_heal", -1)		
		end},
	},
	use_power = {tactical = {HEAL = 0.2}}
}

newEntity{
	name = "cleansing ", prefix=true,
	keywords = {cleansing=true},
	level_range = {1, 50},
	rarity = 12,
	cost = 5,
	greater_ego = 1,
	cleansing_amount = resolvers.mbonus_material(3, 1),
	charm_on_use = {
		{100, function(self, who) return ("cleanse %d total effects of type disease, wound, or poison"):format(self.cleansing_amount) end, function(self, who)
			who:removeEffectsFilter(function(e) return e.subtype.poison or e.subtype.wound or e.subtype.disease end, self.cleansing_amount)	
		end},
	},
	use_power = {tactical = {CURE = 0.2}}
}

newEntity{
	name = "piercing ", prefix=true,
	keywords = {piercing=true},
	level_range = {1, 50},
	rarity = 12,
	greater_ego = 1,
	unique_ego = 1,
	cost = 5,
	piercing_penetration = resolvers.mbonus_material(30, 10),
	charm_on_use = {
		{100, function(self, who) return ("increase all damage penetration by %d%% for 2 turns"):format(self.piercing_penetration) end, function(self, who)
			who:setEffect(who.EFF_ITEM_CHARM_PIERCING, 2, {penetration = self.piercing_penetration})
		end},
	},
	use_power = {tactical = {BUFF = 0.2}}
}

newEntity{
	name = "powerful ", prefix=true,
	keywords = {piercing=true},
	level_range = {1, 50},
	rarity = 12,
	greater_ego = 1,
	unique_ego = 1,
	cost = 5,
	powerful_damage = resolvers.mbonus_material(30, 10),
	charm_on_use = {
		{100, function(self, who) return ("increase all damage by %d%% for 2 turns"):format(self.powerful_damage) end, function(self, who)
			who:setEffect(who.EFF_ITEM_CHARM_POWERFUL, 2, {damage = self.powerful_damage})
		end},
	},
	use_power = {tactical = {BUFF = 0.2}}
}

--[[
newEntity{
	name = "savior's ", prefix=true,
	keywords = {savior=true},
	level_range = {1, 50},
	rarity = 12,
	--greater_ego = 1,
	unique_ego = 1,
	cost = 5,
	savior_saves = resolvers.mbonus_material(30, 10),
	charm_on_use = {
		{100, function(self, who) return ("increase all saves by %d for 2 turns"):format(self.savior_saves) end, function(self, who)
			who:setEffect(who.EFF_ITEM_CHARM_SAVIOR, 2, {save = self.savior_saves})
		end},
	},
	use_power = {tactical = {BUFF = 0.2}}
}]]

newEntity{
	name = "innervating ", prefix=true,
	keywords = {innervating=true},
	level_range = {1, 50},
	rarity = 18,
	cost = 5,
	unique_ego = 1,
	innervating_fatigue = resolvers.mbonus_material(40, 20),
	charm_on_use = {
		{100, function(self, who) return ("reduce fatigue by %d%% for 2 turns"):format(self.innervating_fatigue) end, function(self, who)
			who:setEffect(who.EFF_ITEM_CHARM_INNERVATING, 2, {fatigue = self.innervating_fatigue})
		end},
	},
	use_power = {tactical = {BUFF = 0.2}}
}