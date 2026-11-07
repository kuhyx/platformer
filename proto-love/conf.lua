-- LÖVE configuration. Resolution fixed by spec D13.
-- love.js (npm 11.4.1, newest) embeds a LÖVE 11.4.0 runtime; declaring
-- "11.5" there makes boot.lua log a compatibility warning (verified
-- 2026-11-06, console only), so the web build declares what it runs.
local NATIVE_VERSION = "11.5" -- newest stable (github.com/love2d/love), verified 2026-09-06
local WEB_VERSION = "11.4" -- the runtime inside love.js 11.4.1

function love.conf(t)
    t.identity = "proto-love" -- save dir name, native and IDBFS alike
    t.version = love._os == "Web" and WEB_VERSION or NATIVE_VERSION
    t.window.title = "proto-love"
    t.window.width = 854
    t.window.height = 480
    t.window.resizable = true
    t.modules.physics = false
    t.modules.joystick = true
end
