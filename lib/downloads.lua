require("lousy")

local print = print
local table = table
local util = lousy.util
local string = string
local pairs = pairs
local ipairs = ipairs
local timer = timer
local download = download
local dialog = dialog
local theme = lousy.theme
local setmetatable = setmetatable
local eventbox = function() return widget{type="eventbox"} end
local hbox     = function() return widget{type="hbox"}     end
local label    = function() return widget{type="label"}    end
local luakit = luakit

--- Provides internal support for downloads and a download bar.
module("downloads")

--- Output file for the generated HTML page.
html_out       = luakit.cache_dir  .. '/downloads.html'

--- Template for a download.
download_template = [==[
<div class="download {status}"><h1>{id} {name}</h1>
<span>{complete}/{total} at {speed}</span>&nbsp;&nbsp;
<a href="javascript:cancel_{id}()">Cancel</a>
<a href="javascript:open_{id}()">Open</a>
</div>
]==]

--- Template for the HTML page.
html_template = [==[
<html>
<head>
    <title>Downloads</title>
    <style type="text/css">
    {style}
    </style>
</head>
<body>
<div class="header">
<a href="javascript:clear()">Clear all stopped downloads</a>
</div>
{downloads}
</body>
</html>
]==]

--- CSS styles for the HTML page.
html_style = [===[
    body {
        font-family: monospace;
        margin: 25px;
        line-height: 1.5em;
        font-size: 12pt;
    }
    div.download {
        width: 100%;
        padding: 0px;
        margin: 0 0 25px 0;
        clear: both;
    }
    .download h1 {
        font-size: 12pt;
        font-weight: bold;
        font-style: normal;
        font-variant: small-caps;
        padding: 0 0 5px 0;
        margin: 0;
        color: #333333;
        border-bottom: 1px solid #aaa;
    }
    .download a:link {
        color: #0077bb;
        text-decoration: none;
    }
    .download a:hover {
        color: #0077bb;
        text-decoration: underline;
    }
]===]

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

