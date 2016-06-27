-------------------------------------------------------------
-- @author Mason Larobina &lt;mason.larobina@gmail.com&gt; --
-- @copyright 2010 Mason Larobina                          --
-------------------------------------------------------------

-- Grab environment we need
local assert = assert
local setmetatable = setmetatable
local table = table
local type = type
local signal = require "lousy.signal"
local get_theme = require("lousy.theme").get
local capi = { widget = widget }

module "lousy.widget.tablist"

local data = setmetatable({}, { __mode = "k" })

function update(tlist, tabs, current)
    -- Check function arguments
    assert(data[tlist] and type(tlist.widget) == "widget", "invalid tablist widget")
    assert(type(tabs) == "table", "invalid tabs table")
    assert(current >= 0 and current <= #tabs, "current index out of range")

    -- Hide tablist while re-drawing widgets
    tlist.widget:hide()

    local labels = data[tlist].labels
    local hbox = data[tlist].hbox
    local theme = get_theme()

    -- Make some new tab labels
    local tcount, lcount = #tabs, #labels
    if tcount > lcount then
        for i = lcount+1, tcount do
            local tl = { ebox  = capi.widget{type = "eventbox"},
                         label = capi.widget{type = "label"} }
            tl.label.font = theme.tab_font
            tl.label.textwidth = 1
            if tlist.min_width  then
                tl.ebox.min_size = { w = tlist.min_width }
            end
            tl.ebox.child = tl.label
            tl.ebox:add_signal("button-release", function (e, mods, but)
                return tlist:emit_signal("tab-clicked", i, mods, but)
            end)
            tl.ebox:add_signal("button-double-click", function (e, mods, but)
                return tlist:emit_signal("tab-double-clicked", i, mods, but)
            end)
            hbox:pack(tl.ebox, { expand = true, fill = true })
            labels[i] = tl
        end
    end

    -- Delete some tab labels
    if lcount > tcount then
        for i = tcount+1, lcount do
            local tl = table.remove(labels, tcount+1)
            hbox:remove(tl.ebox)
            tl.label:destroy()
            tl.ebox:destroy()
        end
    end

    -- Update titles & theme
    local fg, bg = theme.tab_fg, theme.tab_bg
    for i = 1, tcount do
        local tab, l, e = tabs[i], labels[i].label, labels[i].ebox
        local title = tab.title or "(Untitled)"
        local fg, bg = tab.fg or fg, tab.bg or bg
        if l.text ~= title then l.text = title end
        if l.fg ~= fg then l.fg = fg end
        if e.bg ~= bg then e.bg = bg end
    end

    -- Show tablist
    if tcount > 0 then tlist.widget:show() end

    -- Emit update signal
    tlist:emit_signal("updated")

    return tlist
end

function destroy(tlist)
    -- Destroy all tablabels
    update(tlist, {}, 0)
    -- Destroy tablist container widget
    tlist.widget:destroy()
    -- Destroy private widget data
    data[tlist] = nil
end

function new()
    -- Create tablist widget table
    local tlist = {
        widget    = capi.widget{type = "scrolled"},
        update    = update,
        destroy   = destroy,
        min_width = 100,
    }

    local hbox = capi.widget{type = "hbox"}
    tlist.widget.child = hbox
    tlist.widget.scrollbars = { h = "external", v = "never" }

    -- Save private widget data
    data[tlist] = { labels = {}, hbox = hbox, }

    -- Setup class signals
    signal.setup(tlist)

    return tlist
end

setmetatable(_M, { __call = function(_, ...) return new(...) end })
-- vim: et:sw=4:ts=8:sts=4:tw=80
