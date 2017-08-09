--- Simple sqlite3 bookmarks - chrome page.
--
-- This module allows you to add and remove bookmarks with a simple graphical
-- webpage at <luakit://bookmarks/>. You can currently:
--
--  - add, edit, and remove individual bookmarks,
--  - tag bookmarks or add markdown descriptions, and
--  - search for and filter bookmarks.
--
-- This module also adds convenience commands and bindings to quickly bookmark a
-- page.
--
-- @module bookmarks_chrome
-- @author Mason Larobina <mason.larobina@gmail.com>
-- @copyright 2012 Mason Larobina <mason.larobina@gmail.com>

-- Grab the luakit environment we need
local bookmarks = require("bookmarks")
local lousy = require("lousy")
local chrome = require("chrome")
local markdown = require("markdown")
local modes = require("modes")
local add_binds, add_cmds = modes.add_binds, modes.add_cmds

local _M = {}

--- Display the bookmark uri and title.
-- @type boolean
-- @readwrite
_M.show_uri = false

--- CSS for bookmarks chrome page.
-- @type string
-- @readwrite
_M.stylesheet = [===[
.bookmark {
    line-height: 1.6em;
    margin: 0.4em 0;
    padding: 0;
    left: 0;
    right: 0;
    border: 1px solid #fff;
    border-radius: 0.3em;
}
.bookmark:first-child { margin-top: 1em; }
.bookmark:last-child { margin-bottom: 1em; }

.bookmark .title, .bookmark .uri {
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
}

.bookmark .top {
    position: relative;
}

.bookmark .title a {
    font-weight: normal;
    text-decoration: none;
}

.bookmark .title a:hover {
    text-decoration: underline;
}

.bookmark .uri, .bookmark .desc {
    display: none;
}

.bookmark .uri {
    color: #aaa;
}

.bookmark .bottom {
    white-space: nowrap;
}

.bookmark .bottom a {
    text-decoration: none;
    -webkit-user-select: none;
    cursor: default;
}

.bookmark .bottom a:hover {
    cursor: pointer;
}

.bookmark .tags a {
    color: #666;
    background-color: #f6f6f6;
    padding: 0.1em 0.4em;
    margin: 0 0.3em;
    -webkit-border-radius: 0.2em;
    -webkit-box-shadow: 0 0.1em 0.1em #666;
}

.bookmark .tags a:hover {
    color: #111;
}

.bookmark .desc {
    color: #222;
    border-left: 0.3em solid #ddd;
    margin: 0 0 0.2em 0.5em;
    padding: 0 0 0 0.5em;
    max-width: 60em;
}

.bookmark .desc > * {
    margin-top: 0.2em;
    margin-bottom: 0.2em;
}

.bookmark .desc > :first-child {
    margin-top: 0;
}

.bookmark .desc > :last-child {
    margin-bottom: 0;
}

.bookmark .controls a {
    color: #888;
    padding: 0.1em 0.4em;
    margin: 0 0;
}

.bookmark .controls a:hover {
    background-color: #fff;
    -webkit-border-radius: 0.2em;
    -webkit-box-shadow: 0 0.1em 0.1em #666;
}

.bookmark .date {
    color: #444;
    margin-right: 0.2em;
}

#templates {
    display: none;
}

#blackout {
    position: fixed;
    left: 0;
    right: 0;
    top: 0;
    bottom: 0;
    opacity: 0.5;
    background-color: #000;
    z-index: 100;
}

#edit-dialog {
    position: fixed;
    z-index: 101;
    font-weight: 100;

    top: 6em;
    left: 50%;
    margin-left: -20em;
    margin-bottom: 6em;
    padding: 2em;
    width: 36em;

    background-color: #eee;
    border-radius: 0.5em;
    box-shadow: 0 0.5em 1em #000;
}

#edit-dialog td:first-child {
    vertical-align: middle;
    text-align: right;
    width: 4em;
}

#edit-dialog td {
    padding: 0.3em;
}

#edit-dialog input, #edit-dialog textarea {
    font-size: inherit;
    border: none;
    outline: none;
    margin: 0;
    padding: 0;
    background-color: #fff;
    border-radius: 0.25em;
    box-shadow: 0 0.1em 0.1em #888;
}

#edit-dialog input[type="text"], #edit-dialog textarea {
    width: 30em;
    padding: 0.5em;
}

#edit-dialog input[type="button"] {
    padding: 0.5em 1em;
    margin-right: 0.5em;
    color: #444;
}

#edit-dialog textarea {
    height: 5em;
}

#edit-view {
    display: none;
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
    <title>Bookmarks</title>
    <style type="text/css">
        {%stylesheet}
    </style>
