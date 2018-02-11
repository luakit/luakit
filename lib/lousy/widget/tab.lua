--- Luakit tab widget.
--
-- @module lousy.widget.tab
-- @copyright 2016 Aidan Holm <aidanholm@gmail.com>

local get_theme = require("lousy.theme").get
local escape = require("lousy.util").escape

local _M = {}

require("lousy.signal").setup(_M, true)

local data = setmetatable({}, { __mode = "k" })

--- Table of functions used to generate parts of the tab label text
-- @readwrite
_M.label_subs = {
    index_fg = function (tl)
        local view = data[tl].view
        local theme = get_theme()
        local nfg, snfg = theme.tab_ntheme, theme.selected_ntheme
        local lfg, bfg, gfg = theme.tab_loading_fg, theme.tab_notrust_fg, theme.tab_trust_fg

        if view.is_loading then -- Show loading on all tabs
            return lfg
        elseif tl.current then
            local trusted = view:ssl_trusted()
            if trusted == false then return bfg
            elseif trusted then return gfg
            else return snfg end
        else
            return nfg
        end
    end,
    index = function (tl) return data[tl].index end,
    title = function (tl) return escape(tl.title) end,
}

--- Format string which defines the text of each tab label
-- @type string
-- @readwrite
_M.label_format = '<span foreground="{index_fg}" font="Monospace">{index} </span>{title}'

local function destroy(tl)
    -- Destroy tab container widget
    tl.widget:destroy()
    -- Remove signal handlers: tab destruction ≠ view destruction (:tabdetach)
    for sig, func in pairs(data[tl].view_handlers) do
        data[tl].view:remove_signal(sig, func)
    end
    -- Destroy private widget data
    data[tl] = nil
end

local function update_label(tl)
    local label = data[tl].label
    label.text = string.gsub(_M.label_format, "{([%w_]+)}", function (k)
        return _M.label_subs[k](tl)
    end)
end

local function set_current(tl, current)
    local theme = get_theme()
    local ebox = tl.widget
    local priv = data[tl]
    local label = priv.label
    priv.current = current
    label.fg = (priv.current and theme.tab_selected_fg) or theme.tab_fg
    if priv.view.private then
        ebox.bg = (priv.current and theme.selected_private_tab_bg) or theme.private_tab_bg
    else
        ebox.bg = (priv.current and theme.tab_selected_bg) or theme.tab_bg
    end
    update_label(tl)
end

local function set_index(tl, index)
    data[tl].index = index
    update_label(tl)
end

local function update_title_and_label(tl)
    local view = data[tl].view
    assert(type(view) == "widget" and view.type == "webview")
    local new_title = (not data[tl].no_title and view.title ~= "" and view.title)
                      or view.uri
                      or (view.is_loading and "Loading…" or "(Untitled)")
    if new_title == tl.title then return end
    tl.title = new_title
    update_label(tl)
end

local function new(view, index)
    assert(type(view) == "widget" and view.type == "webview")
    assert(type(index) == "number")

    local tl = {
        widget = widget{type = "eventbox"},
        destroy = destroy,
    }
    data[tl] = {
        label = widget{type = "label"},
        view = view,
        index = index,
        current = false,
        no_title = false,
    }

    local theme = get_theme()
    local label = data[tl].label
    tl.widget.child = label
    label.font = theme.tab_font
    label.align = { x = 0 }
    label.margin_left = 10
    label.margin_right = 10

    -- Bind signals to associated view
    data[tl].view_handlers = {
        ["property::title"] = function ()
            data[tl].no_title = false
            update_title_and_label(tl)
        end,
        ["property::uri"] = function ()
            update_title_and_label(tl)
        end,
        ["load-status"] = function (_, status)
            if status == "provisional" then data[tl].no_title = true end
            update_title_and_label(tl)
            update_label(tl)
        end,
    }
    for sig, func in pairs(data[tl].view_handlers) do
        view:add_signal(sig, func)
    end

    tl.widget:add_signal("mouse-enter", function (t)
        t.bg = theme.tab_hover_bg
    end)
    tl.widget:add_signal("mouse-leave", function (t)
        local priv = data[tl]
        if priv.view.private then
            t.bg = (priv.current and theme.selected_private_tab_bg) or theme.private_tab_bg
        else
            t.bg = (priv.current and theme.tab_selected_bg) or theme.tab_bg
        end
    end)

    _M.emit_signal("build", tl, view)

    -- Set new title
    update_title_and_label(tl)
    set_current(tl, false)

    -- Setup metatable interface
    setmetatable(tl, {
        __newindex = function (tbl, key, val)
            return ({
                current = set_current,
                index = set_index,
            })[key](tbl, val)
        end,
        __index = function (tbl, key)
            if key == "current" or key == "index" then
                return data[tbl][key]
            end
        end,
    })

    return tl
end

return setmetatable(_M, { __call = function(_, ...) return new(...) end })

-- vim: et:sw=4:ts=8:sts=4:tw=80
