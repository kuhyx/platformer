-- Pure fixed-step sim (D12): movement, collision, rooms, hazards, death,
-- goal. No love.*, so busted drives it (M10); every number comes from the
-- registry or the layout. Port of proto-godot/sim.gd, proven by
-- spec/replay_spec.lua against shared/replay/slice_trace.json.
local registry = require("registry")
local layout = require("layout")
local Rng = require("rng")
local f32 = require("f32") -- Vector2 components are float32 in Godot

local P = registry.get
local intersects = layout.intersects

local Sim = {}
Sim.__index = Sim

Sim.TICK_HZ = 60 -- D12 non-tunable
Sim.TICK = 1 / Sim.TICK_HZ
Sim.ALIVE, Sim.DEAD, Sim.GOAL = 0, 1, 2 -- same ints as sim.gd's State enum

local TICK = Sim.TICK

function Sim.new(rooms, seed)
    local self = setmetatable({}, Sim)
    self.rooms = rooms
    self.seed_value = seed
    self.rng = Rng.new(seed)
    self.tick_count = 0
    self.room_id = 0
    self.pos = { x = 0, y = 0 } -- avatar top-left
    self.vel = { x = 0, y = 0 }
    self.on_ground = false
    self.coyote_left, self.buffer_left = 0, 0
    self.jump_cut_pending = false -- takeoff until release or apex (variable height)
    self.prev_jump = false
    self.state = Sim.ALIVE
    self.state_t = 0 -- seconds spent in DEAD / GOAL
    self.blade_pos = { x = 0, y = 0 }
    self.blade_dir = 1
    self.events = {} -- emitted during the last tick
    return self
end

function Sim.size(_)
    return P("player_w"), P("player_h")
end

function Sim:rect()
    local w, h = self:size()
    return { x = self.pos.x, y = self.pos.y, w = w, h = h }
end

function Sim:room()
    return self.rooms:room(self.room_id)
end

function Sim:blade_rect()
    local blade = self:room().blade
    if not blade then
        return { x = 0, y = 0, w = 0, h = 0 }
    end
    return { x = self.blade_pos.x, y = self.blade_pos.y, w = blade.rect.w, h = blade.rect.h }
end

-- True during hitstop: the whole world, effects included, holds still.
function Sim:frozen()
    return self.state == Sim.DEAD and self.state_t < P("hitstop")
end