</head>
<body>
    <header id="page-header">
        <h1>Bookmarks</h1>
        <span id="search-box">
            <input type="text" id="search" placeholder="Search bookmarks..." />
            <input type="button" class="button" id="clear-button" value="✕" />
            <input type="hidden" id="page" />
        </span>
        <input type="button" id="search-button" class="button" value="Search" />
        <div class="rhs">
            <!-- <input type="button" class="button" id="edit-button" value="Edit" /> -->
            <input type="button" class="button" id="new-button" value="New" />
        </div>
    </header>

    <div id="results" class="content-margin"></div>

    <div class="nav-button-box">
        <a id="nav-prev">prev</a>
        <a id="nav-next">next</a>
    </div>

    <div id="edit-view" stlye="position: absolute;">
        <div id="blackout"></div>
        <div id="edit-dialog">
            <table>
                <tr><td>Title:</td> <td><input class="title" type="text" /></td> </tr>
                <tr><td>URI:</td>   <td><input class="uri"   type="text" /></td> </tr>
                <tr><td>Tags:</td>  <td><input class="tags"  type="text" /></td> </tr>
                <tr><td>Info:</td>  <td><textarea class="desc"></textarea></td>  </tr>
                <tr>
                    <td></td>
                    <td>
                        <input type="button" class="submit-button" value="Save" />
                        <input type="button" class="cancel-button" value="Cancel" />
                    </td>
                </tr>
            </table>
        </div>
    </div>

    <div id="templates" class="hidden">
        <div id="bookmark-skelly">
            <div class="bookmark">
                <div class="title"><a></a></div>
                <div class="uri"></div>
                <div class="desc"></div>
                <div class="bottom">
                    <span class="date"></span>
                    <span class="tags"></span>
                    <span class="controls">
                        <a class="edit-button">edit</a>
                        <a class="delete-button">delete</a>
                    </span>
                </div>
            </div>
        </div>
    </div>
</body>
]==]

