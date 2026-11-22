local NPC = require 'npc'

local Enemy = {}
Enemy.__index = Enemy
setmetatable(Enemy, { __index = NPC }) 
function Enemy.new(spriteSheetPath, x, y, opts)
    opts = opts or {}
    local self = NPC.new(spriteSheetPath, x, y, opts.wanderX or 60, opts.wanderY or 60)
    setmetatable(self, Enemy)


  if opts.frameW and opts.frameH then
    local imgW, imgH = self.spriteSheet:getDimensions()
    self.grid = anim8.newGrid(opts.frameW, opts.frameH, imgW, imgH)
    local walk = anim8.newAnimation(self.grid('1-16', 1), 0.1)
    self.animations = { down = walk, left = walk, right = walk, up = walk }
    self.anim = self.animations.down
end

    self.speed = opts.speed or 1.5         
    self.chaseSpeed = opts.chaseSpeed or 3  
    self.aggroRange = opts.aggroRange or 250
    self.touchRange = 40
    self.damage = opts.damage or 30
    self.hp = opts.hp or 3
    self.maxHp = self.hp
    self.attackCooldown = 0
    self.chasing = false
    return self
end

function Enemy:update(dt, player)
    if self.attackCooldown > 0 then
        self.attackCooldown = self.attackCooldown - dt
    end

    local dx = player.x - self.x
    local dy = player.y - self.y
    local dist = math.sqrt(dx * dx + dy * dy)

    if dist <= self.aggroRange then
        self.chasing = true
        if dist > self.touchRange then
            self.x = self.x + (dx / dist) * self.chaseSpeed
            self.y = self.y + (dy / dist) * self.chaseSpeed
            self.targetX, self.targetY = player.x, player.y
            self:faceTarget()
            self.anim:update(dt)
        else
            self.anim:gotoFrame(2)
            if self.attackCooldown <= 0 then
                player.currHp = math.max(0, player.currHp - self.damage)
                self.attackCooldown = 1
            end
        end
    else
        if self.chasing then
            self.chasing = false
            self.state = "paused"
            self.pauseTimer = 0
            self.originX, self.originY = self.x, self.y
        end
        NPC.update(self, dt)
    end
end

function Enemy:draw()
    if self.visible then
        self.anim:draw(self.spriteSheet, self.x, self.y, nil, 0.5, nil, 64, 64)
    end
end

return Enemy