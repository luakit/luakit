--- UI mod: adds favicons to tabs.
--
-- @module tab_favicons
-- @copyright 2016 Aidan Holm <aidanholm@gmail.com>

local _M = {}

local tab = require("lousy.widget.tab")

tab.add_signal("build", function (tl, view)
    local label = tl.widget.child
    local layout, fav, spin = widget{type = "hbox"}, widget{type="image"}, widget{type="spinner"}
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
        if v.private then fav:filename("resources/icons/tab-icon-private.png")
        elseif uri:match("^luakit://") then fav:filename("resources/icons/tab-icon-chrome.png")
        elseif not fav:set_favicon_for_uri(uri) then
            fav:filename("resources/icons/tab-icon-page.png")
        end
    end
    view:add_signal("favicon", update_favicon)
    view:add_signal("property::uri", update_favicon) -- luakit:// URIs don't emit favicon signal

    local is_loading_cb = function (v)
        if v.is_loading then
            fav:hide() spin:show()
        else
            fav:show() spin:hide()
        end
    end
    view:add_signal("property::is_loading", is_loading_cb)

    tl.widget:add_signal("destroy", function ()
        view:remove_signal("favicon", update_favicon)
        view:remove_signal("property::uri", update_favicon)
        view:remove_signal("property::is_loading", is_loading_cb)
    end)

    spin:start();
    (view.is_loading and fav or spin):hide()
    update_favicon(view)
end)

-- Remove tab numbers
tab.label_format = "{title}"

return _M

-- vim: et:sw=4:ts=8:sts=4:tw=80
