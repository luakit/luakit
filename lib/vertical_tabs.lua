--- UI mod: vertical tabs.
--
-- This module moves the tab bar to the side.
--
-- @module vertical_tabs
-- @copyright 2017 Aidan Holm <aidanholm@gmail.com>

local _M = {}

local window = require("window")
local lousy = require("lousy")
local settings = require("settings")

local appear_cb = setmetatable({}, { __mode = "k" })

window.add_signal("build", function (w)
    -- Replace the existing tablist with a vertical one
    w.tablist:destroy()
    w.tablist = lousy.widget.tablist(w.tabs, "vertical")

    -- Add a paned widget: tablist on left, repack w.tabs on right
    local paned = widget{type="hpaned"}
    w.tabs.parent.child = nil

    do
        local left = settings.get_setting("vertical_tabs.side") == "left"
        local A, B = left and paned.pack1 or paned.pack2, left and paned.pack2 or paned.pack1
        A(paned, w.tablist.widget, { resize = false, shrink = true })
        B(paned, w.tabs)
    end

    local tlw = w.tablist.widget
    appear_cb[paned] = function ()
        if not tlw.visible then return end
        local left = settings.get_setting("vertical_tabs.side") == "left"
        local sbw = settings.get_setting("vertical_tabs.sidebar_width")
        paned.position = left and sbw or (paned.width - sbw)
        tlw:remove_signal("property::visible", appear_cb[paned])
        appear_cb[paned] = nil
    end
    tlw:add_signal("property::visible", appear_cb[paned])

    w.menu_tabs.child = paned
end)

settings.register_settings({
    ["vertical_tabs.sidebar_width"] = {
        type = "number", min = 0,
        default = 200,
    },
    ["vertical_tabs.side"] = {
        type = "enum",
        options = {
            ["left"] = { desc = "Left side of the screen.", label = "Left", },
            ["right"] = { desc = "Right side of the screen.", label = "Right", },
        },
        default = "left",
        desc = "The side of the window that the vertical tabs sidebar should be shown on.",
    },
})

settings.add_signal("setting-changed", function (e)
    if e.key == "vertical_tabs.side" then
        for _, w in pairs(window.bywidget) do
            local paned = w.menu_tabs.child
            assert(paned.type == "hpaned")

            local l, r, width, pos = paned.left, paned.right, paned.width, paned.position
            paned:remove(l)
            paned:remove(r)
            paned:pack1(r)
            paned:pack2(l)
            -- don't flip position if the position is unset
            if not appear_cb[paned] then
                paned.position = width - pos
            end
        end
    end
end)

settings.migrate_global("vertical_tabs.sidebar_width", "vertical_tab_width")

return _M

-- vim: et:sw=4:ts=8:sts=4:tw=80
