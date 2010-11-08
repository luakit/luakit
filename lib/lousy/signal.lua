--------------------------------------------------------------
-- Mimic the luakit signal api functions for tables         --
-- @author Fabian Streitel &lt;karottenreibe@gmail.com&gt;  --
-- @author Mason Larobina  &lt;mason.larobina@gmail.com&gt; --
-- @copyright 2010 Fabian Streitel, Mason Larobina          --
--------------------------------------------------------------

-- Grab environment we need
local assert = assert
local io = io
local ipairs = ipairs
local setmetatable = setmetatable
local string = string
local table = table
local tostring = tostring
local type = type
local unpack = unpack
local verbose = luakit.verbose

--- Provides a signal API similar to GTK's signals.
module("lousy.signal")

-- Private signal data for objects
local data = setmetatable({}, { __mode = "k" })

local methods = {
    "add_signal",
    "emit_signal",
    "remove_signal",
    "remove_signals",
}

local function get_signals(object)
    -- Check table supports signals
    local signals = data[object]
    assert(signals, "given object doesn't support signals")
    return signals
end

function add_signal(object, signame, func)
    local signals = get_signals(object)

    -- Check signal name
    assert(type(signame) == "string", "invalid signame type: " .. type(signame))
    assert(string.match(signame, "^[%w_%-:]+$"), "invalid chars in signame: " .. signame)

    -- Check handler function
    assert(type(func) == "function", "invalid handler function")

    -- Add to signals table
    if not signals[signame] then
        signals[signame] = { func, }
    else
        table.insert(signals[signame], func)
    end
end

function emit_signal(object, signame, ...)
    local sigfuncs = get_signals(object)[signame] or {}

    if verbose then
        io.stderr:write(string.format("D: lousy.signal: emit_signal: %q on %s", signame, tostring(object)))
    end

    for _, sigfunc in ipairs(sigfuncs) do
        local ret = { sigfunc(object, ...) }
        if #ret > 0 and ret[1] ~= nil then
            return unpack(ret)
        end
    end
end

-- Remove a signame & function pair.
function remove_signal(object, signame, func)
    local sigfuncs = get_signals(object)[signame] or {}

    for i, sigfunc in ipairs(sigfuncs) do
        if sigfunc == func then
            return table.remove(sigfuncs, i)
        end
    end
end

-- Remove all signal handlers with the given signame.
function remove_signals(object, signame)
    local signals = get_signals(object) or {}
    signals[signame] = nil
end

function setup(object)
    assert(not data[object], "given object already setup for signals")

    data[object] = {}

    for _, func in ipairs(methods) do
        assert(not object[func], "signal object method conflict: " .. func)
        object[func] = _M[func]
    end

    return object
end

-- vim: et:sw=4:ts=8:sts=4:tw=80
