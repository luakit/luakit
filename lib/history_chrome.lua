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

stylesheet = [===[
.day-heading {
    font-size: 1.6em;
    font-weight: 100;
    margin: 1em 0 0.5em 0.5em;
    -webkit-user-select: none;
    cursor: default;
    overflow: hidden;
    white-space: nowrap;
    text-overflow: ellipsis;
}

.day-sep {
    height: 1em;
}

.item {
    font-size: 1.3em;
    font-weight: 400;
    overflow: hidden;
    white-space: nowrap;
    text-overflow: ellipsis;
}

.item span {
    padding: 0.2em;
}

.item .time {
    -webkit-user-select: none;
    cursor: default;
    color: #888;
    display: inline-block;
    width: 5em;
    text-align: right;
    border-right: 1px solid #ddd;
    padding-right: 0.5em;
    margin-right: 0.1em;
}

.item a {
    text-decoration: none;
}

.item .domain a {
    color: #aaa;
}

.item .domain a:hover {
    color: #666;
}

.item.selected {
    background-color: #eee;
}

.nav-button-box {
    margin: 2em;
}

.nav-button-box a {
    display: none;
    border: 1px solid #aaa;
    padding: 0.4em 1em;
}

]===]

local html = [==[
<!doctype html>
<html>
<head>
    <meta charset="utf-8">
    <title>History</title>
    <style type="text/css">
        {%stylesheet}
    </style>
</head>
<body>
    <header id="page-header">
        <span id="search-box">
            <input type="text" id="search" placeholder="Search history..." />
            <input type="button" id="clear-button" value="X" />
        </span>
        <input type="button" id="search-button" class="button" value="Search" />
        <div class="rhs">
            <input type="button" class="button" disabled id="clear-selected-button" value="Clear selected" />
            <input type="button" class="button" disabled id="clear-results-button" value="Clear results" />
            <input type="button" class="button" id="clear-all-button" value="Clear all" />
        </div>
    </header>

    <div id="results" class="content-margin"></div>

    <div class="nav-button-box">
        <a id="nav-prev">prev</a>
        <a id="nav-next">next</a>
    </div>

    <div id="templates" class="hidden">
        <div id="item-skelly">
            <div class="item">
                <span class="time"></span>
                <span class="title"><a></a></span>
                <span class="domain"><a></a></span>
            </div>
        </div>
    </div>
</body>
]==]

