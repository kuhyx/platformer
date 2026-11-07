-- Cross-engine replay (shared/replay/slice_trace.json): feeding the fixture's
-- inputs to the Lua sim must emit Godot's events, same names, rooms and
-- order, each tick within ±1 (float width differs per engine).
--   cd proto-love && busted
local json = require("spec.json_reader")
local registry = require("registry")
local layout = require("layout")
local Sim = require("sim")

local TRACE = "../shared/replay/slice_trace.json"
local SEED = 7
local TICK_TOLERANCE = 1

-- Run-length encode one tick's input onto segs, as replay.gd::_segments.
local function flag(b)
    return b and 1 or 0
end

local function append_segment(segs, i)
    local row = { 1, flag(i.left), flag(i.right), flag(i.jump) }
    local last = segs[#segs]
    if last and table.concat(last, ",", 2) == table.concat(row, ",", 2) then
        last[1] = last[1] + 1
    else
        segs[#segs + 1] = row
    end
end

local function replay(rooms, segments)
    local sim = Sim.new(rooms, SEED)
    sim:enter_room(0)
    local got = {}
    local function log()
        for _, e in ipairs(sim.events) do
            got[#got + 1] = { sim.tick_count, e.e, sim.room_id }
        end
    end
    log()
    for _, seg in ipairs(segments) do
        local input = { left = seg[2] == 1, right = seg[3] == 1, jump = seg[4] == 1 }
        for _ = 1, seg[1] do
            sim:tick(input)
            log()
        end
    end
    return got
end

describe("replay fixture", function()
    it("emits Godot's events in order, each tick within ±1", function()
        registry.reset()
        local want = json.read_file(TRACE)
        local got = replay(layout.load(require("rooms")), want.inputs)
        local exact = true
        assert.are.equal(#want.events, #got)
        for i, w in ipairs(want.events) do
            local g = got[i]
            assert.are.equal(w[2], g[2], "event " .. i .. " name")
            assert.are.equal(w[3], g[3], "event " .. i .. " room")
            assert.is_true(math.abs(w[1] - g[1]) <= TICK_TOLERANCE,
                ("event %d (%s): tick %d, want %d"):format(i, w[2], g[1], w[1]))
            exact = exact and w[1] == g[1]
        end
        print(("replay: ok (%d events, %s)"):format(#got, exact and "exact ticks" or "within ±1"))
    end)

    it("the --autodrive bot regenerates the fixture's inputs", function()
        registry.reset()
        local want = json.read_file(TRACE)
        local Bot = require("autodrive")
        local sim, bot = Sim.new(layout.load(require("rooms")), SEED), Bot.new()
        sim:enter_room(0)
        local segs = {}
        while not bot:done() and sim.tick_count < 60 * 60 do
            local i = bot:input(sim)
            sim:tick(i)
            bot:observe(sim.events)
            append_segment(segs, i)
        end
        assert.are.same(want.inputs, segs)
    end)
end)
