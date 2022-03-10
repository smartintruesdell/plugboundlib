require "/scripts/vec2.lua"
require "/scripts/util.lua"
require "/scripts/lpl_load_plugins.lua"
local PLUGINS_PATH =
  "/vehicles/modularmech/modularmech_plugins.config"

function init()
  message.setHandler("despawnMech", despawn)

  message.setHandler("currentEnergy", function()
      if not alive() then
        return 0
      end

      return storage.energy / self.energyMax
    end)

  message.setHandler("restoreEnergy", function(_, _, base, percentage)
      if alive() then
        local restoreAmount = (base or 0) + self.energyMax * (percentage or 0)
        storage.energy = math.min(storage.energy + restoreAmount, self.energyMax)
        animator.playSound("restoreEnergy")
      end
    end)

  self.ownerUuid = config.getParameter("ownerUuid")
  self.ownerEntityId = config.getParameter("ownerEntityId")

  -- initialize configuration parameters

  self.movementSettings = config.getParameter("movementSettings")
  self.walkingMovementSettings = config.getParameter("walkingMovementSettings")
  self.flyingMovementSettings = config.getParameter("flyingMovementSettings")

  -- common (not from parts) config

  self.damageFlashTimer = 0
  self.damageFlashTime = config.getParameter("damageFlashTime")
  self.damageFlashDirectives = config.getParameter("damageFlashDirectives")

  self.jumpBoostTimer = 0

  self.fallThroughTimer = 0
  self.fallThroughTime = config.getParameter("fallThroughTime")
  self.fallThroughSustain = false

  self.onGroundTimer = 0
  self.onGroundTime = config.getParameter("onGroundTime")

  self.frontFoot = config.getParameter("frontFootOffset")
  self.backFoot = config.getParameter("backFootOffset")
  self.footCheckXOffsets = config.getParameter("footCheckXOffsets")

  self.legRadius = config.getParameter("legRadius")
  self.legVerticalRatio = config.getParameter("legVerticalRatio")
  self.legCycle = 0.25
  self.reachGroundDistance = config.getParameter("reachGroundDistance")

  self.flightLegOffset = config.getParameter("flightLegOffset")

  self.stepSoundLimitTime = config.getParameter("stepSoundLimitTime")
  self.stepSoundLimitTimer = 0

  self.walkBobMagnitude = config.getParameter("walkBobMagnitude")

  self.landingBobMagnitude = config.getParameter("landingBobMagnitude")
  self.landingBobTime = config.getParameter("landingBobTime")
  self.landingBobTimer = 0
  self.landingBobThreshold = config.getParameter("landingBobThreshold")

  self.boosterBobDelay = config.getParameter("boosterBobDelay")
  self.armBobDelay = config.getParameter("armBobDelay")

  self.armFlipOffset = config.getParameter("armFlipOffset")

  self.flightOffsetFactor = config.getParameter("flightOffsetFactor")
  self.flightOffsetClamp = config.getParameter("flightOffsetClamp")
  self.currentFlightOffset = {0, 0}

  self.boostDirection = {0, 0}

  self.despawnTime = config.getParameter("despawnTime")
  self.explodeTime = config.getParameter("explodeTime")
  self.explodeProjectile = config.getParameter("explodeProjectile")

  self.materialKind = "robotic"

  -- set part image tags

  self.partImages = config.getParameter("partImages")

  for k, v in pairs(self.partImages) do
    animator.setPartTag(k, "partImage", v)
  end

  -- set part directives

  self.partDirectives = config.getParameter("partDirectives")

  for k, v in pairs(self.partDirectives) do
    animator.setGlobalTag(k .. "Directives", v)
  end

  -- setup part functional config

  self.parts = config.getParameter("parts")

  -- setup body

  self.protection = self.parts.body.protection

  -- setup boosters

  self.airControlSpeed = self.parts.booster.airControlSpeed
  self.airControlForce = self.parts.booster.airControlForce
  self.flightControlSpeed = self.parts.booster.flightControlSpeed
  self.flightControlForce = self.parts.booster.flightControlForce

  -- setup legs

  self.groundSpeed = self.parts.legs.groundSpeed
  self.groundControlForce = self.parts.legs.groundControlForce
  self.jumpVelocity = self.parts.legs.jumpVelocity
  self.jumpAirControlSpeed = self.parts.legs.jumpAirControlSpeed
  self.jumpAirControlForce = self.parts.legs.jumpAirControlForce
  self.jumpBoostTime = self.parts.legs.jumpBoostTime

  -- setup arms

  require(self.parts.leftArm.script)
  self.leftArm = _ENV[self.parts.leftArm.armClass]:new(self.parts.leftArm, "leftArm", {2.375, 0}, self.ownerUuid)

  require(self.parts.rightArm.script)
  self.rightArm = _ENV[self.parts.rightArm.armClass]:new(self.parts.rightArm, "rightArm", {-2.375, 0}, self.ownerUuid)

  -- setup energy pool

  self.energyMax = self.parts.body.energyMax
  storage.energy = storage.energy or (config.getParameter("startEnergyRatio", 1.0) * self.energyMax)

  self.energyDrain = self.parts.body.energyDrain + (self.parts.leftArm.energyDrain or 0) + (self.parts.rightArm.energyDrain or 0)

  -- check for environmental hazards / protection

  local hazards = config.getParameter("hazardVulnerabilities")
  for _, statusEffect in pairs(self.parts.body.hazardImmunities or {}) do
    hazards[statusEffect] = nil
  end

  local applyEnvironmentStatuses = config.getParameter("applyEnvironmentStatuses")
  local seatStatusEffects = config.getParameter("loungePositions.seat.statusEffects")

  for _, statusEffect in pairs(world.environmentStatusEffects(mcontroller.position())) do
    if hazards[statusEffect] then
      self.energyDrain = self.energyDrain + hazards[statusEffect].energyDrain
      world.sendEntityMessage(self.ownerEntityId, "queueRadioMessage", hazards[statusEffect].message, 1.5)
    end

    for _, applyEffect in ipairs(applyEnvironmentStatuses) do
      if statusEffect == applyEffect then
        table.insert(seatStatusEffects, statusEffect)
      end
    end
  end

  vehicle.setLoungeStatusEffects("seat", seatStatusEffects)

  self.liquidVulnerabilities = config.getParameter("liquidVulnerabilities")

  -- initialize persistent and last frame state data

  self.facingDirection = 1

  self.lastWalking = false

  self.lastPosition = mcontroller.position()
  self.lastVelocity = mcontroller.velocity()
  self.lastOnGround = mcontroller.onGround()

  self.lastControls = {
    left = false,
    right = false,
    up = false,
    down = false,
    jump = false,
    PrimaryFire = false,
    AltFire = false,
    Special1 = false
  }

  setFlightMode(world.gravity(mcontroller.position()) == 0)

  message.setHandler("deploy", function()
    self.deploy = config.getParameter("deploy")
    self.deploy.fadeTime = self.deploy.fadeInTime + self.deploy.fadeOutTime

    self.deploy.fadeTimer = self.deploy.fadeTime
    self.deploy.deployTimer = self.deploy.deployTime
    mcontroller.setVelocity({0, self.deploy.initialVelocity})
  end)
