local lousy = require("lousy")
local table = table
local string = string
local io = io
local pairs = pairs
local ipairs = ipairs
local luakit = luakit
local window = window
local timer = timer
local download = download
local util = lousy.util
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

--- Removes all finished, cancelled or aborted downloads.
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
            add(a)
        end),

    cmd("dd[elete]",
        function (w, a)
            local n = tonumber(a)
            if n then delete(n) end
        end),

    cmd("dc[ancel]",
        function (w, a)
            local n = tonumber(a)
            if n then downloads[n]:cancel() end
        end),

    cmd("dr[estart]",
        function (w, a)
            local n = tonumber(a)
            if n then restart() end
        end),

    cmd("dcl[ear]", clear),

    cmd("do[pen]",
        function (w, a)
            local n = tonumber(a)
            if n then open(n) end
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
