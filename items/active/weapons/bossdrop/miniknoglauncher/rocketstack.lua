require "/scripts/util.lua"
require "/scripts/interp.lua"

require "/scripts/lpl_load_plugins.lua"
local PLUGINS_PATH = "/stats/_plugins.config"


RocketStack = WeaponAbility:new()

-- Module initialization ------------------------------------------------------

function RocketStack:init()

  self.weapon:setStance(self.stances.idle)

  self.reloadTimer = self.reloadTime

  self.currentStack = 0

  self.weapon.onLeaveAbility = function()
    self.weapon:setStance(self.stances.idle)
  end
end

RocketStack.init =
  PluginLoader.add_plugin_loader("rocketstack", PLUGINS_PATH, RocketStack.init)

function RocketStack:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)

  self.reloadTimer = math.max(0, self.reloadTimer - self.dt)

  if self.fireMode == (self.activatingFireMode or self.abilitySlot)
    and self.reloadTimer == 0
    and not self.weapon.currentAbility
    and not world.lineTileCollision(mcontroller.position(), self:firePosition())
    and not status.resourceLocked("energy") then

    self:setState(self.charge)
  end
end

function RocketStack:charge()
  self.weapon:setStance(self.stances.charge)

  while self.fireMode == (self.activatingFireMode or self.abilitySlot) do
    if self.reloadTimer == 0
        and self.currentStack < self.maxStack
        and status.overConsumeResource("energy", self.energyPerShot) then

      self.currentStack = self.currentStack + 1
      self:reload()
    end

    status.setResourcePercentage("energyRegenBlock", 1.0)

    coroutine.yield()
  end

  self:setState(self.fire)
end

function RocketStack:reload()
  self.reloadTimer = self.reloadTime
  animator.setAnimationState("gun", "reload")
  animator.playSound("reload")
end

function RocketStack:fire()
  if world.lineTileCollision(mcontroller.position(), self:firePosition()) then
    self:setState(self.cooldown)
    return
  end

  self.weapon:setStance(self.stances.fire)

  animator.playSound("fire")

  self:fireProjectiles()
  self.currentStack = 0
  self:reload()

  if self.stances.fire.duration then
    util.wait(self.stances.fire.duration)
  end

  self:setState(self.cooldown)
end

function RocketStack:cooldown()
  self.weapon:setStance(self.stances.cooldown)
  self.weapon:updateAim()

  local progress = 0
  util.wait(self.stances.cooldown.duration, function()
    local from = self.stances.cooldown.weaponOffset or {0,0}
    local to = self.stances.idle.weaponOffset or {0,0}
    self.weapon.weaponOffset = {interp.linear(progress, from[1], to[1]), interp.linear(progress, from[2], to[2])}

    self.weapon.relativeWeaponRotation = util.toRadians(interp.linear(progress, self.stances.cooldown.weaponRotation, self.stances.idle.weaponRotation))
    self.weapon.relativeArmRotation = util.toRadians(interp.linear(progress, self.stances.cooldown.armRotation, self.stances.idle.armRotation))

    progress = math.min(1.0, progress + (self.dt / self.stances.cooldown.duration))
  end)
end

function RocketStack:fireProjectiles()
  local params = copy(self.projectileParameters)
  params.power = self.baseDamage * config.getParameter("damageLevelMultiplier")
  params.powerMultiplier = activeItem.ownerPowerMultiplier()

  local totalSpread = self.spread * (self.currentStack - 1)
  local currentAngle = totalSpread * -0.5
  for i = 1, self.currentStack do
    projectileId = world.spawnProjectile(
        self.projectileType,
        self:firePosition(),
        activeItem.ownerEntityId(),
        self:aimVector(currentAngle),
        false,
        params
      )
    currentAngle = currentAngle + self.spread
  end
end

function RocketStack:firePosition()
  return vec2.add(mcontroller.position(), activeItem.handPosition(self.weapon.muzzleOffset))
end

function RocketStack:aimVector(angleAdjust)
  local aimVector = vec2.rotate({1, 0}, self.weapon.aimAngle + angleAdjust + sb.nrand(self.inaccuracy, 0))
  aimVector[1] = aimVector[1] * self.weapon.aimDirection
  return aimVector
end

function RocketStack:uninit()

end
