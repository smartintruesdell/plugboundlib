require "/scripts/util.lua"
require "/scripts/lpl_load_plugins.lua"
local PLUGINS_PATH =
  "/projectiles/boss/spiderboss/ixolingspawn_plugins.config"

function init()
  self.timer = math.random(10, 30)
end
init = PluginLoader.add_plugin_loader("ixolingspawn", PLUGINS_PATH, init)

function update(dt)
  local bossHealth = world.entityHealth(projectile.sourceEntity())
  if bossHealth and bossHealth[1] > 0 and bossHealth[1] < bossHealth[2] then
    self.timer = math.max(0, self.timer - dt)
    projectile.setTimeToLive(1.0)
    if self.timer == 0 then
      world.spawnMonster("ixoling", mcontroller.position(), { level = config.getParameter("level", 1.0), aggressive = true } )
      projectile.die()
    end
  else
    projectile.die()
  end
end
