--------------------------------------------------------
-- chrome://history with search & pagnination support --
-- © 2011 Mason Larobina <mason.larobina@gmail.com>   --
--------------------------------------------------------

local math = require "math"
local string = string
local table = table
local ipairs = ipairs
local os = require "os"
local tonumber = tonumber
local tostring = tostring

local lousy = require "lousy"
local chrome = require "chrome"
local history = require "history"
local add_cmds = add_cmds
local capi = { luakit = luakit, soup = soup }

module "history.chrome"

-- Time format option (either "24h" or "12h")
time_format = "12h"

html_template = [==[
<html>
<head>
    <title>History</title>
    <style type="text/css">
        body {
            background-color: white;
            color: black;
            margin: 10px;
            display: block;
            font-size: 84%;
            font-family: sans-serif;
        }

        div {
            display: block;
        }

        #results-separator {
            border-top: 1px solid #888;
            background-color: #ddd;
            padding: 3px;
            font-weight: bold;
            margin-top: 10px;
            margin-bottom: -8px;
        }

        .form {
            margin: 0;
            padding: 0;
        }

        .day {
            margin-top: 18px;
            padding: 0px 3px;
            display: inline-block;
        }

        .item {
            margin: 6px 0 6px 18px;
            overflow: auto;
        }

        .item .time {
            color: #888;
            float: left;
            padding-right: 6px;
            padding-top: 1px;
            white-space: nowrap;
            overflow: hidden;
            text-overflow: ellipsis;
        }

        .item .title {
            overflow: hidden;
            white-space: nowrap;
            text-overflow: ellipsis;
        }

        #pagination {
            padding-top: 24px;
            -webkit-margin-start: 18px;
            padding-bottom:18px;
        }

        #pagination a {
            padding: 8px;
            background-color: #ddd;
            -webkit-margin-end: 4px;
            color: -webkit-link;
        }

        .gap {
            margin: -5px 0 -5px 18px;
            width: 16px;
            border-right: 1px solid #ddd;
            height: 14px;
        }
    </style>
    <script>
    function search(term) {
        if ("{opts}")
            location = "chrome://history/?{opts}&q=" + encodeURIComponent(term);
        else
            location = "chrome://history/?q=" + encodeURIComponent(term);
    }
    </script>
</head>
<body>
    <div class="header">
        <form action="javascript:void();" onsubmit="search(this.term.value);" class="form">
            <input type="text" name="term" id="term" {terms} />
            <input type="submit" name="submit" value="Search history" />
        </form>
    </div>
    <div class="main">
        <div id="results-separator">
            {heading}
        </div>
        <div id="results">
            {items}
        </div>
        <div id="pagination">
            {buttons}
        </div>
    </div>
</body>
]==]

day_template = [==[
<div class="day">{day}</div>
]==]

item_template = [==[
<div class="item">
    <div class="time">{time}</div>
    <div class="title"><a href="{href}">{title}</a></div>
</div>
]==]

button_template = [==[
<a href="{uri}">{name}</a>
]==]

gap_html = [==[
<div class="gap"></div>
]==]


chrome.add("history/", function (view, uri)
    local sql_escape, escape = lousy.util.sql_escape, lousy.util.escape
    local opts = uri.opts

    local items = {}
    local ihtml, dhtml, time, ltime, day, lday, title
    local today = os.date("%A, %B %d, %Y")

    local sql = "SELECT id, uri, title, last_visit FROM history"

    -- Filter results with search terms
    local globs = {}
    if opts.q then
        string.gsub(opts.q, "(%S+)", function (term)
            local glob = sql_escape("*" .. string.lower(term) .. "*")
            table.insert(globs, string.format("(lower(uri) GLOB %s "
                .. "OR lower(title) GLOB %s)", glob, glob))
        end)
    end
    if #globs > 0 then
        sql = string.format("%s WHERE %s", sql, table.concat(globs, " AND "))
    end

    local limit = tonumber(opts.limit) or 250
    local page = math.max(tonumber(opts.p) or 1, 1)
    sql = string.format("%s ORDER BY last_visit DESC LIMIT %d OFFSET %d;",
        sql, limit + 1, (page - 1) * limit)

    -- Get history items
    local results, count = history.db:exec(sql)

    -- Build html from results
    for i = 1, math.min(count, limit) do
        local row = results[i]
        day = os.date("%A, %B %d, %Y", tonumber(row.last_visit))

        -- Check if we need a new day separator
        if lday ~= day then
            lday, ltime = day, nil
            if day == today then day = "Today - " .. day end
            dhtml = string.gsub(day_template, "{(%w+)}", { day = day })
            table.insert(items, dhtml)

        -- Insert gap between items more than 30 minutes apart
        elseif ltime and (ltime - tonumber(row.last_visit)) > 60*30 then
            table.insert(items, gap_html)
        end
        ltime = tonumber(row.last_visit)

        -- Add history item
        if time_format == "12h" then
            time = os.date("%I:%M %p", tonumber(row.last_visit))
        else
            time = os.date("%H:%M", tonumber(row.last_visit))
        end
        title = (row.title ~= "" and row.title) or row.uri
        ihtml = string.gsub(item_template, "{(%w+)}", { time = time,
            href = escape(row.uri), title = escape(title) })
        table.insert(items, ihtml)
    end

    -- Add pagination buttons
    local buttons, button = {}
    local buri = lousy.uri.copy(uri)
    if page > 1 then
        buri.opts.p = nil
        button = string.gsub(button_template, "{(%w+)}",
            { uri = tostring(buri), name = "Newest" })
        table.insert(buttons, button)

        buri.opts.p = page-1
        button = string.gsub(button_template, "{(%w+)}",
            { uri = tostring(buri), name = "Page " .. page-1 })
        table.insert(buttons, button)
    end
    -- Check if there are older items
    if count > limit then
        buri.opts.p = page+1
        button = string.gsub(button_template, "{(%w+)}",
            { uri = tostring(buri), name = "Page " .. page+1 })
        table.insert(buttons, button)
    end

    local subs = {
        items = table.concat(items, ""),
        opts = tostring(opts + {p="", q=""}),
        terms = opts.q and string.format("value=%q", escape(opts.q)) or "",
        buttons = table.concat(buttons, "") or "",
        heading = (opts.q and string.format("Showing results for %s",
            escape(string.format("%q", opts.q)))) or "History"
    }
    local html = string.gsub(html_template, "{(%w+)}", subs)
    view:load_string(html, tostring(uri))
end)

local cmd = lousy.bind.cmd
add_cmds({
    cmd("history", function (w, arg)
        if arg then
            w:new_tab(string.format("luakit://history/?q=%s",
                capi.luakit.uri_encode(arg)))
        else
            w:new_tab("luakit://history")
        end
    end),
})

-- Prevent the chrome page showing up in history
history.add_signal("add", function (uri)
    if string.match(uri, "^luakit://history/?") then
        return false
    end
end)

-- vim: et:sw=4:ts=8:sts=4:tw=80
