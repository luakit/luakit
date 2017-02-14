local capi = { widget = widget }
local get_theme = require("lousy.theme").get
local escape = require("lousy.util").escape

local data = setmetatable({}, { __mode = "k" })

local function destroy(tl)
    -- Destroy tab container widget
    tl.widget:destroy()
    -- Destroy private widget data
    data[tl] = nil
end

local function update_label(tl)
    local priv = data[tl]
    local view = priv.view
    local label = priv.label
    assert(view.type == "webview")
    local theme = get_theme()
    local fg, bg, nfg, snfg = theme.tab_fg, theme.tab_bg, theme.tab_ntheme, theme.selected_ntheme
    local lfg, bfg, gfg = theme.tab_loading_fg, theme.tab_notrust_fg, theme.tab_trust_fg

    local ntheme = nfg
    if view.is_loading then -- Show loading on all tabs
        ntheme = lfg
    elseif tl.current then
        local trusted = view:ssl_trusted()
        ntheme = snfg
        if trusted == false then
            ntheme = bfg
        elseif trusted then
            ntheme = gfg
        end
    end
    local tfmt = ' <span foreground="%s">%d</span> %s'
    local title = string.format(tfmt, ntheme or fg, priv.index, escape(tl.title))
    label.text = title
end

local function set_current(tl, current)
    local theme = get_theme()
    local ebox = tl.widget
    local priv = data[tl]
    local label = priv.label
    priv.current = current
    label.fg = (priv.current and theme.tab_selected_fg) or theme.tab_fg
    ebox.bg = (priv.current and theme.tab_selected_bg) or theme.tab_bg
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
                      or (view.is_loading and "Loading,,," or "(Untitled)")
    if new_title == tl.title then return end
    tl.title = new_title
    update_label(tl)
end

local function new(view, index)
    assert(type(view) == "widget" and view.type == "webview")
    assert(type(index) == "number")

    local tl = {
        widget = capi.widget{type = "eventbox"},
        destroy = destroy,
    }
    data[tl] = {
        label = capi.widget{type = "label"},
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

    -- Bind signals to associated view
    view:add_signal("property::title", function (v)
        data[tl].no_title = false
        update_title_and_label(tl)
    end)
    view:add_signal("property::uri",   function (v)
        update_title_and_label(tl)
    end)
    view:add_signal("load-status",     function (v, status)
        if status == "provisional" then data[tl].no_title = true end
        update_title_and_label(tl)
        update_label(tl)
    end)

    tl.widget:add_signal("mouse-enter", function (t)
        t.bg = theme.tab_hover_bg
    end)
    tl.widget:add_signal("mouse-leave", function (t)
        t.bg = (data[tl].current and theme.tab_selected_bg) or theme.tab_bg
    end)

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
        __index = function (tbl, key, val)
            if key == "current" or key == "index" then
                return data[tbl][key]
            end
        end,
    })

    return tl
end

return setmetatable({}, { __call = function(_, ...) return new(...) end })

-- vim: et:sw=4:ts=8:sts=4:tw=80
