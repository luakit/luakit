-- Luakit configuration file, more information at http://luakit.org/

-- Load library of useful functions for luakit
require "lousy"

-- Small util function to print output only when luakit.verbose is true
function info(...) if luakit.verbose then print(string.format(...)) end end

-- Load users global config
-- ("$XDG_CONFIG_HOME/luakit/globals.lua" or "/etc/xdg/luakit/globals.lua")
require "globals"

-- Load users theme
-- ("$XDG_CONFIG_HOME/luakit/theme.lua" or "/etc/xdg/luakit/theme.lua")
lousy.theme.init(lousy.util.find_config("theme.lua"))
theme = assert(lousy.theme.get(), "failed to load theme")

-- Load users window class
-- ("$XDG_CONFIG_HOME/luakit/window.lua" or "/etc/xdg/luakit/window.lua")
require "window"

-- Load users mode configuration
-- ("$XDG_CONFIG_HOME/luakit/modes.lua" or "/etc/xdg/luakit/modes.lua")
require "modes"

-- Load users webview class
-- ("$XDG_CONFIG_HOME/luakit/webview.lua" or "/etc/xdg/luakit/webview.lua")
require "webview"

-- Load users keybindings
-- ("$XDG_CONFIG_HOME/luakit/binds.lua" or "/etc/xdg/luakit/binds.lua")
require "binds"

-- Init scripts
require "follow"
require "formfiller"
require "go_input"
require "follow_selected"
require "go_next_prev"
require "go_up"
require "session"

-- Init bookmarks lib
require "bookmarks"
bookmarks.load()
bookmarks.dump_html()

-- Load session
local wins = session.load()
if wins then
    local w
    for _, win in ipairs(wins) do
        w = nil
        for _, item in ipairs(win) do
            if not w then
                w = window.new({item.uri})
            else
                w:new_tab(item.uri, item.current)
            end
        end
    end
    -- Load cli uris
    if #uris > 0 then
        if not w then
            window.new(uris)
        else
            for i, uri in ipairs(uris) do
                w:new_tab(uri, true)
            end
        end
    end
else
    window.new(uris)
end

-- vim: et:sw=4:ts=8:sts=4:tw=80
