--- New tab page for luakit.
-- @module newtab_chrome
-- @author Aidan Holm
-- @copyright 2016 Aidan Holm

local chrome = require "chrome"
local theme = require "theme"
local luakit = require "luakit"

local _M = {}

--- Path to a HTML file to use for the new tab page.
-- @type string
-- @default `$XDG_DATA_DIR/luakit/newtab.html`
_M.new_tab_file = luakit.data_dir .. "/newtab.html"

--- HTML string to use for the new tab page, if no HTML file is specified.
-- @type string
-- @default Single color page. `theme.bg` is used as the background color.
_M.new_tab_src = "<html><body bgcolor='" .. theme.bg .. "'></body></html>"

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

return _M

-- vim: et:sw=4:ts=8:sts=4:tw=80
