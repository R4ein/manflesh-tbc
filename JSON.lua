local _, ns = ...

local JSON = {}
ns.JSON = JSON

JSON.null = setmetatable({}, { __tostring = function() return "null" end })

local function decodeError(msg, pos)
    error(("Manflesh JSON parse error at position %d: %s"):format(pos or -1, msg), 0)
end

local function codepointToUtf8(cp)
    if cp < 0x80 then
        return string.char(cp)
    elseif cp < 0x800 then
        return string.char(0xC0 + math.floor(cp / 0x40), 0x80 + cp % 0x40)
    elseif cp < 0x10000 then
        return string.char(
            0xE0 + math.floor(cp / 0x1000),
            0x80 + math.floor(cp / 0x40) % 0x40,
            0x80 + cp % 0x40)
    else
        return string.char(
            0xF0 + math.floor(cp / 0x40000),
            0x80 + math.floor(cp / 0x1000) % 0x40,
            0x80 + math.floor(cp / 0x40) % 0x40,
            0x80 + cp % 0x40)
    end
end

local function skipWhitespace(s, i)
    local _, e = s:find("^[ \t\r\n]*", i)
    if e and e >= i then
        return e + 1
    end
    return i
end

local escapeMap = {
    ['"'] = '"', ['\\'] = '\\', ['/'] = '/',
    b = '\b', f = '\f', n = '\n', r = '\r', t = '\t',
}

local parseValue

