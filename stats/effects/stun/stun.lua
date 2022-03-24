require "/scripts/lpl_load_plugins.lua"
local PLUGINS_PATH =
  "/stats/effects/stun/stun_plugins.config"

function init()
  effect.setParentDirectives("fade=7733AA=0.25")
  effect.addStatModifierGroup({
    {stat = "jumpModifier", amount = -0.3}
  })
end
init = PluginLoader.add_plugin_loader("stun", PLUGINS_PATH, init)

function update(dt)
  mcontroller.controlModifiers({
      groundMovementModifier = 0.5,
      speedModifier = 0.5,
      airJumpModifier = 0.7
    })
end

function uninit()

end
