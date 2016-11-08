local assert = assert
local setmetatable = setmetatable
local table = table
local type = type
local signal = require "lousy.signal"
local get_theme = require("lousy.theme").get
local capi = { widget = widget, luakit = luakit, }
local tab = require "lousy.widget.tab"
local pairs = pairs
local math = math

module "lousy.widget.tablist"

min_width = 100

local data = setmetatable({}, { __mode = "k" })

function destroy(tlist)
    -- Destroy tablist container widget
    tlist.widget:destroy()
    -- Destroy private widget data
    data[tlist] = nil
end

local function scroll_current_tab_into_view(tlist)
    assert(data[tlist])

    -- Only queue one scroll operation at a time
    if data[tlist].scroll_tab_queued then return end
    data[tlist].scroll_tab_queued = true

    -- When opening a new webview, the new tab widget's size is not yet allocated
    -- Queueing the scroll op avoids a lot of nasty hacks
    capi.luakit.idle_add(function()
        -- Get the currently selected tab
        local notebook = data[tlist].notebook
        local view = notebook[notebook:current()]
        tl = data[tlist].tabs[view]
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
    local low, high = a or 1, b or data[tlist].notebook:count()
    local views = data[tlist].notebook.children

    for i=low, high do
        local view = views[i]
        local tl = data[tlist].tabs[view]
        tl.index = i
    end
end

function new(notebook, orientation)
    assert(type(notebook) == "widget" and notebook.type == "notebook")
    assert(orientation == "horizontal" or orientation == "vertical")

    -- Create tablist widget table
    local tlist = {
        widget  = capi.widget{type = "scrolled"},
        destroy = destroy,
    }

    local box = capi.widget{type = orientation == "horizontal" and "hbox" or "vbox"}
    local theme = get_theme()
    box.bg = theme.tab_list_bg
    tlist.widget.child = box

    -- Hide scrollbar on horizontal tablist, since it covers the tabs
    if orientation == "horizontal" then
        tlist.widget.scrollbars = { h = "external", v = "never" }
    end

    -- Save private widget data
    data[tlist] = {
        tabs = setmetatable({}, { __mode = "k" }),
        box = box,
        notebook = notebook,
        orientation = orientation,
        visible = true,
    }

    -- Setup class signals
    signal.setup(tlist)

    -- Attach notebook signal handlers
    notebook:add_signal("page-added", function (nbook, view, idx)
        local tl = tab(view, idx)
        data[tlist].tabs[view] = tl

        if min_width and min_width > 0 and orientation == "horizontal" then
            tl.widget.min_size = { w = min_width }
        end
        box:pack(tl.widget, { expand = orientation == "horizontal", fill = true })
        box:reorder(tl.widget, idx-1)
        regenerate_tab_indices(tlist, idx)

        tl.widget:add_signal("button-release", function (e, mods, but)
            return tlist:emit_signal("tab-clicked", tl.index, mods, but)
        end)
        tl.widget:add_signal("button-double-click", function (e, mods, but)
            return tlist:emit_signal("tab-double-clicked", tl.index, mods, but)
        end)
    end)

    notebook:add_signal("page-removed", function (nbook, view, idx)
        local tl = data[tlist].tabs[view]
        box:remove(tl.widget)
        tl.widget:destroy()
        regenerate_tab_indices(tlist, idx)
        data[tlist].tabs[view] = nil
    end)

    notebook:add_signal("switch-page", function (nbook, view, idx)
        local prev_view = data[tlist].prev_view
        data[tlist].prev_view = view

        if prev_view then
            local prev_tl = data[tlist].tabs[prev_view]
            if prev_tl then prev_tl.current = false end
        end
        local tl = data[tlist].tabs[view]
        tl.current = true

        scroll_current_tab_into_view(tlist)
    end)

    notebook:add_signal("page-reordered", function (nbook, view, idx)
        local tl = data[tlist].tabs[view]
        local old_idx = tl.index
        box:reorder(tl.widget, idx-1)
        regenerate_tab_indices(tlist, math.min(old_idx, idx), math.max(old_idx, idx))
        scroll_current_tab_into_view(tlist)
    end)

    local function update_tablist_visibility()
        if tlist.visible and notebook:count() >= 2 then tlist.widget:show() end
        if not tlist.visible or notebook:count() < 2 then tlist.widget:hide() end
    end

    -- Show tablist widget if there is more than one tab
    notebook:add_signal("page-added", update_tablist_visibility)
    notebook:add_signal("page-removed", update_tablist_visibility)
    tlist.widget:hide()

    -- Setup metatable interface
    setmetatable(tlist, {
        __newindex = function (tbl, key, val)
            if key == "visible" then
                data[tbl].visible = val
                update_tablist_visibility()
            end
        end,
        __index = function (tbl, key, val)
            if key == "visible" then return data[tbl][key] end
        end,
    })

    return tlist
end

setmetatable(_M, { __call = function(_, ...) return new(...) end })
