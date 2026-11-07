-- Invisible autosave (D03): room id + registry hash in the LÖVE save dir.
-- Native: atomic (write save.txt.tmp, then os.rename over save.txt; LÖVE's
-- filesystem API has no rename). Web: the same dir is love.js's IDBFS mount.
-- Missing or corrupt → room 0, silently (D19). Mirrors save_file.gd; the
-- format is two `key=value` lines because LÖVE ships no JSON, and it is
-- parsed, never load()-ed.
local M = {}

M.FILE = "save.txt"
M.TMP = "save.txt.tmp"

function M.encode(room_id, params_hash)
    return ("room_id=%d\nparams_hash=%s\n"):format(room_id, params_hash or "")
end

-- The saved room id when it is a valid index, else 0. Pure (tested).
function M.decode(text, room_count)
    if type(text) ~= "string" then
        return 0
    end
    local id = tonumber(text:match("^room_id=(%-?%d+)\n"))
    if not id or id < 0 or id >= room_count then
        return 0
    end
    return id
end

local function abs_path(name)
    return love.filesystem.getSaveDirectory() .. "/" .. name
end

function M.write(room_id, params_hash)
    local ok, err = love.filesystem.write(M.TMP, M.encode(room_id, params_hash))
    if not ok then
        print("save: cannot write " .. M.TMP .. ": " .. tostring(err))
        return false
    end
    local renamed, rerr = os.rename(abs_path(M.TMP), abs_path(M.FILE))
    if not renamed then
        print("save: rename failed: " .. tostring(rerr))
        return false
    end
    return true
end

function M.read_room(room_count)
    if not love.filesystem.getInfo(M.FILE, "file") then
        return 0
    end
    return M.decode(love.filesystem.read(M.FILE), room_count)
end

return M
