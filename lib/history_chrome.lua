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
            display: block;
            font-size: 62.5%;
            margin: 1em;
            font-family: sans-serif;
        }

        ol, li {
            margin: 0;
            padding: 0;
            list-style: none;
        }

        h3 {
            color: black;
            font-size: 1.6em;
            margin-bottom: 1.0em;
        }

        h1, h2, h3 {
            text-shadow: 0 1px 0 #f2f2f2;
            -webkit-user-select: none;
            font-weight: normal;
        }

        #search-form input {
            min-width: 33%;
            width: 10em;
            font-size: 1.6em;
            font-weight: normal;
        }

        #results-header {
            border-top: 1px solid #aaa;
            background-color: #f2f2f2;
            padding: 0.3em;
            font-weight: normal;
            font-size: 1.2em;
            margin-top: 0.5em;
            margin-bottom: 0.5em;
        }

        .day {
            white-space: nowrap;
            margin: 1em 0 0.5em 0;
            padding: 0 0.3em;
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
            font-size: 1.2em;
            display: -webkit-box;
        }

        .entry:hover {
            background-color: #f6f6f6;
            -webkit-border-radius: 0.5em;
        }

        .selected {
            background-color: #f0f0f0;
        }

        .selected:hover {
            background-color: #f0f0f0 !important;
            -webkit-border-radius: 0 !important;
        }

        .entry .time {
            color: #888;
            width: 4em;
            text-align: right;

            overflow: hidden;
            text-overflow: ellipsis;
            white-space: nowrap;

            padding: 0.3em 0.45em 0.3em 0;
            margin: 0 0.45em 0 0;
            border-right: 1px solid #f2f2f2;

            -webkit-user-select: none;
            cursor: default;
        }

        .entry .title {
            padding: 0.3em 0;
            overflow: hidden;
            white-space: nowrap;
            text-overflow: ellipsis;
            max-width: 600px;
        }

        .entry .title a {
            text-decoration: none;
        }

        .entry .title a:hover {
            text-decoration: underline;
        }

        .entry .domain {
            color: #bbb;
            padding: 0.3em 0;
            margin-left: 0.75em;
            -webkit-box-flex: 1;
            overflow: hidden;
            white-space: nowrap;
            text-overflow: ellipsis;
            text-decoration: none;
        }

        .entry .domain a:hover {
            color: #999;
            text-decoration: underline;
            cursor: pointer;
            -webkit-user-select: none;
        }

        #controls {
            margin: 1em 0 0 0;
        }

        #nav-buttons {
            display: -webkit-box;
            margin: 2em 0 2em 0.5em;
        }

        #nav-buttons a {
            font-size: 1.2em;
            display: block;
            padding: 0.5em 1em;
            margin-left: 0.5em;
            background-color: #eee;
            border: 1px solid #eee;
            -webkit-user-select: none;
            cursor: pointer;
            text-decoration: none;
            color: #444;
        }

        #nav-buttons a:hover {
            border: 1px solid #aaa;
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
        <div id="controls">
            <input type="button" id="clear-all" value="Clear All History...">
            <input type="button" id="clear-results" value="Clear All Results">
            <input type="button" id="clear-selected" value="Clear All Selected">
        </div>
        <div id="results">
        </div>
        <div id="nav-buttons">
            <a id="nav-prev" href>prev</a>
            <a id="nav-next" href>next</a>
        </div>
    </div>

    <div id="templates">
        <div id="entry-template">
            <li class="entry">
                <div class="time"></div>
                <div class="title"><a></a></div>
                <div class="domain"><a></a></div>
            </li>
        </div>
    </div>

</body>
]==]

