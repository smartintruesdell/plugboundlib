require "/scripts/lpl_load_plugins.lua"
local PLUGINS_PATH =
  "/stats/effects/food/starving/starving_plugins.config"

function init()
  world.sendEntityMessage(entity.id(), "queueRadioMessage", "starving")

  self.soundInterval = config.getParameter("soundInterval")
  self.soundTimer = 0

  self.tickTime = 1.0
  self.tickTimer = self.tickTime
  self.timer = 0
  self.compoundDamage = config.getParameter("starvationCompoundDamage", 1)
  self.movementModifiers = config.getParameter("movementModifiers", {})
end
init = PluginLoader.add_plugin_loader("starving", PLUGINS_PATH, init)

function update(dt)
  self.soundTimer = math.max(0, self.soundTimer - dt)
  if self.soundTimer == 0 then
    animator.playSound("beep")
    self.soundTimer = self.soundInterval
  end

  self.timer = self.timer + dt
  local tickDamage = self.compoundDamage * self.timer * dt
  status.modifyResource("health", -tickDamage)
  mcontroller.controlModifiers(self.movementModifiers)
end

function uninit()

end
