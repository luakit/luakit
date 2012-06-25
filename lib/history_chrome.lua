-- Grab what we need from the Lua environment
local table = table
local string = string
local io = io
local print = print
local pairs = pairs
local ipairs = ipairs
local math = math
local assert = assert
local setmetatable = setmetatable
local rawget = rawget
local rawset = rawset
local type = type
local os = os
local error = error

-- Grab the luakit environment we need
local history = require("history")
local lousy = require("lousy")
local chrome = require("chrome")
local add_binds = add_binds
local add_cmds = add_cmds
local webview = webview
local capi = {
    luakit = luakit
}

module("history.chrome")

local html = [==[
<!doctype html>
<html>
<head>
    <meta charset="utf-8">
    <title>History</title>
    <style type="text/css">
        body {
            background-color: white;
            color: black;
            margin: 1em;
            display: block;
            font-size: 84%;
            font-family: sans-serif;
        }

        ol, li {
            margin: 0px;
            padding: 0px;
        }

        h3 {
            color: black;
            font-size: 1.2em;
            margin-bottom: 0.5em;
        }

        h1, h2, h3 {
            text-shadow: 0 1px 0 #f2f2f2;
            -webkit-user-select: none;
            font-weight: normal;
        }

        #search-form input {
            width: 50%;
            min-width: 300px;
            font-weight: normal;
            font-size: 120%;
        }

        #results-header {
            border-top: 1px solid #aaa;
            background-color: #f2f2f2;
            padding: 3px;
            font-weight: normal;
            font-size: 120%;
            margin-top: 0.5em;
            margin-bottom: 0.5em;
        }

        .day {
            white-space: nowrap;
            margin-top: 1em;
            padding: 0 3px;
            display: block;

            -webkit-user-select: none;
            cursor: default;
        }

        .day-results {
            margin-bottom: 1em;
        }

        .entry {
            margin: 0;
            padding: 0;
            list-style: none;
            display: -webkit-box;
        }

        .entry:hover {
            background-color: #f6f6f6;
            -webkit-border-radius: 4px;
        }

        .entry .time, .entry .date {
            color: #888;
            text-align: right;

            overflow: hidden;
            text-overflow: ellipsis;
            white-space: nowrap;

            padding: 0.2em 0.3em 0.2em 0;
            margin: 0 0.3em 0 0;
            border-right: 1px solid #f2f2f2;

            -webkit-user-select: none;
            cursor: default;
        }

        .entry .time {
            width: 4em;
        }

        .entry .date {
            width: 7em;
        }

        .entry .title {
            padding: 0.2em 0;
            overflow: hidden;
            white-space: nowrap;
            text-overflow: ellipsis;
            max-width: 500px;
        }
        .entry .title a {
            text-decoration: none;
        }

        .entry .title a:hover {
            text-decoration: underline;
        }

        .entry .domain {
            color: #bbb;

            padding: 0.2em 0;
            margin-left: 0.75em;

            -webkit-box-flex: 1;
            overflow: hidden;
            white-space: nowrap;
            text-overflow: ellipsis;
        }

        .entry .domain a:hover {
            color: #999;
            text-decoration: underline;
            cursor: pointer;
            -webkit-user-select: none;
        }

    </style>
</head>
<body>
    <div class="header">
        <form id="search-form">
            <input type="text" id="search" />
        </form>
    </div>
    <div class="main">
        <div id="results-header">
            History
        </div>
        <div id="results">
        </div>
    </div>
</body>
]==]

