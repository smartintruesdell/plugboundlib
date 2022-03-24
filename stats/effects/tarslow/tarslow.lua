require "/scripts/lpl_load_plugins.lua"
local PLUGINS_PATH =
  "/stats/effects/tarslow/tarslow_plugins.config"

function init()
  animator.setParticleEmitterOffsetRegion("drips", mcontroller.boundBox())
  animator.setParticleEmitterActive("drips", true)
  effect.setParentDirectives("fade=300030=0.8")
  effect.addStatModifierGroup({
    {stat = "jumpModifier", amount = -0.20}
  })
end
init = PluginLoader.add_plugin_loader("tarslow", PLUGINS_PATH, init)

function update(dt)
  mcontroller.controlModifiers({
      groundMovementModifier = 0.5,
      speedModifier = 0.65,
      airJumpModifier = 0.80
    })
end

function uninit()

end
