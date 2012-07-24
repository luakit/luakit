-----------------------------------------------------------
-- Downloads for luakit                                  --
-- © 2010-2012 Mason Larobina <mason.larobina@gmail.com> --
-- © 2010 Fabian Streitel <karottenreibe@gmail.com>      --
-----------------------------------------------------------

-- Grab environment we need from the standard lib
local assert = assert
local ipairs = ipairs
local os = os
local pairs = pairs
local setmetatable = setmetatable
local string = string
local table = table
local type = type
local tostring = tostring
local print = print

-- Grab environment from luakit libs
local lousy = require("lousy")
local webview = webview
local window = window
local add_cmds = add_cmds
local add_binds = add_binds

local capi = {
    download = download,
    timer = timer,
    luakit = luakit,
    widget = widget,
    xdg = xdg
}

module("downloads")

-- Unique ids for downloads in this luakit instance
local id_count = 0
local function next_download_id()
    id_count = id_count + 1
    return tostring(id_count)
end

-- Default download directory
default_dir = capi.xdg.download_dir or (os.getenv("HOME") .. "/downloads")

-- Setup signals on download module
lousy.signal.setup(_M, true)

-- Private data for the download instances (speed tracking)
local downloads = {}

function get_all()
    return lousy.util.table.clone(downloads)
end

-- Get download object from id (passthrough if already given download object)
function to_download(id)
    if type(id) == "download" then return id end
    for d, data in pairs(downloads) do
        if id == data.id then return d end
    end
end

function get(id)
    local d = assert(to_download(id),
        "download.get() expected valid download object or id")
    return d, downloads[d]
end

local function is_running(d)
    local status = d.status
    return status == "created" or status == "started"
end

function do_open(d, w)
    if _M.emit_signal("open-file", d.destination, d.mime_type, w) ~= true then
        if w then
            w:error(string.format("Couldn't open: %q (%s)", d.destination,
                d.mime_type))
        end
    end
end

local status_timer = capi.timer{interval=1000}
status_timer:add_signal("timeout", function ()
    local running = 0
    for d, data in pairs(downloads) do
        -- Create list of running downloads
        if is_running(d) then running = running + 1 end

        -- Raise "download::status" signals
        local status = d.status
        if status ~= data.last_status then
            data.last_status = status
            _M.emit_signal("download::status", d, data)

            -- Open download
            if status == "finished" and data.opening then
                do_open(d)
            end
        end
    end

    -- Stop the status_timer after all downloads finished
    if running == 0 then status_timer:stop() end

    -- Update window download status widget
    for _, w in pairs(window.bywidget) do
        w.sbar.r.downloads.text = (running == 0 and "") or running.."↓"
    end

    _M.emit_signal("status-tick", running)
end)

function add(uri, opts)
    opts = opts or {}
    local d = (type(uri) == "string" and capi.download{uri=uri}) or uri

    assert(type(d) == "download",
        string.format("download.add() expected uri or download object "
            .. "(got %s)", type(d) or "nil"))

    -- Emit signal to get initial download location
    local fn = _M.emit_signal("download-location", d.uri,
        d.suggested_filename, d.mime_type)

    assert(fn == nil or type(fn) == "string" and #fn > 1,
        string.format("invalid filename: %q", tostring(file)))

    -- Ask the user where we should download the file to
    if not fn then
        fn = capi.luakit.save_file("Save file", opts.window, default_dir,
            d.suggested_filename)
    end

    if fn then
        d.destination = fn
        d:start()
        local data = {
            created = capi.luakit.time(),
            id = next_download_id(),
        }
        downloads[d] = data
        if not status_timer.started then status_timer:start() end
        _M.emit_signal("download::status", d, downloads[d])
        return true
    end
end

function cancel(id)
    local d = assert(to_download(id),
        "download.cancel() expected valid download object or id")
    d:cancel()
    _M.emit_signal("download::status", d, downloads[d])
end

function remove(id)
    local d = assert(to_download(id),
        "download.remove() expected valid download object or id")
    if is_running(d) then cancel(d) end
    _M.emit_signal("removed-download", d, downloads[d])
    downloads[d] = nil
end

function restart(id)
    local d = assert(to_download(id),
        "download.restart() expected valid download object or id")
    local new_d = add(d.uri) -- TODO use soup message from old download
    if new_d then remove(d) end
    return new_d
end

function open(id, w)
    local d = assert(to_download(id),
        "download.open() expected valid download object or id")
    local data = assert(downloads[d], "download removed")

    if d.status == "finished" then
        data.opening = false
        do_open(d, w)
    else
        -- Set open flag to open file when download finishes
        data.opening = true
    end
end

-- Clear all finished, cancelled or aborted downloads
function clear()
    for d, _ in pairs(downloads) do
        if not is_running(d) then
            downloads[d] = nil
        end
    end
    _M.emit_signal("cleared-downloads")
end

-- Catch "download-request" webview widget signals
webview.init_funcs.download_request = function (view, w)
    view:add_signal("download-request", function (v, d)
        add(d, { window = w.win })
        return true
    end)
end

window.init_funcs.download_status = function (w)
    local r = w.sbar.r
    r.downloads = capi.widget{type="label"}
    r.layout:pack(r.downloads)
    r.layout:reorder(r.downloads, 1)
    -- Apply theme
    local theme = lousy.theme.get()
    r.downloads.fg = theme.downloads_sbar_fg
    r.downloads.font = theme.downloads_sbar_font
end

-- Prevent luakit from soft-closing if there are downloads still running
capi.luakit.add_signal("can-close", function ()
    local count = 0
    for d, _ in pairs(downloads) do
        if is_running(d) then
            count = count + 1
        end
    end
    if count > 0 then
        return count .. " download(s) still running"
    end
end)

-- Download normal mode binds.
local key = lousy.bind.key
add_binds("normal", {
    key({"Control"}, "D",
        "Generate `:download` command with current URI.",
        function (w)
            w:enter_cmd(":download " .. (w.view.uri or "http://"))
        end),
})

-- Download commands
local cmd = lousy.bind.cmd
add_cmds({
    cmd("down[load]", "Download the given URI.", function (w, a)
        add(a, { window = w.win })
    end),
})
