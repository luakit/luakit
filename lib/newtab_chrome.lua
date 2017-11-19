--- New tab page for luakit.
--
-- This module provides <luakit://newtab/>, the luakit new
-- tab page. This page is opened by default when opening a new tab without
-- specifying a URL to open.
--
-- # Customization
--
-- The easiest way to customize what is shown at
-- <luakit://newtab/> is to create a HTML file at the
-- path specified by `newtab_chrome.new_tab_file`. By default, this is the
-- `newtab.html` file located in the luakit data directory.
--
-- If this file exists, then its contents will be used to provide the new tab
-- page. Otherwise, the value of `newtab_chrome.new_tab_src` is used.
--
-- # Files and Directories
--
-- - The default path for the new-tab file is `newtab.html`, located in the luakit data directory.
--
-- @module newtab_chrome
-- @author Aidan Holm
-- @copyright 2016 Aidan Holm <aidanholm@gmail.com>

local chrome = require "chrome"
local theme = require "theme"
local luakit = require "luakit"
local settings = require "settings"

local _M = {}

--- Path to a HTML file to use for the new tab page.
--The default value is `$XDG_DATA_DIR/luakit/newtab.html`.
-- @type string
-- @readwrite
_M.new_tab_file = luakit.data_dir .. "/newtab.html"

--- HTML string to use for the new tab page, if no HTML file is specified.
-- The default value produces a page with no content and a single solid
-- background color. `theme.bg` is used as the background color.
-- @type string
-- @readwrite
_M.new_tab_src = ([==[
    <html>
        <head><title>New Tab</title></head>
        <body bgcolor="{bgcolor}"></body>
    </html>
]==]):gsub("{bgcolor}", theme.bg)

local function load_file_contents(file)
    if not file then return nil end
    local f = io.open(file, "rb")
    if not f then return nil end
    local content = f:read("*all")
    f:close()
    return content
end

chrome.add("newtab", function ()
    return load_file_contents(_M.new_tab_file) or _M.new_tab_src
end)

luakit.idle_add(function ()
    local undoclose = package.loaded.undoclose
    if not undoclose then return end
    undoclose.add_signal("save", function (view)
        local uri, hist = view.uri or "", view.history
        if uri:match("^luakit://newtab/?") and #hist.items == 1 then
            return false
        end
    end)
end)

require "window"
settings.override_setting("window.new_tab_page", "luakit://newtab/")

return _M

-- vim: et:sw=4:ts=8:sts=4:tw=80
