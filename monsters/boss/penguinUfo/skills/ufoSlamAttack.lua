-- Set a global table so that we can detect modules that are loaded and need
-- plugin patching but which do not have an init method for hooks.
LPL_Additional_Paths = LPL_Additional_Paths or {}
LPL_Additional_Paths["/monsters/boss/penguinUfo/skills/ufoSlamAttack_plugins.config"] = true

--------------------------------------------------------------------------------
ufoSlamAttack = {}

function ufoSlamAttack.enter()
  if self.targetPosition == nil then return nil end

  return {
    slamHeight = config.getParameter("ufoSlamAttack.slamHeight"),
    riseSpeed = config.getParameter("ufoSlamAttack.riseSpeed"),
    slamSpeed = config.getParameter("ufoSlamAttack.slamSpeed"),
    timer = config.getParameter("ufoSlamAttack.skillTime"),
    stunDuration = config.getParameter("ufoSlamAttack.stunDuration"),
    prepareSlam = false,
    slam = false
  }
end

function ufoSlamAttack.enteringState(stateData)
  monster.setActiveSkillName("ufoSlamAttack")
end

function ufoSlamAttack.update(dt, stateData)
  mcontroller.controlFace(1)
  local position = mcontroller.position()

  stateData.timer = stateData.timer - dt
  if stateData.timer <= 0 then
    return true
  end

  --Move to above target
  if not stateData.prepareSlam then
    local approachPosition = {
      self.targetPosition[1],
      self.spawnPosition[2]
    }
    local toApproach = world.distance(approachPosition, position)

    if math.abs(toApproach[1]) < 3 or checkWalls(util.toDirection(toApproach[1])) then
      stateData.prepareSlam = true
    else
      flyTo(approachPosition)
      return false
    end
  end

  --Move up a bit before slamming
  if stateData.prepareSlam then
    local approachPosition = {
      position[1],
      self.spawnPosition[2] + stateData.slamHeight
    }

    if checkWalls(1) then
      approachPosition[1] = approachPosition[1] - 2
    end
    if checkWalls(-1) then
      approachPosition[1] = approachPosition[1] + 2
    end

    local toApproach = world.distance(approachPosition, position)

    if math.abs(toApproach[2]) < 1 then
      stateData.slam = true
      animator.setParticleEmitterActive("falling", true)
    else
      flyTo(approachPosition, stateData.riseSpeed)
    end
  end

  --Slam and stay on ground for stun duration
  if stateData.slam then
    mcontroller.controlParameters({
      gravityEnabled = true
    })
    if mcontroller.onGround() then -- and not monster.isFiring() then
      if not stateData.landed then
        animator.playSound("landing")
        animator.playSound("stunned", -1)
        animator.burstParticleEmitter("landing")
      end
      stateData.landed = true
      monster.setDamageOnTouch(false)
      animator.setParticleEmitterActive("falling", false)
      animator.setParticleEmitterActive("stunned", true)
      if stateData.timer > stateData.stunDuration then
        stateData.timer = stateData.stunDuration
      end
    else
      if not stateData.landed then
        monster.setDamageOnTouch(true)
      end
      mcontroller.controlApproachYVelocity(-config.getParameter("ufoSlamAttack.slamSpeed"), 100)
    end
  end

  return false
end

function ufoSlamAttack.leavingState(stateData)
  monster.setDamageOnTouch(false)
  animator.setParticleEmitterActive("stunned", false)
  animator.stopAllSounds("stunned")
end

function ufoSlamAttack.flyToTargetYOffsetRange(targetPosition)
  local position = mcontroller.position()
  local yOffsetRange = config.getParameter("targetYOffsetRange")
  local destination = {
    targetPosition[1],
    util.clamp(position[2], targetPosition[2] + yOffsetRange[1], targetPosition[2] + yOffsetRange[2])
  }

  if math.abs(destination[2] - position[2]) < 1.0 then
    return true
  else
    flyTo(destination)
  end

  return false
end
