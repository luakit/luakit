--- lousy.mode library.
--
-- Mode setting and getting operations for objects.
--
-- @module lousy.mode
-- @author Mason Larobina <mason.larobina@gmail.com>
-- @copyright 2010 Mason Larobina <mason.larobina@gmail.com>

local _M = {}

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
function _M.is_modeable(object)
    local t = type(object)
    return ((t == "table" or t == "userdata" or t == "lightuserdata")
        and type(object.emit_signal) == "function")
end

--- Get the current mode for a given object.
-- @param object A mode-able object.
-- @treturn string The current mode of the given object, or the default mode of that object,
-- or "normal".
function _M.get(object)
    if not _M.is_modeable(object) then
        return error("attempt to get mode on non-modeable object")
    end
    return current_modes[object] or default_modes[object] or default_mode
end

--- Set the mode for a given object.
-- @param object A mode-able object.
-- @tparam string mode A mode name (e.g. "insert", "command", ...).
-- @treturn string The newly set mode.
function _M.set(object, mode, ...)
    if not _M.is_modeable(object) then
        return error("attempt to set mode on non-modeable object")
    end
    mode = mode or default_modes[object] or default_mode
    local changed = current_modes[object] ~= mode
    current_modes[object] = mode
    -- Raises a mode change signal on the object.
    if changed then
        object:emit_signal("mode-changed", mode, ...)
    end
    return mode
end

return setmetatable(_M, { __call = function(_, ...) return _M.set(...) end })

-- vim: et:sw=4:ts=8:sts=4:tw=80