--- Public methods
methods = {
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
        for i,t in ipairs(bar.downloads) do
            if t.download == d then
                bar.layout:remove(t.widget.e)
                local wi = t.widget
                for _,w in ipairs{ wi.sep, wi.l, wi.s, wi.f, wi.p, wi.h, wi.e } do w:destroy() end
                table.remove(bar.downloads, i)
                if d.status == "started" then d:cancel() end
                break
            end
        end
        if #bar.downloads == 0 then bar.ebox:hide() end
    end,

    --- Removes the download at the given index.
    --    Hides the bar if all downloads were removed.
    --    @param bar The bar to modify.
    --    @param i The index of the download to remove.
    remove = function(bar, i)
        local t = bar.downloads[i]
        if t then bar:remove_download(t.download) end
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

    --- Opens the given download after completion.
    --    @param bar The download bar
    --    @param t The table of the download to open
    open_download = function(bar, t)
        local ti = timer{interval=1000}
        ti:add_signal("timeout", function(ti)
            local d  = t.download
            if d.status == "finished" then
                ti:stop()
                open_file(d.destination, d.mime_type, t.widget.l)
            end
        end)
        ti:start()
    end,

    --- Opens the download at the given index after completion.
    --    @param bar The download bar
    --    @param i The index of the download to open
    open = function(bar, i)
        local t = bar.downloads[i]
        if t then bar:open_download(t) end
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
            local t = bar:add_download_widget(d)
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
        for i,t in ipairs(bar.downloads) do
            local d = t.download
            bar:update_download_widget(t, i)
            if d.status == "created" or d.status == "started" then
                all_finished = false
            end
        end
        -- stop timer if everyone finished
        if all_finished then
            bar.timer:stop()
        end
    end,

    --- Dumps the HTML for the download page to the given file or
    -- <code>html_out</code> if no file is given.
    -- @param bar The bar to use as the source of the dump.
    -- @param file Optional. The file to dump to.
    -- @return The path to the file that was dumped.
    dump_html = function(bar, file)
        if not file then file = html_out end
        local downloads = bar.downloads
        local rows = {}
        for i,t in ipairs(downloads) do
            local d = t.download
            local subs = {
                id       = i
                name     = bar:basename(d)
                speed    = bar:speed(t)
                complete = d.current_size
                total    = d.total_size
                percent  = d.progress * 100
                status   = d.status
            }
            local row = string.gsub(download_template, "{(%w+)}", subs)
            table.insert(rows, row)
        end
        local html_subs = {
            style = html_style
            downloads = table.concat(downloads, "\n")
        }
        local html = string.gsub(html_template, "{(%w+)}", html_subs)
        local fh = io.open(file, "w")
        fh:write(html)
        io.close(fh)
        return "file://" .. file
    end
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
            if b == 1 then
                -- open file
                bar:open_download(t)
            elseif b == 3 then
                -- remove download
                local d  = t.download
                bar:remove_download(d)
            end
        end)
    end,

    --- Applies the theme to a download bar widget.
    apply_widget_theme = function(bar, t)
        local wi = t.widget
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

    -- Creates and connects all widget components for a download widget.
    assemble_download_widget = function(bar, t)
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
        wi.h:pack_start(wi.l, true,  true,  0)
        wi.h:pack_end(wi.sep, false, false, 0)
        wi.e:set_child(wi.h)
        bar:apply_widget_theme(t)
        bar:update_download_widget(t, #bar.downloads + 1)
    end,

    -- Adds a new label to the download bar and registers signals for it.
    add_download_widget = function(bar, d)
        local dt = {last_size=0}
        local t  = {download=d, data=dt, widget=nil}
        bar:assemble_download_widget(t)
        local wi = t.widget
        bar.layout:pack_start(wi.e, true, true, 0)
        bar:attach_download_widget_signals(t)
        return t
    end,

    -- Changes colors and widgets to indicate a download success.
    indicate_success = function(bar, wi)
        wi.p:hide()
        wi.s:show()
    end,

    -- Changes colors and widgets to indicate a download failure.
    indicate_failure = function(bar, wi)
        wi.p:hide()
        wi.f:show()
    end,

    -- Updates the text of the given download widget for the given download.
    update_download_widget = function(bar, t, i)
        local wi = t.widget
        local dt = t.data
        local d  = t.download
        local _,_,basename = bar:basename(d)
        wi.l.text = string.format("%i %s", i, basename)
        if d.status == "finished" then
            bar:indicate_success(wi)
        elseif d.status == "error" then
            bar:indicate_failure(wi)
        elseif d.status == "cancelled" then
            wi.p:hide()
        else
            wi.p.text = string.format('%.2f%%', d.progress * 100)
            local speed = bar:speed(t)
            dt.last_size = d.current_size
            wi.l.text = string.format("%i %s (%.1f Kb/s)", i, basename, speed/1024)
        end
    end,

    -- Calculates a fancy name for a download to show to the user.
    basename = function(bar, d)
        local _,_,basename = string.find(d.destination, ".*/([^/]*)")
        return basename
    end

    -- Calculates the speed of a download
    speed = function(bar, t)
        return t.download.current_size - (t.data.last_size or 0)
    end
}

--- Creates a download bar widget.
--    To add the bar to a window, pack <code>bar.ebox</code>.
--    @return A download bar.
--    @field ebox The main eventbox of the bar.
--    @field clear The clear button of the bar.
--    @field timer A timer used for checking the status of the downloads.
--    @field downloads An array of all displayed downloads.
function create_bar()
    local bar = {
        layout    = hbox(),
        ebox      = eventbox(),
        clear     = {
            ebox  = eventbox(),
            label = label(),
        },
        downloads = {},
        timer     = timer{interval=1000},
    }
    -- Set metatable
    local mt = { __index=methods }
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

