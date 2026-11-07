-- Debug bot (M9, `love . --autodrive`): the closed-loop policy from
-- proto-godot/tests/replay.gd that generated shared/replay/slice_trace.json.
-- It plays the slice once (die in each room, clear both, touch the goal,
-- loop) by producing a virtual pad that input.poll() merges with the real
-- keyboard and gamepads, so every tick goes through the game's input path.
-- Pure: reads the sim, no love.* use.
local Sim = require("sim")

local SAFE_BEHIND = 10 -- px the blade must be behind the take-off point [design guess, replay.gd]
local SAFE_AHEAD = 140 -- px the blade must be ahead: outruns the jump arc [design guess, replay.gd]
local LEDGE = 3 -- room 1's raised ledge (solids[2] in Godot's 0-based arrays)
local DONE = 5

local Bot = {}
Bot.__index = Bot

function Bot.new()
    return setmetatable({ phase = 0 }, Bot)
end

function Bot:done()
    return self.phase >= DONE
end

local function near(sim, x)
    local w = sim:size()
    return sim.pos.x + 2 * w >= x and sim.pos.x < x
end

local function blade_clear(sim)
    local blade = sim:blade_rect()
    local behind = sim.blade_dir < 0 and blade.x + blade.w < sim.pos.x - SAFE_BEHIND
    local ahead = blade.x > sim.pos.x + SAFE_AHEAD
    return behind or ahead
end

-- Phases: 0 die in room 1's pit, 1 clear room 1, 2 die in room 2,
-- 3 clear room 2 timing the blade, 4 ride the goal loop back to room 1.
function Bot:steering(sim)
    return not self:done() and sim.state == Sim.ALIVE and self.phase ~= 0 and self.phase ~= 2
end

function Bot:input(sim)
    local input = { left = false, right = sim.state == Sim.ALIVE and not self:done(), jump = false }
    if not self:steering(sim) then
        return input
    end
    local gap_x = sim:room().gaps[1][1]
    if self.phase == 1 then
        input.jump = near(sim, gap_x) or near(sim, sim:room().solids[LEDGE].x)
    elseif self.phase == 3 and near(sim, gap_x) then
        local clear = blade_clear(sim)
        local w = sim:size()
        input.jump = clear
        input.right = clear or sim.pos.x + w < gap_x - w
    end
    return input
end

-- Advance the phase from the events the sim emitted this tick.
function Bot:observe(events)
    for _, e in ipairs(events) do
        if e.e == "respawn" or e.e == "goal" or (e.e == "room_enter" and self.phase == 1) then
            self.phase = self.phase + 1
        elseif e.e == "room_enter" and self.phase == 4 then
            self.phase = DONE
        end
    end
end

return Bot
