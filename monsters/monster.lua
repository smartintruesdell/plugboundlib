require "/scripts/behavior.lua"
require "/scripts/pathing.lua"
require "/scripts/util.lua"
require "/scripts/vec2.lua"
require "/scripts/poly.lua"
require "/scripts/drops.lua"
require "/scripts/status.lua"
require "/scripts/companions/capturable.lua"
require "/scripts/tenant.lua"
require "/scripts/actions/movement.lua"
require "/scripts/actions/animator.lua"

require "/scripts/lpl_load_plugins.lua"
local PLUGINS_PATH = "/monsters/monster_plugins.config"

-- Engine callback - called on initialization of entity
function init()
  -- PLUGIN LOADER ------------------------------------------------------------
  PluginLoader.load(PLUGINS_PATH)
  if plugin_init ~= nil then
    plugin_init()
  end
  -- END PLUGIN LOADER --------------------------------------------------------

  init_behavior()
  init_handlers()
  init_ControlMap()
  init_effects_death()
  init_effects_elite()
  init_effects_damageBar()
  init_interactive()
  init_chains_animation()
end

-- from init(), refactored to improve plugin support
function init_behavior()
  self.pathing = {}

  self.shouldDie = true
  self.notifications = {}
  storage.spawnTime = world.time()
  if storage.spawnPosition == nil or config.getParameter("wasRelocated", false) then
    local position = mcontroller.position()
    local groundSpawnPosition
    if mcontroller.baseParameters().gravityEnabled then
      groundSpawnPosition = findGroundPosition(position, -20, 3)
    end
    storage.spawnPosition = groundSpawnPosition or position
  end

  self.behavior = behavior.behavior(
    config.getParameter("behavior"),
    sb.jsonMerge(
      config.getParameter("behaviorConfig", {}),
      skillBehaviorConfig()
    ),
    _ENV
  )
  self.board = self.behavior:blackboard()
  self.board:setPosition("spawn", storage.spawnPosition)

  self.collisionPoly = mcontroller.collisionPoly()

  script.setUpdateDelta(config.getParameter("initialScriptDelta", 5))
  mcontroller.setAutoClearControls(false)
  self.behaviorTickRate = config.getParameter("behaviorUpdateDelta", 2)
  self.behaviorTick = math.random(1, self.behaviorTickRate)

  animator.setGlobalTag("flipX", "")
  self.board:setNumber("facingDirection", mcontroller.facingDirection())

  capturable.init()

  local deathBehavior = config.getParameter("deathBehavior")
  if deathBehavior then
    self.deathBehavior = behavior.behavior(deathBehavior, config.getParameter("behaviorConfig", {}), _ENV, self.behavior:blackboard())
  end
end

-- from init(), refactored to improve plugin support
function init_handlers()
  -- Listen to damage taken
  self.damageTaken = damageListener("damageTaken", function(notifications)
    for _,notification in pairs(notifications) do
      if notification.healthLost > 0 then
        self.damaged = true
        self.board:setEntity("damageSource", notification.sourceEntityId)
      end
    end
  end)

  self.debug = true

  message.setHandler(
    "notify",
    function(_,_,notification)
      return notify(notification)
    end
  )
  message.setHandler(
    "despawn",
    function()
      monster.setDropPool(nil)
      monster.setDeathParticleBurst(nil)
      monster.setDeathSound(nil)
      self.deathBehavior = nil
      self.shouldDie = true
      status.addEphemeralEffect("monsterdespawn")
    end
  )
end

-- from init(), refactored to improve plugin support
function init_ControlMap()
  self.forceRegions = ControlMap:new(config.getParameter("forceRegions", {}))
  self.damageSources = ControlMap:new(config.getParameter("damageSources", {}))
  self.touchDamageEnabled = false
end

-- from init(), refactored to improve plugin support
function init_effects_death()
  if animator.hasSound("deathPuff") then
    monster.setDeathSound("deathPuff")
  end
  if config.getParameter("deathParticles") then
    monster.setDeathParticleBurst(config.getParameter("deathParticles"))
  end
end

-- from init(), refactored to improve plugin support
function init_effects_elite()
  if config.getParameter("elite", false) then
    status.setPersistentEffects("elite", {"elitemonster"})
  end
end
function init_effects_damageBar()
  if config.getParameter("damageBar") then
    monster.setDamageBar(config.getParameter("damageBar"));
  end
end

-- from init(), refactored to improve plugin support
function init_interactive()
  monster.setInteractive(config.getParameter("interactive", false))
end

-- from init(), refactored to improve plugin support
function init_chains_animation()
  monster.setAnimationParameter("chains", config.getParameter("chains"))
end

function update(dt)
  capturable.update(dt)
  self.damageTaken:update(dt)

  if update_handle_stunned(dt) then return end
  update_handle_suppress_touch_damage(dt)

  update_do_behavior_tick(dt)
  update_facing(dt)
end

function update_handle_stunned()
  if status.resourcePositive("stunned") then
    animator.setAnimationState("damage", "stunned")
    animator.setGlobalTag("hurt", "hurt")
    self.stunned = true
    mcontroller.clearControls()
    if self.damaged then
      self.suppressDamageTimer = config.getParameter("stunDamageSuppression", 0.5)
      monster.setDamageOnTouch(false)
    end
    return true
  else
    animator.setGlobalTag("hurt", "")
    animator.setAnimationState("damage", "none")
    return false
  end
