-- Round a Lua double to the nearest IEEE-754 single (ties to even).
-- Godot's Vector2 stores float32 components, so sim.gd's positions and
-- velocities are rounded on every store; sim.lua applies this at the same
-- stores. Without it the shared fixture's goal touch (an exact 808 + 12 =
-- 820 edge) lands one tick later in doubles, after the recorded input ends.
-- Portable on purpose: string.pack and ffi each exist in only some of the
-- three VMs this runs on (LuaJIT, PUC 5.1 in love.js, 5.5 in busted).
local LN2 = math.log(2)
local MANTISSA_BITS = 23 -- IEEE-754 binary32

-- floor(log2(a)), corrected for log rounding at exact powers of two.
local function exponent(a)
    local e = math.floor(math.log(a) / LN2)
    if 2 ^ e > a then
        e = e - 1
    elseif 2 ^ (e + 1) <= a then
        e = e + 1
    end
    return e
end

return function(x)
    if x == 0 or x ~= x or x == math.huge or x == -math.huge then
        return x
    end
    local a = math.abs(x)
    local scale = 2 ^ (exponent(a) - MANTISSA_BITS)
    local v = a / scale
    local r = math.floor(v + 0.5)
    if r - v == 0.5 and r % 2 == 1 then
        r = r - 1
    end
    r = r * scale
    return x < 0 and -r or r
end
