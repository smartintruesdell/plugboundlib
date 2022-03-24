require "/scripts/versioningutils.lua"
-- Set a global table so that we can detect modules that are loaded and need
-- plugin patching but which do not have an init method for hooks.
LPL_Additional_Paths = LPL_Additional_Paths or {}
LPL_Additional_Paths["/versioning/PlayerEntity_30_31_plugins.config"] = true

function update(data)
  local gp = {}

  local sp = data.statusController.statusProperties

  for _, propertyName in pairs({
      "vaultKeySeed",
      "mechUnlocked",
      "mechItemSet",
      "mechPrimaryColorIndex",
      "mechSecondaryColorIndex"
    }) do

    gp[propertyName] = sp[propertyName]
    sp[propertyName] = nil
  end

  data.genericProperties = gp

  return data
end