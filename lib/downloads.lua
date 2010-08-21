require("lousy")

local table = table
local util = lousy.util
local string = string
local pairs = pairs
local timer = timer
local download = download
local dialog = dialog
local setmetatable = setmetatable
local eventbox = function() return widget{type="eventbox"} end
local hbox     = function() return widget{type="hbox"}     end
local label    = function() return widget{type="label"}    end

--- Provides internal support for downloads and a download bar.
module("downloads")

--- A table that contains rules for download locations.
--    Each key in the table is a pattern, each value a directory
--    in the local filesystem. If the pattern of a newly added
--    download matches one of the rules, it will be automatically
--    downloaded to that folder.
rules = {}

--- Used to open a download when clicked on.
--    The default implementation just displays an error message.
--    @param f The path to the file to open.
--    @param mt The inferred mime type of the file.
--    @param wi The download widget associated with the file.
open_file = function(f, mt, wi)
    if wi then
        local te = wi.text
        wi.text = "Can't open"
        local t = timer{interval=2000}
        t:add_signal("timeout", function(t)
            wi.text = te
            t:stop()
        end)
        t:start()
    end
end

--- The default directory for a new download.
dir = "/home"

--- Prototype for a download bar.
bar_mt = {
    --- Shows the download bar.
    --    @param bar The bar to show.
    show = function(bar) bar.ebox:show() end,

    --- Hides the download bar.
    --    @param bar The bar to hide.
    hide = function(bar) bar.ebox:hide() end,

    --- Removes the given download from the download bar and cancels it if
    --    necessary.
    --    Hides the bar if all downloads were removed.
    --    @param bar The bar to modify.
    --    @param d The download to remove.
    remove_download = function(bar, d)
        for i,t in pairs(bar.downloads) do
            if t.download == d then
                bar.layout:remove(t.widget.e)
                table.remove(bar.downloads, i)
                if d.status == "started" then d:cancel() end
                break
            end
        end
        if #bar.downloads == 0 then bar.ebox:hide() end
    end,

    --- Removes all finished, cancelled or aborted downloads from a downlod bar.
    --    Hides the bar if all downloads were removed.
    --    @param bar The bar to modify.
    clear_done = function(bar)
        for i,t in pairs(util.table.clone(bar.downloads)) do
            local d = t.download
            if d.status ~= "created" and d.status ~= "started" then
                bar:remove_download(d)
            end
        end
    end,

    --- Adds a download to the download bar.
    --    Tries to apply one of the <code>rules</code>. If that fails,
    --    asks the user to choose a location with a save dialog.
    --    @param bar The bar to modify.
    --    @param uri The uri to add.
    --    @param win The window to display the dialog over.
    download = function(bar, uri, win)
        local d = download{uri=uri}
        local file

        -- ask da rulez
        for p,dir in pairs(rules) do
            if string.match(uri, p) then
                file = string.format("%s/%s", dir, d.suggested_filename)
            end
        end

        -- if no rule matched, ask the user
        file = file or dialog.save("Save file", win, dir, d.suggested_filename)

        -- if the user didn't abort or a rule matched: download the file
        if file then
            d.destination = file
            d:start()
            local t = bar:add_download_widget(d, bar.theme)
            table.insert(bar.downloads, t)
            bar:show()
            -- start refresh timer
            if not bar.timer.started then bar.timer:start() end
        end
    end,

    --- Updates the widgets in the download bar.
    --    Stops the refresh timer when all downloads are stopped.
    --    @param bar The bar to refresh.
    refresh = function(bar)
        local all_finished = true
        -- update
        for _,t in pairs(bar.downloads) do
            local d = t.download
            bar:update_download_widget(t)
            if d.status == "created" or d.status == "started" then
                all_finished = false
            end
        end
        -- stop timer if everyone finished
        if all_finished then
            bar.timer:stop()
        end
    end,
}

