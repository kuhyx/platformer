-- Parameter registry accessor (spec/DOCS-parameters.md, D14). Every tunable
-- comes from the generated params.lua; nothing is hardcoded. The overlay
-- writes through set(); F5 calls reload() to re-read the file from disk.
-- Pure Lua: no love.* use, so the sim and its tests share it.
local M = {}

local MODULE = "params"

local entries = {} -- key -> { value, min, max, step } (live, mutable copy)
local shipped = {} -- key -> value as generated (tests restore from this)
local sorted_keys = {}

local function copy(e)
    return { value = e.value, min = e.min, max = e.max, step = e.step }
end

-- (Re)load from the generated module. package.loaded is cleared first so a
-- running game picks up an edited params.lua (F5).
function M.reload()
    package.loaded[MODULE] = nil
    local raw = require(MODULE)
    entries, shipped, sorted_keys = {}, {}, {}
    for key, e in pairs(raw) do
        if key:sub(1, 1) ~= "_" then
            entries[key] = copy(e)
            shipped[key] = e.value
            sorted_keys[#sorted_keys + 1] = key
        end
    end
    -- params.lua is a hash table, so file order is lost; sort for a stable overlay.
    table.sort(sorted_keys)
end

-- Back to the shipped values without touching the disk.
function M.reset()
    if next(entries) == nil then
        M.reload()
    end
    for key, value in pairs(shipped) do
        entries[key].value = value
    end
end

local function entry(key)
    if next(entries) == nil then
        M.reload()
    end
    local e = entries[key]
    assert(e, "unknown param: " .. tostring(key))
    return e
end

function M.get(key)
    return entry(key).value
end

-- Live tweak (M7): clamped to the entry's bounds.
function M.set(key, value)
    local e = entry(key)
    e.value = math.min(math.max(value, e.min), e.max)
end

function M.entry(key)
    return entry(key)
end

function M.shipped(key)
    entry(key)
    return shipped[key]
end

function M.keys()
    if next(entries) == nil then
        M.reload()
    end
    return sorted_keys
end

return M