function Sim:emit(name, data)
    data = data or {}
    data.e = name
    self.events[#self.events + 1] = data
end

-- Fresh entry into a room: spawn point, blade reset, checkpoint saved.
function Sim:enter_room(id, keep_motion)
    self.room_id = id
    local blade = self:room().blade
    if blade then
        self.blade_pos = { x = blade.rect.x, y = blade.rect.y }
        self.blade_dir = 1
    end
    if not keep_motion then
        self:spawn()
    end
    self.state = Sim.ALIVE
    self.state_t = 0
    self:emit("room_enter", { room = id })
    self:emit("checkpoint", { room = id })
end

function Sim:spawn()
    local spawn = self:room().spawn
    self.pos = { x = spawn.x, y = spawn.y }
    self.vel = { x = 0, y = 0 }
    self.on_ground = false
    self.coyote_left = 0
    self.buffer_left = 0
    self.jump_cut_pending = false
end

function Sim:tick(input)
    self.events = {}
    self.tick_count = self.tick_count + 1
    if self.state == Sim.ALIVE then
        self:tick_alive(input)
    elseif self.state == Sim.DEAD then
        self.state_t = self.state_t + TICK
        if self.state_t >= P("hitstop") + P("respawn_delay") then
            self:spawn()
            self.state = Sim.ALIVE
            self:emit("respawn", { room = self.room_id })
        end
    elseif self.state == Sim.GOAL then
        self.state_t = self.state_t + TICK
        if self.state_t >= P("goal_flash_duration") then
            self:enter_room(0)
        end
    end
    self.prev_jump = input.jump
end

-- Coyote time + jump buffer: a press within jump_buffer of landing, or
-- within coyote_time of leaving a ledge, still takes off.
function Sim:takeoff(input)
    local jump_pressed = input.jump and not self.prev_jump
    self.buffer_left = jump_pressed and P("jump_buffer") or math.max(self.buffer_left - TICK, 0)
    self.coyote_left = self.on_ground and P("coyote_time") or math.max(self.coyote_left - TICK, 0)
    -- The press counts on its own tick: jump_buffer 0 means no buffering, not no jumping.
    if (jump_pressed or self.buffer_left > 0) and (self.on_ground or self.coyote_left > 0) then
        self.vel.y = f32(-P("jump_velocity"))
        self.buffer_left = 0
        self.coyote_left = 0
        self.on_ground = false
        self.jump_cut_pending = true
        self:emit("jump")
    end
end

-- Variable height: releasing before the apex multiplies the rise.
function Sim:jump_cut(input)
    if self.jump_cut_pending and not input.jump then
        if self.vel.y < 0 then
            self.vel.y = f32(self.vel.y * P("jump_cut_multiplier"))
        end
        self.jump_cut_pending = false
    end
    if self.vel.y >= 0 then
        self.jump_cut_pending = false
    end
end

function Sim:tick_alive(input)
    local axis = (input.right and 1 or 0) - (input.left and 1 or 0)
    self.vel.x = f32(axis * P("move_speed"))
    self:takeoff(input)
    self:jump_cut(input)
    self.vel.y = f32(math.min(self.vel.y + P("gravity") * TICK, P("max_fall_speed")))
    self:move()
    self:edges()
    self:move_blade()
    self:touch()
end

-- Axis-separated AABB sweep against the room's solids.
function Sim:move()
    local solids = self:room().solids
    local w, h = self:size()
    self.pos.x = f32(self.pos.x + self.vel.x * TICK)
    for _, s in ipairs(solids) do
        if intersects(self:rect(), s) then
            self.pos.x = f32(self.vel.x > 0 and s.x - w or s.x + s.w)
        end
    end
    self.pos.y = f32(self.pos.y + self.vel.y * TICK)
    self.on_ground = false
    for _, s in ipairs(solids) do
        if intersects(self:rect(), s) then
            if self.vel.y > 0 then
                self.pos.y = f32(s.y - h)
                self.on_ground = true
            else
                self.pos.y = f32(s.y + s.h)
            end
            self.vel.y = 0
        end
    end
end

-- Room edges: hard cut to the neighbour (D16), clamp at the ends of the slice.
function Sim:edges()
    local w = self:size()
    local width = self.rooms.width
    if self.pos.x < 0 then
        if self.room_id > 0 then
            self:enter_room(self.room_id - 1, true)
            self.pos.x = f32(width - w)
        else
            self.pos.x = 0
        end
    elseif self.pos.x + w > width then
        if self.room_id < self.rooms:count() - 1 then
            self:enter_room(self.room_id + 1, true)
            self.pos.x = 0
        else
            self.pos.x = f32(width - w)
        end
    end
end

function Sim:move_blade()
    local blade = self:room().blade
    if not blade then
        return
    end
    local lo, hi = blade.track[1], blade.track[2]
    self.blade_pos.x = f32(self.blade_pos.x + self.blade_dir * P("blade_speed") * TICK)
    if self.blade_pos.x >= hi then
        self.blade_pos.x = hi
        self.blade_dir = -1
    elseif self.blade_pos.x <= lo then
        self.blade_pos.x = lo
        self.blade_dir = 1
    end
end

function Sim:touch()
    local me = self:rect()
    for _, hz in ipairs(self:room().hazards) do
        if intersects(me, hz) then
            return self:die()
        end
    end
    if self:room().blade and intersects(me, self:blade_rect()) then
        return self:die()
    end
    local goal = self:room().goal
    if goal and intersects(me, goal) then
        self.state = Sim.GOAL
        self.state_t = 0
        self:emit("goal", { room = self.room_id })
    end
end

function Sim:die()
    self.state = Sim.DEAD
    self.state_t = 0
    self:emit("death", { room = self.room_id, x = self.pos.x, y = self.pos.y })
end

return Sim