-- Internal helper functions, which operate on a download bar.
local download_helpers = {
    -- Adds signals to the download bar.
    attach_signals = function(bar)
        bar.clear.ebox:add_signal("button-release", function(e, m, b)
            if b == 1 then bar:clear_done() end
        end)
    end,

    -- Adds signals to a download widget.
    attach_download_widget_signals = function(bar, t)
        t.widget.e:add_signal("button-release", function(e, m, b)
            local d  = t.download
            if b == 1 then
                -- open file
                local ti = timer{interval=1000}
                ti:add_signal("timeout", function(ti)
                    if d.status == "finished" then
                        ti:stop()
                        open_file(d.destination, d.mime_type, t.widget.l)
                    end
                end)
                ti:start()
            elseif b == 3 then
                -- remove download
                bar:remove_download(d)
            end
        end)
    end,

    --- Applies a theme to a download bar widget.
    apply_widget_theme = function(bar, t, theme)
        local wi = t.widget
        for _,w in pairs({wi.e, wi.h, wi.l, wi.p, wi.f, wi.s, wi.sep}) do
            w.font = theme.download_font or theme.downloadbar_font or theme.font
        end
        local fg = theme.download_fg or theme.downloadbar_fg or theme.fg
        for _,w in pairs({wi.e, wi.h, wi.l, wi.sep}) do
            w.fg = fg
        end
        wi.p.fg = theme.download_loaded_fg  or theme.loaded_fg  or fg
        wi.s.fg = theme.download_success_fg or theme.success_fg or fg
        wi.f.fg = theme.download_failure_fg or theme.failure_fg or fg
        for _,w in pairs({wi.e, wi.h}) do
            w.bg = theme.download_bg or theme.downloadbar_bg or theme.bg
        end
    end,

    -- Creates and connects all widget components for a download widget.
    assemble_download_widget = function(bar, t, theme)
        t.widget = {
            e = eventbox(),
            h = hbox(),
            l = label(),
            p = label(),
            s = label(),
            f = label(),
            sep = label(),
        }
        local wi = t.widget
        wi.f.text = "✗"
        wi.f:hide()
        wi.s.text = "✔"
        wi.s:hide()
        wi.sep.text = "|"
        wi.h:pack_start(wi.p, false, false, 0)
        wi.h:pack_start(wi.f, false, false, 0)
        wi.h:pack_start(wi.s, false, false, 0)
        wi.h:pack_start(wi.l, false, false, 0)
        wi.h:pack_end(wi.sep, false, false, 0)
        wi.e:set_child(wi.h)
        bar:apply_widget_theme(t, theme)
        bar:update_download_widget(t)
    end,

    -- Adds a new label to the download bar and registers signals for it.
    add_download_widget = function(bar, d, theme)
        local dt = {last_size=0}
        local t  = {download=d, data=dt, widget=nil}
        bar:assemble_download_widget(t, theme)
        local wi = t.widget
        bar.layout:pack_start(wi.e, false, false, 0)
        bar.layout:reorder(wi.e, 0)
        bar:attach_download_widget_signals(t)
        return t
    end,

    -- Updates the text of the given download widget for the given download.
    update_download_widget = function(bar, t)
        local wi = t.widget
        local dt = t.data
        local d  = t.download
        local _,_,basename = string.find(d.destination, ".*/([^/]*)")
        if d.status == "finished" then
            wi.p:hide()
            wi.s:show()
            wi.l.text = basename
        elseif d.status == "error" then
            wi.p:hide()
            wi.e:show()
            wi.l.text = basename
        elseif d.status == "cancelled" then
            wi.p:hide()
            wi.l.text = basename
        else
            wi.p.text = string.format('%.2f%%', d.progress * 100)
            local speed = d.current_size - (dt.last_size or 0)
            dt.last_size = d.current_size
            wi.l.text = string.format("%s (%.1f Kb/s)", basename, speed/1024)
        end
    end,
}

--- Creates a download bar widget.
--    To add the bar to a window, pack <code>bar.ebox</code>.
--    @param theme A theme to apply to the bar.
--    @return A download bar.
--    @field ebox The main eventbox of the bar.
--    @field clear The clear button of the bar.
--    @field timer A timer used for checking the status of the downloads.
--    @field downloads An array of all displayed downloads.
function create_bar(theme)
    local bar = {
        layout    = hbox(),
        ebox      = eventbox(),
        clear     = {
            ebox  = eventbox(),
            label = label(),
        },
        downloads = {},
        timer     = timer{interval=1000},
        theme     = theme,
    }
    -- Set metatable
    local mt = { __index=bar_mt }
    setmetatable(bar, mt)
    -- Add internal helper functions to bar
    for k,v in pairs(download_helpers) do bar[k] = v end
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
    -- Setup timer
    bar.timer:add_signal("timeout", function() bar:refresh() end)
    return bar
end

