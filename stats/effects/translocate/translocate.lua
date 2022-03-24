require "/scripts/lpl_load_plugins.lua"
local PLUGINS_PATH =
  "/stats/effects/translocate/translocate_plugins.config"

function init()
  animator.setAnimationState("blink", "blinkout")
  effect.setParentDirectives("?multiply=ffffff00")
  animator.playSound("activate")
  effect.addStatModifierGroup({{stat = "activeMovementAbilities", amount = 1}})
end
init = PluginLoader.add_plugin_loader("translocate", PLUGINS_PATH, init)

function update(dt)
  if animator.animationState("blink") == "none" then
    teleport()
  end
end

function teleport()
  local discId = status.statusProperty("translocatorDiscId")
  if discId and world.entityExists(discId) then
    local teleportTarget = world.callScriptedEntity(discId, "teleportPosition", mcontroller.collisionPoly())
    if teleportTarget then
      mcontroller.setPosition(teleportTarget)
    end
    world.callScriptedEntity(status.statusProperty("translocatorDiscId"), "kill")
  end
  status.setStatusProperty("translocatorDiscId", nil)

  effect.setParentDirectives("")
  animator.burstParticleEmitter("translocate")
  animator.setAnimationState("blink", "blinkin")
end

function uninit()

end
