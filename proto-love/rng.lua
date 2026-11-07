-- The one seeded RNG (D12). Park–Miller minimal standard LCG: every product
-- stays below 2^46, so plain `*` and `%` are exact in LuaJIT (native),
-- PUC Lua 5.1 (love.js) and Lua 5.5 (busted) alike; no bit ops, which those
-- three VMs spell differently. Not Godot's PCG32: particles and shake are
-- deterministic per engine, and the replay fixture does not depend on them.
local M = {}
M.__index = M

local MODULUS = 2147483647 -- 2^31 - 1
local MULTIPLIER = 16807

function M.new(seed)
    local self = setmetatable({}, M)
    self:set_seed(seed)
    return self
end

function M:set_seed(seed)
    local s = math.floor(math.abs(seed)) % MODULUS
    self.state = s == 0 and 1 or s
end

function M:next()
    self.state = self.state * MULTIPLIER % MODULUS
    return self.state
end

-- Uniform in [lo, hi).
function M:randf_range(lo, hi)
    return lo + (hi - lo) * ((self:next() - 1) / (MODULUS - 1))
end

return M
