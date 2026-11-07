-- Drawing: the room, avatar, blade, particles, goal flash, pause dim and the
-- web start gate, in the 854x480 internal space (D13), letterboxed into the
-- window with aspect preserved. Mirrors main.gd::_draw. No text (D04).
local registry = require("registry")
local Sim = require("sim")

local P = registry.get

local M = {}

M.VIEW_W, M.VIEW_H = 854, 480 -- D13 internal resolution (non-tunable)

-- Palette fixed by the slice spec: no sprites, one colour per element.
local COLOR_PLAYER = { 1, 1, 1 }
local COLOR_HAZARD = { 1, 0, 0 }
local COLOR_CHECKPOINT = { 0, 1, 0 }
local COLOR_GOAL = { 1, 1, 0 }
local COLOR_FLOOR = { 0.745, 0.745, 0.745 } -- Godot's Color.GRAY
local COLOR_BACKGROUND = { 0.10, 0.10, 0.12 }
local COLOR_LETTERBOX = { 0, 0, 0 }
local TAU = 2 * math.pi

-- Window → internal transform: uniform scale, centred.
function M.fit()
    local ww, wh = love.graphics.getDimensions()
    local s = math.min(ww / M.VIEW_W, wh / M.VIEW_H)
    return s, (ww - M.VIEW_W * s) / 2, (wh - M.VIEW_H * s) / 2
end

function M.to_internal(x, y)
    local s, ox, oy = M.fit()
    return (x - ox) / s, (y - oy) / s
end

local function fill(color, r)
    love.graphics.setColor(color)
    love.graphics.rectangle("fill", r.x, r.y, r.w, r.h)
end

local function draw_world(sim, fx)
    local rm = sim:room()
    for _, s in ipairs(rm.solids) do
        fill(COLOR_FLOOR, s)
    end
    for _, h in ipairs(rm.hazards) do
        fill(COLOR_HAZARD, h)
    end
    fill(COLOR_CHECKPOINT, rm.checkpoint)
    if rm.goal then
        fill(COLOR_GOAL, rm.goal)
    end
    if rm.blade then
        fill(COLOR_HAZARD, sim:blade_rect())
    end
    if sim.state ~= Sim.DEAD then
        fill(COLOR_PLAYER, sim:rect())
    end
    love.graphics.setColor(COLOR_PLAYER)
    fx:draw(function(x, y, w, h)
        love.graphics.rectangle("fill", x, y, w, h)
    end)
end

local function dim()
    love.graphics.setColor(0, 0, 0, P("pause_dim"))
    love.graphics.rectangle("fill", 0, 0, M.VIEW_W, M.VIEW_H)
end

-- Pulsing icon, no text (D02/D04): a circle breathing between
-- radius × (1 − depth) and radius.
local function draw_gate(phase)
    local wave = (1 + math.sin(phase / P("gate_pulse_period") * TAU)) / 2
    local radius = P("gate_icon_radius") * (1 - P("gate_pulse_depth") * (1 - wave))
    dim()
    love.graphics.setColor(COLOR_PLAYER)
    love.graphics.circle("fill", M.VIEW_W / 2, M.VIEW_H / 2, radius)
end

-- `ui`: { paused, gate, gate_phase, overlay }.
function M.draw(sim, fx, ui)
    local g = love.graphics
    local s, ox, oy = M.fit()
    g.clear(COLOR_LETTERBOX)
    g.push()
    g.translate(ox, oy)
    g.scale(s)
    g.setScissor(ox, oy, M.VIEW_W * s, M.VIEW_H * s)
    g.clear(COLOR_BACKGROUND)
    g.push()
    g.translate(fx.shake.x, fx.shake.y)
    draw_world(sim, fx)
    g.pop()
    if fx:flash_alpha() > 0 then
        g.setColor(1, 1, 1, fx:flash_alpha())
        g.rectangle("fill", 0, 0, M.VIEW_W, M.VIEW_H)
    end
    if ui.paused then
        dim()
    end
    if ui.gate then
        draw_gate(ui.gate_phase)
    end
    if ui.overlay then
        ui.overlay:draw(M.VIEW_H)
    end
    g.setScissor()
    g.pop()
end

return M
