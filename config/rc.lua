-----------------------------------------------------------------------
-- luakit configuration file, more information at http://luakit.org/ --
-----------------------------------------------------------------------

require "lfs"

if unique then
    unique.new("org.luakit")
    -- Check for a running luakit instance
    if unique.is_running() then
        if uris[1] then
            for _, uri in ipairs(uris) do
                if lfs.attributes(uri) then uri = os.abspath(uri) end
                unique.send_message("tabopen " .. uri)
            end
        else
            unique.send_message("winopen")
        end
        luakit.quit()
    end
end

-- Load library of useful functions for luakit
require "lousy"

-- Small util functions to print output (info prints only when luakit.verbose is true)
function warn(...) io.stderr:write(string.format(...) .. "\n") end
function info(...) if luakit.verbose then io.stdout:write(string.format(...) .. "\n") end end

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

-- Load users webview class
-- ("$XDG_CONFIG_HOME/luakit/webview.lua" or "/etc/xdg/luakit/webview.lua")
require "webview"

-- Load users mode configuration
-- ("$XDG_CONFIG_HOME/luakit/modes.lua" or "/etc/xdg/luakit/modes.lua")
require "modes"

-- Load users keybindings
-- ("$XDG_CONFIG_HOME/luakit/binds.lua" or "/etc/xdg/luakit/binds.lua")
require "binds"

----------------------------------
-- Optional user script loading --
----------------------------------

require "webinspector"

-- Add sqlite3 cookiejar
require "cookies"

-- Cookie blocking by domain (extends cookies module)
-- Add domains to the whitelist at "$XDG_CONFIG_HOME/luakit/cookie.whitelist"
-- and blacklist at "$XDG_CONFIG_HOME/luakit/cookie.blacklist".
-- Each domain must be on it's own line and you may use "*" as a
-- wildcard character (I.e. "*google.com")
--require "cookie_blocking"

-- Block all cookies by default (unless whitelisted)
--cookies.default_allow = false

-- Add uzbl-like form filling
require "formfiller"

-- Add proxy support & manager
require "proxy"

-- Add quickmarks support & manager
require "quickmarks"

-- Add session saving/loading support
require "session"

-- Add command to list closed tabs & bind to open closed tabs
require "undoclose"

-- Add command to list tab history items
require "tabhistory"

-- Add greasemonkey-like javascript userscript support
require "userscripts"

-- Add bookmarks support
require "bookmarks"
require "bookmarks_chrome"

-- Add download support
require "downloads"
require "downloads_chrome"

-- Example using xdg-open for opening downloads / showing download folders
--downloads.add_signal("open-file", function (file, mime)
--    luakit.spawn(string.format("xdg-open %q", file))
--    return true
--end)

-- Add vimperator-like link hinting & following
require "follow"

-- Use a custom charater set for hint labels
--local s = follow.label_styles
--follow.label_maker = s.sort(s.reverse(s.charset("asdfqwerzxcv")))

-- Match only hint labels
--follow.pattern_maker = follow.pattern_styles.match_label

-- Add command history
require "cmdhist"

-- Add search mode & binds
require "search"

-- Add ordering of new tabs
require "taborder"

-- Save web history
require "history"
require "history_chrome"

require "introspector"

-- Add command completion
require "completion"

-- NoScript plugin, toggle scripts and or plugins on a per-domain basis.
-- `,ts` to toggle scripts, `,tp` to toggle plugins, `,tr` to reset.
-- Remove all "enable_scripts" & "enable_plugins" lines from your
-- domain_props table (in config/globals.lua) as this module will conflict.
--require "noscript"

require "follow_selected"
require "go_input"
require "go_next_prev"
require "go_up"

-----------------------------
-- End user script loading --
-----------------------------

-- Restore last saved session
local w = (session and session.restore())
if w then
    for i, uri in ipairs(uris) do
        w:new_tab(uri, i == 1)
    end
else
    -- Or open new window
    window.new(uris)
end

-------------------------------------------
-- Open URIs from other luakit instances --
-------------------------------------------

if unique then
    unique.add_signal("message", function (msg, screen)
        local cmd, arg = string.match(msg, "^(%S+)%s*(.*)")
        local w = lousy.util.table.values(window.bywidget)[1]
        if cmd == "tabopen" then
            w:new_tab(arg)
        elseif cmd == "winopen" then
            w = window.new((arg ~= "") and { arg } or {})
        end
        w.win.screen = screen
        w.win.urgency_hint = true
    end)
end

-- vim: et:sw=4:ts=8:sts=4:tw=80