local function parseString(s, i)
    i = i + 1
    local buf = {}
    local len = #s
    while i <= len do
        local c = s:sub(i, i)
        if c == '"' then
            return table.concat(buf), i + 1
        elseif c == '\\' then
            local n = s:sub(i + 1, i + 1)
            if n == 'u' then
                local hex = s:sub(i + 2, i + 5)
                local code = tonumber(hex, 16)
                if not code then decodeError("invalid \\u escape", i) end
                i = i + 6
                -- combine UTF-16 surrogate pairs into a single codepoint
                if code >= 0xD800 and code <= 0xDBFF and s:sub(i, i + 1) == '\\u' then
                    local low = tonumber(s:sub(i + 2, i + 5), 16)
                    if low and low >= 0xDC00 and low <= 0xDFFF then
                        code = 0x10000 + (code - 0xD800) * 0x400 + (low - 0xDC00)
                        i = i + 6
                    end
                end
                buf[#buf + 1] = codepointToUtf8(code)
            else
                local rep = escapeMap[n]
                if not rep then decodeError("invalid escape character", i) end
                buf[#buf + 1] = rep
                i = i + 2
            end
        else
            buf[#buf + 1] = c
            i = i + 1
        end
    end
    decodeError("unterminated string", i)
end

local function parseNumber(s, i)
    local start = i
    local len = #s
    while i <= len do
        local c = s:sub(i, i)
        if c:match("[%d%.eE%+%-]") then
            i = i + 1
        else
            break
        end
    end
    local numStr = s:sub(start, i - 1)
    local n = tonumber(numStr)
    if not n then decodeError("invalid number '" .. numStr .. "'", start) end
    return n, i
end

local function parseArray(s, i)
    i = i + 1
    local arr = {}
    i = skipWhitespace(s, i)
    if s:sub(i, i) == ']' then
        return arr, i + 1
    end
    while true do
        local value
        value, i = parseValue(s, i)
        arr[#arr + 1] = value
        i = skipWhitespace(s, i)
        local c = s:sub(i, i)
        if c == ',' then
            i = skipWhitespace(s, i + 1)
        elseif c == ']' then
            return arr, i + 1
        else
            decodeError("expected ',' or ']' in array", i)
        end
    end
end

local function parseObject(s, i)
    i = i + 1
    local obj = {}
    i = skipWhitespace(s, i)
    if s:sub(i, i) == '}' then
        return obj, i + 1
    end
    while true do
        i = skipWhitespace(s, i)
        if s:sub(i, i) ~= '"' then
            decodeError("expected string key in object", i)
        end
        local key
        key, i = parseString(s, i)
        i = skipWhitespace(s, i)
        if s:sub(i, i) ~= ':' then
            decodeError("expected ':' after object key", i)
        end
        i = skipWhitespace(s, i + 1)
        local value
        value, i = parseValue(s, i)
        obj[key] = value
        i = skipWhitespace(s, i)
        local c = s:sub(i, i)
        if c == ',' then
            i = i + 1
        elseif c == '}' then
            return obj, i + 1
        else
            decodeError("expected ',' or '}' in object", i)
        end
    end
end

function parseValue(s, i)
    i = skipWhitespace(s, i)
    local c = s:sub(i, i)
    if c == '{' then
        return parseObject(s, i)
    elseif c == '[' then
        return parseArray(s, i)
    elseif c == '"' then
        return parseString(s, i)
    elseif c == 't' then
        if s:sub(i, i + 3) == 'true' then return true, i + 4 end
        decodeError("invalid literal", i)
    elseif c == 'f' then
        if s:sub(i, i + 4) == 'false' then return false, i + 5 end
        decodeError("invalid literal", i)
    elseif c == 'n' then
        if s:sub(i, i + 3) == 'null' then return JSON.null, i + 4 end
        decodeError("invalid literal", i)
    elseif c == '' then
        decodeError("unexpected end of input", i)
    else
        return parseNumber(s, i)
    end
end

local ESCAPE = {
    ['"'] = '\\"', ['\\'] = '\\\\', ['\b'] = '\\b', ['\f'] = '\\f',
    ['\n'] = '\\n', ['\r'] = '\\r', ['\t'] = '\\t',
}

local function escapeChar(c)
    return ESCAPE[c] or ("\\u%04x"):format(c:byte())
end

local function encodeString(s)
    return '"' .. s:gsub('[%c"\\]', escapeChar) .. '"'
end

-- treated as a JSON array only if the keys are exactly 1..n with no gaps/extras
local function isArray(t)
    local n = 0
    for k in pairs(t) do
        if type(k) ~= "number" or k % 1 ~= 0 or k < 1 then
            return false
        end
        if k > n then n = k end
    end
    for i = 1, n do
        if t[i] == nil then return false end
    end
    return true, n
end

local encodeValue

local function encodeNumber(v)
    if v ~= v or v == math.huge or v == -math.huge then
        return "null"
    end
    if v % 1 == 0 then
        return ("%d"):format(v)
    end
    return ("%.14g"):format(v)
end

function encodeValue(v, buf)
    if v == JSON.null then
        buf[#buf + 1] = "null"
        return
    end
    local t = type(v)
    if t == "nil" then
        buf[#buf + 1] = "null"
    elseif t == "number" then
        buf[#buf + 1] = encodeNumber(v)
    elseif t == "boolean" then
        buf[#buf + 1] = v and "true" or "false"
    elseif t == "string" then
        buf[#buf + 1] = encodeString(v)
    elseif t == "table" then
        local arr, n = isArray(v)
        if arr then
            buf[#buf + 1] = "["
            for i = 1, n do
                if i > 1 then buf[#buf + 1] = "," end
                encodeValue(v[i], buf)
            end
            buf[#buf + 1] = "]"
        else
            buf[#buf + 1] = "{"
            local first = true
            for k, val in pairs(v) do
                if not first then buf[#buf + 1] = "," end
                first = false
                buf[#buf + 1] = encodeString(tostring(k))
                buf[#buf + 1] = ":"
                encodeValue(val, buf)
            end
            buf[#buf + 1] = "}"
        end
    else
        buf[#buf + 1] = "null"
    end
end

function JSON.encode(value)
    local buf = {}
    encodeValue(value, buf)
    return table.concat(buf)
end

function JSON.decode(text)
    if type(text) ~= "string" then
        return nil, "input is not a string"
    end
    local ok, result, rest = pcall(function()
        local value, i = parseValue(text, 1)
        i = skipWhitespace(text, i)
        return value, i
    end)
    if not ok then
        return nil, tostring(result)
    end
    if rest and rest <= #text then
        return nil, ("trailing characters after JSON value at position %d"):format(rest)
    end
    return result
end