local main_js = [=[
$(document).ready(function () {

    var months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    var days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];

    function make_history_item(h, use_date) {
        var domain = /:\/\/([^/]+)\//.exec(h.uri);
        return $("<li/>")
            .addClass("entry")
            .attr("id", h.id)
            .append($("<div/>") // time/date
                .addClass(use_date && "date" || "time")
                .text(use_date && h.date || h.time))
            .append($("<div/>") // title / uri
                .addClass("title")
                .append($("<a/>")
                    .attr("href", h.uri)
                    .text(h.title || h.uri)))
            .append($("<div/>")
                .addClass("domain")
                .append($("<a/>")
                    .text(domain && domain[1] || "")));
    };

    var $search = $('#search').eq(0);
    var $search_form = $('#search-form').eq(0);
    var $results_header = $("#results-header").eq(0);
    var $results = $('#results').eq(0);

    var non_blank = /\S/;

    var auto_submit_timer;
    var last_search;


    $search_form.submit(function (e) {
        // Stop submit
        e.preventDefault();

        // Stop auto-submit timer
        clearTimeout(auto_submit_timer);

        var query = $search.val();
        var mode = non_blank.test(query) && "results" || "main";

        $results_header.text(mode == "main" && "History" ||
            "Showing results for \"" + query + "\"");

        var results = history_search({ query: query, limit: 100 });

        // Clear all previous results
        $results.empty();

        // Save last search query
        last_search = $search.val();

        // return if no history items to display
        if (results.length === "undefined") {
            return;
        }

        var last_date;
        var $dlist;

        for (var i = 0; i < results.length; i++) {
            var h = results[i];

            if (h.date !== last_date) {
                last_date = h.date;

                if (i !== 0) {
                    $results.append($dlist);
                }

                if (mode === "main") {
                    $results.append($("<h3/>").addClass("day").text(h.date));
                }

                $dlist = $("<ol/>").addClass("day-results");
            }

            $dlist.append(make_history_item(h, mode === "results"));
        }

        $results.append($dlist);
    });

    $results.on("click", ".entry .domain", function (e) {
        $search.val($(this).text());
        $search.submit();
    });

    function submit_search() {
        if ($search.val() !== last_search) {
            $search_form.submit();
        }
    };

    $search.keydown(function () {
        clearTimeout(auto_submit_timer);
        auto_submit_timer = setTimeout(submit_search, 1000);
    });

    $search_form.submit();
});

]=]

export_funcs = {
    history_search = function (opts)
        local sql = { "SELECT id, uri, title, last_visit FROM ("
            .. "SELECT *, lower(uri||title) AS urititle FROM history"
        }

        local where, args, argc = {}, {}, 1

        string.gsub(opts.query or "", "(-?)([^%s]+)", function (notlike, term)
            if #term ~= 0 then
                table.insert(where, (notlike == "-" and "NOT " or "") ..
                    string.format("(urititle GLOB ?%d)", argc, argc))
                argc = argc + 1
                table.insert(args, "*"..string.lower(term).."*")
            end
        end)

        if #where ~= 0 then
            table.insert(sql, "WHERE " .. table.concat(where, " AND "))
        end

        table.insert(sql, string.format("ORDER BY last_visit DESC "
            .. "LIMIT ?%d OFFSET ?%d)", argc, argc+1))
        table.insert(args, opts.limit or -1)
        table.insert(args, opts.offset or 0)

        local rows = history.db:exec(table.concat(sql, " "), args)

        for i, row in ipairs(rows) do
            local time = rawget(row, "last_visit")
            rawset(row, "date", os.date("%d %b %Y", time))
            rawset(row, "time", os.date("%H:%M", time))
        end

        return rows
    end,
}

chrome.add("history", function (view, meta)
    local uri = "luakit://history/"
    view:load_string(html, uri)

    function on_first_visual(_, status)
        -- Wait for new page to be created
        if status ~= "first-visual" then return end

        -- Hack to run-once
        view:remove_signal("load-status", on_first_visual)

        -- Double check that we are where we should be
        if view.uri ~= uri then return end

        -- Export luakit JS<->Lua API functions
        for name, func in pairs(export_funcs) do
            view:register_function(name, func)
        end

        -- Load jQuery JavaScript library
        local jquery = lousy.load("lib/jquery.min.js")
        local _, err = view:eval_js(jquery, { no_return = true })
        assert(not err, err)

        -- Load main luakit://download/ JavaScript
        local _, err = view:eval_js(main_js, { no_return = true })
        assert(not err, err)
    end

    view:add_signal("load-status", on_first_visual)
end)

local cmd = lousy.bind.cmd
add_cmds({
    cmd("history", function (w)
        w:new_tab("luakit://history/")
    end),
})