end
init = PluginLoader.add_plugin_loader("modularmech", PLUGINS_PATH, init)

function update(dt)
  -- despawn if owner has left the world
  if not self.ownerEntityId or world.entityType(self.ownerEntityId) ~= "player" then
    despawn()
  end

  if self.explodeTimer then
    self.explodeTimer = math.max(0, self.explodeTimer - dt)
    if self.explodeTimer == 0 then
      local params = {
        referenceVelocity = mcontroller.velocity(),
        damageTeam = {
          type = "enemy",
          team = 9001
        }
      }
      world.spawnProjectile(self.explodeProjectile, mcontroller.position(), nil, nil, false, params)
      animator.playSound("explode")
      vehicle.destroy()
    else
      local fade = 1 - (self.explodeTimer / self.explodeTime)
      animator.setGlobalTag("directives", string.format("?fade=FCC93C;%.1f", fade))
    end
    return
  elseif self.despawnTimer then
    self.despawnTimer = math.max(0, self.despawnTimer - dt)
    if self.despawnTimer == 0 then
      vehicle.destroy()
    else
      local multiply, fade, light
      if self.despawnTimer > 0.5 * self.despawnTime then
        fade = 1.0 - (self.despawnTimer - 0.5 * self.despawnTime) / (0.5 * self.despawnTime)
        light = fade
        multiply = 255
      else
        fade = 1.0
        light = self.despawnTimer / (0.5 * self.despawnTime)
        multiply = math.floor(255 * light)
      end
      animator.setGlobalTag("directives", string.format("?multiply=ffffff%02x?fade=ffffff;%.1f", multiply, fade))
      animator.setLightActive("deployLight", true)
      animator.setLightColor("deployLight", {light, light, light})
    end
    return
  end

  setFlightMode(world.gravity(mcontroller.position()) == 0)

  -- update positions and movement

  self.boostDirection = {0, 0}

  local newPosition = mcontroller.position()
  local newVelocity = mcontroller.velocity()

  -- decrement timers

  self.stepSoundLimitTimer = math.max(0, self.stepSoundLimitTimer - dt)
  self.landingBobTimer = math.max(0, self.landingBobTimer - dt)
  self.jumpBoostTimer = math.max(0, self.jumpBoostTimer - dt)
  self.fallThroughTimer = math.max(0, self.fallThroughTimer - dt)
  self.onGroundTimer = math.max(0, self.onGroundTimer - dt)

  -- track onGround status
  if mcontroller.onGround() then
    self.onGroundTimer = self.onGroundTime
  end
  local onGround = self.onGroundTimer > 0

  -- hit ground

  if onGround and not self.lastOnGround and newVelocity[2] - self.lastVelocity[2] > self.landingBobThreshold then
    self.landingBobTimer = self.landingBobTime
    triggerStepSound()
  end

  -- update driver

  local driverId = vehicle.entityLoungingIn("seat")
  if driverId and not self.driverId then
    animator.setAnimationState("power", "activate")
  elseif self.driverId and not driverId then
    animator.setAnimationState("power", "deactivate")
  end
  self.driverId = driverId

  -- read controls or do deployment

  local newControls = {}
  local oldControls = self.lastControls

  if self.deploy then
    self.deploy.fadeTimer = math.max(0.0, self.deploy.fadeTimer - dt)
    self.deploy.deployTimer = math.max(0.0, self.deploy.deployTimer - dt)

    -- visual fade in
    local multiply = math.floor(math.min(1.0, (self.deploy.fadeTime - self.deploy.fadeTimer) / self.deploy.fadeInTime) * 255)
    local fade = math.min(1.0, self.deploy.fadeTimer / self.deploy.fadeOutTime)
    animator.setGlobalTag("directives", string.format("?multiply=ffffff%02x?fade=ffffff;%.1f", multiply, fade))
    animator.setLightActive("deployLight", true)
    animator.setLightColor("deployLight", {fade, fade, fade})

    -- boost to a stop
    if self.deploy.deployTimer < self.deploy.boostTime then
      mcontroller.approachYVelocity(0, math.abs(self.deploy.initialVelocity) / self.deploy.boostTime * mcontroller.parameters().mass)
      boost({0, util.toDirection(-self.deploy.initialVelocity)})
    end

    if self.deploy.deployTimer == 0.0 then
      self.deploy = nil
      animator.setLightActive("deployLight", false)
    end
  else
    self.damageFlashTimer = math.max(0, self.damageFlashTimer - dt)
    if self.damageFlashTimer == 0 then
      animator.setGlobalTag("directives", "")
    end

    local walking = false
    if self.driverId then
      for k, _ in pairs(self.lastControls) do
        newControls[k] = vehicle.controlHeld("seat", k)
      end

      self.aimPosition = vehicle.aimPosition("seat")

      if newControls.Special1 and not self.lastControls.Special1 then
        animator.playSound("horn")
      end

      if self.flightMode then
        if newControls.jump then
          local vel = mcontroller.velocity()
          if vel[1] ~= 0 or vel[2] ~= 0 then
            mcontroller.approachVelocity({0, 0}, self.flightControlForce)
            boost(vec2.mul(vel, -1))
          end
        else
          if newControls.right then
            mcontroller.approachXVelocity(self.flightControlSpeed, self.flightControlForce)
            boost({1, 0})
          end

          if newControls.left then
            mcontroller.approachXVelocity(-self.flightControlSpeed, self.flightControlForce)
            boost({-1, 0})
          end

          if newControls.up then
            mcontroller.approachYVelocity(self.flightControlSpeed, self.flightControlForce)
            boost({0, 1})
          end

          if newControls.down then
            mcontroller.approachYVelocity(-self.flightControlSpeed, self.flightControlForce)
            boost({0, -1})
          end
        end
      else
        if not newControls.jump then
          self.fallThroughSustain = false
        end

        if onGround then
          if newControls.right and not newControls.left then
            mcontroller.approachXVelocity(self.groundSpeed, self.groundControlForce)
            walking = true
          end

          if newControls.left and not newControls.right then
            mcontroller.approachXVelocity(-self.groundSpeed, self.groundControlForce)
            walking = true
          end

          if newControls.jump and self.jumpBoostTimer > 0 then
            mcontroller.setYVelocity(self.jumpVelocity)
          elseif newControls.jump and not self.lastControls.jump then
            if newControls.down then
              self.fallThroughTimer = self.fallThroughTime
              self.fallThroughSustain = true
            else
              jump()
            end
          else
            self.jumpBoostTimer = 0
          end
        else
          local controlSpeed = self.jumpBoostTimer > 0 and self.jumpAirControlSpeed or self.airControlSpeed
          local controlForce = self.jumpBoostTimer > 0 and self.jumpAirControlForce or self.airControlForce

          if newControls.right then
            mcontroller.approachXVelocity(controlSpeed, controlForce)
            boost({1, 0})
          end

          if newControls.left then
            mcontroller.approachXVelocity(-controlSpeed, controlForce)
            boost({-1, 0})
          end

          if newControls.jump then
            if self.jumpBoostTimer > 0 then
              mcontroller.setYVelocity(self.jumpVelocity)
            end
          else
            self.jumpBoostTimer = 0
          end
        end
      end

      self.facingDirection = world.distance(self.aimPosition, mcontroller.position())[1] > 0 and 1 or -1

      self.lastControls = newControls
    else
      for k, _ in pairs(self.lastControls) do
        self.lastControls[k] = false
      end

      newControls = self.lastControls
      oldControls = self.lastControls

      self.aimPosition = nil
    end
  end

  -- update damage team (don't take damage without a driver)
  -- also anything else that depends on a driver's presence

  if self.driverId then
    vehicle.setDamageTeam(world.entityDamageTeam(self.driverId))
    vehicle.setInteractive(false)
    vehicle.setForceRegionEnabled("itemMagnet", true)
    vehicle.setDamageSourceEnabled("bumperGround", not self.flightMode)
    animator.setLightActive("activeLight", true)
  else
    vehicle.setDamageTeam({type = "ghostly"})
    vehicle.setInteractive(true)
    vehicle.setForceRegionEnabled("itemMagnet", false)
    vehicle.setDamageSourceEnabled("bumperGround", false)
    animator.setLightActive("activeLight", false)
    animator.setLightActive("boostLight", false)
  end

  -- decay and check energy

  if self.driverId then
    storage.energy = math.max(0, storage.energy - self.energyDrain * dt)
  end

  local inLiquid = world.liquidAt(mcontroller.position())
  if inLiquid then
    local liquidName = root.liquidName(inLiquid[1])
    if self.liquidVulnerabilities[liquidName] then
      storage.energy = math.max(0, storage.energy - self.liquidVulnerabilities[liquidName].energyDrain * dt)
      if storage.energy == 0 then
        explode()
        return
      end

      if not self.liquidVulnerabilities[liquidName].warned then
        world.sendEntityMessage(self.ownerEntityId, "queueRadioMessage", self.liquidVulnerabilities[liquidName].message)
        self.liquidVulnerabilities[liquidName].warned = true
      end
    end
  end

  if storage.energy == 0 then
    despawn()
    return
  end

  -- set appropriate movement parameters for walking/falling conditions

  if not self.flightMode then
    if walking ~= self.lastWalking then
      self.lastWalking = walking
      if self.lastWalking then
        mcontroller.applyParameters(self.walkingMovementSettings)
      else
        mcontroller.resetParameters(self.movementSettings)
      end
    end

    if self.fallThroughTimer > 0 or self.fallThroughSustain then
      mcontroller.applyParameters({ignorePlatformCollision = true})
    else
      mcontroller.applyParameters({ignorePlatformCollision = false})
    end
  end

  -- flip to match facing direction

  animator.setFlipped(self.facingDirection < 0)

  -- compute leg cycle

  if onGround then
    local newLegCycle = self.legCycle
    newLegCycle = self.legCycle + ((newPosition[1] - self.lastPosition[1]) * self.facingDirection) / (4 * self.legRadius)

    if math.floor(self.legCycle * 2) ~= math.floor(newLegCycle * 2) then
      triggerStepSound()
    end

    self.legCycle = newLegCycle
  end

  -- animate legs, leg joints, and hips

  if self.flightMode then
    -- legs stay locked in place for flight
  else
    local legs = {
      front = {},
      back = {}
    }
    local legCycleOffset = 0

    for _, legSide in pairs({"front", "back"}) do
      local leg = legs[legSide]

      leg.offset = legOffset(self.legCycle + legCycleOffset)
      legCycleOffset = legCycleOffset + 0.5

      leg.onGround = leg.offset[2] <= 0

      -- put foot down when stopped
      if not walking and math.abs(newVelocity[1]) < 0.5 then
        leg.offset[2] = 0
        leg.onGround = true
      end

      local footGroundOffset = findFootGroundOffset(leg.offset, self[legSide .. "Foot"])
      if footGroundOffset then
        leg.offset[2] = leg.offset[2] + footGroundOffset
      else
        leg.offset[2] = self.reachGroundDistance[2]
        leg.onGround = false
      end

      animator.setAnimationState(legSide .. "Foot", leg.onGround and "flat" or "tilt")
      animator.resetTransformationGroup(legSide .. "Leg")
      animator.translateTransformationGroup(legSide .. "Leg", leg.offset)
      animator.resetTransformationGroup(legSide .. "LegJoint")
      animator.translateTransformationGroup(legSide .. "LegJoint", {0.6 * leg.offset[1], 0.7 * leg.offset[2]})
    end

    if math.abs(newVelocity[1]) < 0.5 and math.abs(self.lastVelocity[1]) >= 0.5 then
      triggerStepSound()
    end

    animator.resetTransformationGroup("hips")
    local hipsOffset = math.max(-0.625, math.min(0, math.min(legs.front.offset[2] + 0.75, legs.back.offset[2] + 0.75)))
    animator.translateTransformationGroup("hips", {0, hipsOffset})
  end

  -- update and animate arms

  local chains = {}
  for _, arm in pairs({"left", "right"}) do
    local fireControl = (arm == "left") and "PrimaryFire" or "AltFire"

    animator.resetTransformationGroup(arm .. "Arm")
    animator.resetTransformationGroup(arm .. "ArmFlipper")

    self[arm .. "Arm"]:updateBase(dt, self.driverId, newControls[fireControl], oldControls[fireControl], self.aimPosition, self.facingDirection)
    self[arm .. "Arm"]:update(dt)

    if self[arm.."Arm"].renderChain then
      table.insert(chains, self[arm.."Arm"].chain)
    end

    if self.facingDirection < 0 then
      animator.translateTransformationGroup(arm .. "ArmFlipper", {(arm == "right") and self.armFlipOffset or -self.armFlipOffset, 0})
    end
  end
  vehicle.setAnimationParameter("chains", chains)

  -- animate boosters and boost flames

  animator.resetTransformationGroup("boosters")

  if self.jumpBoostTimer > 0 then
    boost({0, 1})
  end

  if self.boostDirection[1] == 0 and self.boostDirection[2] == 0 then
    animator.setAnimationState("boost", "idle")
    animator.setLightActive("boostLight", false)
  else
    local stateTag = "boost"
    if self.boostDirection[2] > 0 then
      stateTag = stateTag .. "N"
    elseif self.boostDirection[2] < 0 then
      stateTag = stateTag .. "S"
    end
    if self.boostDirection[1] * self.facingDirection > 0 then
      stateTag = stateTag .. "E"
    elseif self.boostDirection[1] * self.facingDirection < 0 then
      stateTag = stateTag .. "W"
    end
    animator.setAnimationState("boost", stateTag)
    animator.setLightActive("boostLight", true)
  end

  -- animate bobbing and landing

  animator.resetTransformationGroup("body")
  if self.flightMode then
    local newFlightOffset = {
        math.max(-self.flightOffsetClamp, math.min(self.boostDirection[1] * self.facingDirection * self.flightOffsetFactor, self.flightOffsetClamp)),
        math.max(-self.flightOffsetClamp, math.min(self.boostDirection[2] * self.flightOffsetFactor, self.flightOffsetClamp))
      }

    self.currentFlightOffset = vec2.div(vec2.add(newFlightOffset, vec2.mul(self.currentFlightOffset, 4)), 5)

    animator.translateTransformationGroup("boosters", self.currentFlightOffset)
    animator.translateTransformationGroup("rightArm", self.currentFlightOffset)
    animator.translateTransformationGroup("leftArm", self.currentFlightOffset)
  elseif not onGround or self.jumpBoostTimer > 0 then
    -- TODO: bob while jumping?
  elseif self.landingBobTimer == 0 then
    local bodyCycle = (self.legCycle * 2) % 1
    local bodyOffset = {0, self.walkBobMagnitude * math.sin(math.pi * bodyCycle)}
    animator.translateTransformationGroup("body", bodyOffset)

    local boosterCycle = ((self.legCycle * 2) - self.boosterBobDelay) % 1
    local boosterOffset = {0, self.walkBobMagnitude * math.sin(math.pi * boosterCycle)}
    animator.translateTransformationGroup("boosters", boosterOffset)

    local armCycle = ((self.legCycle * 2) - self.armBobDelay) % 1
    local armOffset = {0, self.walkBobMagnitude * math.sin(math.pi * armCycle)}
    animator.translateTransformationGroup("rightArm", self.rightArm.bobLocked and boosterOffset or armOffset)
    animator.translateTransformationGroup("leftArm", self.leftArm.bobLocked and boosterOffset or armOffset)
  else
    -- TODO: make this less complicated
    local landingCycleTotal = 1.0 + math.max(self.boosterBobDelay, self.armBobDelay)
    local landingCycle = landingCycleTotal * (1 - (self.landingBobTimer / self.landingBobTime))

    local bodyCycle = math.max(0, math.min(1.0, landingCycle))
    local bodyOffset = {0, -self.landingBobMagnitude * math.sin(math.pi * bodyCycle)}
    animator.translateTransformationGroup("body", bodyOffset)

    local legJointOffset = {0, 0.5 * bodyOffset[2]}
    animator.translateTransformationGroup("frontLegJoint", legJointOffset)
    animator.translateTransformationGroup("backLegJoint", legJointOffset)

    local boosterCycle = math.max(0, math.min(1.0, landingCycle + self.boosterBobDelay))
    local boosterOffset = {0, -self.landingBobMagnitude * 0.5 * math.sin(math.pi * boosterCycle)}
    animator.translateTransformationGroup("boosters", boosterOffset)

    local armCycle = math.max(0, math.min(1.0, landingCycle + self.armBobDelay))
    local armOffset = {0, -self.landingBobMagnitude * 0.25 * math.sin(math.pi * armCycle)}
    animator.translateTransformationGroup("rightArm", self.rightArm.bobLocked and boosterOffset or armOffset)
    animator.translateTransformationGroup("leftArm", self.leftArm.bobLocked and boosterOffset or armOffset)
  end

  self.lastPosition = newPosition
  self.lastVelocity = newVelocity
  self.lastOnGround = onGround
end

function onInteraction(args)
  local playerUuid = world.entityUniqueId(args.sourceId)
  if not self.driverId and playerUuid ~= self.ownerUuid then
    return "None"
  end
end

function applyDamage(damageRequest)
  local energyLost = math.min(storage.energy, damageRequest.damage * (1 - self.protection))

  storage.energy = storage.energy - energyLost

  if storage.energy == 0 then
    explode()
  else
    self.damageFlashTimer = self.damageFlashTime
    animator.setGlobalTag("directives", self.damageFlashDirectives)
  end

  return {{
    sourceEntityId = damageRequest.sourceEntityId,
    targetEntityId = entity.id(),
    position = mcontroller.position(),
    damageDealt = damageRequest.damage,
    healthLost = energyLost,
    hitType = damageRequest.hitType,
    damageSourceKind = damageRequest.damageSourceKind,
    targetMaterialKind = self.materialKind,
    killed = storage.energy == 0
  }}
end

function jump()
  self.jumpBoostTimer = self.jumpBoostTime
  mcontroller.setYVelocity(self.jumpVelocity)
  animator.playSound("jump")
end

function armRotation(armSide)
  local absoluteOffset = animator.partPoint(armSide .. "BoosterFront", "shoulder")
  local relativeOffset = vec2.mul(absoluteOffset, {self.facingDirection, 1})
  local shoulderPosition = vec2.add(mcontroller.position(), absoluteOffset)
  local aimVec = world.distance(self.aimPosition, shoulderPosition)
  local rotation = vec2.angle(aimVec)
  if self.facingDirection == -1 then
    rotation = math.pi - rotation
  end
end

function legOffset(legCycle)
  legCycle = legCycle % 1
  if legCycle < 0.5 then
    return {util.lerp(legCycle * 2, self.legRadius - 0.1, -self.legRadius - 0.1), 0}
  else
    local angle = (legCycle - 0.5) * 2 * math.pi
    local offset = vec2.withAngle(math.pi - angle, self.legRadius)
    offset[2] = offset[2] * self.legVerticalRatio
    return offset
  end
end

function findFootGroundOffset(legOffset, footOffset)
  local footBaseOffset = {self.facingDirection * (legOffset[1] + footOffset[1]), footOffset[2]}
  local footPos = vec2.add(mcontroller.position(), footBaseOffset)

  local bestGroundPos
  for _, offset in pairs(self.footCheckXOffsets) do
    world.debugPoint(vec2.add(footPos, {offset, 0}), "yellow")
    local groundPos = world.lineCollision(vec2.add(footPos, {offset, self.reachGroundDistance[1]}), vec2.add(footPos, {offset, self.reachGroundDistance[2]}), {"Null", "Block", "Dynamic", "Platform", "Slippery"})
    if groundPos and bestGroundPos then
      bestGroundPos = bestGroundPos[2] > groundPos[2] and bestGroundPos or groundPos
    elseif groundPos then
      bestGroundPos = groundPos
    end
  end
  if bestGroundPos then
    return world.distance(bestGroundPos, footPos)[2]
  end
end

function triggerStepSound()
  if self.stepSoundLimitTimer == 0 then
    animator.playSound("step")
    self.stepSoundLimitTimer = self.stepSoundLimitTime
  end
end

function resetAllTransformationGroups()
  for _, groupName in ipairs({"frontLeg", "backLeg", "frontLegJoint", "backLegJoint", "hips", "body", "rightArm", "leftArm", "boosters"}) do
    animator.resetTransformationGroup(groupName)
  end
end

function setFlightMode(enabled)
  if self.flightMode ~= enabled then
    self.flightMode = enabled
    resetAllTransformationGroups()
    self.jumpBoostTimer = 0
    self.currentFlightOffset = {0, 0}
    self.fallThroughSustain = false

    mcontroller.resetParameters(self.movementSettings)
    if enabled then
      mcontroller.setVelocity({0, 0})
      mcontroller.applyParameters(self.flyingMovementSettings)
      animator.setAnimationState("frontFoot", "tilt")
      animator.setAnimationState("backFoot", "tilt")
      animator.translateTransformationGroup("frontLeg", self.flightLegOffset)
      animator.translateTransformationGroup("backLeg", self.flightLegOffset)
      animator.translateTransformationGroup("frontLegJoint", vec2.mul(self.flightLegOffset, 0.5))
      animator.translateTransformationGroup("backLegJoint", vec2.mul(self.flightLegOffset, 0.5))
    else

    end
  end
end

function boost(newBoostDirection)
  self.boostDirection = vec2.add(self.boostDirection, newBoostDirection)
end

function alive()
  return not self.explodeTimer and not self.despawnTimer
end

function explode()
  if alive() then
    self.explodeTimer = self.explodeTime
    vehicle.setLoungeEnabled("seat", false)
    vehicle.setInteractive(false)
    animator.setParticleEmitterActive("explode", true)
    animator.playSound("explodeWindup")
  end
end

function despawn()
  if alive() then
    self.despawnTimer = self.despawnTime
    vehicle.setLoungeEnabled("seat", false)
    vehicle.setInteractive(false)
    animator.burstParticleEmitter("despawn")
    animator.setParticleEmitterActive("despawn", true)
    animator.playSound("despawn")
  end
end
