-- Snapshot = { room_id, checkpoint_id, player_state, rng_seed, params_hash }
-- (spec/DOCS-dev-principles.md §3). Feeds saves, replays and the F6 dump;
-- restore() puts a Sim back exactly where a snapshot left it. Mirrors
-- sim_state.gd. Pure: the registry hash is passed in by the caller.
local M = {}

function M.snapshot(sim, params_hash)
    return {
        room_id = sim.room_id,
        checkpoint_id = sim.room_id,
        player_state = {
            x = sim.pos.x,
            y = sim.pos.y,
            vx = sim.vel.x,
            vy = sim.vel.y,
            on_ground = sim.on_ground,
            coyote_left = sim.coyote_left,
            buffer_left = sim.buffer_left,
            jump_cut_pending = sim.jump_cut_pending,
            state = sim.state,
            state_t = sim.state_t,
            blade_x = sim.blade_pos.x,
            blade_y = sim.blade_pos.y,
            blade_dir = sim.blade_dir,
        },
        rng_seed = sim.seed_value,
        rng_state = sim.rng.state,
        params_hash = params_hash or "",
        tick = sim.tick_count,
    }
end

function M.restore(sim, snap)
    local p = snap.player_state
    sim.room_id = snap.room_id
    sim.pos = { x = p.x, y = p.y }
    sim.vel = { x = p.vx, y = p.vy }
    sim.on_ground = p.on_ground
    sim.coyote_left = p.coyote_left
    sim.buffer_left = p.buffer_left
    sim.jump_cut_pending = p.jump_cut_pending
    sim.state = p.state
    sim.state_t = p.state_t
    sim.blade_pos = { x = p.blade_x, y = p.blade_y }
    sim.blade_dir = p.blade_dir
    sim.seed_value = snap.rng_seed
    sim.rng.state = snap.rng_state
    sim.tick_count = snap.tick
end

-- Flat, deterministic text form (sorted keys) for the F6 dump and for
-- comparing two snapshots in tests. Numbers use %.17g so doubles round-trip.
local function encode(v, indent)
    local t = type(v)
    if t == "number" then
        return ("%.17g"):format(v)
    elseif t ~= "table" then
        return t == "string" and ("%q"):format(v) or tostring(v)
    end
    local keys = {}
    for k in pairs(v) do
        keys[#keys + 1] = k
    end
    table.sort(keys)
    local pad = indent .. "  "
    local parts = {}
    for _, k in ipairs(keys) do
        parts[#parts + 1] = ("%s%s = %s"):format(pad, k, encode(v[k], pad))
    end
    return "{\n" .. table.concat(parts, ",\n") .. "\n" .. indent .. "}"
end

function M.encode(snap)
    return encode(snap, "")
end

return M
