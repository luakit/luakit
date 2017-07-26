--- Luakit tablist widget.
--
-- @module lousy.widget.tablist
-- @copyright 2016 Aidan Holm
-- @copyright 2010 Mason Larobina

local signal = require "lousy.signal"
local get_theme = require("lousy.theme").get
local tab = require "lousy.widget.tab"

local _M = {}

--- Width that tabs will shrink to before scrolling starts.
-- @type number
-- @readwrite
_M.min_width = 100

local data = setmetatable({}, { __mode = "k" })

local function destroy(tlist)
    -- Destroy tablist container widget
    tlist.widget:destroy()
    -- Remove signal handlers
    for _, entry in pairs(data[tlist].handlers) do
        data[tlist].notebook:remove_signal(entry.signame, entry.func)
    end
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
        tabs = setmetatable({}, { __mode = "k" }),
        box = box,
        notebook = notebook,
        orientation = orientation,
        visible = true,
    }

    -- Setup class signals
    signal.setup(tlist)

    -- Attach notebook signal handlers
    local function update_tablist_visibility()
        if tlist.visible and notebook:count() >= 2 then tlist.widget:show() end
        if not tlist.visible or notebook:count() < 2 then tlist.widget:hide() end
    end

    data[tlist].handlers = {
        {
            signame = "page-added",
            func = function (_, view, idx)
                local tl = tab(view, idx)
                data[tlist].tabs[view] = tl

                if _M.min_width and _M.min_width > 0 and orientation == "horizontal" then
                    tl.widget.min_size = { w = _M.min_width }
                end
                box:pack(tl.widget, { expand = orientation == "horizontal", fill = true })
                box:reorder(tl.widget, idx-1)
                regenerate_tab_indices(tlist)

                tl.widget:add_signal("button-release", function (_, mods, but)
                    return tlist:emit_signal("tab-clicked", tl.index, mods, but)
                end)
                tl.widget:add_signal("button-double-click", function (_, mods, but)
                    return tlist:emit_signal("tab-double-clicked", tl.index, mods, but)
                end)
            end,
        },
        {
            signame = "page-removed",
            func = function (_, view)
                local tl = data[tlist].tabs[view]
                box:remove(tl.widget)
                tl:destroy()
                regenerate_tab_indices(tlist)
                data[tlist].tabs[view] = nil
            end,
        },
        {
            signame = "switch-page",
            func = function (_, view)
                local prev_view = data[tlist].prev_view
                data[tlist].prev_view = view

                if prev_view then
                    local prev_tl = data[tlist].tabs[prev_view]
                    if prev_tl then prev_tl.current = false end
                end
                local tl = data[tlist].tabs[view]
                tl.current = true

                scroll_current_tab_into_view(tlist)
            end,
        },
        {
            signame = "page-reordered",
            func = function (_, view, idx)
                local tl = data[tlist].tabs[view]
                local old_idx = tl.index
                box:reorder(tl.widget, idx-1)
                regenerate_tab_indices(tlist, math.min(old_idx, idx), math.max(old_idx, idx))
                scroll_current_tab_into_view(tlist)
            end,
        },
        -- Show tablist widget if there is more than one tab
        { signame = "page-added", func = update_tablist_visibility, },
        { signame = "page-removed", func = update_tablist_visibility, },
    }
    for _, entry in pairs(data[tlist].handlers) do
        notebook:add_signal(entry.signame, entry.func)
    end

    tlist.widget:hide()

    -- Setup metatable interface
    setmetatable(tlist, {
        __newindex = function (tbl, key, val)
            if key == "visible" then
                data[tbl].visible = val
                update_tablist_visibility()
            end
        end,
        __index = function (tbl, key)
            if key == "visible" then return data[tbl][key] end
        end,
    })

    return tlist
end

return setmetatable(_M, { __call = function(_, ...) return _M.new(...) end })

-- vim: et:sw=4:ts=8:sts=4:tw=80
