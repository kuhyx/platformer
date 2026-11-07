-- Room layout loader (D24): turns the generated rooms.lua into rect tables and
-- proves the slice is winnable at the current registry values: every gap
-- must be clearable by a full jump and every step-up must be lower than the
-- jump apex. A layout that fails is a bug, not a tuning job. Mirrors rooms.gd.
-- Room ids are 0-based (fixture, saves, events); room(id) is the only place
-- that maps them onto Lua's 1-based arrays.
local registry = require("registry")

local M = {}
M.__index = M

-- Strict overlap, as Godot's Rect2.intersects: shared edges do not touch.
function M.intersects(a, b)
    return a.x < b.x + b.w and b.x < a.x + a.w and a.y < b.y + b.h and b.y < a.y + a.h
end

local function rect(a)
    return { x = a[1], y = a[2], w = a[3], h = a[4] }
end

local function rects(list)
    local out = {}
    for i, a in ipairs(list or {}) do
        out[i] = rect(a)
    end
    return out
end

local function parse_room(raw)
    local out = {
        spawn = { x = raw.spawn[1], y = raw.spawn[2] },
        checkpoint = rect(raw.checkpoint),
        solids = rects(raw.solids),
        hazards = rects(raw.hazards),
        gaps = raw.gaps or {},
    }
    if raw.blade then
        local track = raw.blade.track
        out.blade = { rect = rect(raw.blade.rect), track = { track[1], track[2] } }
    end
    if raw.goal then
        out.goal = rect(raw.goal)
    end
    return out
end

-- Horizontal reach of one full jump from flat ground, at the current values.
function M.jump_reach()
    local air_time = 2 * registry.get("jump_velocity") / registry.get("gravity")
    return registry.get("move_speed") * air_time
end

function M.jump_apex()
    local v = registry.get("jump_velocity")
    return v * v / (2 * registry.get("gravity"))
end

-- `data` is the table rooms.lua returns.
function M.load(data)
    local self = setmetatable({ width = data.width, height = data.height, rooms = {} }, M)
    for i, raw in ipairs(data.rooms) do
        self.rooms[i] = parse_room(raw)
    end
    self:assert_winnable()
    return self
end

function M:count()
    return #self.rooms
end

function M:room(id)
    return self.rooms[id + 1]
end

-- The lowest solid top in a room is its floor level; steps are measured from it.
function M:floor_thickness(id)
    local lowest = 0
    for _, s in ipairs(self:room(id).solids) do
        lowest = math.max(lowest, self.height - s.y)
    end
    return lowest
end

function M:assert_winnable()
    local reach, apex = M.jump_reach(), M.jump_apex()
    local pw = registry.get("player_w")
    for id = 0, self:count() - 1 do
        for _, gap in ipairs(self:room(id).gaps) do
            local span = gap[2] - gap[1] + pw
            assert(span < reach, ("room %d: gap %s-%s needs %.0f px, reach is %.0f")
                :format(id, gap[1], gap[2], span, reach))
        end
        for _, s in ipairs(self:room(id).solids) do
            local step = self.height - s.y - self:floor_thickness(id)
            assert(step < apex,
                ("room %d: step of %.0f px exceeds apex %.0f"):format(id, step, apex))
        end
    end
end

return M
