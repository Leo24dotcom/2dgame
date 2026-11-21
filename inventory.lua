--
-- inventory.lua  –  A simple 4-slot inventory HUD for Love2D
--
-- Usage (in main.lua):
--
--   love.load:
--       Inventory = require 'inventory'
--       inventory = Inventory.new({
--           'sprites/chest.png',
--           'sprites/key.png',
--           'sprites/potion.png',
--           'sprites/sword.png',
--       })
--       inventory:add('key')
--
--   love.draw (AFTER cam:detach, so the HUD stays on screen):
--       inventory:draw()
--
--   Other useful functions:
--       inventory:add('sword')         -- put an item in the first open slot
--       inventory:remove('sword')      -- remove an item by name
--       inventory:hasItem('sword')     -- returns true/false
--

local Inventory = {}
Inventory.__index = Inventory

--- Create a new inventory.
-- @param itemImages  a table of image paths keyed by item name, e.g.
--                    { chest = 'sprites/chest.png', key = 'sprites/key.png', ... }
--                    OR a simple list of paths — the filename (minus extension) becomes the name
function Inventory.new(itemImages)
    local self = setmetatable({}, Inventory)

    -- 4 inventory slots, all start empty (nil)
    self.slots = { nil, nil, nil, nil }

    -- Load every item image into a lookup table: name -> Love2D Image
    self.images = {}
    for nameOrIndex, path in pairs(itemImages) do
        -- If the table is a simple list (numeric keys), derive the name from the filename
        local name
        if type(nameOrIndex) == 'number' then
            name = path:match("([^/]+)%.png$") or path:match("([^/]+)%..+$")
        else
            name = nameOrIndex
        end
        self.images[name] = love.graphics.newImage(path)
    end

    -- HUD settings
    self.slotSize = 40          -- pixel size of each slot square
    self.padding   = 4          -- gap between slots
    self.topMargin = 10         -- distance from top of screen

    return self
end

--- Add an item to the first empty slot.
-- @param name  the item name (must match an image key)
-- @return true if added, false if inventory is full
function Inventory:add(name)
    for i = 1, 4 do
        if self.slots[i] == nil then
            self.slots[i] = name
            return true
        end
    end
    return false
end

--- Remove the first occurrence of an item.
-- @param name  the item name to remove
-- @return true if removed, false if not found
function Inventory:remove(name)
    for i = 1, 4 do
        if self.slots[i] == name then
            self.slots[i] = nil
            return true
        end
    end
    return false
end

--- Check whether the inventory contains an item.
-- @param name  the item name to look for
-- @return true/false
function Inventory:hasItem(name)
    for i = 1, 4 do
        if self.slots[i] == name then
            return true
        end
    end
    return false
end

--- Draw the inventory HUD.  Call AFTER cam:detach() so it stays fixed on screen.
function Inventory:draw()
    local totalWidth = 4 * self.slotSize + 3 * self.padding
    local startX = (love.graphics.getWidth() - totalWidth) / 2
    local startY = self.topMargin

    for i = 1, 4 do
        local x = startX + (i - 1) * (self.slotSize + self.padding)
        local y = startY

        -- Slot background
        love.graphics.setColor(0, 0, 0, 0.6)
        love.graphics.rectangle('fill', x, y, self.slotSize, self.slotSize)

        -- Slot border
        love.graphics.setColor(1, 1, 1, 0.8)
        love.graphics.rectangle('line', x, y, self.slotSize, self.slotSize)

        -- Slot number (small, bottom-right corner)
        love.graphics.setColor(1, 1, 1, 0.4)
        love.graphics.print(tostring(i), x + self.slotSize - 10, y + self.slotSize - 14)

        -- Item icon (if slot is occupied)
        if self.slots[i] and self.images[self.slots[i]] then
            local img = self.images[self.slots[i]]
            local imgW, imgH = img:getDimensions()
            local scale = (self.slotSize - 8) / math.max(imgW, imgH)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(img, x + 4, y + 4, 0, scale, scale)
        end
    end

    -- Reset color so we don't tint anything drawn after us
    love.graphics.setColor(1, 1, 1, 1)
end

return Inventory
