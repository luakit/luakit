require("lousy")

local print = print
local table = table
local string = string
local io = io
local pairs = pairs
local ipairs = ipairs
local setmetatable = setmetatable
local getmetatable = getmetatable
local eventbox = function () return widget{type="eventbox"} end
local hbox     = function () return widget{type="hbox"}     end
local label    = function () return widget{type="label"}    end
local luakit = luakit
local window = window
local timer = timer
local download = download
local dialog = dialog
local util = lousy.util
local theme = lousy.theme

--- Provides internal support for downloads and a download bar.
module("downloads")

-- Calculates a fancy name for a download to show to the user.
download.basename = function (d)
    local _,_,basename = string.find(d.destination, ".*/([^/]*)$")
    return basename or d.destination or "no fileame"
end

-- Calculates the speed of a download.
download.speed = function (d)
    return d.current_size - d.last_size
end

--- The URI of the chrome page
chrome_page = "chrome://downloads/"

--- Template for a download.
download_template = [==[
<div class="download {status}"><h1>{id} {name}</h1>
<span>{modeline}</span>&nbsp;&nbsp;
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
<a href="javascript:clear();refresh()">Clear all stopped downloads</a>
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
    .download.cancelled {
        background-color: #ffa07a;
    }
    .download.error {
        background-color: #ffa07a;
    }
    .download.created {
        background-color: #ffffff;
    }
    .download.started {
        background-color: #ffffff;
    }
    .download.finished {
        background-color: #90ee90;
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
-- Each key in the table is a pattern, each value a directory
-- in the local filesystem. If the pattern of a newly added
-- download matches one of the rules, it will be automatically
-- downloaded to that folder.
rules = {}

--- Used to open a download when clicked on.
-- The default implementation just displays an error message.
-- @param f The path to the file to open.
-- @param mt The inferred mime type of the file.
-- @param w A window in which to show notifications, if necessary.
open_file = function (f, mt, w)
    w:error(string.format("Can't open " .. f))
end

--- The default directory for a new download.
dir = "/home"

--- The list of active downloads.
downloads = {}

-- The global refresh timer.
local refresh_timer = timer{interval=1000}

-- Refreshes all download bars.
local function refresh_all()
    for _,w in pairs(window.bywidget) do
        local bar = w.dbar
        bar:refresh()
        if #downloads == 0 then bar:hide() end
    end
    if #downloads == 0 then refresh_timer:stop() end
end

refresh_timer:add_signal("timeout", refresh_all)

--- Adds a download to the download bar.
-- Tries to apply one of the <code>rules</code>. If that fails,
-- asks the user to choose a location with a save dialog.
-- @param bar The bar to modify.
-- @param uri The uri to add.
-- @param win The window to display the dialog over.
function add(uri)
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
        table.insert(downloads, d)
        if not refresh_timer.started then refresh_timer:start() end
        refresh_all()
    end
end

--- Removes the given download from all download bars and cancels it if necessary.
-- Hides the bars if all downloads were removed.
-- @param i The index of the download to remove.
function delete(i)
    local d = table.remove(downloads, i)
    if d.status == "started" then d:cancel() end
    refresh_all()
end

--- Removes all finished, cancelled or aborted downloads from all downlod bars.
-- Hides the bars if all downloads were removed.
function clear()
    local function iter()
        for i,d in ipairs(downloads) do
            if d.status ~= "created" and d.status ~= "started" then
                return i
            end
        end
    end
    for i in iter do table.remove(downloads, i) end
    refresh_all()
end

--- Opens the download at the given index after completion.
-- @param i The index of the download to open.
-- @param w A window to show notifications in, if necessary.
function open(i, w)
    local d = downloads[i]
    local t = timer{interval=1000}
    t:add_signal("timeout", function (t)
        if d.status == "finished" then
            t:stop()
            open_file(d.destination, d.mime_type, w)
        end
    end)
    ti:start()
end

--- Compiles the HTML for the download page.
-- @return The HTML to render.
function html()
    local rows = {}
    for i,d in ipairs(downloads) do
        local modeline
        if d.status == "started" then
            modeline = string.format("%i/%i (%i%%) at %.2f", d.current_size, d.total_size, (d.progress * 100), download.speed(d))
        else
            modeline = string.format("%i/%i (%i%%)", d.current_size, d.total_size, (d.progress * 100))
        end
        local subs = {
            id       = i,
            name     = download.basename(d),
            status   = d.status,
            modeline = modeline,
        }
        local row = string.gsub(download_template, "{(%w+)}", subs)
        table.insert(rows, row)
    end
    local html_subs = {
        style = html_style,
        downloads = table.concat(rows, "\n"),
    }
    return string.gsub(html_template, "{(%w+)}", html_subs)
end

--- Shows the chrome page in the given view.
-- @param view The view to show the page in.
function show_chrome(view)
    view:load_string(html(), chrome_page)
    -- small hack to achieve a one time signal
    local sig = {}
    sig.fun = function (v, status)
        view:remove_signal("load-status", sig.fun)
        if status ~= "committed" or view.uri ~= chrome_page then return end
        view:register_function("clear", clear)
        view:register_function("refresh", function () show_chrome(view) end)
        view:eval_js("setTimeout(refresh, 1000)", "downloads.lua")
    end
    view:add_signal("load-status", sig.fun)
end

--- Methods for download bars.
bar_methods = {
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
            if b == 1 then
                -- open file
                open(i, bar.win)
            elseif b == 3 then
                -- remove download
                delete(i)
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
            d.last_size = d.current_size
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
function create_bar()
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

