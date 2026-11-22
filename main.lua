function love.load()
    camera = require 'libraries/camera'
    NPC = require 'npc'

    cam = camera()

    anim8 = require 'libraries/anim8'
    love.graphics.setDefaultFilter("nearest", "nearest")

    sti = require 'libraries/sti'
    gameMap = sti('maps/cave.lua')
    gameMap:resize(love.graphics.getWidth()*2, love.graphics.getHeight())

    player = {}
    player.speed = 5
    player.spriteSheet = love.graphics.newImage('sprites/player-sheet.png')
    player.grid = anim8.newGrid( 12, 18, player.spriteSheet:getWidth(), player.spriteSheet:getHeight() )

    player.animations = {}
    player.animations.down = anim8.newAnimation( player.grid('1-4', 1), 0.2 )
    player.animations.left = anim8.newAnimation( player.grid('1-4', 2), 0.2 )
    player.animations.right = anim8.newAnimation( player.grid('1-4', 3), 0.2 )
    player.animations.up = anim8.newAnimation( player.grid('1-4', 4), 0.2 )

    player.anim = player.animations.left

    player.currHp = 100
    player.maxHp = 100

    myNPC = NPC.new('sprites/player-sheet.png', 796, 216, 80, 0)
    drNPC = NPC.new('sprites/player-sheet.png', 200, 900, 50, 50)
    Enemy = require 'enemy'
    enemy1 = Enemy.new('enemies/eldritch-beast-with-skull-head-walking-forward-dbc4-spritesheet.png', 400, 400, {
    frameW = 128, frameH = 128,  
    damage = 10,
})

    Inventory = require 'inventory'
    inventory = Inventory.new({
        'sprites/chest.png',
        'sprites/key.png',
        'sprites/potion.png',
        'sprites/sword.png',
    })

    -- Narrator: ink + talkies wrapper. See narrator.lua.
    narrator = require 'narrator'
    narrator:init()

    characterJeanne = narrator:newCharacter("Jeanne",  "sprites/jeanne.png")
    characterMark   = narrator:newCharacter("Mark", "sprites/mark.png")

    -- Seed the ink variable `has_potion` from the live inventory right before
    -- each conversation. Bella's script uses it to branch; the doctor's
    -- script ignores it, but it's harmless to pass.
    local function questContext()
        return { has_potion = inventory:hasItem("potion") }
    end

    narrator:bindNPC(myNPC, characterJeanne, "Jeanne_script", questContext)
    narrator:bindNPC(drNPC, characterMark,   "Mark",    questContext)

     --Tag handler: the doctor's ink ends his "gives you a potion" line with
    -- '# give sword`. When that tag flows through the narrator, add a
    -- sword to the inventory (but only if the player doesn't already have
    -- one, so repeat visits don't stack).
    narrator.onTag = function(tag)
        print("Tag received: [" .. tostring(tag) .. "]")
    
        if tag == "Accept Jeanne's help" then
            if not inventory:hasItem("sword") then
                inventory:add("sword")
                print("Sword added!")
            end
        end
    end

    -- Font for the floating "E" key prompt.
    promptFont = love.graphics.newFont(14)

    resetGame()
    
    gameState = "mainMenu"
end

function resetGame()
    -- reset player x,y to start positions
    --player.x = 400
    --player.y = 600

    -- Distance (in world pixels) at which the "E" prompt appears.
    --interactRange = 80

    -- Set when the player is close enough to a bound NPC to interact.
    --nearbyNPC = nil
    player.x = 400
    player.y = 600
    player.currHp = player.maxHp

    enemy1.x, enemy1.y = 400, 400
    enemy1.originX, enemy1.originY = 400, 400
    enemy1.attackCooldown = 0
    enemy1.chasing = false

    interactRange = 80
    nearbyNPC = nil
end

-- Check if a world position collides with a tile on the Trees layer
function treeAt(x, y)
    local layer = gameMap.layers["Trees"]
    local tx = math.floor(x / gameMap.tilewidth) + 1
    local ty = math.floor(y / gameMap.tileheight) + 1
    return layer.data[ty] and layer.data[ty][tx]
end

-- Find the closest bound NPC within interactRange (or nil).
function findNearbyNPC()
    local closest, closestDist = nil, interactRange
    for _, npc in ipairs(narrator._boundNPCs) do
        local dx = npc.x - player.x
        local dy = npc.y - player.y
        local dist = math.sqrt(dx * dx + dy * dy)
        if dist <= closestDist then
            closest, closestDist = npc, dist
        end
    end
    return closest
end

function love.update(dt)
    if gameState ~= "play" then return end
    local dialogueOpen = narrator:isOpen()

    -- Freeze the player while a dialog is on screen so the conversation feels
    -- grounded. NPCs are paused via narrator:bindNPC's update wrapper.
    if not dialogueOpen then
        local isMoving = false
        local oldX, oldY = player.x, player.y

        if love.keyboard.isDown("d") then
            player.x = player.x + player.speed
            player.anim = player.animations.right
            isMoving = true
        end

        if love.keyboard.isDown("a") then
            player.x = player.x - player.speed
            player.anim = player.animations.left
            isMoving = true
        end

        if love.keyboard.isDown("s") then
            player.y = player.y + player.speed
            player.anim = player.animations.down
            isMoving = true
        end

        if love.keyboard.isDown("w") then
            player.y = player.y - player.speed
            player.anim = player.animations.up
            isMoving = true
        end

        -- Collision: check each axis separately so player slides along walls
        if treeAt(player.x, oldY) then player.x = oldX end
        if treeAt(player.x, player.y) then player.y = oldY end

        if isMoving == false then
            player.anim:gotoFrame(2)
        end
    else
        -- Hold the idle pose during conversation.
        player.anim:gotoFrame(2)
    end

    checkGameOverZone()
    player.anim:update(dt)

    -- Update camera position
    cam:lookAt(player.x, player.y)

    -- This section prevents the camera from viewing outside the background
    -- First, get width/height of the game window
    local w = love.graphics.getWidth()
    local h = love.graphics.getHeight()

    -- Left border
    if cam.x < w/2 then
        cam.x = w/2
    end

    -- Right border
    if cam.y < h/2 then
        cam.y = h/2
    end

    -- Get width/height of background
    local mapW = gameMap.width * gameMap.tilewidth
    local mapH = gameMap.height * gameMap.tileheight

    -- Right border
    if cam.x > (mapW - w/2) then
        cam.x = (mapW - w/2)
    end
    -- Bottom border
    if cam.y > (mapH - h/2) then
        cam.y = (mapH - h/2)
    end

    myNPC:update(dt)
    drNPC:update(dt)
    if not dialogueOpen then
        enemy1:update(dt, player)
    end

    if player.currHp <= 0 then
        gameState = "gameOver"
    end

    -- Refresh proximity once per frame, only when no dialog is showing.
    if dialogueOpen then
        nearbyNPC = nil
    else
        nearbyNPC = findNearbyNPC()
    end

    narrator:update(dt)
end

-- Small "E" key hint floating above an NPC's head.
function drawInteractPrompt(npc)
    local prevFont = love.graphics.getFont()
    love.graphics.setFont(promptFont)

    local label = "E"
    local textW = promptFont:getWidth(label)
    local textH = promptFont:getHeight()
    local padX, padY = 6, 3
    local boxW = textW + padX * 2
    local boxH = textH + padY * 2
    local boxX = math.floor(npc.x - boxW / 2)
    local boxY = math.floor(npc.y - 50 - boxH)

    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle("fill", boxX, boxY, boxW, boxH, 4, 4)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("line", boxX, boxY, boxW, boxH, 4, 4)
    love.graphics.print(label, boxX + padX, boxY + padY)

    love.graphics.setFont(prevFont)
end

function love.draw()
    if gameState == "mainMenu" then
        local w = love.graphics.getWidth()
        local h = love.graphics.getHeight()
        love.graphics.printf("Press Enter to start", 0, h/2, w, "center")
    elseif gameState == "play" then
        cam:attach()
            gameMap:drawLayer(gameMap.layers["Ground"])
            player.anim:draw(player.spriteSheet, player.x, player.y, nil, 6, nil, 6, 9)
            myNPC:draw()
            drNPC:draw()
            enemy1:draw()
            gameMap:drawLayer(gameMap.layers["Trees"])

            if nearbyNPC then
                drawInteractPrompt(nearbyNPC)
            end
        cam:detach()
        drawHPBar()

        love.graphics.print("x = " .. math.floor(player.x) .. " y = " .. math.floor(player.y), 10, 10)
        inventory:draw()

        -- Dialogue UI is drawn last so it sits on top of everything.
        narrator:draw()
    elseif gameState == "gameOver" then
        love.graphics.print("Game Over Press Enter to start again", 400, 200)
    end
end

function love.keypressed(key)

    if key == "return" and gameState == "mainMenu" then
        resetGame()
        gameState = "play"
        return
    end

    if key == "return" and gameState == "gameOver" then
        resetGame()
        gameState = "mainMenu"
        return
    end

    if key == "escape" then
        love.event.quit()
    end

    if narrator:isOpen() then
        -- Inside a dialog: advance / pick options.
        if key == "space" or key == "return" then
            narrator:onAction()
        elseif key == "up" then
            narrator:prevOption()
        elseif key == "down" then
            narrator:nextOption()
        end
    else
        -- Outside a dialog: E starts a conversation with the closest NPC.
        if key == "e" and nearbyNPC then
            narrator:startScript(nearbyNPC)
        end
    end
end

function drawHPBar()
    local x = 500
    local y = 20
    local width = 200
    local height = 20

    -- Background
    love.graphics.setColor(0.3, 0.3, 0.3)
    love.graphics.rectangle("fill", x, y, width, height)

    -- Current health
    local hpWidth = width * (player.currHp / player.maxHp)

    love.graphics.setColor(0, 1, 0)
    love.graphics.rectangle("fill", x, y, hpWidth, height)

    -- Border
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle("line", x, y, width, height)

    love.graphics.print("HP: " .. player.currHp .. "/" .. player.maxHp, x, y + 25)

    love.graphics.setColor(1, 1, 1)
end

function checkGameOverZone()
    local zoneX = 400
    local zoneY = 0
    local zoneWidth = 300
    local zoneHeight = 40

    if player.x >= zoneX and
       player.x <= zoneX + zoneWidth and
       player.y >= zoneY and
       player.y <= zoneY + zoneHeight then

        gameState = "gameOver"
    end
end
