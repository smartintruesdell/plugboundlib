require "/items/active/weapons/melee/meleeslash.lua"
require "/scripts/lpl_load_plugins.lua"
local PLUGINS_PATH =
  "/items/active/weapons/melee/abilities/spear/spearstab_plugins.config"

-- Spear stab attack
-- Extends normal melee attack and adds a hold state
SpearStab = MeleeSlash:new()

function SpearStab:init()
  MeleeSlash.init(self)

  self.holdDamageConfig = sb.jsonMerge(self.damageConfig, self.holdDamageConfig)
  self.holdDamageConfig.baseDamage =
    self.holdDamageMultiplier * self.damageConfig.baseDamage
end
SpearStab.init = PluginLoader.add_plugin_loader("spearstab", PLUGINS_PATH, SpearStab.init)

function SpearStab:fire()
  MeleeSlash.fire(self)

  if self.fireMode == "primary" and self.allowHold ~= false then
    self:setState(self.hold)
  end
end

function SpearStab:hold()
  self.weapon:setStance(self.stances.hold)
  self.weapon:updateAim()

  while self.fireMode == "primary" do
    local damageArea = partDamageArea("blade")
    self.weapon:setDamage(self.holdDamageConfig, damageArea)
    coroutine.yield()
  end

  self.cooldownTimer = self:cooldownTime()
end
