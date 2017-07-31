--- Save history in sqlite3 database - chrome page.
--
-- This module provides the luakit://history/ chrome page - a user interface for
-- searching the web browsing history.
--
-- @module history_chrome
-- @copyright 2010-2011 Mason Larobina <mason.larobina@gmail.com>

-- Grab the luakit environment we need
local history = require("history")
local lousy = require("lousy")
local chrome = require("chrome")
local modes     = require("modes")
local add_cmds  = modes.add_cmds

local _M = {}

--- CSS applied to the history chrome page.
-- @readwrite
_M.stylesheet = [===[
.day-heading {
    font-size: 1.3em;
    font-weight: 100;
    margin: 1em 0 0.5em 0;
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

local html_template = [==[
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
        <h1>History</h1>
        <span id="search-box">
            <input type="text" id="search" placeholder="Search history..." />
            <input type="button" class="button" id="clear-button" value="✕" />
            <input type="hidden" id="page" />
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

    var limit = 100, results_len = 0;

    var months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    var days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];

    var item_html = $("#item-skelly").html();

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
        $prev = $("#nav-prev").eq(0),
        $page = $("#page").eq(0);

    if ($page.val() == "")
        $page.val(1);

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
        if (parseInt($page.val(), 10) > 1)
            $prev.show();
        else
            $prev.hide();
    }

    function search() {
        var query = $search.val();
        history_search({
            query: query, limit: limit, page: parseInt($page.val(), 10),
        }).then(function (results) {
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
        });
    }

    /* input field callback */
    $search.keydown(function(ev) {
        if (ev.which == 13) { /* Return */
            reset_mode();
            $page.val(1);
            search();
            $search.blur();
        }
    });

    $("#clear-button").click(function () {
        $search.val("");
        $page.val(1);
        search();
    });

    $("#search-button").click(function () {
        $page.val(1);
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
        var page = parseInt($page.val(), 10);
        $page.val(page + 1);
        search();
    });

    $prev.click(function () {
        var page = parseInt($page.val(), 10);
        $page.val(Math.max(page - 1,1));
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

    initial_search_term().then(function (query) {
        if (query)
            $search.val(query);
        search();
    });
});

]=]

local initial_search_term

local export_funcs = {
    history_search = function (_, opts)
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

        for _, row in ipairs(rows) do
            local time = rawget(row, "last_visit")
            rawset(row, "date", os.date("%A, %d %B %Y", time))
            rawset(row, "time", os.date("%H:%M", time))
        end

        return rows
    end,

    history_clear_all = function (_)
        history.db:exec [[ DELETE FROM history ]]
    end,

    history_clear_list = function (_, ids)
        if not ids or #ids == 0 then return end
        local marks = {}
        for i=1,#ids do marks[i] = "?" end
        history.db:exec("DELETE FROM history WHERE id IN ("
            .. table.concat(marks, ",") .. " )", ids)
    end,

    initial_search_term = function (_)
        local term = initial_search_term
        initial_search_term = nil
        return term
    end,
}

chrome.add("history", function ()
    local html = string.gsub(html_template, "{%%(%w+)}", {
        -- Merge common chrome stylesheet and history stylesheet
        stylesheet = chrome.stylesheet .. _M.stylesheet
    })
    return html
end,
function (view)
    -- Load jQuery JavaScript library
    local jquery = lousy.load("lib/jquery.min.js")
    local _, err = view:eval_js(jquery, { no_return = true })
    assert(not err, err)

    -- Load main luakit://history/ JavaScript
    _, err = view:eval_js(main_js, { no_return = true })
    assert(not err, err)
end,
export_funcs)

-- Prevent history items from turning up in history
history.add_signal("add", function (uri)
    if string.match(uri, "^luakit://history/") then return false end
end)

add_cmds({
    { ":history", "Open <luakit://history/> in a new tab.",
        function (w, o)
            initial_search_term = o.arg
            w:new_tab("luakit://history/")
        end },
})

return _M

-- vim: et:sw=4:ts=8:sts=4:tw=80
