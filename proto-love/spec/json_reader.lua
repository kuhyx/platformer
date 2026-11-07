-- Test-only JSON reader for shared/replay/slice_trace.json (LÖVE ships no
-- JSON parser and nothing is vendored). Handles exactly what the fixture
-- uses: objects, arrays, numbers, plain strings (no escapes beyond \" \\ \/),
-- true/false/null. Anything else is an error, never a silent guess.
local M = {}

local parse_value

local function skip_ws(s, i)
    return s:find("[^ \t\r\n]", i) or (#s + 1)
end

local function parse_string(s, i)
    local out, j = {}, i + 1
    while true do
        local c = s:sub(j, j)
        if c == "" then
            error("json: unterminated string at " .. i)
        elseif c == '"' then
            return table.concat(out), j + 1
        elseif c == "\\" then
            local esc = s:sub(j + 1, j + 1)
            assert(esc == '"' or esc == "\\" or esc == "/", "json: unsupported escape \\" .. esc)
            out[#out + 1] = esc
            j = j + 2
        else
            out[#out + 1] = c
            j = j + 1
        end
    end
end

local function parse_number(s, i)
    local text = s:match("^-?%d+%.?%d*[eE]?[-+]?%d*", i)
    assert(text and #text > 0, "json: bad number at " .. i)
    return tonumber(text), i + #text
end

local function parse_array(s, i)
    local out = {}
    i = skip_ws(s, i + 1)
    if s:sub(i, i) == "]" then
        return out, i + 1
    end
    while true do
        local v
        v, i = parse_value(s, i)
        out[#out + 1] = v
        i = skip_ws(s, i)
        local c = s:sub(i, i)
        if c == "]" then
            return out, i + 1
        end
        assert(c == ",", "json: expected , or ] at " .. i)
        i = skip_ws(s, i + 1)
    end
end

local function parse_object(s, i)
    local out = {}
    i = skip_ws(s, i + 1)
    if s:sub(i, i) == "}" then
        return out, i + 1
    end
    while true do
        assert(s:sub(i, i) == '"', "json: expected key at " .. i)
        local key
        key, i = parse_string(s, i)
        i = skip_ws(s, i)
        assert(s:sub(i, i) == ":", "json: expected : at " .. i)
        out[key], i = parse_value(s, skip_ws(s, i + 1))
        i = skip_ws(s, i)
        local c = s:sub(i, i)
        if c == "}" then
            return out, i + 1
        end
        assert(c == ",", "json: expected , or } at " .. i)
        i = skip_ws(s, i + 1)
    end
end

local LITERALS = { ["true"] = true, ["false"] = false }

parse_value = function(s, i)
    i = skip_ws(s, i)
    local c = s:sub(i, i)
    if c == "{" then
        return parse_object(s, i)
    elseif c == "[" then
        return parse_array(s, i)
    elseif c == '"' then
        return parse_string(s, i)
    end
    for word, value in pairs(LITERALS) do
        if s:sub(i, i + #word - 1) == word then
            return value, i + #word
        end
    end
    if s:sub(i, i + 3) == "null" then
        return nil, i + 4
    end
    return parse_number(s, i)
end

function M.decode(text)
    local value, i = parse_value(text, 1)
    assert(skip_ws(text, i) > #text, "json: trailing data at " .. i)
    return value
end

function M.read_file(path)
    local f = assert(io.open(path, "r"))
    local text = f:read("*a")
    f:close()
    return M.decode(text)
end

return M
