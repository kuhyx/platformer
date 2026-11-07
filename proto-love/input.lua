-- Fixed input map (spec/DOCS-input-map.md, D05): keyboard and every
-- connected gamepad are polled together each tick, no rebinding. A
-- `virtual` table (the --autodrive bot) is OR-ed in on the same path.
local M = {}

local DEAD_ZONE = 0.25 -- DOCS-input-map.md: fixed, not a tunable

local KEYS_LEFT = { "a", "left" }
local KEYS_RIGHT = { "d", "right" }
local KEYS_JUMP = { "space", "w", "up", "z", "k" }

M.PAUSE_KEYS = { escape = true, p = true }
M.PAUSE_BUTTON = "start"
M.DEBUG_KEYS = { overlay = "f1", reload = "f5", snapshot = "f6" }

local function key_down(keys)
    return love.keyboard.isDown(unpack(keys))
end

local function pads()
    local out = {}
    for _, js in ipairs(love.joystick.getJoysticks()) do
        if js:isGamepad() then
            out[#out + 1] = js
        end
    end
    return out
end

local function pad_state(js)
    local x = js:getGamepadAxis("leftx")
    return {
        left = x <= -DEAD_ZONE or js:isGamepadDown("dpleft"),
        right = x >= DEAD_ZONE or js:isGamepadDown("dpright"),
        jump = js:isGamepadDown("a"),
    }
end

-- One tick's input: { left, right, jump } booleans.
function M.poll(virtual)
    local state = {
        left = key_down(KEYS_LEFT),
        right = key_down(KEYS_RIGHT),
        jump = key_down(KEYS_JUMP),
    }
    local sources = pads()
    sources[#sources + 1] = virtual
    for _, s in pairs(sources) do
        local st = s.getGamepadAxis and pad_state(s) or s
        state.left = state.left or st.left
        state.right = state.right or st.right
        state.jump = state.jump or st.jump
    end
    return state
end

return M
