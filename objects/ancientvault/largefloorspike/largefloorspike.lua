require "/scripts/lpl_load_plugins.lua"
local PLUGINS_PATH =
  "/objects/ancientvault/largefloorspike/largefloorspike_plugins.config"

function init()
  self.extendTime = config.getParameter("extendTime", 0.25)
  self.damageSource = config.getParameter("spikeDamage")
  object.setDamageSources({})

  message.setHandler("trigger", function()
      if animator.animationState("spike") == "retracted" then
        extend()
      end
    end)
end
init = PluginLoader.add_plugin_loader("largefloorspike", PLUGINS_PATH, init)

function extend()
  animator.setAnimationState("spike", "extend")
  object.setDamageSources({self.damageSource})
  self.extendTimer = self.extendTime
end

function retract()
  animator.setAnimationState("spike", "retract")
  object.setDamageSources({})
end

function update(dt)
  if self.extendTimer then
    self.extendTimer = math.max(0, self.extendTimer - dt)
    if self.extendTimer <= 0 then
      retract()
      self.extendTimer = nil
    end
    if animator.animationState("spike") ~= "extend" then
      object.setDamageSources({})
    end
  end
end
