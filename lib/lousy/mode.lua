---------------------------------------------------------------------------
-- @author Mason Larobina &lt;mason.larobina@gmail.com&gt;
-- @copyright 2010 Mason Larobina
---------------------------------------------------------------------------

--- Grab environment we need
local setmetatable = setmetatable
local type = type
local io = io
local debug = debug
local error = error

--- Mode setting and getting operations for objects.
module("lousy.mode")

--- The default mode if no default modes are set.
local default_mode = "normal"

--- Weak table of objects current modes.
local current_modes = {}
setmetatable(current_modes, { __mode = "k" })

--- Weak table of objects default modes.
local default_modes = {}
setmetatable(default_modes, { __mode = "k" })

--- Check if the mode can be set on an object.
-- An object is considered mode-able if it has an "emit_signal" method.
-- @param object The object to check.
function is_modeable(object)
    return (object and object.emit_signal and type(object.emit_signal) == "function")
end

--- Get the current mode for a given object.
-- @param object A mode-able object.
-- @return The current mode of the given object, or the default mode of that object,
-- or "normal".
function get(object)
    if not is_modeable(object) then
        return error("attempt to get mode on non-modeable object")
    end
    return current_modes[object] or default_modes[object] or default_mode
end

--- Set the mode for a given object.
-- @param object A mode-able object.
-- @param mode A mode name (I.e. "insert", "command", ...)
-- @return The newly set mode.
function set(object, mode)
    if not is_modeable(object) then
        return error("attempt to set mode on non-modeable object")
    end
    local mode = mode or default_modes[object] or default_mode
    current_modes[object] = mode
    -- Raises a mode change signal on the object.
    object:emit_signal("mode-changed", mode)
    return mode
end

--- Set the default mode for a given object.
-- @param object A mode-able object.
-- @param mode A mode name (I.e. "insert", "command", ...)
function set_default(object, mode)
    if not is_modeable(object) then
        return error("attempt to set default mode on non-modeable object")
    end
    default_modes[object] = mode
end

setmetatable(_M, { __call = function(_, ...) return set(...) end })

-- vim: et:sw=4:ts=8:sts=4:tw=80
