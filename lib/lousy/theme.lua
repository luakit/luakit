--- lousy.theme library.
--
-- This module provides theme variable lookup for other modules.
--
-- @module lousy.theme
-- @author Mason Larobina <mason.larobina@gmail.com>
-- @author Damien Leone <damien.leone@gmail.com>
-- @author Julien Danjou <julien@danjou.info>
-- @copyright 2008-2009 Damien Leone, Julien Danjou, 2010 Mason Larobina

local util = require "lousy.util"

local theme

local _M = {}

-- Searches recursively for theme value.
-- (I.e. `w.bg = theme.some_thing_bg` ->
-- `w.bg = (theme.some_thing_bg or theme.thing_bg or theme.bg)`)
local function index(t, k)
    local v = rawget(t, k)
    if v then return v end
    -- Knock a "level_" from the key name
    if string.find(k, "_") then
        local ret = index(t, string.sub(k, string.find(k, "_") + 1, -1))
        -- Cache result
        if ret then t[k] = ret end
        return ret
    end
end

-- Minimum default theme
local default_theme = {
    fg   = "#fff",
    bg   = "#000",
    font = "9px monospace",
}

--- Load the theme table from file.
-- @tparam string path The filepath of the theme.
function _M.init(path)
    if not path then return error("error loading theme: no path specified") end
    -- Load theme table
    local success
    success, theme = pcall(function() return dofile(path) end)
    if not success then
        return error("error loading theme file " .. theme)
    elseif not theme then
        return error("error loading theme file " .. path)
    elseif type(theme) ~= "table" then
        return error("error loading theme: not a table")
    end
    -- Merge with defaults and set metatable
    theme = setmetatable(util.table.join(default_theme, theme), { __index = index })
    return theme
end

--- Get the current theme.
-- @treturn table The current theme table.
function _M.get()
    return theme
end

return _M

-- vim: et:sw=4:ts=8:sts=4:tw=80
