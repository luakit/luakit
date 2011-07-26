-------------------------------------------------------
-- Downloads for luakit                              --
-- © 2010 Fabian Streitel <karottenreibe@gmail.com>  --
-- © 2010 Mason Larobina  <mason.larobina@gmail.com> --
-------------------------------------------------------

-- Grab environment we need from the standard lib
local assert = assert
local ipairs = ipairs
local os = os
local pairs = pairs
local setmetatable = setmetatable
local string = string
local table = table
local tonumber = tonumber
local type = type

-- Grab environment from luakit libs
local lousy = require("lousy")
local add_binds = add_binds
local add_cmds = add_cmds
local menu_binds = menu_binds
local new_mode = new_mode
local window = window
local webview = webview
local theme = lousy.theme

-- Grab environment from C API
local capi = {
    download = download,
    timer = timer,
    luakit = luakit,
    widget = widget,
}

--- Provides internal support for downloads.
module("downloads")

--- The downloads module.
-- @field opening Tracks which downloads are being opened.
-- @field downloads The list of active downloads.
-- @field default_dir The default directory for a new download.
-- @class table
-- @name downloads
opening = setmetatable({}, { __mode = "k" })
downloads = {}
default_dir = capi.luakit.get_special_dir("DOWNLOAD") or (os.getenv("HOME") .. "/downloads")

-- Tracks speed data for downloads by weak table.
local speeds = setmetatable({}, { __mode = "k" })

-- Track auto opened files to prevent multiple signals
local auto_opened = setmetatable({}, { __mode = "k" })

-- Setup signals on downloads module.
lousy.signal.setup(_M, true)

--- Calculates a fancy name for a download to show to the user.
-- @param d The download.
function get_basename(d)
    return string.match(d.destination or "", ".*/([^/]*)$") or "no filename"
end

--- Checks whether the download is in created or started state.
-- @param d The download.
function is_running(d)
    return d.status == "created" or d.status == "started"
end

--- Calculates the speed of a download in b/s.
-- @param d The download.
function get_speed(d)
    local s = speeds[d] or {}
    if s.current_size then
        return (s.current_size - (s.last_size or 0))
    end
    return 0
end

-- Add indicator to status bar.
window.init_funcs.downloads_status = function (w)
    local r = w.sbar.r
    r.downloads = capi.widget{type="label"}
    r.layout:pack_start(r.downloads, false, false, 0)
    r.layout:reorder(r.downloads, 1)
    -- Apply theme
    local theme = theme.get()
    r.downloads.fg = theme.downloads_sbar_fg
    r.downloads.font = theme.downloads_sbar_font
end

-- Refresh indicator
local status_timer = capi.timer{interval=1000}
status_timer:add_signal("timeout", function ()
    -- Track how many downloads are active
    local running = 0
    for _, d in ipairs(downloads) do
        if is_running(d) then running = running + 1 end
        -- Get speed table
        if not speeds[d] then speeds[d] = {} end
        local s = speeds[d]
        -- Save download progress
        s.last_size = s.current_size or 0
        s.current_size = d.current_size
        -- Auto open finished files
        if d.status == "finished" and not opening[d] and not auto_opened[d] then
            auto_opened[d] = true
            local should_open = _M.emit_signal("auto-open-filter", d.destination, d.mime_type)
            if should_open then
                open(d)
            end
        end
    end
    -- Update download indicator widget
    for _, w in pairs(window.bywidget) do
        w.sbar.r.downloads.text = running == 0 and "" or running.."↓"
    end
    -- Stop after downloads finish
    if #downloads == 0 or running == 0 then
        status_timer:stop()
    end
end)

--- Adds a download.
-- Tries to apply one of the <code>rules</code>. If that fails,
-- asks the user to choose a location with a save dialog.
-- @param arg The uri or download or webkit download.
-- @param opts Download options.
--      - autostart: Whether to start the download right away.
--      - window: A window to display the save-as dialog over.
-- @return <code>true</code> if a download was started
function add(arg, opts)
    opts = opts or {}
    local d = (type(arg) == "string" and capi.download{uri=arg}) or arg
    assert(type(d) == "download",
        string.format("expected uri or download, got: %s", type(d) or "nil"))

    -- Emit signal to determine the download location.
    local file = _M.emit_signal("download-location", d.uri, d.suggested_filename)

    -- Check return type
    assert(file == nil or type(file) == "string" and #file > 1,
        string.format("invalid filename: %q", file or "nil"))

    -- If no download location returned ask the user
    if not file then
        file = capi.luakit.save_file("Save file", opts.window, default_dir, d.suggested_filename)
    end

    -- If a suitable filename was given proceed with the download
    if file then
        d.destination = file
        if opts.autostart ~= false then d:start() end
        table.insert(downloads, d)
        if not status_timer.started then status_timer:start() end
        return true
    end
end

-- Add download window method
window.methods.download = function (w, uri)
    add(uri, { window = w.win })
end

--- Removes all finished, cancelled or aborted downloads.
function clear()
    local tmp = {}
    for _, d in ipairs(downloads) do
        if is_running(d) then
            table.insert(tmp, d)
        end
    end
    downloads = tmp
end

local function get_download(d)
    if type(d) == "number" then
        d = assert(downloads[d], "invalid index")
    end
    assert(type(d) == "download", "invalid download")
    return d
end

