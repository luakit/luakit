--- Downloads for luakit.
--
-- This module adds support for downloading files from websites, and provides a
-- Lua API to monitor and control the file download process.
--
-- Enabling this module is sufficient for starting downloads, but users will
-- probably wish to also enable the `downloads_chrome` module.
--
-- @module downloads
-- @copyright 2010-2012 Mason Larobina <mason.larobina@gmail.com>
-- @copyright 2010 Fabian Streitel <karottenreibe@gmail.com>

-- Grab environment from luakit libs
local lousy = require("lousy")
local webview = require("webview")
local window = require("window")
local modes = require("modes")
local add_binds, add_cmds = modes.add_binds, modes.add_cmds

local _M = {}

--- Path to downloads database.
-- @readwrite
_M.db_path = luakit.data_dir .. "/downloads.db"

local query_insert

-- Setup signals on downloads module
lousy.signal.setup(_M, true)

-- Unique ids for downloads in this luakit instance
local id_count = 0
local function next_download_id()
    id_count = id_count + 1
    return tostring(id_count)
end

--- Default download directory.
-- @readwrite
-- @type string
_M.default_dir = xdg.download_dir or (os.getenv("HOME") .. "/downloads")

-- Private data for the download instances (speed tracking)
local dls = {}

--- Connect to and initialize the downloads database.
function _M.init()
    -- Return if database handle already open
    if _M.db then return end

    _M.db = sqlite3{ filename = _M.db_path }
    _M.db:exec [[
        PRAGMA synchronous = OFF;
        PRAGMA secure_delete = 1;

        CREATE TABLE IF NOT EXISTS downloads (
            finished_time INTEGER PRIMARY KEY,
            created_time INTEGER,
            uri TEXT,
            destination TEXT,
            total_size INTEGER
        );
    ]]

    query_insert = _M.db:compile [[
        INSERT INTO downloads
        VALUES (?, ?, ?, ?, ?)
    ]]

    local rows = _M.db:exec("SELECT * FROM downloads")
    for _, row in ipairs(rows) do
        local d = {uri = rawget(row, "uri"), destination = rawget(row, "destination"),
                   total_size = rawget(row, "total_size"), status = "finished"}
        local data = {
            created = rawget(row, "created_time"),
            id = next_download_id(),
            old = true,
        }
        dls[d] = data
    end
end

luakit.idle_add(_M.init)

--- Get all download objects.
-- @treturn table The table of all download objects.
function _M.get_all()
    return lousy.util.table.clone(dls)
end

--- Get download object from ID (passthrough if already given download object).
-- @tparam download|number id The download object or the ID of a download object.
-- @treturn download The download object.
-- @treturn table The download object's private data.
function _M.to_download(id)
    if type(id) == "download" then return id end
    id = tostring(id)
    for d, data in pairs(dls) do
        if id == data.id then return d end
    end
end

--- Get private data for a download object.
-- @tparam download|number id The download object or the ID of a download object.
function _M.get(id)
    local d = assert(_M.to_download(id),
        "download.get() expected valid download object or id")
    return d, dls[d]
end

local function is_running(d)
    local status = d.status
    return status == "created" or status == "started"
end

--- Attempt to open a downloaded file.
-- @tparam download d The download object.
-- @tparam table w The current window table.
function _M.do_open(d, w)
    if _M.emit_signal("open-file", d.destination, d.mime_type, w) ~= true then
        if w then
            w:error(string.format("Couldn't open: %q (%s)", d.destination,
                d.mime_type))
        end
    end
end

