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
            margin: 10px;
            display: block;
            font-size: 84%;
            font-family: sans-serif;
        }

        #results-header {
            border-top: 1px solid #888;
            background-color: #ddd;
            padding: 3px;
            font-weight: bold;
            margin-top: 10px;
        }

        #search-form input {
            width: 50%;
            min-width: 300px;
            font-size: 140%;
        }

        .day {
            margin-top: 18px;
            padding: 0px 3px;
            display: inline-block;
        }

        .hist-item {
            margin: 6px 0 6px 0;
            overflow: auto;
        }

        .hist-item .time {
            color: #888;
            float: left;
            margin-right: 0.75em;
            overflow: hidden;
            padding-top: 1px;
            text-align: right;
            text-overflow: ellipsis;
            white-space: nowrap;
            width: 7em;
        }

        .hist-item .title {
            overflow: hidden;
            white-space: nowrap;
            text-overflow: ellipsis;
        }

        .gap {
            margin: -5px 0 -5px 18px;
            width: 16px;
            border-right: 1px solid #ddd;
            height: 14px;
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

    function make_history_item(h, absdate) {
        var d = new Date(h.last_visit * 1000);

        if (absdate) {
            var dstr = (d.getDate() + "&nbsp;" + months[d.getMonth()] + "&nbsp;"
                + d.getFullYear());
        } else {
            var dstr = (d.getHours() + ":" + d.getMinutes());
        }

        var e = ("<div class='hist-item' id='" + h.id + "'><div class='time'>"
            + dstr + "</div><div class='title'><a href='" + encodeURI(h.uri)
            + "'>" + $('<div/>').text(h.title).html() + "</a></div></div>");
        return e;
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

        if (non_blank.test(query)) {
            var absdate = true;
            $results_header.text("Showing results for \"" + query + "\"");
        } else {
            var absdate = false;
            $results_header.text("History");
        }

        var results = history_search({ query: query, limit: 100 });

        // Clear all previous results
        $results.empty();

        // Save last search query
        last_search = $search.val();

        // return if no history items to display
        if (results.length === "undefined") {
            return;
        }

        for (var i = 0; i < results.length; i++) {
            var h = results[i];
            $results.append(make_history_item(h, absdate));
        }
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
        local sql = { [[
            SELECT id, uri, title, last_visit FROM (
                SELECT *, lower(uri||title) AS urititle FROM history]] }

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

        table.insert(sql, "ORDER BY last_visit DESC")

        table.insert(sql, string.format("LIMIT ?%d OFFSET ?%d)", argc, argc+1))
        table.insert(args, opts.limit or -1)
        table.insert(args, opts.offset or 0)

        local query = table.concat(sql, " ")
        local rows = history.db:exec(query, args)

        print(string.gsub(table.concat(sql, " "), "%s+", " "))

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
