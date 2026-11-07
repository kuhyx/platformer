-- Debug overlay (F1): one slider per registry entry, generated from the
-- registry (D14, never hand-built), plus room id and fps. Debug builds only
-- (unfused `love .`), which is how its labels coexist with D04. Mirrors
-- overlay.gd. Drawn in the 854x480 internal space; mouse coords arrive
-- already mapped into it. params.lua carries no unit/desc, so rows show
-- key and value only.
local registry = require("registry")

local Overlay = {}
Overlay.__index = Overlay

local PANEL_WIDTH_RATIO = 0.5 -- share of the viewport the panel takes
local ROW_H = 18 -- px per row; 24 entries + status fit in 480 without scrolling
local PAD = 4
local NAME_W = 0.42 -- shares of the panel width: name | slider | value
local SLIDER_W = 0.4
local KNOB_W = 4
local PANEL_ALPHA = 0.8
local TRACK_COLOR = { 0.35, 0.35, 0.4 }

function Overlay.new(view_w)
    local w = view_w * PANEL_WIDTH_RATIO
    return setmetatable({
        visible = false,
        width = w,
        slider_x = w * NAME_W,
        slider_w = w * SLIDER_W,
        dragging = nil,
        status = "",
    }, Overlay)
end

function Overlay:set_status(room_id, fps)
    self.status = ("room %d   fps %d"):format(room_id, fps)
end

local function row_y(i)
    return PAD + i * ROW_H
end

-- Value under slider x, snapped to the entry's step and clamped.
function Overlay:value_at(key, x)
    local e = registry.entry(key)
    local t = math.min(math.max((x - self.slider_x) / self.slider_w, 0), 1)
    local steps = math.floor((e.max - e.min) * t / e.step + 0.5)
    return e.min + steps * e.step
end

function Overlay:key_at(x, y)
    if x < self.slider_x or x > self.slider_x + self.slider_w then
        return nil
    end
    local i = math.floor((y - PAD) / ROW_H)
    return registry.keys()[i] -- row 0 is the status line
end

function Overlay:mousepressed(x, y)
    if not self.visible then
        return false
    end
    self.dragging = self:key_at(x, y)
    self:mousemoved(x)
    return x < self.width
end

function Overlay:mousemoved(x)
    if self.dragging then
        registry.set(self.dragging, self:value_at(self.dragging, x))
    end
end

function Overlay:mousereleased()
    self.dragging = nil
end

local function fmt(v)
    return (("%.3f"):format(v):gsub("0+$", ""):gsub("%.$", ""))
end

function Overlay:draw_row(i, key)
    local g = love.graphics
    local e = registry.entry(key)
    local y = row_y(i)
    local t = (e.value - e.min) / (e.max - e.min)
    g.setColor(1, 1, 1)
    g.print(key, PAD, y)
    g.setColor(TRACK_COLOR)
    g.rectangle("fill", self.slider_x, y + ROW_H / 2 - 1, self.slider_w, 2)
    g.setColor(1, 1, 1)
    g.rectangle("fill", self.slider_x + t * self.slider_w - KNOB_W / 2, y + 2, KNOB_W, ROW_H - 4)
    g.print(fmt(e.value), self.slider_x + self.slider_w + PAD * 2, y)
end

function Overlay:draw(view_h)
    if not self.visible then
        return
    end
    local g = love.graphics
    g.setColor(0, 0, 0, PANEL_ALPHA)
    g.rectangle("fill", 0, 0, self.width, view_h)
    g.setColor(1, 1, 1)
    g.print(self.status, PAD, row_y(0))
    for i, key in ipairs(registry.keys()) do
        self:draw_row(i, key)
    end
end

return Overlay