local status_timer = timer{interval=300}
status_timer:add_signal("timeout", function ()
    local running = 0
    for d, data in pairs(dls) do
        -- Create list of running downloads
        if is_running(d) then running = running + 1 end

        -- Raise "download::status" signals
        local status = d.status
        if (not data.old) and (status ~= data.last_status) then
            data.last_status = status
            _M.emit_signal("download::status", d, data)

            -- Open download
            if status == "finished" and data.opening then
                _M.do_open(d)
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

--- Add a new download.
-- @tparam string uri The URI to download.
-- @tparam table opts A table of options.
function _M.add(uri, opts)
    opts = opts or {}
    local d = (type(uri) == "string" and download{uri=uri}) or uri

    assert(type(d) == "download",
        string.format("download.add() expected uri or download object "
            .. "(got %s)", type(d) or "nil"))

    d:add_signal("decide-destination", function(dd, suggested_filename)
        -- Emit signal to get initial download location
        local fn = opts.filename or _M.emit_signal("download-location", dd.uri,
            opts.suggested_filename or suggested_filename, dd.mime_type)
        assert(fn == nil or type(fn) == "string" and #fn > 1,
            string.format("invalid filename: %q", tostring(fn)))

        -- Ask the user where we should download the file to
        if not fn then
            fn = luakit.save_file("Save file", opts.window, _M.default_dir,
                suggested_filename)
        end

        dd.allow_overwrite = true

        if fn then
            dd.destination = fn
            dd:add_signal("created-destination", function(ddd)
                local data = {
                    created = luakit.time(),
                    id = next_download_id(),
                }
                dls[ddd] = data
                if not status_timer.started then status_timer:start() end
                _M.emit_signal("download::status", ddd, dls[ddd])
            end)
        else
            dd:cancel()
        end
        return true
    end)

    d:add_signal("finished", function(dd)
        query_insert:exec{os.time(), dls[dd].created, dd.uri, dd.destination, dd.total_size}
    end)
end

--- Cancel a download.
-- @tparam download|number id The download object or the ID of a download object.
function _M.cancel(id)
    local d = assert(_M.to_download(id),
        "download.cancel() expected valid download object or id")
    d:cancel()
    _M.emit_signal("download::status", d, dls[d])
end

--- Remove a download.
-- If the download is running, it will be cancelled.
-- @tparam download|number id The download object or the ID of a download object.
function _M.remove(id)
    local d = assert(_M.to_download(id),
        "download.remove() expected valid download object or id")
    if is_running(d) then _M.cancel(d) end
    _M.emit_signal("removed-download", d, dls[d])
    dls[d] = nil
end

--- Restart a download.
-- A new download with the same source URI as `id` is created, and the original
-- download `id` is removed.
-- @tparam download|number id The download object or the ID of a download object.
-- @treturn download The download object.
function _M.restart(id)
    local d = assert(_M.to_download(id),
        "download.restart() expected valid download object or id")
    local new_d = _M.add(d.uri) -- TODO use soup message from old download
    if new_d then _M.remove(d) end
    return new_d
end

--- Attempt to open a downloaded file, as soon as the download completes.
-- If the download is already completed, this is equivalent to `do_open()`.
-- @tparam download|number id The download object or the ID of a download object.
-- @tparam table w The current window table.
function _M.open(id, w)
    local d = assert(_M.to_download(id),
        "download.open() expected valid download object or id")
    local data = assert(dls[d], "download removed")

    if d.status == "finished" then
        data.opening = false
        _M.do_open(d, w)
    else
        -- Set open flag to open file when download finishes
        data.opening = true
    end
end

--- Clear all finished, cancelled or aborted downloads.
function _M.clear()
    for d, _ in pairs(dls) do
        if not is_running(d) then
            dls[d] = nil
        end
    end
    _M.emit_signal("cleared-downloads")
end

-- If undoclose is loaded, then additionally block these ephemeral tabs from
-- being saved in the undolist.
local download_views
luakit.idle_add(function ()
    local undoclose = package.loaded.undoclose
    if not undoclose then return end
    download_views = setmetatable({}, { __mode = "k" })
    undoclose.add_signal("save", function (v)
        if download_views[v] then return false end
    end)
end)

-- Catch "download-started" webcontext widget signals (webkit2 API)
-- returned d is a download_t
luakit.add_signal("download-start", function (d, v)
    local w

    if v then
        w = webview.window(v)
        if v.uri == "about:blank" and #v.history.items == 1 then
            if download_views then download_views[v] = true end
            w:close_tab(v)
        end
    else
        -- Fall back to currently focused window
        for _, ww in pairs(window.bywidget) do
            if ww.win.focused then
                w, v = ww, ww.view
                break
            end
        end
    end

    _M.add(d, { window = w.win }, v)
    return true
end)

window.add_signal("init", function (w)
    local r = w.sbar.r
    r.downloads = widget{type="label"}
    r.layout:pack(r.downloads)
    r.layout:reorder(r.downloads, 1)
    -- Apply theme
    local theme = lousy.theme.get()
    r.downloads.fg = theme.downloads_sbar_fg
    r.downloads.font = theme.downloads_sbar_font
end)

-- Prevent luakit from soft-closing if there are downloads still running
luakit.add_signal("can-close", function ()
    local count = 0
    for d, _ in pairs(dls) do
        if is_running(d) then
            count = count + 1
        end
    end
    if count > 0 then
        return count .. " download(s) still running"
    end
end)

-- Download normal mode binds.
add_binds("normal", {
    { "<Control-D>", "Generate `:download` command with current URI.",
        function (w) w:enter_cmd(":download " .. (w.view.uri or "http://")) end },
})

-- Download commands
add_cmds({
    { ":down[load]", "Download a webpage by URI, defaulting to the current page.", {
        func = function (w, o)
            local uri = o.arg or w.view.uri
            if uri and not uri:match("^luakit://")
                then _M.add(uri, { window = w.win })
            elseif uri then
                w:error("cannot download URI '"..uri.."'")
            else
                w:error("cannot retrieve current page URI")
            end
        end,
        format = "{uri}",
    }},
})

return _M

-- vim: et:sw=4:ts=8:sts=4:tw=80
