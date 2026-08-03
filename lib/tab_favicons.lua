--- UI mod: adds favicons to tabs.
--
-- This module modifies the default luakit user interface.
--
-- By default, tabs are numbered and do not feature the website icon
-- associated with the web page that is currently loaded. This module
-- removes the tab numbers and replaces them with the web page icon, for
-- an alternative appearance.
--
-- @module tab_favicons
-- @copyright 2017 Aidan Holm <aidanholm@gmail.com>

local _M = {}

local tab = require("lousy.widget.tab")

tab.add_signal("build", function (tl, view)
    local label = tl.widget.child
    local layout, fav, spin = widget{type = "hbox"}, widget{type="image"}, widget{type="spinner"}
    fav.min_size = { w = 16, h = 16 }
    spin.min_size = { w = 16, h = 16 }
    tl.widget.child = layout
    layout.homogeneous = false
    layout:pack(fav)
    layout:pack(spin)
    layout:pack(label, { expand = true, fill = true })

    label.margin_left = 6
    label.margin_right = 2
    layout.margin_left = 5
    layout.margin_right = 10

    local update_favicon = function (v)
        local uri = v.uri or "about:blank"
        if not fav.is_alive then return end

        if v.private then
            fav:filename("icons/tab-icon-private.png")
            return
        end
        if uri:match("^luakit://") then
            fav:filename("icons/tab-icon-chrome.png")
            return
        end
        if uri == "about:blank" then
            fav:filename("icons/tab-icon-page.png")
            return
        end

        local favicon_js = [=[
            favicon = document.evaluate('//link[(@rel="icon") or (@rel="shortcut icon")]/@href',
                document, null, XPathResult.STRING_TYPE, null).stringValue || '/favicon.ico';
        ]=]
        v:eval_js(favicon_js, { callback = function (favicon_uri, err)
            assert(not err, err)
            if not fav.is_alive then return end
            favicon_uri = favicon_uri:match("^luakit://(.*)")
            if favicon_uri then fav:filename(favicon_uri)
            elseif not fav:set_favicon_for_uri(uri) then
                fav:filename("icons/tab-icon-page.png")
            end
        end})
    end
    -- luakit:// URIs don't emit favicon signal
    -- view:add_signal("property::uri", function (v)
    --     if v.uri:match("^luakit://") then update_favicon(v) return end
    --     if webview.has_load_block(v) then update_favicon(v) return end
    -- end)
    view:add_signal("favicon", update_favicon)

    local load_status_cb = function (v, status)
        if v.is_loading then
            fav:hide() spin:show() spin:start()
        else
            fav:show() spin:hide() spin:stop()
        end
        if status == "finished" then update_favicon(v) end
    end
    view:add_signal("load-status", load_status_cb)

    tl.widget:add_signal("destroy", function ()
        view:remove_signal("favicon", update_favicon)
        view:remove_signal("property::uri", update_favicon)
        view:remove_signal("load-status", load_status_cb)
    end)

    load_status_cb(view, "provisional")
end)

-- Remove tab numbers
tab.label_format = "{title}"

return _M

-- vim: et:sw=4:ts=8:sts=4:tw=80
