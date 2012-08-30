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
local bookmarks = require("bookmarks")
local lousy = require("lousy")
local chrome = require("chrome")
local markdown = require("markdown")
local sql_escape = lousy.util.sql_escape
local add_binds = add_binds
local add_cmds = add_cmds
local webview = webview
local capi = {
    luakit = luakit
}

module("bookmarks.chrome")

-- Display the bookmark uri and title.
show_uri = false

stylesheet = [===[
.bookmark {
    line-height: 1.6em;
    padding: 0.4em 0.5em;
    margin: 0;
    left: 0;
    right: 0;
    border: 1px solid #fff;
    border-radius: 0.3em;
}

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
    font-size: 1.4em;
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
    font-size: 1.3em;
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
]===]


local html = [==[
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
        <span id="search-box">
            <input type="text" id="search" placeholder="Search bookmarks..." />
            <input type="button" id="clear-button" value="X" />
        </span>
        <input type="button" id="search-button" class="button" value="Search" />
        <div class="rhs">
            <!-- <input type="button" class="button" id="edit-button" value="Edit" /> -->
            <input type="button" class="button" id="new-button" value="New" />
        </div>
    </header>

    <div id="results" class="content-margin"></div>

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
$(document).ready(function () { 'use strict'

    var bookmark_html = $("#bookmark-skelly").html(),
        $results = $("#results"), $search = $("#search"),
        $edit_view = $("#edit-view"), $edit_dialog = $("#edit-dialog");

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

    function search() {

        var results = bookmarks_search({ query: $search.val() });

        if (results.length === "undefined") {
            $results.empty();
            return;
        }

        /* display results */
        var html = "";
        for (var i = 0; i < results.length; i++)
            html += make_bookmark(results[i]);

        $results.get(0).innerHTML = html;
    };

    /* input field callback */
    $search.keydown(function(ev) {
        if (ev.which == 13) { /* Return */
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
        var b = bookmarks_get(parseInt($b.attr("bookmark_id")));
        show_edit(b);
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
        search();
    });

    $("#search-button").click(function () {
        search();
    });

    search();

    var values = new_bookmark_values();
    if (values)
        show_edit(values);
});
]=]

local new_bookmark_values

export_funcs = {
    bookmarks_search = function (opts)
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

    bookmarks_add = bookmarks.add,
    bookmarks_get = bookmarks.get,
    bookmarks_remove = bookmarks.remove,

    new_bookmark_values = function ()
        local values = new_bookmark_values
        new_bookmark_values = nil
        return values
    end,
}

chrome.add("bookmarks", function (view, meta)
    local uri = "luakit://bookmarks/"

    local style = chrome.stylesheet .. _M.stylesheet

    if not _M.show_uri then
        style = style .. " .bookmark .uri { display: none !important; } "
    end

    local html = string.gsub(html, "{%%(%w+)}", { stylesheet = style })

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

chrome_page = "luakit://bookmarks/"

local key, buf = lousy.bind.key, lousy.bind.buf
add_binds("normal", {
    key({}, "B", "Shortcut to add a bookmark to the current URL",
        function(w)
            new_bookmark_values = { uri = w.view.uri, title = w.view.title }
            w:new_tab(chrome_page)
        end),

    buf("^gb$", "Open bookmarks manager in the current tab.",
        function(w)
            w:navigate(chrome_page)
        end),

    buf("^gB$", "Open bookmarks manager in a new tab.",
        function(w)
            w:new_tab(chrome_page)
        end)
})

local cmd = lousy.bind.cmd
add_cmds({
    cmd("bookmarks", "Open bookmarks manager in a new tab.",
        function (w)
            w:new_tab(chrome_page)
        end),

    cmd("bookmark", "Add bookmark",
        function (w, a)
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
            w:new_tab(chrome_page)
        end),
})
