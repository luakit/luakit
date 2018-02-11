--- lousy.signal library.
--
-- Mimic the luakit signal API functions for tables.
--
-- @module lousy.signal
-- @author Fabian Streitel <karottenreibe@gmail.com>
-- @author Mason Larobina <mason.larobina@gmail.com>
-- @copyright 2010 Fabian Streitel <karottenreibe@gmail.com>
-- @copyright 2010 Mason Larobina <mason.larobina@gmail.com>

local _M = {}

local clone_table = (require "lousy.util").table.clone

-- Private signal data for objects
local data = setmetatable({}, { __mode = "k" })

local methods = {
    "add_signal",
    "emit_signal",
    "remove_signal",
    "remove_signals",
}

local function get_data(object)
    local d = data[object]
    assert(d, "object isn't setup for signals")
    return d
end

--- Add a signal handler to an object, for a particular signal.
--
-- When a signal with the given name is emitted on the given object with
-- `emit_signal()`, the given callback function will be called, along with all
-- other signal handlers for the signal on the object.
--
-- The first argument passed to the callback function will be the object this
-- signal is emitted on (`object`), *unless* this object was setup for signals
-- with `module=true`, i.e. as a module object. In that case, the object will
-- not be passed to the callback at all. Subsequently, the callback
-- function will receive all additional arguments passed to `emit_signal()`.
--
-- `object` must have been set up for signals with `setup()`.
--
-- @param object The object on which to listen for signals.
-- @tparam string signame The name of the signal to listen for.
-- @tparam function func The signal handler callback function.
function _M.add_signal(object, signame, func)
    local signals = get_data(object).signals

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

--- Emit a signal on an object.
--
-- `object` must have been set up for signals with `setup()`.
--
-- @param object The object on which to emit the signal.
-- @tparam string signame The name of the signal to emit.
-- @param ... Additional arguments are passed any signal handlers called.
function _M.emit_signal(object, signame, ...)
    local d = get_data(object)
    -- Shallow clone the signal table, since it can change while executing
    -- signal handlers.
    local sigfuncs = clone_table(d.signals[signame] or {})

    msg.debug("emit_signal: %q on %s", signame, tostring(object))

    for _, sigfunc in ipairs(sigfuncs) do
        local ret
        if d.module then
            ret = { sigfunc(...) }
        else
            ret = { sigfunc(object, ...) }
        end
        if ret[1] ~= nil then
            return unpack(ret)
        end
    end
end

--- Remove a signal handler function from an object.
--
-- `object` must have been set up for signals with `setup()`.
--
-- @param object The object on which to remove a signal handler.
-- @tparam string signame The name of the signal handler to remove.
-- @tparam function func The signal handler callback function to remove.
-- @treturn[1] function Returns the removed callback function, if the signal
-- handler was found.
-- @treturn[2] nil If the signal handler was not found.
function _M.remove_signal(object, signame, func)
    local signals = get_data(object).signals
    local sigfuncs = signals[signame] or {}

    for i, sigfunc in ipairs(sigfuncs) do
        if sigfunc == func then
            table.remove(sigfuncs, i)
            -- Remove empty sigfuncs table
            if #sigfuncs == 0 then
                signals[signame] = nil
            end
            return func
        end
    end
end

--- Remove all signal handlers with a given name from an object.
-- @param object The object on which to remove a signal handler.
-- @tparam string signame The name of the signal handler to remove.
function _M.remove_signals(object, signame)
    local signals = get_data(object).signals
    signals[signame] = nil
end

--- Setup an object for signals.
--
-- Sets up the given object for signals, and returns the object.
--
-- If `module` is `true`, then the object is not passed to signal callback
-- functions as the first parameter when a signal is emitted.
--
-- `object` must *not* have been set up for signals with `setup()`.
--
-- @param object The object to set up for signals.
-- @tparam boolean module Whether this object should be treated as a module.
-- @return The given object.
function _M.setup(object, module)
    assert(not data[object], "given object already setup for signals")

    data[object] = { signals = {}, module = module }

    for _, fn in ipairs(methods) do
        assert(not object[fn], "signal object method conflict: " .. fn)
        if module then
            local func = _M[fn]
            object[fn] = function (...) return func(object, ...) end
        else
            object[fn] = _M[fn]
        end
    end

    return object
end

return _M

-- vim: et:sw=4:ts=8:sts=4:tw=80
