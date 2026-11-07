-- Headless slice checks (M10), a port of proto-godot/tests/test_sim.gd:
-- drives Sim with scripted input, no engine running.
--   cd proto-love && busted
local registry = require("registry")
local layout = require("layout")
local Sim = require("sim")
local SimState = require("sim_state")

local IDLE = { left = false, right = false, jump = false }
local RIGHT = { left = false, right = true, jump = false }
local RIGHT_JUMP = { left = false, right = true, jump = true }
local JUMP = { left = false, right = false, jump = true }
local SEED = 7
local SECONDS = 60 -- ticks per second, D12
local LEDGE = 3 -- room 1's raised ledge: solids[2] in Godot's 0-based arrays

local rooms

local function fresh(room)
    local sim = Sim.new(rooms, SEED)
    sim:enter_room(room or 0)
    return sim
end

local function run(sim, ticks, input)
    local seen = {}
    for _ = 1, ticks do
        sim:tick(input)
        for _, e in ipairs(sim.events) do
            seen[e.e] = true
        end
    end
    return seen
end

-- Hold right, jump when the pit or the ledge is next. Ends in room 2.
local function run_room_1(sim)
    local seen = {}
    local w = sim:size()
    local pit_x = sim:room().gaps[1][1]
    local ledge_x = sim:room().solids[LEDGE].x
    for _ = 1, 8 * SECONDS do
        local x = sim.pos.x
        local near_pit = x + w >= pit_x - w and x < pit_x
        local near_ledge = x + w >= ledge_x - w and x < ledge_x
        sim:tick((near_pit or near_ledge) and RIGHT_JUMP or RIGHT)
        for _, e in ipairs(sim.events) do
            seen[e.e] = true
        end
        if sim.room_id == 1 then
            break
        end
    end
    return seen
end

-- Walk off the ledge, then press jump a few ticks later.
local function late_jump_after_ledge(coyote)
    registry.set("coyote_time", coyote)
    local sim = fresh()
    local w, h = sim:size()
    local ledge = sim:room().solids[LEDGE]
    sim.pos = { x = ledge.x + ledge.w - w - 1, y = ledge.y - h }
    run(sim, 2, IDLE) -- settle onto the ledge
    sim.pos.x = rooms.width - w -- stand on the ledge's last pixel
    run(sim, 1, IDLE)
    sim.pos.x = ledge.x + ledge.w -- airborne past the edge, still in room 1
    run(sim, 2, IDLE)
    local seen = run(sim, 1, JUMP)
    registry.set("coyote_time", registry.shipped("coyote_time"))
    return seen.jump == true
end

-- Tap jump while falling, a few ticks before landing.
local function early_jump_before_landing(buffer)
    registry.set("jump_buffer", buffer)
    local sim = fresh()
    local _, h = sim:size()
    sim.pos.y = sim.pos.y - 2 * h -- drop from above the floor
    run(sim, 9, IDLE) -- most of the way down
    run(sim, 1, JUMP)
    local seen = run(sim, SECONDS, IDLE)
    registry.set("jump_buffer", registry.shipped("jump_buffer"))
    return seen.jump == true
end

describe("sim", function()
    before_each(function()
        registry.reset()
        rooms = layout.load(require("rooms"))
    end)

    it("idle avatar rests on the floor", function()
        local sim = fresh()
        run(sim, SECONDS, IDLE)
        local _, h = sim:size()
        assert.is_true(sim.on_ground)
        assert.are.equal(rooms:room(0).solids[1].y - h, sim.pos.y)
    end)

    it("room 1's spike pit kills and respawn returns to room 1", function()
        local sim = fresh()
        local seen = run(sim, 5 * SECONDS, RIGHT)
        assert.is_true(seen.death)
        assert.is_true(seen.respawn)
        assert.are.equal(0, sim.room_id)
    end)

    it("jumping the pit and the ledge reaches room 2 and autosaves", function()
        local sim = fresh()
        local seen = run_room_1(sim)
        assert.is_nil(seen.death)
        assert.are.equal(1, sim.room_id)
        assert.is_true(seen.checkpoint)
    end)

    it("room 2's gap or blade kills; respawn stays in room 2", function()
        local sim = fresh(1)
        local seen = run(sim, 5 * SECONDS, RIGHT)
        assert.is_true(seen.death)
        assert.are.equal(1, sim.room_id)
    end)

    it("blade patrols inside its track", function()
        local sim = fresh(1)
        local track = sim:room().blade.track
        local start_x = sim.blade_pos.x
        run(sim, SECONDS, IDLE)
        assert.are_not.equal(start_x, sim.blade_pos.x)
        assert.is_true(sim.blade_pos.x >= track[1] and sim.blade_pos.x <= track[2])
    end)

    it("touching the goal fires goal, then the loop restarts in room 1", function()
        local sim = fresh(1)
        local goal = sim:room().goal
        local w = sim:size()
        sim.pos = { x = goal.x - w - 1, y = goal.y }
        local seen = run(sim, 2 * SECONDS, RIGHT)
        assert.is_true(seen.goal)
        assert.are.equal(0, sim.room_id)
        assert.are.equal(Sim.ALIVE, sim.state)
    end)

    it("coyote_time 0: no jump after leaving the ledge; default: jump fires", function()
        assert.is_false(late_jump_after_ledge(0))
        assert.is_true(late_jump_after_ledge(registry.shipped("coyote_time")))
    end)

    it("jump_buffer 0: early tap is lost; default: fires on landing", function()
        assert.is_false(early_jump_before_landing(0))
        assert.is_true(early_jump_before_landing(registry.shipped("jump_buffer")))
    end)

    it("coyote_time and jump_buffer 0: a press on the ground still jumps", function()
        registry.set("coyote_time", 0)
        registry.set("jump_buffer", 0)
        local sim = fresh()
        run(sim, 2, IDLE)
        assert.is_true(run(sim, 1, JUMP).jump == true)
    end)

    it("same seed + inputs give identical snapshots (D12)", function()
        local a, b = fresh(), fresh()
        run_room_1(a)
        run_room_1(b)
        run(a, SECONDS, RIGHT)
        run(b, SECONDS, RIGHT)
        local snap = function(s)
            return SimState.encode(SimState.snapshot(s))
        end
        assert.are.equal(snap(a), snap(b))
    end)

    it("same seed: the death burst and shake replay identically", function()
        local Fx = require("fx")
        local function burst()
            local sim, fx = fresh(), Fx.new()
            for _ = 1, 3 * SECONDS do
                sim:tick(RIGHT)
                fx:on_events(sim.events, sim.rng, sim:rect())
                if not sim:frozen() then
                    fx:tick(sim.rng)
                end
            end
            return fx, sim.rng.state
        end
        local a, ra = burst()
        local b, rb = burst()
        assert.are.equal(ra, rb)
        assert.are.same(a.particles, b.particles)
        assert.is_true(#a.particles > 0 or ra ~= SEED, "the pit death consumed the RNG")
    end)

    it("an unwinnable gap fails the layout assert", function()
        registry.set("jump_velocity", registry.entry("jump_velocity").min)
        assert.has_error(function()
            layout.load(require("rooms"))
        end)
    end)
end)
