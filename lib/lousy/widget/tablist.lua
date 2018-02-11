--- Luakit tablist widget.
--
-- @module lousy.widget.tablist
-- @copyright 2016 Aidan Holm <aidanholm@gmail.com>
-- @copyright 2010 Mason Larobina <mason.larobina@gmail.com>

local signal = require "lousy.signal"
local get_theme = require("lousy.theme").get
local tab = require "lousy.widget.tab"
local settings = require "settings"
local window = require "window"

local _M = {}

--- Width that tabs will shrink to before scrolling starts.
-- @type number
-- @readwrite
_M.min_width = 100

local data = setmetatable({}, { __mode = "k" })

local function destroy(tlist)
    tlist:set_notebook(nil)
    -- Destroy tablist container widget
    tlist.widget:destroy()
    -- Destroy private widget data
    data[tlist] = nil
end

local function scroll_current_tab_into_view(tlist)
    assert(data[tlist])
    if not data[tlist].notebook then return end -- switching notebook

    -- Only queue one scroll operation at a time
    if data[tlist].scroll_tab_queued then return end
    data[tlist].scroll_tab_queued = true

    -- When opening a new webview, the new tab widget's size is not yet allocated
    -- Queueing the scroll op avoids a lot of nasty hacks
    luakit.idle_add(function()
        -- Cancel if tlist already destroyed
        if not data[tlist] then return end

        -- Get the currently selected tab
        local notebook = data[tlist].notebook
        local view = notebook[notebook:current()]
        local tl = data[tlist].tabs[view]
        if not tl then return end

        local axis = data[tlist].orientation == "horizontal" and "x" or "y"
        local size = data[tlist].orientation == "horizontal" and "width" or "height"

        -- Scroll current tab into view
        local tab_delta = tl.widget[size]
        local tab_min = tab_delta * (tl.index-1)
        local tab_max = tab_min + tab_delta
        local vp_min = tlist.widget.scroll[axis]
        local vp_max = vp_min + tlist.widget[size]

        if tab_min < vp_min then -- need to scroll up
            tlist.widget.scroll = { [axis] = tab_min }
        end
        if tab_max > vp_max then -- need to scroll down
            tlist.widget.scroll = { [axis] = tlist.widget.scroll[axis] + (tab_max - vp_max) }
        end

        data[tlist].scroll_tab_queued = false
        return false
    end)
end

