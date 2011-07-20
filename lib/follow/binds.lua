------------------------------------------------------------
-- Follow binds for the link following lib                --
-- © 2010-2011 Fabian Streitel <karottenreibe@gmail.com>  --
-- © 2010-2011 Mason Larobina  <mason.larobina@gmail.com> --
------------------------------------------------------------

require "lousy"
local string = string
local buf = lousy.bind.buf
local add_binds, window = add_binds, window
local downloads = require "downloads"
local capi = { luakit = luakit }
local modes = require "follow.modes"

module "follow.binds"

-- Add link following binds
add_binds("normal", {
    -- Follow link
    buf("^f$", function (w,b,m)
        w:start_follow(modes.normal, nil, function (sig) return sig end)
    end),

    -- Focus element
    buf("^;;$", function (w,b,m)
        w:start_follow(modes.focus, "focus", function (sig) return sig end)
    end),

    -- Open new tab (optionally [count] times)
    buf("^F$", function (w,b,m)
        local name
        if (m.count or 0) > 1 then name = "open "..m.count.." tabs(s)" end
        w:start_follow(modes.uri, name or "open tab", function (uri, s)
            for i=1,(s.count or 1) do w:new_tab(uri, false) end
            return "root-active"
        end, m.count)
    end),

    -- Yank element uri or description into primary selection
    buf("^;y$", function (w,b,m)
        w:start_follow(modes.uri, "yank", function (uri)
            uri = string.gsub(uri, " ", "%%20")
            capi.luakit.set_selection(uri)
            w:notify("Yanked uri: " .. uri)
        end)
    end),

    -- Yank element description
    buf("^;Y$", function (w,b,m)
        w:start_follow(modes.desc, "yank desc", function (desc)
            capi.luakit.set_selection(desc)
            w:notify("Yanked desc: " .. desc)
        end)
    end),

    -- Follow a sequence of <CR> delimited hints in background tabs.
    buf("^;F$", function (w,b,m)
        w:start_follow(modes.uri, "multi tab", function (uri, s)
            w:new_tab(uri, false)
            w:set_mode("follow") -- re-enter follow mode with same state
        end)
    end),

    -- Download uri
    buf("^;s$", function (w,b,m)
        w:start_follow(modes.uri, "download", function (uri)
            downloads.add(uri)
            return "root-active"
        end)
    end),

    -- Open image src
    buf("^;i$", function (w,b,m)
        w:start_follow(modes.image, "open image", function (src)
            w:navigate(src)
            return "root-active"
        end)
    end),

    -- Open image src in new tab
    buf("^;I$", function (w,b,m)
        w:start_follow(modes.image, "tab image", function (src)
            w:new_tab(src)
            return "root-active"
        end)
    end),

    -- Open link
    buf("^;o$", function (w,b,m)
        w:start_follow(modes.uri, "open", function (uri)
            w:navigate(uri)
            return "root-active"
        end)
    end),

    -- Open link in new tab
    buf("^;t$", function (w,b,m)
        w:start_follow(modes.uri, "open tab", function (uri)
            w:new_tab(uri)
            return "root-active"
        end)
    end),

    -- Open link in background tab
    buf("^;b$", function (w,b,m)
        w:start_follow(modes.uri, "open bg tab", function (uri)
            w:new_tab(uri, false)
            return "root-active"
        end)
    end),

    -- Open link in new window
    buf("^;w$", function (w,b,m)
        w:start_follow(modes.uri, "open window", function (uri)
            window.new{uri}
            return "root-active"
        end)
    end),

    -- Set command `:open <uri>`
    buf("^;O$", function (w,b,m)
        w:start_follow(modes.uri, ":open", function (uri)
            w:enter_cmd(":open "   ..uri)
        end)
    end),

    -- Set command `:tabopen <uri>`
    buf("^;T$", function (w,b,m)
        w:start_follow(modes.uri, ":tabopen", function (uri)
            w:enter_cmd(":tabopen "..uri)
        end)
    end),

    -- Set command `:winopen <uri>`
    buf("^;W$", function (w,b,m)
        w:start_follow(modes.uri,    ":winopen",   function (uri)
            w:enter_cmd(":winopen "..uri)
        end)
    end),
})
