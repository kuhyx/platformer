-- Debug-build hooks (unfused `love .` on desktop): command-line flags, F5
-- registry + code reload, F6 snapshot dump, and event-triggered
-- screenshots for the M9 agent-play check. Release builds (web, fused)
-- never call into this module except parse_args (web passes no flags).
local registry = require("registry")
local SimState = require("sim_state")

local M = {}

M.SNAPSHOT = "snapshot.lua"
-- Event-relative screenshot ticks for --shots (slice checklist frames).
local SHOT_START_TICK = 10 -- room 1, a moment after boot
local SHOT_AFTER_DEATH = 8 -- past hitstop (frozen burst is one dot), burst mid-spread
local SHOT_AFTER_ROOM_2 = 40 -- avatar in from the edge, blade moving

-- Flags: --autodrive, --seed=N, --shots, --quit-after=N (ticks).
function M.parse_args(args)
    local opts = {}
    for _, a in ipairs(args or {}) do
        if a == "--autodrive" then
            opts.autodrive = true
        elseif a == "--shots" then
            opts.shots = true
        elseif a:match("^%-%-seed=%-?%d+$") then
            opts.seed = tonumber(a:match("=(.*)"))
        elseif a:match("^%-%-quit%-after=%d+$") then
            opts.quit_after = tonumber(a:match("=(.*)"))
        end
    end
    return opts
end

-- Swap a module's functions into the table every caller already holds, so
-- live objects (whose metatable is that table) run the new code next tick.
function M.hotswap(name)
    local old = package.loaded[name]
    package.loaded[name] = nil
    local ok, new = pcall(require, name)
    package.loaded[name] = old
    if not ok or type(new) ~= "table" then
        print("reload: " .. name .. " failed: " .. tostring(new))
        return false
    end
    for k, v in pairs(new) do
        old[k] = v
    end
    return true
end

-- F5: registry from disk, then the movement and juice code.
function M.reload()
    registry.reload()
    local swapped = M.hotswap("sim") and M.hotswap("fx")
    print("reload: params" .. (swapped and " + sim.lua + fx.lua" or ""))
end

function M.dump_snapshot(sim, params_hash)
    local text = "return " .. SimState.encode(SimState.snapshot(sim, params_hash)) .. "\n"
    love.filesystem.write(M.SNAPSHOT, text)
    print("snapshot: " .. love.filesystem.getSaveDirectory() .. "/" .. M.SNAPSHOT)
end

-- Shot scheduler: call on_tick after every sim tick; returns a label to
-- capture at the end of this frame, or nil.
function M.new_shots()
    return { due = { [SHOT_START_TICK] = "room1_start" }, taken = {} }
end

local function schedule(shots, tick, label)
    if not shots.taken[label] then
        shots.due[tick] = label
    end
end

function M.shot_label(shots, sim)
    for _, e in ipairs(sim.events) do
        if e.e == "death" then
            schedule(shots, sim.tick_count + SHOT_AFTER_DEATH, "death_burst")
        elseif e.e == "room_enter" and e.room == 1 then
            schedule(shots, sim.tick_count + SHOT_AFTER_ROOM_2, "room2_blade")
        elseif e.e == "goal" then
            schedule(shots, sim.tick_count, "goal_flash")
        end
    end
    local label = shots.due[sim.tick_count]
    if label and not shots.taken[label] then
        shots.taken[label] = true
        return label
    end
    return nil
end

function M.capture(label, tick)
    local name = ("shot_%04d_%s.png"):format(tick, label)
    love.graphics.captureScreenshot(name)
    print("shot: " .. love.filesystem.getSaveDirectory() .. "/" .. name)
end

return M
