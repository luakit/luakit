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

-- Init formfiller lib
require "formfiller"

-- Init bookmarks lib
require "bookmarks"
bookmarks.load()
bookmarks.dump_html()

-- Init downloads lib
require "downloads"
downloads.dir = luakit.get_special_dir("DOWNLOAD") or (os.getenv("HOME") .. "/downloads")
downloads.rules = {
    ["scholar\.google\."] = os.getenv("HOME") .. "/downloads/pdfs"
 -- to download everything without asking:
 -- [".*"               ] = downloads.dir
}
downloads.warn_file = downloads.open_file
downloads.open_file = function (f, m, wi)
    local mime_types = {
        ["^text/"        ] = "gvim",
        ["^video/"       ] = "mplayer",
        ["/pdf$"         ] = "evince",
    }
    local extensions = {
        ["mp3"           ] = "mplayer",
    }

    for p,e in pairs(mime_types) do
        if string.match(m, p) then
            luakit.spawn(string.format('%s "%s"', e, f))
            return
        end
    end

    local _,_,ext = string.find(f, ".*%.([^.]*)")
    for p,e in pairs(extensions) do
        if string.match(ext, p) then
            luakit.spawn(string.format('%s "%s"', e, f))
            return
        end
    end

    downloads.warn_file(f, m, wi)
end

window.new(uris)

-- vim: et:sw=4:ts=8:sts=4:tw=80
