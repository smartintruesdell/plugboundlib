require "/scripts/lpl_load_plugins.lua"
local PLUGINS_PATH =
  "/npcs/goodstrader_plugins.config"

function extraInit()
  self.baseBuyFactor = config.getParameter("baseBuyFactor")
  self.baseSellFactor = config.getParameter("baseSellFactor")

  self.buyExponent = config.getParameter("buyExponent")
  self.sellExponent = config.getParameter("sellExponent")

  local factorRecoveryTime = config.getParameter("factorRecoveryTime")
  self.buyRecoveryRate = (self.baseBuyFactor - 1.0) / factorRecoveryTime
  self.sellRecoveryRate = (self.baseSellFactor - 1.0) / factorRecoveryTime

  self.guiConfig = config.getParameter("guiConfig")
  self.guiConfig.baseBuyFactor = self.baseBuyFactor
  self.guiConfig.baseSellFactor = self.baseSellFactor
  self.guiConfig.buyExponent = self.buyExponent
  self.guiConfig.sellExponent = self.sellExponent

  self.sellRotationTime = config.getParameter("sellRotationTime")
  self.sellOptions = config.getParameter("sellOptions")

  storage.currentBuyFactor = storage.currentBuyFactor or self.baseBuyFactor
  storage.currentSellFactor = storage.currentSellFactor or self.baseSellFactor

  message.setHandler("onGoodsBuy", onGoodsBuy_callback)
  message.setHandler("onGoodsSell", onGoodsSell_callback)
end
extraInit = PluginLoader.add_plugin_loader("goodstrader", PLUGINS_PATH, extraInit)

function onGoodsBuy_callback()
  storage.currentBuyFactor = storage.currentBuyFactor ^ self.buyExponent
end

function onGoodsSell_callback()
  storage.currentSellFactor = storage.currentSellFactor ^ self.sellExponent
end

function handleInteract(args)
  recoverFactors()

  self.guiConfig.buyFactor = storage.currentBuyFactor
  self.guiConfig.sellFactor = storage.currentSellFactor

  local sellItemSeed = math.floor(os.time() / self.sellRotationTime)
  self.guiConfig.sellItem = self.sellOptions[sb.staticRandomI32Range(1, #self.sellOptions, npc.seed(), sellItemSeed)]

  return {"ScriptPane", self.guiConfig}
end

function recoverFactors()
  local currentTime = os.time()
  if storage.lastFactorUpdate then
    local elapsedTime = currentTime - storage.lastFactorUpdate
    storage.currentBuyFactor = math.max(self.baseBuyFactor, storage.currentBuyFactor + self.buyRecoveryRate * elapsedTime)
    storage.currentSellFactor = math.min(self.baseSellFactor, storage.currentSellFactor + self.sellRecoveryRate * elapsedTime)
  end
  storage.lastFactorUpdate = currentTime
end
