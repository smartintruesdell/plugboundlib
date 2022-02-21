require "/scripts/lpl_load_plugins.lua"
local PLUGINS_PATH =
  "/interface/games/fossilgames/fossil_plugins.config"

FossilTypes = {
  {
    {0,0,0,1,1},
    {0,0,0,1,1},
    {1,1,1,1,1},
    {1,0,1,0,1},
    {1,0,1,0,1}
  },
  {
    {1,0,1,0,0},
    {1,1,1,0,0},
    {0,0,1,0,0},
    {0,0,1,1,1},
    {0,0,1,0,1}
  },
  {
    {1,1,1,1,1},
    {0,0,0,0,1},
    {1,1,1,1,1},
    {0,0,1,0,1},
    {0,0,1,1,1}
  },
  {
    {1,0,0,0,0},
    {1,0,0,0,0},
    {1,1,1,1,1},
    {1,0,0,0,0},
    {1,0,0,0,0}
  },
  {
    {0,0,1,0,1},
    {1,1,1,1,1},
    {1,0,1,0,1},
    {1,1,1,1,1},
    {0,0,1,0,1}
  }
}

Fossil = {}

function Fossil:new(tiles)
  local newFossil = {
    size = {#tiles[1], #tiles},
    tiles = {}
  }
  for y,row in ipairs(tiles) do
    for x,v in ipairs(row) do
      if v == 1 then
        table.insert(newFossil.tiles, {x,y})
      end
    end
  end
  setmetatable(newFossil, extend(self))
  return newFossil
end
Fossil.new = PluginLoader.add_plugin_loader("fossil", PLUGINS_PATH, Fossil.new)

function Fossil:rotate()
  local offset = {-99,-99}
  self.size = {self.size[2], self.size[1]}
  for i,tile in ipairs(self.tiles) do
    self.tiles[i] = {tile[2], -tile[1]}
    if self.tiles[i][1] < -offset[1] then offset[1] = -self.tiles[i][1] end
    if self.tiles[i][2] < -offset[2] then offset[2] = -self.tiles[i][2] end
  end
  self:offset(offset)
end

function Fossil:offset(offset)
  for i,tile in ipairs(self.tiles) do
    self.tiles[i] = {tile[1] + offset[1], tile[2] + offset[2]}
  end
end

function Fossil:place(tileWorld, offset)
  for _,tile in ipairs(self.tiles) do
    tileWorld:addBone(vec2.add(tile, offset), true)
  end
end
