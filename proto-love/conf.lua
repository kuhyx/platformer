-- LÖVE configuration. Resolution fixed by spec D13.
function love.conf(t)
    t.version = "11.5" -- newest stable release (github.com/love2d/love), verified 2026-09-06
    t.window.title = "proto-love"
    t.window.width = 854
    t.window.height = 480
    t.window.resizable = true
    t.modules.physics = false
    t.modules.joystick = true
end
