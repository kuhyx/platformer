-- LÖVE configuration. Resolution fixed by spec D13.
function love.conf(t)
    t.version = "11.5" -- verify against the installed LÖVE; 12.x may be current
    t.window.title = "proto-love"
    t.window.width = 854
    t.window.height = 480
    t.window.resizable = true
    t.modules.physics = false
    t.modules.joystick = true
end