local main_js = [=[
$(document).ready(function () { 'use strict';

    var limit = 100, results_len = 0;

    var bookmark_html = $("#bookmark-skelly").html(),
        $results = $("#results"), $search = $("#search"),
        $edit_view = $("#edit-view"), $edit_dialog = $("#edit-dialog"),
        $next = $("#nav-next").eq(0), $prev = $("#nav-prev").eq(0),
        $page = $("#page").eq(0);

    if ($page.val() == "")
        $page.val(1);

    function make_bookmark(b) {
        var $b = $(bookmark_html);

        $b.attr("bookmark_id", b.id);
        $b.find(".title a").attr("href", b.uri).text(b.title || b.uri);
        $b.find(".date").text(b.date);

        if (b.title)
            $b.find(".uri").text(b.uri).show();

        if (b.markdown_desc)
            $b.find(".desc").html(b.markdown_desc).show();

        if (b.tags) {
            var $tags = $b.find(".tags"), tags = b.tags.split(" "),
                len = tags.length, i = 0;
            for (; i < len;)
                $tags.append($("<a></a>").text(tags[i++]));
        }

        return $b.prop("outerHTML");
    }

    function show_edit(b) {
        b = b || {};
        var $e = $edit_dialog;
        $e.attr("bookmark_id", b.id);
        $e.attr("created", b.created);
        $e.find(".title").val(b.title);
        $e.find(".uri").val(b.uri);
        $e.find(".tags").val(b.tags);
        $e.find(".desc").val(b.desc);
        $edit_view.fadeIn("fast", function () {
            $edit_dialog.find(".title").focus();
        });
    }

    function find_bookmark_parent(that) {
        return $(that).parents(".bookmark").eq(0);
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
            bookmarks_search({
                query: query,
                limit: limit,
                page: parseInt($page.val(), 10)
            }).then(function (results) {

            // Used to trigger hiding of next nav button when results_len < limit
            results_len = results.length || 0;

            if (results.length === "undefined") {
                $results.empty();
                update_nav_buttons();
                return;
            }

            /* display results */
            var html = "";
            for (var i = 0; i < results.length; i++)
                html += make_bookmark(results[i]);

            update_nav_buttons();

            $results.get(0).innerHTML = html;
        });
    };

    /* input field callback */
    $search.keydown(function(ev) {
        if (ev.which == 13) { /* Return */
            $page.val(1);
            search();
            $search.blur();
            reset_mode();
        }
    });

    // 'delete' callback
    $results.on("click", ".bookmark .controls .delete-button", function (e) {
        var $b = find_bookmark_parent(this);
        // delete bookmark from database
        bookmarks_remove(parseInt($b.attr("bookmark_id")));
        // remove/hide bookmark from list
        $b.slideUp(function() { $b.remove(); });
    });

    $results.on("click", ".bookmark .tags a", function () {
        $search.val($(this).text());
        search();
    });

    $results.on("click", ".bookmark .controls .edit-button", function (e) {
        var $b = find_bookmark_parent(this);
        bookmarks_get(parseInt($b.attr("bookmark_id"))).then(function (b) {
            show_edit(b);
        });
    });

    function edit_submit() {
        var $e = $edit_dialog, id = $e.attr("bookmark_id"),
            created = $e.attr("created");

        try {
            bookmarks_add($e.find(".uri").val(), {
                title: $e.find(".title").val(),
                tags: $e.find(".tags").val(),
                desc: $e.find(".desc").val(),
                created: created ? parseInt(created) : undefined,
            });
        } catch (err) {
            alert(err);
            return;
        }

        // Delete existing bookmark (only when editing bookmark)
        if (id)
            bookmarks_remove(parseInt(id));

        search();

        $edit_view.fadeOut("fast");
    };

    $edit_dialog.on("click", ".submit-button", function (e) {
        edit_submit();
    });

    $edit_dialog.find('input[type="text"]').keydown(function(ev) {
        if (ev.which == 13) /* Return */
            edit_submit();
    });

    $edit_dialog.on("click", ".cancel-button", function (e) {
        $edit_view.fadeOut("fast");
    });

    $("#new-button").click(function () {
        show_edit();
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

    search();

    new_bookmark_values().then(function (values) {
        if (values)
            show_edit(values);
    });
});
]=]

local new_bookmark_values

local export_funcs = {
    bookmarks_search = function (_, opts)
        if not bookmarks.db then bookmarks.init() end

        local sql = { "SELECT", "*", "FROM bookmarks" }

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
            sql[2] = [[ *, lower(uri||title||desc||tags) AS text ]]
            table.insert(sql, "WHERE " .. table.concat(where, " AND "))
        end

        local order_by = [[ ORDER BY created DESC LIMIT ?%d OFFSET ?%d ]]
        table.insert(sql, string.format(order_by, argc, argc+1))

        local limit, page = opts.limit or 100, opts.page or 1
        table.insert(args, limit)
        table.insert(args, limit > 0 and (limit * (page - 1)) or 0)

        sql = table.concat(sql, " ")

        if #where ~= 0 then
            local wrap = [[SELECT id, uri, title, desc, tags, created, modified
                FROM (%s)]]
            sql = string.format(wrap, sql)
        end

        local rows = bookmarks.db:exec(sql, args)

        local date = os.date
        for _, row in ipairs(rows) do
            row.date = date("%d %B %Y", row.created)
            local desc = row.desc
            if desc and string.find(desc, "%S") then
                row.markdown_desc = markdown(desc)
            end
        end

        return rows
    end,

    bookmarks_add = function (_, ...) return bookmarks.add(...) end,
    bookmarks_get = function (_, ...) return bookmarks.get(...) end,
    bookmarks_remove = function (_, ...) return bookmarks.remove(...) end,

    new_bookmark_values = function (_)
        local values = new_bookmark_values
        new_bookmark_values = nil
        return values
    end,
}

chrome.add("bookmarks", function ()
    local style = chrome.stylesheet .. _M.stylesheet

    if not _M.show_uri then
        style = style .. " .bookmark .uri { display: none !important; } "
    end

    local html = string.gsub(html_template, "{%%(%w+)}", { stylesheet = style })
    return html
end,
function (view)
    -- Load jQuery JavaScript library
    local jquery = lousy.load("lib/jquery.min.js")
    view:eval_js(jquery, { no_return = true })

    -- Load main luakit://bookmarks/ JavaScript
    view:eval_js(main_js, { no_return = true })
end,
export_funcs)

--- URI of the bookmarks chrome page.
-- @type string
-- @readonly
_M.chrome_page = "luakit://bookmarks/"

add_binds("normal", {
    { "B", "Add a bookmark for the current URL.",
        function(w)
            new_bookmark_values = { uri = w.view.uri, title = w.view.title }
            w:new_tab(_M.chrome_page)
        end },
    { "^gb$", "Open the bookmarks manager in the current tab.",
        function(w) w:navigate(_M.chrome_page) end },
    { "^gB$", "Open the bookmarks manager in a new tab.",
        function(w) w:new_tab(_M.chrome_page) end }
})

add_cmds({
    { ":bookmarks", "Open the bookmarks manager in a new tab.",
        function (w) w:new_tab(_M.chrome_page) end },
    { ":bookmark", "Add a bookmark for the current URL.", {
        func = function (w, o)
            local a = o.arg
            if not a then
                new_bookmark_values = {
                    uri = w.view.uri, title = w.view.title
                }
            else
                a = lousy.util.string.split(a)
                new_bookmark_values = {
                    uri = a[1], tags = table.concat(a, " ", 2)
                }
            end
            w:new_tab(_M.chrome_page)
        end,
        format = "{uri}",
    }},
})

return _M

-- vim: et:sw=4:ts=8:sts=4:tw=80
