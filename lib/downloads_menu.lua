local downloads = require("downloads")
local lousy = require("lousy")
local ipairs = ipairs
local table = table
local download = download
local string = string

local new_mode, add_binds, add_cmds = new_mode, add_binds, add_cmds
local menu_binds = menu_binds

module("downloads.menu")

-- Add menu commands
local cmd = lousy.bind.cmd
add_cmds({
    -- View all downloads in an interactive menu
    cmd("downloads", function (w) w:set_mode("dllist") end),
})

-- Add mode to display all downloads in an interactive menu
new_mode("dllist", {
    enter = function (w)
        local rows = {{ "    Download", "Status", title = true }}
        for i, d in ipairs(downloads.downloads) do
            local name = string.format("%3s %s", i, download.basename(d))
            local status
            if download.is_running(d) then
                status = string.format("%.2f/%.2f Mb (%i%%) at %.1f Kb/s", d.current_size/1048576, d.total_size/1048576, (d.progress * 100), download.speed(d))
            else
                status = d.status
            end
            table.insert(rows, { name, status, idx = i })
        end
        w.menu:build(rows)
        w:notify("Use j/k to move, d delete, c cancel, r restart, o open.", false)
    end,

    leave = function (w)
        w.menu:hide()
    end,
})

-- Add additional binds to downloads menu mode
local key = lousy.bind.key
add_binds("dllist", lousy.util.table.join({
    -- Delete download
    key({}, "d",
        function (w)
            local row = w.menu:get()
            if row and row.idx then
                downloads.delete(row.idx)
                w.menu:del()
            end
        end),

    -- Cancel download
    key({}, "c",
        function (w)
            local row = w.menu:get()
            if row and row.idx then
                downloads.downloads[row.idx]:cancel()
            end
        end),

    -- Open download
    key({}, "o",
        function (w)
            local row = w.menu:get()
            if row and row.idx then
                downloads.open(row.idx)
            end
        end),

    -- Open download in new tab
    key({}, "r",
        function (w)
            local row = w.menu:get()
            if row and row.idx then
                downloads.restart(row.idx)
            end
        end),

    -- Exit menu
    key({}, "q", function (w) w:set_mode() end),

}, menu_binds))

