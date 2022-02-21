require "/scripts/util.lua"
require "/scripts/lpl_load_plugins.lua"
local PLUGINS_PATH =
  "/interface/scripted/keytrader/keytradergui_plugins.config"

function init()
  widget.setItemSlotItem("itmKey", "vaultkey")

  self.tradeOptions = config.getParameter("tradeOptions")

  self.seed = player.getProperty("vaultKeySeed")
  if not self.seed then
    setNewSeed()
  end

  setupTrade()
end
init = PluginLoader.add_plugin_loader("keytradergui", PLUGINS_PATH, init)

function update(dt)
  local playerItemCount = player.hasCountOfItem(self.tradeItem)
  local canTrade = playerItemCount >= self.tradeCount
  local directive = canTrade and "^green;"or"^red;"
  if playerItemCount > 99 then
    playerItemCount = "99+"
  end
  widget.setText("lblTradeItemQuantity", string.format("%s%s/%s", directive, playerItemCount, self.tradeCount))
  widget.setButtonEnabled("btnTrade", canTrade)
end

function setNewSeed()
  self.seed = util.seedTime()
  player.setProperty("vaultKeySeed", self.seed)
end

function setupTrade()
  local tradeOption = self.tradeOptions[sb.staticRandomI32Range(1, #self.tradeOptions, self.seed)]
  self.tradeItem = tradeOption[1]
  self.tradeCount = tradeOption[2]
  widget.setItemSlotItem("itmTradeItem", self.tradeItem)

  local tradeItemConfig = root.itemConfig(self.tradeItem)
  widget.setText("lblTradeItemName", tradeItemConfig.config.shortdescription)

  update()
end

function tradeForKey()
  if player.consumeItem({self.tradeItem, self.tradeCount}) then
    player.giveItem("vaultkey")
    setNewSeed()
    setupTrade()
  end
end
