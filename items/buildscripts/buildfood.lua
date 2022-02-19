require "/scripts/lpl_load_plugins.lua"
local PLUGINS_PATH = "/items/buildscripts/buildfood_plugins.config"

function build(directory, config, parameters, level, seed)
  if not parameters.timeToRot then
    local rottingMultiplier =
      parameters.rottingMultiplier or
      config.rottingMultiplier or
      1.0

    parameters.timeToRot =
      root.assetJson("/items/rotting.config:baseTimeToRot") * rottingMultiplier
  end

  config.tooltipFields = config.tooltipFields or {}
  config.tooltipFields.rotTimeLabel = getRotTimeDescription(parameters.timeToRot)

  return config, parameters
end

build = PluginLoader.add_plugin_loader("buildfood", PLUGINS_PATH, build)

function getRotTimeDescription(rotTime)
  local descList = root.assetJson("/items/rotting.config:rotTimeDescriptions")
  for i, desc in ipairs(descList) do
    if rotTime <= desc[1] then return desc[2] end
  end
  return descList[#descList]
end
