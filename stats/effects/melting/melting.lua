require "/scripts/lpl_load_plugins.lua"
local PLUGINS_PATH =
  "/stats/effects/melting/melting_plugins.config"

function init()
  animator.setParticleEmitterOffsetRegion("flames", mcontroller.boundBox())
  animator.setParticleEmitterActive("flames", true)
  effect.setParentDirectives("fade=FF8800=0.2")

  script.setUpdateDelta(5)

  self.tickTime = 1.0
  self.tickTimer = self.tickTime
  self.damage = 30

  status.applySelfDamageRequest({
      damageType = "IgnoresDef",
      damage = 30,
      damageSourceKind = "fire",
      sourceEntityId = entity.id()
    })
end
init = PluginLoader.add_plugin_loader("melting", PLUGINS_PATH, init)

function update(dt)
  self.tickTimer = self.tickTimer - dt
  if self.tickTimer <= 0 then
    self.tickTimer = self.tickTime
    self.damage = self.damage * 2
    status.applySelfDamageRequest({
        damageType = "IgnoresDef",
        damage = self.damage,
        damageSourceKind = "fire",
        sourceEntityId = entity.id()
      })
  end
end

function onExpire()
  status.addEphemeralEffect("burning")
end