local function regenerate_tab_indices(tlist, a, b)
    if not data[tlist].notebook then return end -- switching notebook
    local low, high = a or 1, b or data[tlist].notebook:count()
    local views = data[tlist].notebook.children
    local max_pad_len = #tostring(data[tlist].notebook:count())

    for i=low, high do
        local view = views[i]
        local tl = data[tlist].tabs[view]
        local pad_len = data[tlist].orientation == "vertical" and (max_pad_len - #tostring(i)) or 0
        tl.index = (" "):rep(pad_len) .. tostring(i)
    end
end

local function update_tablist_visibility(tlist)
    if not data[tlist].notebook then return end -- switching notebook
    if settings.get_setting("tablist.always_visible") then
        tlist.widget.visible = true
    else
        tlist.widget.visible = data[tlist].notebook:count() > 1
    end
end

local function tablist_nb_page_added_cb(tlist, view, idx)
    local tl = tab(view, idx)
    data[tlist].tabs[view] = tl

    local orientation = data[tlist].orientation
    if _M.min_width and _M.min_width > 0 and orientation == "horizontal" then
        tl.widget.min_size = { w = _M.min_width }
    end
    data[tlist].box:pack(tl.widget, { expand = orientation == "horizontal", fill = true })
    data[tlist].box:reorder(tl.widget, idx-1)
    regenerate_tab_indices(tlist)

    tl.widget:add_signal("button-release", function (_, mods, but)
        return tlist:emit_signal("tab-clicked", tl.index, mods, but)
    end)
    tl.widget:add_signal("button-double-click", function (_, mods, but)
        return tlist:emit_signal("tab-double-clicked", tl.index, mods, but)
    end)

    update_tablist_visibility(tlist)
end

local function tablist_nb_page_removed_cb(tlist, view)
    local tl = data[tlist].tabs[view]
    data[tlist].box:remove(tl.widget)
    tl:destroy()
    regenerate_tab_indices(tlist)
    data[tlist].tabs[view] = nil

    update_tablist_visibility(tlist)
end

local function tablist_nb_switch_page_cb(tlist, view)
    local prev_view = data[tlist].prev_view
    data[tlist].prev_view = view

    if prev_view then
        local prev_tl = data[tlist].tabs[prev_view]
        if prev_tl then prev_tl.current = false end
    end
    local tl = data[tlist].tabs[view]
    tl.current = true

    scroll_current_tab_into_view(tlist)
end

local function tablist_nb_page_reordered_cb(tlist, view, idx)
    local tl = data[tlist].tabs[view]
    local old_idx = tl.index
    data[tlist].box:reorder(tl.widget, idx-1)
    regenerate_tab_indices(tlist, math.min(old_idx, idx), math.max(old_idx, idx))
    scroll_current_tab_into_view(tlist)
end

local function set_notebook(tlist, nb)
    assert(data[tlist])
    assert(nb == nil or (type(nb) == "widget" and nb.type == "notebook"))

    if data[tlist].notebook then
        -- Remove existing notebook signals
        for signame, func in pairs(data[tlist].handlers) do
            data[tlist].notebook:remove_signal(signame, func)
        end
        -- Destroy all tabs
        for _, tl in pairs(data[tlist].tabs) do
            data[tlist].box:remove(tl.widget)
            tl:destroy()
        end
        assert(#data[tlist].box.children == 0)
        data[tlist].notebook = nil
        data[tlist].tabs = nil
    end

    if nb then
        -- Attach notebook signal handlers
        data[tlist].handlers = {
            ["page-added"] = function (_, ...) tablist_nb_page_added_cb(tlist, ...) end,
            ["page-removed"] = function (_, ...) tablist_nb_page_removed_cb(tlist, ...) end,
            ["switch-page"] = function (_, ...) tablist_nb_switch_page_cb(tlist, ...) end,
            ["page-reordered"] = function (_, ...) tablist_nb_page_reordered_cb(tlist, ...) end,
        }
        for signame, func in pairs(data[tlist].handlers) do
            nb:add_signal(signame, func)
        end
        -- Make new tabs
        data[tlist].tabs = setmetatable({}, { __mode = "k" })
        local current_view = nb[nb:current()]
        for _, view in ipairs(nb.children) do
            tablist_nb_page_added_cb(tlist, view, nb:indexof(view))
            if view == current_view then
                tablist_nb_switch_page_cb(tlist, view, nb:indexof(view))
            end
        end
        data[tlist].notebook = nb
        update_tablist_visibility(tlist)
    end
end

--- Create a new tablist widget connected to a given notebook widget.
--
-- `orientation` should be one of `"horizontal"` or `"vertical"`.
--
-- @tparam widget notebook The notebook widget to connect to.
-- @tparam string orientation The orientation of the new tablist widget.
-- @treturn table A table containing the new widget and its interface.
function _M.new(notebook, orientation)
    assert(type(notebook) == "widget" and notebook.type == "notebook")
    assert(orientation == "horizontal" or orientation == "vertical")

    -- Create tablist widget table
    local tlist = {
        widget  = widget{type = "scrolled"},
        destroy = destroy,
        set_notebook = set_notebook,
    }

    local box = widget{type = orientation == "horizontal" and "hbox" or "vbox"}
    local theme = get_theme()
    box.bg = theme.tab_list_bg
    tlist.widget.child = box

    -- Hide scrollbar on horizontal tablist, since it covers the tabs
    if orientation == "horizontal" then
        tlist.widget.scrollbars = { h = "external", v = "never" }
    end

    -- Save private widget data
    data[tlist] = {
        box = box,
        orientation = orientation,
        visible = true,
    }

    -- Setup class signals
    signal.setup(tlist)
    tlist.widget:hide()

    -- Setup metatable interface
    setmetatable(tlist, {
        __newindex = function (tbl, key, val)
            if key == "visible" then
                data[tbl].visible = val
                update_tablist_visibility(tlist)
            end
        end,
        __index = function (tbl, key)
            if key == "visible" then return data[tbl][key] end
        end,
    })

    tlist:set_notebook(notebook)
    return tlist
end

settings.register_settings({
    ["tablist.always_visible"] = {
        type = "boolean",
        default = false,
        domain_specific = false,
        desc = "Whether the tab list should be visible with only a single tab open.",
    },
})

settings.add_signal("setting-changed", function (e)
    if e.key == "tablist.always_visible" then
        -- Hack: cause update_tablist_visibility() to be called for all windows
        for _, w in pairs(window.bywidget) do
            w.tablist.visible = w.tablist.visible
        end
    end
end)

return setmetatable(_M, { __call = function(_, ...) return _M.new(...) end })

-- vim: et:sw=4:ts=8:sts=4:tw=80