end

function update_handle_suppress_touch_damage(dt)
  -- Suppressing touch damage
  if self.suppressDamageTimer then
    monster.setDamageOnTouch(false)
    self.suppressDamageTimer = math.max(self.suppressDamageTimer - dt, 0)
    if self.suppressDamageTimer == 0 then
      self.suppressDamageTimer = nil
    end
  elseif status.statPositive("invulnerable") then
    monster.setDamageOnTouch(false)
  else
    monster.setDamageOnTouch(self.touchDamageEnabled)
  end
end

function update_do_behavior_tick(dt)
  if self.behaviorTick >= self.behaviorTickRate then
    self.behaviorTick = self.behaviorTick - self.behaviorTickRate
    mcontroller.clearControls()

    self.tradingEnabled = false
    self.setFacingDirection = false
    self.moving = false
    self.rotated = false
    self.forceRegions:clear()
    self.damageSources:clear()
    self.damageParts = {}
    clearAnimation()

    if self.behavior then
      local board = self.behavior:blackboard()
      board:setEntity("self", entity.id())
      board:setPosition("self", mcontroller.position())
      board:setNumber("dt", dt * self.behaviorTickRate)
      board:setNumber("facingDirection", self.facingDirection or mcontroller.facingDirection())

      self.behavior:run(dt * self.behaviorTickRate)
    end
    BGroup:updateGroups()

    updateAnimation()

    if not self.rotated and self.rotation then
      mcontroller.setRotation(0)
      animator.resetTransformationGroup(self.rotationGroup)
      self.rotation = nil
      self.rotationGroup = nil
    end

    self.interacted = false
    self.damaged = false
    self.stunned = false
    self.notifications = {}

    setDamageSources()
    setPhysicsForces()
    monster.setDamageParts(self.damageParts)
    overrideCollisionPoly()
  end
  self.behaviorTick = self.behaviorTick + 1
end

function update_facing()
  if config.getParameter("facingMode", "control") == "transformation" then
    mcontroller.controlFace(1)
  end
end

function skillBehaviorConfig()
  local skills = config.getParameter("skills", {})
  local skillConfig = {}

  for _,skillName in pairs(skills) do
    local skillHostileActions = root.monsterSkillParameter(skillName, "hostileActions")
    if skillHostileActions then
      construct(skillConfig, "hostileActions")
      util.appendLists(skillConfig.hostileActions, skillHostileActions)
    end
  end

  return skillConfig
end

function interact(args)
  self.interacted = true
  self.board:setEntity("interactionSource", args.sourceId)
end

function shouldDie()
  return (self.shouldDie and status.resource("health") <= 0) or capturable.justCaptured
end

function die()
  if not capturable.justCaptured then
    if self.deathBehavior then
      self.deathBehavior:run(script.updateDt())
    end
    capturable.die()
  end
  spawnDrops()
end

function uninit()
  BGroup:uninit()
end

function setDamageSources()
  monster.setDamageSources(
    util.map(
      util.mergeLists(
        setDamageSources_get_part_sources(),
        self.damageSources:values()
      ),
      setDamageSources_build_damage_source
    )
  )
end

function setDamageSources_get_part_sources()
  local partSources = {}
  for part,ds in pairs(config.getParameter("damageParts", {})) do
    local damageArea = animator.partPoly(part, "damageArea")
    if damageArea then
      ds.poly = damageArea
      table.insert(partSources, ds)
    end
  end

  return partSources
end

function setDamageSources_build_damage_source(ds)
  ds.damage =
    ds.damage * root.evalFunction(
      "monsterLevelPowerMultiplier",
      monster.level()
    ) * status.stat("powerMultiplier")

  if ds.knockback and type(ds.knockback) == "table" then
    ds.knockback[1] = ds.knockback[1] * mcontroller.facingDirection()
  end

  local team = entity.damageTeam()
  ds.team = {
    type = ds.damageTeamType or team.type,
    team = ds.damageTeam or team.team
  }

  return ds
end

function setPhysicsForces()
  local regions = util.map(self.forceRegions:values(), function(region)
    if region.type == "RadialForceRegion" then
      region.center = vec2.add(mcontroller.position(), region.center)
    elseif region.type == "DirectionalForceRegion" then
      if region.rectRegion then
        region.rectRegion = rect.translate(region.rectRegion, mcontroller.position())
        util.debugRect(region.rectRegion, "blue")
      elseif region.polyRegion then
        region.polyRegion = poly.translate(region.polyRegion, mcontroller.position())
      end
    end

    return region
  end)

  monster.setPhysicsForces(regions)
end

function overrideCollisionPoly()
  local collisionParts = config.getParameter("collisionParts", {})

  for _,part in pairs(collisionParts) do
    local collisionPoly = animator.partPoly(part, "collisionPoly")
    if collisionPoly then
      -- Animator flips the polygon by default
      -- to have it unflipped we need to flip it again
      if not config.getParameter("flipPartPoly", true) and mcontroller.facingDirection() < 0 then
        collisionPoly = poly.flip(collisionPoly)
      end
      mcontroller.controlParameters({collisionPoly = collisionPoly, standingPoly = collisionPoly, crouchingPoly = collisionPoly})
      break
    end
  end
end

function setupTenant(...)
  require("/scripts/tenant.lua")
  tenant.setHome(...)
end