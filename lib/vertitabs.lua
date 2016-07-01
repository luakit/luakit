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
local string = require "string"

module "vertitabs"

local data = setmetatable({}, { __mode = "k" })

function update(tlist, tabs, current)
    -- Check function arguments
    assert(data[tlist] and type(tlist.widget) == "widget", "invalid tablist widget")
    assert(type(tabs) == "table", "invalid tabs table")
    assert(current >= 0 and current <= #tabs, "current index out of range")

    -- Hide tablist while re-drawing widgets
    tlist.widget:hide()

    if not tlist.visible then return end

    local labels = data[tlist].labels
    local vbox = data[tlist].vbox
    local theme = get_theme()

    -- Make some new tab labels
    local tcount, lcount = #tabs, #labels

    if tcount > lcount then
        for i = lcount+1, tcount do
            local tl = { ebox  = capi.widget{type = "eventbox"},
                         label = capi.widget{type = "label"} }
            tl.label.font = theme.tab_font
			tl.label.align = {x = 0 }
            tl.ebox.child = tl.label
            tl.ebox:add_signal("button-release", function (e, mods, but)
                return tlist:emit_signal("tab-clicked", i, mods, but)
            end)
            tl.ebox:add_signal("button-double-click", function (e, mods, but)
                return tlist:emit_signal("tab-double-clicked", i, mods, but)
            end)
            vbox:pack(tl.ebox, { expand = false, fill = false })
            labels[i] = tl
        end
    end

    -- Delete some tab labels
    if lcount > tcount then
        for i = tcount+1, lcount do
            local tl = table.remove(labels, tcount+1)
            vbox:remove(tl.ebox)
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

    -- Scroll current tab into view
    if labels[1] then
        local tab_delta = labels[1].ebox.height
        local tab_min = tab_delta * (current-1)
        local tab_max = tab_min + tab_delta
        local vp_min = tlist.widget.scroll.y
        local vp_max = vp_min + tlist.widget.height
        local scrolloff = 5

        if tab_min < vp_min then -- need to scroll up
            tlist.widget.scroll = { y = tab_min }
        end
        if tab_max > vp_max then -- need to scroll down
            tlist.widget.scroll = { y = tlist.widget.scroll.y + (tab_max - vp_max) }
        end
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
        widget  = capi.widget{type = "scrolled"},
        update  = update,
        destroy = destroy,
        visible = true,
    }

    local vbox = capi.widget{type = "vbox"}
    local theme = get_theme()
    vbox.bg = theme.tab_list_bg
    tlist.widget.child = vbox

    -- Save private widget data
    data[tlist] = { labels = {}, vbox = vbox, }

    -- Setup class signals
    signal.setup(tlist)

    return tlist
end

setmetatable(_M, { __call = function(_, ...) return new(...) end })