local main_js = [=[
$(document).ready(function () {

    var limit = 100, page = 1, results_len = 0;

    var months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    var days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];

    var entry_html = $("#entry-template").html();
    $("#templates").remove();

    function make_history_item(h) {
        // Create element
        var $e = $(entry_html);
        $e.attr("id", h.id);
        // Update date/time
        $e.find(".time").text(h.time);
        // Set title & href
        $e.find(".title a")
            .attr("href", h.uri)
            .text(h.title || h.uri);
        // Set domain link
        var domain = /:\/\/([^/]+)\//.exec(h.uri);
        $e.find(".domain a").text(domain && domain[1] || "");
        return $e;
    };

    var $search = $('#search').eq(0),
        $results = $('#results').eq(0),
        $results_header = $("#results-header").eq(0),
        $clear_all = $("#clear-all").eq(0),
        $clear_results = $("#clear-results").eq(0),
        $clear_selected = $("#clear-selected").eq(0),
        $next = $("#nav-next").eq(0),
        $prev = $("#nav-prev").eq(0);

    function update_frag(query) {
        if (limit !== 100 || page > 1)
            document.location.hash = (
                encodeURIComponent(query ? query : "") + "/"
                + (limit === 100 ? "" : limit + ",") + page);
        else
            document.location.hash = (
                query ? encodeURIComponent(query) : "");
    }

    function update_buttons(query) {
        var uri = ("#" + encodeURIComponent(query ? query : "") + "/" +
            (limit === 100 ? "" : limit + ","));

        if (page > 1) {
            $prev.show();
            $prev.attr("href", uri + (page - 1));
        } else {
            $prev.hide();
            $prev.attr("href", uri + page);
        }

        if (results_len == limit) {
            $next.show();
            $next.attr("href", uri + (page + 1));
        } else {
            $next.hide();
            $next.attr("href", uri + page);
        }

    }

    function do_search(query) {
        // Detect blank query
        if (query && /^\s*$/.test(query))
            query = null;

        update_frag(query);

        $results_header.text(query && "Showing results for \"" +
            query + "\"" || "History");

        $clear_all.attr("disabled", !!query);
        $clear_results.attr("disabled", !query);
        $clear_selected.attr("disabled", true);

        var rows = history_search({ query: query, limit: limit, page: page });

        $results.empty();

        // Used to trigger hiding of next nav button when results_len < limit
        results_len = rows.length ? rows.length : 0;

        if (!rows.length) {
            results_len = 0;
            update_buttons(query);
            $clear_results.attr("disabled", true);
            $clear_all.attr("disabled", true);
            return;
        }

        var last_date, last_time = 0;
        var $group;

        for (var i = 0; i < rows.length; i++) {
            var h = rows[i];

            // Group items by date
            if (h.date !== last_date) {
                last_date = h.date;

                if (i !== 0)
                    $results.append($group);

                $results.append($("<h3/>").addClass("day").text(h.date));
                $group = $("<ol/>").addClass("day-results");

            // Create another group if items more than an hour apart
            } else if ((last_time - h.last_visit) > 3600) {
                $results.append($group);
                $group = $("<ol/>").addClass("day-results");
            }

            last_time = h.last_visit;
            $group.append(make_history_item(h));
        }
        $results.append($group);

        update_buttons(query);
    }

    var $search_form = $('#search-form').eq(0);

    $search_form.submit(function (e) {
        e.preventDefault();
        $search.blur();
        reset_mode();
        // We are starting a new query, show page 1
        page = 1;
        do_search($search.val());
    });

    // Auto search history by domain when clicking on domain
    $results.on("click", ".entry .domain a", function (e) {
        $search.val($(this).text());
        $search.submit();
    });

    $results.on("click", ".entry", function (e) {
        var $e = $(this);
        if ($e.hasClass("selected")) {
            $(this).removeClass("selected");
            if ($results.find(".selected").length === 0)
                $clear_selected.attr("disabled", true);
        } else {
            $(this).addClass("selected");
            $clear_selected.attr("disabled", false);
        }
    });

    $clear_all.click(function () {
        if (confirm("Clear all browsing history?")) {
            history_clear_all();
            $results.fadeOut("fast", function () {
                $results.empty();
                $results.show();
                $search_form.submit();
            });
            $clear_all.blur();
        }
    });

    function clear_elems($elems) {
        var ids = [], last_index = $elems.length - 1;
        $elems.each(function (index) {
            var $e = $(this);
            ids.push($e.attr("id"));
            if (index == last_index)
                $e.fadeOut("fast", function () { $search_form.submit() });
            else
                $e.fadeOut("fast");
            if (ids.length)
                history_clear_list(ids);
        });
    };

    $clear_results.click(function () {
        clear_elems($results.find(".entry"));
        $clear_results.blur();
    });

    $clear_selected.click(function () {
        clear_elems($results.find(".selected"));
        $clear_selected.blur();
    });

    function parse_frag() {
        var frag = document.location.hash.substr(1);
        var m = /\/(\d+),(\d+)$/.exec(frag) || /\/(\d+)$/.exec(frag);
        return {
            limit: m && m.length == 3 ? parseInt(m[1]) : 100,
            page: m ? parseInt(m[m.length - 1]) : 1,
            query: decodeURIComponent(
                m ? frag.substr(0, frag.length - m[0].length) : frag)
        }
    }

    $(window).on("hashchange", function () {
        var frag = parse_frag();

        if ($search.val() === frag.query && limit === frag.limit
            && page === frag.page)
            return;

        limit = frag.limit;
        page = frag.page;
        $search.val(frag.query);
        do_search(frag.query);
    });

    // Get initial query, limit & page num from URI fragment
    var frag = parse_frag();
    limit = frag.limit;
    page = frag.page;
    $search.val(frag.query);

    // Show initial search results
    do_search(frag.query);
});

]=]

export_funcs = {
    history_search = function (opts)
        local sql = { "SELECT id, uri, title, last_visit FROM ("
            .. "SELECT *, lower(uri||title) AS urititle FROM history"
        }

        local where, args, argc = {}, {}, 1

        string.gsub(opts.query or "", "(-?)([^%s]+)", function (notlike, term)
            if term ~= "" then
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
        table.insert(args, (opts.limit and opts.limit * (opts.page - 1)) or 0)

        local rows = history.db:exec(table.concat(sql, " "), args)

        for i, row in ipairs(rows) do
            local time = rawget(row, "last_visit")
            rawset(row, "date", os.date("%A, %d %B %Y", time))
            rawset(row, "time", os.date("%H:%M", time))
        end

        return rows
    end,

    history_clear_all = function ()
        history.db:exec [[ DELETE FROM history ]]
    end,

    history_clear_list = function (ids)
        if not ids or #ids == 0 then return end
        local marks = {}
        for i=1,#ids do marks[i] = "?" end
        history.db:exec("DELETE FROM history WHERE id IN ("
            .. table.concat(marks, ",") .. " )", ids)
    end,
}

chrome.add("history", function (view, meta)
    view:load_string(html, meta.uri)

    function on_first_visual(_, status)
        -- Wait for new page to be created
        if status ~= "first-visual" then return end

        -- Hack to run-once
        view:remove_signal("load-status", on_first_visual)

        -- Double check that we are where we should be
        if view.uri ~= meta.uri then return end

        -- Export luakit JS<->Lua API functions
        for name, func in pairs(export_funcs) do
            view:register_function(name, func)
        end

        view:register_function("reset_mode", function ()
            meta.w:set_mode() -- HACK to unfocus search box
        end)

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

-- Prevent history items from turning up in history
history.add_signal("add", function (uri)
    if string.match(uri, "^luakit://history/") then return false end
end)

local cmd = lousy.bind.cmd
add_cmds({
    cmd("history", function (w, query)
        w:new_tab("luakit://history/" .. (query and "#"..query or ""))
    end),
})
