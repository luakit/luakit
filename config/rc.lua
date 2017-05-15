----------------------------------------------------------------------------------------
-- luakit configuration file, more information at https://aidanholm.github.io/luakit/ --
----------------------------------------------------------------------------------------

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
local lousy = require "lousy"

-- Load users global config
-- ("$XDG_CONFIG_HOME/luakit/globals.lua" or "/etc/xdg/luakit/globals.lua")
require "globals"

-- Load users theme
-- ("$XDG_CONFIG_HOME/luakit/theme.lua" or "/etc/xdg/luakit/theme.lua")
lousy.theme.init(lousy.util.find_config("theme.lua"))
assert(lousy.theme.get(), "failed to load theme")

-- Load users window class
-- ("$XDG_CONFIG_HOME/luakit/window.lua" or "/etc/xdg/luakit/window.lua")
local window = require "window"

-- Load users webview class
-- ("$XDG_CONFIG_HOME/luakit/webview.lua" or "/etc/xdg/luakit/webview.lua")
local webview = require "webview"

-- Left-aligned status bar widgets
require "widget.uri"
require "widget.hist"
require "widget.progress"

-- Right-aligned status bar widgets
require "widget.buf"
require "widget.ssl"
require "widget.tabi"
require "widget.scroll"

-- Load users mode configuration
-- ("$XDG_CONFIG_HOME/luakit/modes.lua" or "/etc/xdg/luakit/modes.lua")
require "modes"

-- Load users keybindings
-- ("$XDG_CONFIG_HOME/luakit/binds.lua" or "/etc/xdg/luakit/binds.lua")
require "binds"

----------------------------------
-- Optional user script loading --
----------------------------------

-- Add adblock
-- Enabled by default to work around bug https://github.com/aidanholm/luakit/issues/261
require "adblock"
require "adblock_chrome"

require "webinspector"

-- Add uzbl-like form filling
require "formfiller"

-- Add proxy support & manager
require "proxy"

-- Add quickmarks support & manager
require "quickmarks"

-- Add session saving/loading support
local session = require "session"

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
local downloads = require "downloads"
require "downloads_chrome"

-- Add automatic PDF downloading and opening
require "viewpdf"

-- Example using xdg-open for opening downloads / showing download folders
downloads.add_signal("open-file", function (file)
    luakit.spawn(string.format("xdg-open %q", file))
    return true
end)

-- Add vimperator-like link hinting & following
require "follow"

-- Use a custom charater set for hint labels
--local s = follow.label_styles
--follow.label_maker = s.sort(s.reverse(s.charset("asdfqwerzxcv")))

-- Match only hint labels
--follow.pattern_maker = follow.pattern_styles.match_label

-- Uncomment if you want to ignore case when matching
--follow.ignore_case = true

-- Add command history
require "cmdhist"

-- Add search mode & binds
require "search"

-- Add ordering of new tabs
require "taborder"

-- Save web history
require "history"
require "history_chrome"

require "help_chrome"
require "introspector_chrome"

-- Add command completion
require "completion"

-- Press Control-E while in insert mode to edit the contents of the currently
-- focused <textarea> or <input> element, using `xdg-open`
require "open_editor"

-- NoScript plugin, toggle scripts and or plugins on a per-domain basis.
-- `,ts` to toggle scripts, `,tp` to toggle plugins, `,tr` to reset.
-- Remove all "enable_scripts" & "enable_plugins" lines from your
-- domain_props table (in config/globals.lua) as this module will conflict.
--require "noscript"

require "follow_selected"
require "go_input"
require "go_next_prev"
require "go_up"

-- Block insecure content on secure pages by default
-- Add a bind to w:toggle_mixed_content() to temporarily enable mixed content
-- for the current tab.
require "mixed_content"

-- Filter Referer HTTP header if page domain does not match Referer domain
require_web_module("referer_control_wm")

require "error_page"

-- Add userstyles loader
require "styles"

-- Hide scrollbars on all pages
require "hide_scrollbars"

-- Automatically apply per-domain webview properties
require "domain_props"

-- Add a stylesheet when showing images
require "image_css"

-- Add a new tab page
require "newtab_chrome"

-----------------------------
-- End user script loading --
-----------------------------

-- Set the number of web processes to use. A value of 0 means 'no limit'.
luakit.process_limit = 0

-- Restore last saved session
local w = (not luakit.nounique) and (session and session.restore())
if w then
    for i, uri in ipairs(uris) do
        w:new_tab(uri, { switch = i == 1 })
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
        local ww = lousy.util.table.values(window.bywidget)[1]
        if cmd == "tabopen" then
            ww:new_tab(arg)
        elseif cmd == "winopen" then
            ww = window.new((arg ~= "") and { arg } or {})
        end
        ww.win.screen = screen
        ww.win.urgency_hint = true
    end)
end

-- vim: et:sw=4:ts=8:sts=4:tw=80
