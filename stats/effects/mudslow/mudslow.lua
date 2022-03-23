require "/scripts/lpl_load_plugins.lua"
local PLUGINS_PATH =
  "/stats/effects/mudslow/mudslow_plugins.config"

function init()
  animator.setParticleEmitterOffsetRegion("drips", mcontroller.boundBox())
  animator.setParticleEmitterActive("drips", true)
  effect.setParentDirectives("fade=505000=0.6")
  effect.addStatModifierGroup({
    {stat = "jumpModifier", amount = -0.15}
  })
end
init = PluginLoader.add_plugin_loader("mudslow", PLUGINS_PATH, init)

function update(dt)
  mcontroller.controlModifiers({
      speedModifier = 0.8,
      airJumpModifier = 0.85
    })
end

function uninit()

end
