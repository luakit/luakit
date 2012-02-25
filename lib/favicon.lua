-- Grab environment
local os = os
local lousy = require "lousy"
local capi = { luakit = luakit, download = download, timer = timer }
local webview = webview
local window = window
local string = string
local setmetatable = setmetatable

module("favicon")

local settings = {
    dir = capi.luakit.cache_dir .. '/favicons/',
    default_icon = (capi.luakit.dev_paths and os.exists("./extras/luakit.png")) or
        os.exists("/usr/share/pixmaps/luakit.png")
}
lousy.util.mkdir(settings.dir)

webview.init_funcs.favicon = function (view, w)
    view:add_signal("property::icon_uri", function (v)
        local path = settings.dir .. capi.luakit.checksum(v.icon_uri)
        local function update()
            capi.luakit.idle_add(function ()
                if w.view == v then
                    w:update_icon()
                end
                return false
            end)
        end
        if (not os.exists(path)) then
            local dl = capi.download{ uri = v.icon_uri }
            dl.destination = path
            dl:start()
            local t = capi.timer{interval=1000}
            t:add_signal("timeout", function (t)
                if (dl.status ~= "started" or dl.status ~= "created") then t:stop() end
                if dl.status == "finished" then
                    if (dl.total_size == 0) then
                        capi.luakit.spawn(string.format("rm -f %q", path))
                    end
                    update()
                elseif dl.status == "error" then
                    capi.luakit.spawn(string.format("rm -f %q", path))
                end
            end)
            t:start()
        else
            update()
        end
    end)
end

webview.init_funcs.reset_icon_on_load_fail = function (view, w)
    view:add_signal("load-status", function (v, status)
        if (w.view == v and status == "failed") then
            capi.luakit.idle_add(function ()
                w:update_icon()
                return false
            end)
        end
    end)
end

window.init_funcs.notebook_signals_favicon = function (w)
    w.tabs:add_signal("switch-page", function (nbook, view, idx)
        capi.luakit.idle_add(function ()
            w:update_icon()
            return false
        end)
    end)
end

window.methods.update_icon = function (w)
    local path = settings.default_icon
    if (w.view.icon_uri) then
        path = settings.dir .. capi.luakit.checksum(w.view.icon_uri)
        if not os.exists(path) then
            path = settings.default_icon
        end
    end
    w.win.icon = path
end

setmetatable(_M, {
    __index    = function (_, k) return settings[k] end,
    __newindex = function (_, k, v)
        settings[k] = v
        if (k == 'dir') then
            lousy.util.mkdir(v)
        end
    end,
})
-- vim: et:sw=4:ts=8:sts=4:tw=80
