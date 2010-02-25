-- Physical combat
newTalentType{ type="technique/2hweapon-offense", name = "two handed weapons", description = "Specialized two handed techniques." }
newTalentType{ type="technique/2hweapon-cripple", name = "two handed weapons", description = "Specialized two handed techniques." }
newTalentType{ type="technique/shield-offense", name = "weapon and shields", description = "Specialized weapon and shield techniques." }
newTalentType{ type="technique/shield-defense", name = "weapon and shields", description = "Specialized weapon and shield techniques." }
newTalentType{ type="technique/dualweapon-training", name = "dual wielding", description = "Specialized dual wielding techniques." }
newTalentType{ type="technique/dualweapon-attack", name = "dual wielding", description = "Specialized dual wielding techniques." }
newTalentType{ type="technique/archery-base", name = "archery - base", description = "Ability to shoot, you should never this this." }
newTalentType{ type="technique/archery-bow", name = "archery - bows", description = "Specialized bow techniques." }
newTalentType{ type="technique/archery-sling", name = "archery - slings", description = "Specialized sling techniques." }
newTalentType{ type="technique/archery-training", name = "archery - common", description = "Generic archery techniques." }
newTalentType{ type="technique/archery-cripple", name = "archery - cripple", description = "Specialized archery techniques to maim your targets." }
newTalentType{ type="technique/combat-techniques-active", name = "combat-techniques", description = "Generic combat oriented techniques." }
newTalentType{ type="technique/combat-techniques-passive", name = "combat-techniques", description = "Generic combat oriented techniques." }
newTalentType{ type="technique/combat-training", name = "combat-training", description = "Teaches to use various armors and improves health." }
newTalentType{ type="technique/magical-combat", name = "magical-combat", description = "Blend magic and melee." }

-- Generic requires for techs based on talent level
-- Uses STR unless the wielder knows Arcane Combat
techs_req1 = function(self, t) local stat = self:getMag() >= self:getStr() and self:knowTalent(self.T_ARCANE_COMBAT) and "mag" or "str"; return {
	stat = { [stat]=function(level) return 12 + (level-1) * 2 end },
	level = function(level) return 0 + (level-1)  end,
} end
techs_req2 = function(self, t) local stat = self:getMag() >= self:getStr() and self:knowTalent(self.T_ARCANE_COMBAT) and "mag" or "str"; return {
	stat = { [stat]=function(level) return 20 + (level-1) * 2 end },
	level = function(level) return 4 + (level-1)  end,
} end
techs_req3 = function(self, t) local stat = self:getMag() >= self:getStr() and self:knowTalent(self.T_ARCANE_COMBAT) and "mag" or "str"; return {
	stat = { [stat]=function(level) return 28 + (level-1) * 2 end },
	level = function(level) return 8 + (level-1)  end,
} end
techs_req4 = function(self, t) local stat = self:getMag() >= self:getStr() and self:knowTalent(self.T_ARCANE_COMBAT) and "mag" or "str"; return {
	stat = { [stat]=function(level) return 36 + (level-1) * 2 end },
	level = function(level) return 12 + (level-1)  end,
} end
techs_req5 = function(self, t) local stat = self:getMag() >= self:getStr() and self:knowTalent(self.T_ARCANE_COMBAT) and "mag" or "str"; return {
	stat = { [stat]=function(level) return 44 + (level-1) * 2 end },
	level = function(level) return 16 + (level-1)  end,
} end

-- Generic requires for techs_dex based on talent level
techs_dex_req1 = {
	stat = { dex=function(level) return 12 + (level-1) * 2 end },
	level = function(level) return 0 + (level-1)  end,
}
techs_dex_req2 = {
	stat = { dex=function(level) return 20 + (level-1) * 2 end },
	level = function(level) return 4 + (level-1)  end,
}
techs_dex_req3 = {
	stat = { dex=function(level) return 28 + (level-1) * 2 end },
	level = function(level) return 8 + (level-1)  end,
}
techs_dex_req4 = {
	stat = { dex=function(level) return 36 + (level-1) * 2 end },
	level = function(level) return 12 + (level-1)  end,
}
techs_dex_req5 = {
	stat = { dex=function(level) return 44 + (level-1) * 2 end },
	level = function(level) return 16 + (level-1)  end,
}

-- Generic rquires based either on str or dex
techs_strdex_req1 = function(self, t) local stat = self:getStr() >= self:getDex() and "str" or "dex"; return {
	stat = { [stat]=function(level) return 12 + (level-1) * 2 end },
	level = function(level) return 0 + (level-1)  end,
} end
techs_strdex_req2 = function(self, t) local stat = self:getStr() >= self:getDex() and "str" or "dex"; return {
	stat = { [stat]=function(level) return 20 + (level-1) * 2 end },
	level = function(level) return 4 + (level-1)  end,
} end
techs_strdex_req3 = function(self, t) local stat = self:getStr() >= self:getDex() and "str" or "dex"; return {
	stat = { [stat]=function(level) return 28 + (level-1) * 2 end },
	level = function(level) return 8 + (level-1)  end,
} end
techs_strdex_req4 = function(self, t) local stat = self:getStr() >= self:getDex() and "str" or "dex"; return {
	stat = { [stat]=function(level) return 36 + (level-1) * 2 end },
	level = function(level) return 12 + (level-1)  end,
} end
techs_strdex_req5 = function(self, t) local stat = self:getStr() >= self:getDex() and "str" or "dex"; return {
	stat = { [stat]=function(level) return 44 + (level-1) * 2 end },
	level = function(level) return 16 + (level-1)  end,
} end

load("/data/talents/techniques/2hweapon.lua")
load("/data/talents/techniques/dualweapon.lua")
load("/data/talents/techniques/weaponshield.lua")
load("/data/talents/techniques/combat-techniques.lua")
load("/data/talents/techniques/combat-training.lua")
load("/data/talents/techniques/bow.lua")
load("/data/talents/techniques/sling.lua")
load("/data/talents/techniques/archery.lua")
load("/data/talents/techniques/magical-combat.lua")
