--------------------------------------------------------
-- Save web history                                   --
-- (C) 2010 Mason Larobina <mason.larobina@gmail.com> --
--------------------------------------------------------

-- Get environment we need from Lua stdlib
local os = os
local io = io
local string = string
local table = table
local math = math

-- Get environment we need from luakit libs
local new_mode = new_mode
local add_cmds = add_cmds
local add_binds = add_binds
local menu_binds = menu_binds
local webview = webview
local lousy = require "lousy"
local escape = lousy.util.escape
local capi = { luakit = luakit }

module("history")

-- Location to save web history
file = capi.luakit.data_dir .. "/history"

-- Save web history
webview.init_funcs.save_hist = function (view)
    view:add_signal("load-status", function (v, status)
        if status == "first-visual" and v.uri ~= "about:blank" then
            local fh = io.open(file, "a")
            fh:write(string.format("%d %s\n", os.time(), v.uri))
            fh:close()
        end
    end)
end

function reltime(time)
    local d = math.max(os.time() - time, 0)

    if d < 60*60*24 then
        return "Today"
    elseif d < 60*60*24*2 then
        return "Yesterday"
    elseif d < 60*60*24*7 then
        return "Last 7 days"
    elseif d < 60*60*24*30 then
        return "Last Month"
    elseif d < 60*60*24*30*3 then
        return "Last 3 Months"
    elseif d < 60*60*24*365 then
        return "Last Year"
    else
        return "Ages ago"
    end
end

new_mode("historylist", {
    enter = function (w)
        -- Populate history menu
        local items, count = {}, 0
        if os.exists(file) then
            for line in io.lines(file) do
                local time, uri = string.match(line, "^(%d+)%s(.+)$")
                if uri then
                    count = count + 1
                    table.insert(items, { time = time, uri = uri })
                end
            end
        end

        -- Check if no history
        if count == 0 then
            w:notify("No history to list")
            return
        end

        -- Build rows (with headings)
        local rows = {}
        local last = nil
        for i = 1, count do
            local item = items[(count - i + 1)]
            local h = reltime(item.time)
            if h ~= last then
                table.insert(rows, { h, title = true })
                last = h
            end
            table.insert(rows, { escape(" " .. item.uri), uri = item.uri })
        end
        w.menu:build(rows)
        w:notify("Use j/k to move, o open, t tabopen, w winopen.", false)
    end,

    leave = function (w)
        w.menu:hide()
    end,
})

local cmd = lousy.bind.cmd
add_cmds({
    cmd("hist[ory]",
        function (w) w:set_mode("historylist") end),
})

local key = lousy.bind.key
add_binds("historylist", lousy.util.table.join({
    -- Open hist item
    key({}, "o",
        function (w)
            local row = w.menu:get()
            if row and row.uri then
                w:navigate(row.uri)
            end
        end),

    -- Open hist item
    key({}, "Return",
        function (w)
            local row = w.menu:get()
            if row and row.uri then
                w:navigate(row.uri)
            end
        end),

    -- Open hist item in background tab
    key({}, "t",
        function (w)
            local row = w.menu:get()
            if row and row.uri then
                w:new_tab(row.uri, false)
            end
        end),

    -- Open hist item in new window
    key({}, "w",
        function (w)
            local row = w.menu:get()
            if row and row.uri then
                window.new({row.uri})
            end
        end),

    key({}, "q",
        function (w) w:set_mode() end),

}, menu_binds))

-- vim: et:sw=4:ts=8:sts=4:tw=80