--- Opens the download at the given index after completion.
-- @param d The download or its index.
-- @param i The index of the download to open.
-- @param w A window to show notifications in, if necessary.
function open(d, w)
    d = get_download(d)
    local t = capi.timer{interval=1000}
    opening[d] = true
    t:add_signal("timeout", function (t)
        if not is_running(d) then t:stop() end
        if d.status == "finished" then
            opening[d] = false
            auto_opened[d] = true
            if _M.emit_signal("open-file", d.destination, d.mime_type, w) ~= true then
                if w then
                    w:error(string.format("Can't open: %q (%s)", d.destination, d.mime_type))
                end
            end
        end
    end)
    t:start()
end

--- Cancels the download.
-- @param d The download or its index.
function cancel(d)
    d = get_download(d)
    d:cancel()
end

--- Remove the given download from the downloads table and cancel it if.
-- necessary.
-- @param d The download or its index.
function delete(d)
    d = get_download(d)
    -- Remove download from downloads table
    for i, v in ipairs(downloads) do
        if v == d then
            table.remove(downloads, i)
            break
        end
    end
    -- Stop download
    if is_running(d) then cancel(d) end
end

-- Removes and re-adds the given download.
-- @param d The download or its index.
function restart(d)
    d = get_download(d)
    local new_d = add(d.uri)
    if new_d then delete(d) end
    return new_d
end

-- Register signal handler with webview
webview.init_funcs.download_request = function (view, w)
    view:add_signal("download-request", function (v, dl)
        add(dl, { autostart = false, window = w.win })
        return true
    end)
end

-- Check if downloads are finished and last window can exit.
capi.luakit.add_signal("can-close", function ()
    local count = 0
    for _, d in ipairs(downloads) do
        if is_running(d) then count = count + 1 end
    end
    if count > 0 then
        return count .. " download(s) still running"
    end
end)

-- Download normal mode binds.
local key, buf = lousy.bind.key, lousy.bind.buf
add_binds("normal", {
    key({"Control"}, "D", function (w)
        w:enter_cmd(":download " .. (w:get_current().uri or "http://") .. " ")
    end),
})

-- Download commands.
local cmd = lousy.bind.cmd
add_cmds({
    cmd("down[load]", function (w, a)
        add(a)
    end),

    -- View all downloads in an interactive menu
    cmd("downloads", function (w)
        w:set_mode("downloadlist")
    end),

    cmd("dd[elete]", function (w, a)
        local d = downloads[assert(tonumber(a), "invalid index")]
        if d then delete(d) end
    end),

    cmd("dc[ancel]", function (w, a)
        local d = downloads[assert(tonumber(a), "invalid index")]
        if d then cancel(d) end
    end),

    cmd("dr[estart]", function (w, a)
        local d = downloads[assert(tonumber(a), "invalid index")]
        if d then restart(d) end
    end),

    cmd("dcl[ear]", clear),

    cmd("do[pen]", function (w, a)
        local d = downloads[assert(tonumber(a), "invalid index")]
        if d then open(d, w) end
    end),
})

-- Add mode to display all downloads in an interactive menu.
new_mode("downloadlist", {
    enter = function (w)
        -- Check if there are downloads
        if #downloads == 0 then
            w:notify("No downloads to list")
            return
        end

        -- Build downloads list
        local rows = {{ "Download", "Status", title = true }}
        for _, d in ipairs(downloads) do
            local function name()
                local i = lousy.util.table.hasitem(downloads, d) or 0
                return string.format("%3s %s", i, get_basename(d))
            end
            local function status()
                if is_running(d) then
                    return string.format("%.2f/%.2f Mb (%i%%) at %.1f Kb/s",
                        d.current_size/1048576, d.total_size/1048576,
                        (d.progress * 100), get_speed(d) / 1024)
                else
                    return d.error or d.status
                end
            end
            table.insert(rows, { name, status, dl = d })
        end
        w.menu:build(rows)
        w:notify("Use j/k to move, d delete, c cancel, r restart, o open.", false)

        -- Update menu every second
        local update_timer = capi.timer{interval=1000}
        update_timer:add_signal("timeout", function ()
            w.menu:update()
        end)
        w.download_menu_state = { update_timer = update_timer }
        update_timer:start()
    end,

    leave = function (w)
        local ds = w.download_menu_state
        if ds and ds.update_timer.started then
            ds.update_timer:stop()
        end
        w.menu:hide()
    end,
})

-- Add additional binds to downloads menu mode.
local key = lousy.bind.key
add_binds("downloadlist", lousy.util.table.join({
    -- Delete download
    key({}, "d", function (w)
        local row = w.menu:get()
        if row and row.dl then
            delete(row.dl)
            w.menu:del()
        end
    end),

    -- Cancel download
    key({}, "c", function (w)
        local row = w.menu:get()
        if row and row.dl then
            cancel(row.dl)
        end
    end),

    -- Open download
    key({}, "o", function (w)
        local row = w.menu:get()
        if row and row.dl then
            open(row.dl, w)
        end
    end),

    -- Restart download
    key({}, "r", function (w)
        local row = w.menu:get()
        if row and row.dl then
            restart(row.dl)
        end
        -- HACK: Bad way of refreshing download list to show new items
        -- (I.e. the new download from the restart)
        w:set_mode("downloadlist")
    end),

    -- Exit menu
    key({}, "q", function (w) w:set_mode() end),

}, menu_binds))

-- vim: et:sw=4:ts=8:sts=4:tw=80
