-- Juice (D06): death particles, screen shake, goal flash. Ticked in lockstep
-- with the sim and fed its RNG, so a replay reproduces every particle.
-- Mirrors fx.gd. Pure: draw() takes a rectangle callback instead of love.*.
local registry = require("registry")
local Sim = require("sim")

local P = registry.get
local TICK = Sim.TICK
local TAU = 2 * math.pi

local Fx = {}
Fx.__index = Fx

function Fx.new()
    local self = { particles = {}, shake_left = 0, shake = { x = 0, y = 0 }, flash_left = 0 }
    return setmetatable(self, Fx)
end

function Fx:burst(rng, cx, cy)
    local speed, life = P("particle_speed"), P("particle_lifetime")
    for _ = 1, math.floor(P("death_particles")) do
        local angle = rng:randf_range(0, TAU)
        local mag = rng:randf_range(0, speed)
        self.particles[#self.particles + 1] = {
            x = cx, y = cy, vx = math.cos(angle) * mag, vy = math.sin(angle) * mag, life = life,
        }
    end
end

-- `avatar` is the sim's rect at the moment of the events.
function Fx:on_events(events, rng, avatar)
    for _, e in ipairs(events) do
        if e.e == "death" then
            self:burst(rng, avatar.x + avatar.w / 2, avatar.y + avatar.h / 2)
            self.shake_left = P("shake_duration")
        elseif e.e == "goal" then
            self.flash_left = P("goal_flash_duration")
        end
    end
end

function Fx:tick(rng)
    local gravity = P("gravity")
    for i = #self.particles, 1, -1 do
        local p = self.particles[i]
        p.life = p.life - TICK
        if p.life <= 0 then
            table.remove(self.particles, i)
        else
            p.vy = p.vy + gravity * TICK
            p.x = p.x + p.vx * TICK
            p.y = p.y + p.vy * TICK
        end
    end
    self.shake_left = math.max(self.shake_left - TICK, 0)
    if self.shake_left > 0 then
        local amp = P("shake_amplitude")
        self.shake = { x = rng:randf_range(-amp, amp), y = rng:randf_range(-amp, amp) }
    else
        self.shake = { x = 0, y = 0 }
    end
    self.flash_left = math.max(self.flash_left - TICK, 0)
end

function Fx:flash_alpha()
    local total = P("goal_flash_duration")
    return total > 0 and self.flash_left / total or 0
end

-- rect(x, y, w, h) draws one filled square per particle.
function Fx:draw(rect)
    local side = P("particle_size")
    for _, p in ipairs(self.particles) do
        rect(p.x, p.y, side, side)
    end
end

return Fx
