---------------------------------------------------------------------------
-- @author Mason Larobina &lt;mason.larobina@gmail.com&gt;
-- @copyright 2010 Mason Larobina
---------------------------------------------------------------------------

--- Get environment we need
local setmetatable = setmetatable
local string = string
local util = require "lousy.util"
local error = error
local rawget = rawget

module "lousy.theme"

local function recursive_index(t, k, orig)
    local v = rawget(t, k)
    if v then return v end
    -- Save the original key name
    if not orig then orig = k end
    -- Knock a "level_" from the key name
    if string.find(k, "_") then
        k = string.sub(k, string.find(k, "_") + 1, -1)
        return recursive_index(t, k, orig)
    end
    return error(string.format("unable to find suitable match for: %q", orig))
end

-- Minimum default theme
local default_theme = {
    fg   = "#fff",
    bg   = "#000",
    font = "monospace normal 9",
}

--- Create recursively searching theme table.
-- @param t A table of key value pairs.
-- @return A table which searches recursively for a non-nil value.
-- (E.g. `widget.fg = theme.some_thing_fg` will do
-- `widget.fg = (theme.some_thing_fg or theme.thing_fg or theme.fg)`)
function from_table(t)
    t = util.table.join(default_theme, t)
    return setmetatable(t, { __index = recursive_index })
end
