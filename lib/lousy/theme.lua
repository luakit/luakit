---------------------------------------------------------------------------
-- @author Mason Larobina &lt;mason.larobina@gmail.com&gt;
-- @author Damien Leone &lt;damien.leone@gmail.com&gt;
-- @author Julien Danjou &lt;julien@danjou.info&gt;
-- @copyright 2008-2009 Damien Leone, Julien Danjou, 2010 Mason Larobina
---------------------------------------------------------------------------

--- Get environment we need
local setmetatable = setmetatable
local string = string
local util = require "lousy.util"
local error = error
local rawget = rawget
local pcall = pcall
local dofile = dofile
local type = type

--- Theme library for lousy.
module "lousy.theme"

local theme

-- Searches recursively for theme value.
-- (I.e. `w.bg = theme.some_thing_bg` ->
-- `w.bg = (theme.some_thing_bg or theme.thing_bg or theme.bg)`)
local function index(t, k)
    local v = rawget(t, k)
    if v then return v end
    -- Knock a "level_" from the key name
    if string.find(k, "_") then
        return index(t, string.sub(k, string.find(k, "_") + 1, -1))
    end
end

-- Minimum default theme
local default_theme = {
    fg   = "#fff",
    bg   = "#000",
    font = "monospace normal 9",
}

--- Load the theme table from file.
-- @param path The filepath of the theme.
function init(path)
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
-- @return The current theme table.
function get()
    return theme
end

-- vim: ft=lua:et:sw=4:ts=8:sts=4:tw=80
