require "/scripts/lpl_load_plugins.lua"
local PLUGINS_PATH =
  "/objects/hylotl/hylotlredalert/hylotlredalert_plugins.config"

function init()
  self.alarmSoundTimer = 0
  self.alarmSoundDuration = config.getParameter("alarmSoundDuration")

  self.lightColor = config.getParameter("lightColor", {0, 187, 255})
end
init = PluginLoader.add_plugin_loader("hylotlredalert", PLUGINS_PATH, init)

function update(dt)
  if object.getInputNodeLevel(0) then
    animator.setAnimationState("alarmState", "on")

    local lightWave = math.sin((self.alarmSoundTimer / self.alarmSoundDuration) * math.pi) * 0.5 + 0.5
    object.setLightColor({lightWave * self.lightColor[1], lightWave * self.lightColor[2], lightWave * self.lightColor[3]})

    if self.alarmSoundTimer <= 0 then
      animator.playSound("alarm")
      self.alarmSoundTimer = self.alarmSoundDuration
    else
      self.alarmSoundTimer = self.alarmSoundTimer - dt
    end
  else
    self.alarmSoundTimer = 0
    animator.setAnimationState("alarmState", "off")
    object.setLightColor({0, 0, 0, 0})
  end
end
