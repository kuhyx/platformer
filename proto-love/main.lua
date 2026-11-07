-- Glue for the slice (spec/DOCS-slice.md): polls input, ticks the sim at a
-- fixed 60 Hz, reacts to its events (fx, autosave), owns pause, the web
-- start gate and the debug hooks. Every rule lives in sim.lua; drawing is
-- view.lua. Mirrors proto-godot/main.gd.
local registry = require("registry")
local layout = require("layout")
local Sim = require("sim")
local Fx = require("fx")
local Save = require("save")
local Input = require("input")
local View = require("view")
local Debug = require("devtools") -- not "debug": that name is Lua's stdlib

local MAX_CATCHUP_TICKS = 5 -- frame hitch guard: drop sim time beyond this
local REPLAY_SEED = 7 -- shared/replay/slice_trace.json was recorded with it

local is_web = love.system.getOS() == "Web"
local is_debug = not is_web and not love.filesystem.isFused()

local sim, fx, overlay, bot, shots, opts
local params_hash = ""
local acc = 0
local paused = false
local gate_active = is_web -- D02: one start gate on web, absent on desktop
local gate_phase = 0
local ready_signalled = false
local pending_shot
local was_grounded = false

-- Web only: love.js has no JS bridge, so stdout is the one channel out.
-- web/index.html turns these marker lines into window.__gameReady and
-- window.__game (read by e2e_web.mjs); they never reach the canvas (D04).
local function web_signal(line)
    if is_web then
        print(line)
    end
end

local function hash_registry()
    local text = love.filesystem.read("params.lua") or ""
    return love.data.encode("string", "hex", love.data.hash("sha256", text))
end

-- Reacts to whatever the sim emitted: effects, autosave.
local function after_tick()
    -- Edge-only (not per tick): lets e2e_web.mjs hop on state, not on sleeps.
    if sim.on_ground ~= was_grounded then
        was_grounded = sim.on_ground
        web_signal("__air=" .. (was_grounded and 0 or 1))
    end
    fx:on_events(sim.events, sim.rng, sim:rect())
    for _, e in ipairs(sim.events) do
        if e.e == "checkpoint" then
            Save.write(e.room, params_hash)
        elseif e.e == "room_enter" then
            web_signal("__room=" .. e.room)
        end
    end
end

-- Debug-only extras: overlay, --autodrive bot (replays start in room 1
-- with the fixture's seed), --shots scheduler.
local function load_debug(args)
    opts = Debug.parse_args(args)
    overlay = require("overlay").new(View.VIEW_W)
    shots = opts.shots and Debug.new_shots()
    if opts.autodrive then
        bot = require("autodrive").new()
        opts.seed = opts.seed or REPLAY_SEED
    end
end

function love.load(args)
    opts = {}
    if is_debug then
        load_debug(args)
    end
    registry.reload()
    params_hash = hash_registry()
    local rooms = layout.load(require("rooms"))
    sim = Sim.new(rooms, opts.seed or os.time())
    fx = Fx.new()
    sim:enter_room(bot and 0 or Save.read_room(rooms:count()))
    after_tick()
end

local function step()
    local input = Input.poll(bot and bot:input(sim))
    sim:tick(input)
    if bot then
        bot:observe(sim.events)
    end
    after_tick()
    if not sim:frozen() then
        fx:tick(sim.rng)
    end
    if shots then
        pending_shot = Debug.shot_label(shots, sim) or pending_shot
    end
    if opts.quit_after and sim.tick_count >= opts.quit_after then
        love.event.quit()
    end
end

function love.update(dt)
    gate_phase = gate_phase + dt
    if overlay and overlay.visible then
        overlay:set_status(sim.room_id, love.timer.getFPS())
    end
    if paused or gate_active then
        return
    end
    acc = math.min(acc + dt, MAX_CATCHUP_TICKS * Sim.TICK)
    while acc >= Sim.TICK do
        acc = acc - Sim.TICK
        step()
    end
end

function love.draw()
    View.draw(sim, fx, { paused = paused, gate = gate_active and ready_signalled,
        gate_phase = gate_phase, overlay = overlay })
    if pending_shot then
        Debug.capture(pending_shot, sim.tick_count)
        pending_shot = nil
    end
    if not ready_signalled then
        -- Web contract: the patched index.html turns this stdout line into
        -- window.__gameReady (love.js has no JS bridge). Gate draws after it.
        ready_signalled = true
        web_signal("__gameReady")
    end
end

local function toggle_pause()
    paused = not paused
end

-- Any key, click or button dismisses the gate, once the first frame is up.
local function gate_consumes()
    if gate_active then
        if ready_signalled then
            gate_active = false
            web_signal("__gate=0")
        end
        return true
    end
    return false
end

function love.keypressed(key, _, isrepeat)
    if isrepeat or gate_consumes() then
        return
    end
    if Input.PAUSE_KEYS[key] then
        toggle_pause()
    elseif not overlay then
        return
    elseif key == Input.DEBUG_KEYS.overlay then
        overlay.visible = not overlay.visible
    elseif key == Input.DEBUG_KEYS.reload then
        Debug.reload()
    elseif key == Input.DEBUG_KEYS.snapshot then
        Debug.dump_snapshot(sim, params_hash)
    end
end

function love.gamepadpressed(_, button)
    if not gate_consumes() and button == Input.PAUSE_BUTTON then
        toggle_pause()
    end
end

function love.mousepressed(x, y)
    if not gate_consumes() and overlay then
        overlay:mousepressed(View.to_internal(x, y))
    end
end

function love.mousemoved(x, y)
    if overlay then
        overlay:mousemoved((View.to_internal(x, y)))
    end
end

function love.mousereleased()
    if overlay then
        overlay:mousereleased()
    end
end
