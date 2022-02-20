require "/scripts/lpl_load_plugins.lua"
local PLUGINS_PATH =
  "/items/active/unsorted/railplatform/placementpreview_plugins.config"

function init() end
init = PluginLoader.add_plugin_loader("placementpreview", PLUGINS_PATH, init)

function update()
  localAnimator.clearDrawables()
  local previewPosition = animationConfig.animationParameter("previewPosition")

  if previewPosition then
    local previewImage = animationConfig.animationParameter("previewImage")
    local previewValid = animationConfig.animationParameter("previewValid")

    if previewValid then
      previewImage = previewImage .. "?fade=55FF5500;0.25?border=2;66FF6677;00000000"
    else
      previewImage = previewImage .. "?fade=FF555500;0.25?border=2;FF666677;00000000"
    end

    localAnimator.addDrawable({
      image = previewImage,
      position = previewPosition,
      fullbright = true
    })
  end
end
