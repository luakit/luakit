local setmetatable = setmetatable
local type = type

module("mode")

-- Internal mode to revert to if all else fails
local default_mode = "normal"

-- Weak table of windows modes
local current_modes = {}
setmetatable(current_modes, { __mode = "k" })

-- Weak table of default modes on a per-window basis
local default_modes = {}
setmetatable(default_modes, { __mode = "k" })

-- Check if `win` is a window widget
function iswindow(win)
    return type(win) == "widget" and win.type =="window"
end

-- Return the current mode for a given window widget
function get(win)
    if not iswindow(win) then
        -- TODO I should find some better way of printing error messages,
        -- maybe create lua wrappers around error, warn & debug C functions.
        print("Warning: attempt to set mode on non-window widget.")
        return nil
    end
    return current_modes[win] or default_modes[win] or default_mode
end

-- Set the current mode for a given window widget
function set(win, mode)
    if not iswindow(win) then
        print("Warning: attempt to get mode on non-window widget.")
        return nil
    end
    local mode = mode or default_modes[win] or default_mode
    current_modes[win] = mode
    -- Raise mode change signal on window widget
    win:emit_signal("mode-changed", mode)
    return mode
end

-- Set the default mode for a given window widget
function set_default(win, mode)
    if not iswindow(win) then
        print("Warning: attempt to set default mode on non-window widget.")
        return nil
    end
    default_modes[win] = mode
end

setmetatable(_M, { __call = function(_, ...) return set(...) end })
