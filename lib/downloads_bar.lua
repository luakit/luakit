local downloads = require("downloads")
local lousy = require("lousy")
local table = table
local add_binds = add_binds
local ipairs = ipairs
local pairs = pairs
local string = string
local window = window
local download = download

module("downloads.bar")

--- Methods for download bars.
methods = {
    --- Shows the download bar.
    -- @param bar The bar to show.
    show = function (bar) bar.ebox:show() end,

    --- Hides the download bar.
    -- @param bar The bar to hide.
    hide = function (bar) bar.ebox:hide() end,

    --- Updates the widgets in the download bar.
    -- @param bar The bar to refresh.
    refresh = function (bar)
        for _,wi in ipairs(bar.widgets) do
            bar:destroy_download_widget(wi)
        end
        bar.widgets = {}
        for i,_ in ipairs(downloads) do
            bar:add_download_widget(i)
        end
    end,

    -- Adds signals to the download bar.
    attach_signals = function (bar)
        bar.clear.ebox:add_signal("button-release", function (e, m, b)
            if b == 1 then clear() end
        end)
    end,

    -- Removes and destroys a download widget.
    destroy_download_widget = function (bar, wi)
        bar.layout:remove(wi.e)
        wi.e:destroy()
    end,

    -- Adds a new label to the download bar and registers signals for it.
    add_download_widget = function (bar, i)
        local wi = bar:assemble_download_widget(i)
        bar.layout:pack_start(wi.e, true, true, 0)
        bar:attach_download_widget_signals(wi)
        table.insert(bar.widgets, wi)
        bar:show()
    end,

    -- Creates and connects all widget components for a download widget.
    assemble_download_widget = function (bar, i)
        local wi = {
            e = eventbox(),
            h = hbox(),
            l = label(),
            p = label(),
            s = label(),
            f = label(),
            sep = label(),
            index = i,
        }
        wi.f.text = "✗"
        wi.f:hide()
        wi.s.text = "✔"
        wi.s:hide()
        wi.sep.text = "|"
        wi.h:pack_start(wi.p, false, false, 0)
        wi.h:pack_start(wi.f, false, false, 0)
        wi.h:pack_start(wi.s, false, false, 0)
        wi.h:pack_start(wi.l, true,  true,  0)
        wi.h:pack_end(wi.sep, false, false, 0)
        wi.e:set_child(wi.h)
        bar:apply_widget_theme(wi)
        bar:update_download_widget(wi)
        return wi
    end,

    -- Adds signals to a download widget.
    attach_download_widget_signals = function (bar, wi)
        wi.e:add_signal("button-release", function (e, m, b)
            local i  = wi.index
            local d = downloads[i]
            if b == 1 then
                if download.is_running(d) or d.status == "finished" then
                    open(i, bar.win)
                else
                    restart(i)
                end
            elseif b == 3 then
                if download.is_running(d) then
                    d:cancel()
                else
                    delete(i)
                end
            end
        end)
    end,

    --- Applies the theme to a download bar widget.
    apply_widget_theme = function (bar, wi)
        local theme = theme.get()
        for _,w in pairs({wi.e, wi.h, wi.l, wi.p, wi.f, wi.s, wi.sep}) do
            w.font = theme.dbar_font
        end
        local fg = theme.dbar_fg
        for _,w in pairs({wi.e, wi.h, wi.l, wi.sep}) do
            w.fg = fg
        end
        wi.p.fg = theme.dbar_loaded_fg
        wi.s.fg = theme.dbar_success_fg
        wi.f.fg = theme.dbar_error_fg
        for _,w in pairs({wi.e, wi.h}) do
            w.bg = theme.dbar_bg
        end
    end,

    -- Updates the text of the given download widget for the given download.
    update_download_widget = function (bar, wi)
        local i = wi.index
        local d = downloads[i]
        local basename = download.basename(d)
        wi.l.text = string.format("%i %s", i, basename)
        if d.status == "finished" then
            bar:indicate_success(wi)
        elseif d.status == "error" then
            bar:indicate_failure(wi)
        elseif d.status == "cancelled" then
            wi.p:hide()
        else
            wi.p.text = string.format('%.2f%%', d.progress * 100)
            local speed = download.speed(d)
            wi.l.text = string.format("%i %s (%.1f Kb/s)", i, basename, speed/1024)
        end
    end,

    -- Changes colors and widgets to indicate a download success.
    indicate_success = function (bar, wi)
        wi.p:hide()
        wi.s:show()
    end,

    -- Changes colors and widgets to indicate a download failure.
    indicate_failure = function (bar, wi)
        wi.p:hide()
        wi.f:show()
    end,
}

--- Creates a download bar widget.
-- To add the bar to a window, pack <code>bar.ebox</code>.
-- @return A download bar.
-- @field ebox The main eventbox of the bar.
-- @field clear The clear button of the bar.
function create()
    local bar = {
        layout    = hbox(),
        ebox      = eventbox(),
        clear     = {
            ebox  = eventbox(),
            label = label(),
        },
        widgets   = {},
    }
    -- Set metatable
    local mt = { __index=bar_methods }
    setmetatable(bar, mt)
    -- Setup signals
    bar:attach_signals()
    -- Pack bar
    bar.ebox:hide()
    bar.ebox:set_child(bar.layout)
    -- Pack download clear button
    local c = bar.clear
    bar.layout:pack_end(c.ebox, false, false, 0)
    c.ebox:set_child(c.label)
    c.label.text = "clear"
    return bar
end

-- Refreshes all download views.
local function refresh()
    for _,w in pairs(window.bywidget) do
        -- refresh bars
        local bar = w.dbar
        bar:refresh()
        if #downloads == 0 then bar:hide() end
    end
end

table.insert(downloads.refresh_functions, refresh)

window.init_funcs.download_bar = function (w)
    w.dbar = create()
    w.layout:pack_start(w.dbar.ebox, false, false, 0)
    w.layout:reorder_child(w.dbar.ebox, 2)
end

-- vim: et:sw=4:ts=8:sts=4:tw=80
