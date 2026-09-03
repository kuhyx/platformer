-- Boot stub: loads the generated registry, draws the avatar placeholder.
-- The slice (spec/slice.md) is not implemented yet.
local registry = require("params")

local BACKGROUND = { 0.10, 0.10, 0.12 }
local PLACEHOLDER_SPAWN = { x = 100, y = 400 } -- slice will read spawn from room data

local function param(key)
    local entry = registry[key]
    assert(entry, "unknown param: " .. key)
    return entry.value
end

function love.load()
    love.graphics.setBackgroundColor(BACKGROUND)
end

function love.draw()
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle(
        "fill",
        PLACEHOLDER_SPAWN.x,
        PLACEHOLDER_SPAWN.y,
        param("player_w"),
        param("player_h")
    )
end