local main_js = [=[
$(document).ready(function () { 'use strict';

    var limit = 100, page = 1, results_len = 0;

    var months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    var days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];

    var item_html = $("#item-skelly").html();
    $("#templates").remove();

    function make_history_item(h) {
        var $e = $(item_html);
        $e.attr("history_id", h.id);
        $e.find(".time").text(h.time);
        $e.find(".title a")
            .attr("href", h.uri)
            .text(h.title || h.uri);
        var domain = /:\/\/([^/]+)\//.exec(h.uri);
        $e.find(".domain a").text(domain && domain[1] || "");
        return $e.prop("outerHTML");
    };

    var $search = $('#search').eq(0),
        $results = $('#results').eq(0),
        $results_header = $("#results-header").eq(0),
        $clear_all = $("#clear-all-button").eq(0),
        $clear_results = $("#clear-results-button").eq(0),
        $clear_selected = $("#clear-selected-button").eq(0),
        $next = $("#nav-next").eq(0),
        $prev = $("#nav-prev").eq(0);

    function update_clear_buttons(all, results, selected) {
        $clear_all.attr("disabled", !!all);
        $clear_results.attr("disabled", !!results);
        $clear_selected.attr("disabled", !!selected);
    }

    function update_nav_buttons() {
        if (results_len === limit)
            $next.show();
        else
            $next.hide();
        if (page > 1)
            $prev.show();
        else
            $prev.hide();
    }

    function search() {
        var query = $search.val(),
            results = history_search({
                query: query, limit: limit, page: page });

        // Used to trigger hiding of next nav button when results_len < limit
        results_len = results.length || 0;

        update_clear_buttons(query, !query, true);

        if (!results.length) {
            $results.empty();
            update_nav_buttons();
            return;
        }

        var last_date, last_time = 0, group_html;

        var i = 0, len = results.length, html = "";

        var sep = $("<div/>").addClass("day-sep").prop("outerHTML"),
            $heading = $("<div/>").addClass("day-heading");

        for (; i < len;) {
            var h = results[i++];

            if (h.date !== last_date) {
                last_date = h.date;
                html += $heading.text(h.date).prop("outerHTML");

            } else if ((last_time - h.last_visit) > 3600)
                html += sep;

            last_time = h.last_visit;
            html += make_history_item(h);
        }

        update_nav_buttons(query);

        $results.get(0).innerHTML = html;
    }

    /* input field callback */
    $search.keydown(function(ev) {
        if (ev.which == 13) { /* Return */
            reset_mode();
            page = 1;
            search();
            $search.blur();
        }
    });

    $("#clear-button").click(function () {
        $search.val("");
        page = 1;
        search();
    });

    $("#search-button").click(function () {
        page = 1;
        search();
    });

    // Auto search history by domain when clicking on domain
    $results.on("click", ".item .domain a", function (e) {
        $search.val($(this).text());
        search();
    });

    // Select items & enable/disable clear all selected button
    $results.on("click", ".item", function (e) {
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
                search();
            });
            $clear_all.blur();
        }
    });

    $next.click(function () {
        page++;
        search();
    });

    $prev.click(function () {
        page = Math.max(page-1,1);
        search();
    });

    function clear_elems($elems) {
        var ids = [], last = $elems.length - 1;

        $elems.each(function (index) {
            var $e = $(this);
            ids.push($e.attr("history_id"));
            if (index == last)
                $e.fadeOut("fast", function () { search(); });
            else
                $e.fadeOut("fast");
        });

        if (ids.length)
            history_clear_list(ids);
    };

    $clear_results.click(function () {
        clear_elems($results.find(".item"));
        $clear_results.blur();
    });

    $clear_selected.click(function () {
        clear_elems($results.find(".selected"));
        $clear_selected.blur();
    });

    var query = initial_search_term();
    if (query)
        $search.val(query);

    search();
});

]=]

local initial_search_term

export_funcs = {
    history_search = function (opts)
        local sql = { "SELECT", "*", "FROM history" }

        local where, args, argc = {}, {}, 1

        string.gsub(opts.query or "", "(-?)([^%s]+)", function (notlike, term)
            if term ~= "" then
                table.insert(where, (notlike == "-" and "NOT " or "") ..
                    string.format("(text GLOB ?%d)", argc, argc))
                argc = argc + 1
                table.insert(args, "*"..string.lower(term).."*")
            end
        end)

        if #where ~= 0 then
            sql[2] = [[ *, lower(uri||title) AS text ]]
            table.insert(sql, "WHERE " .. table.concat(where, " AND "))
        end

        local order_by = [[ ORDER BY last_visit DESC LIMIT ?%d OFFSET ?%d ]]
        table.insert(sql, string.format(order_by, argc, argc+1))

        local limit, page = opts.limit or 100, opts.page or 1
        table.insert(args, limit)
        table.insert(args, limit > 0 and (limit * (page - 1)) or 0)

        sql = table.concat(sql, " ")

        if #where ~= 0 then
            local wrap = [[SELECT id, uri, title, last_visit FROM (%s)]]
            sql = string.format(wrap, sql)
        end

        local rows = history.db:exec(sql, args)

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

    initial_search_term = function ()
        local term = initial_search_term
        initial_search_term = nil
        return term
    end,
}

chrome.add("history", function (view, meta)

    local html = string.gsub(html, "{%%(%w+)}", {
        -- Merge common chrome stylesheet and history stylesheet
        stylesheet = chrome.stylesheet .. stylesheet
    })

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
        initial_search_term = query
        w:new_tab("luakit://history/")
    end),
})
