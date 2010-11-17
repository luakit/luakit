local lousy = require("lousy")
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
local util = lousy.util
local theme = lousy.theme
local add_binds, add_cmds = add_binds, add_cmds

--- Provides internal support for downloads.
module("downloads")

-- Calculates a fancy name for a download to show to the user.
download.basename = function (d)
    local _,_,basename = string.find(d.destination or "", ".*/([^/]*)$")
    return basename or "no filename"
end

-- Calculates the speed of a download.
download.speed = function (d)
    return d.current_size - d.last_size
end

-- Checks whether the download is in created or started state.
download.is_running = function (d)
    return d.status == "created" or d.status == "started"
end

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
    w:error("Can't open " .. f)
end

--- The default directory for a new download.
dir = "/home"

--- The list of active downloads.
downloads = {}

-- The global refresh timer.
local refresh_timer = timer{interval=1000}

--- A list of functions to call on each refresh.
refresh_functions = {}

--- Refreshes all download related widgets and resets the downloads speeds.
function refresh_all()
    -- call refresh functions
    for _,fun in ipairs(refresh_functions) do fun() end
    for _,w in pairs(window.bywidget) do
        -- reset download speeds
        for _,d in ipairs(downloads) do
            d.last_size = d.current_size
        end
    end
    -- stop timer if necessary
    if #downloads == 0 then refresh_timer:stop() end
end

refresh_timer:add_signal("timeout", refresh_all)

--- Adds a download.
-- Tries to apply one of the <code>rules</code>. If that fails,
-- asks the user to choose a location with a save dialog.
-- @param uri The uri to add.
-- @return <code>true</code> if a download was started
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
    file = file or luakit.save_file("Save file", win, dir, d.suggested_filename)

    -- if the user didn't abort or a rule matched: download the file
    if file then
        d.destination = file
        d:start()
        table.insert(downloads, d)
        if not refresh_timer.started then refresh_timer:start() end
        refresh_all()
        return true
    end
end

--- Deletes the given download and cancels it if necessary.
-- @param i The index of the download to delete.
function delete(i)
    local d = table.remove(downloads, i)
    if download.is_running(d) then d:cancel() end
    refresh_all()
end

--- Removes and re-adds the download at the given index.
-- @param i The index of the download to restart.
function restart(i)
    local d = downloads[i]
    if not d then return end
    if add(d.uri) then delete(i) end
end

--- Removes all finished, cancelled or aborted downloads from all downlod bars.
-- Hides the bars if all downloads were deleted.
function clear()
    local function iter()
        for i,d in ipairs(downloads) do
            if not download.is_running(d) then return i end
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
    t:start()
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

-- Download normal mode binds.
local key = lousy.bind.key
add_binds("normal", {
    key({"Control", "Shift"}, "D",
        function (w)
            w:enter_cmd(":download " .. ((w:get_current() or {}).uri or "http://") .. " ")
        end),
})

-- Download commands.
local cmd = lousy.bind.cmd
add_cmds({
    cmd("down[load]",
        function (w, a)
            downloads.add(a)
        end),

    cmd("dd[elete]",
        function (w, a)
            local n = tonumber(a)
            if n then downloads.delete(n) end
        end),

    cmd("dc[ancel]",
        function (w, a)
            local n = tonumber(a)
            if n then downloads[n]:cancel() end
        end),

    cmd("dr[estart]",
        function (w, a)
            local n = tonumber(a)
            if n then downloads.restart() end
        end),

    cmd("dcl[ear]",
        function (w)
            downloads.clear()
        end),

    cmd("do[pen]",
        function (w, a)
            local n = tonumber(a)
            if n then downloads.open(n) end
        end),
})

-- Overwrite quit commands to check if downloads are finished
add_cmds({
    cmd("q[uit]",
        function (w)
            for _,d in ipairs(downloads) do
                if download.is_running(d) then
                    w:error("Can't close last window since downloads are still running. " ..
                            "Use :q! to quit anyway.")
                    return
                end
            end
            w:close_win()
        end),

    cmd({"quit!", "q!"},
        function (w)
            w:close_win()
        end),

    cmd({"writequit", "wq"},
        function (w)
            if #downloads ~= 0 and #luakit.windows == 1 then
                w:error("Can't close last window since downloads are still running. " ..
                        "Use :wq! to quit anyway.")
            else
                w:save_session()
                w:close_win()
            end
        end),

    cmd({"writequit!", "wq!"},
        function (w)
            w:save_session()
            w:close_win()
        end),

}, true)

-- vim: et:sw=4:ts=8:sts=4:tw=80
