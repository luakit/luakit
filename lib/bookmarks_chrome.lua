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
local sql_escape = lousy.util.sql_escape
local add_binds = add_binds
local add_cmds = add_cmds
local webview = webview
local capi = {
    luakit = luakit
}

module("bookmarks.chrome")

local html = [==[
<!doctype html>
<html>
<head>
    <meta charset="utf-8">
    <title>Bookmarks</title>
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
            margin: 0px;
            padding: 0px;
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

        #input {
            min-width: 33%;
            width: 10em;
            font-size: 1.6em;
            font-weight: normal;
        }

        #search {
            padding: 0 0.6em;
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

        .bookmark {
            margin: 0;
            padding: 0.3em;
            list-style: none;
            border: 1px solid #fff;
            font-size: 1.2em;
            display: -webkit-box;
            overflow: hidden;
            white-space: nowrap;
            text-overflow: ellipsis;
        }

        .bookmark:hover {
            background-color: #f2f2f2;
            border: 1px solid #e5e5e5;
            -webkit-border-radius: 4px;
        }

        .bookmark .title {
            margin: 0;
        }

        .bookmark .title a {
            text-decoration: none;
            overflow: visible;
        }

        .bookmark .title a:hover {
            text-decoration: underline;
        }

        .bookmark .tags {
            display: -webkit-box;
            margin-top: 3px;
        }

        .bookmark .tag {
            margin: 0.3em 0.5em 0 0;
            padding: 0.4em;
            font-size: 0.8em;
            overflow: hidden;
            text-overflow: ellipsis;
            color: #888;
            background-color: #f0f0f0;
            border-left: 1px solid #f5f5f5;
            border-top: 1px solid #f5f5f5;
            border-bottom: 1px solid #bbb;
            border-right: 1px solid #bbb;
            -webkit-user-select: none;
            cursor: default;
            display: block;
        }

        .bookmark-box {
            display: block;
        }

        .bookmark .tag:hover {
            color: #000;
        }

        .bookmark .tag a {
            margin: 0 0.4em;
            text-decoration: none;
            font-weight: bold;
            color: #700;
            visibility: hidden;
        }

        .bookmark .lhs {
            width: 8em;
            margin: 0;
            padding: 0;
            color: #888;
            overflow: hidden;
            white-space: nowrap;
            text-overflow: ellipsis;
            -webkit-user-select: none;
            cursor: default;
        }

        .bookmark .del {
            margin: 0 2em;
            display: none;
        }

        .bookmark .del a {
            font-size: 90%;
            text-decoration: none;
            color: #888;
        }

        .bookmark .del a:hover {
            color: #700;
            text-decoration: underline;
        }
    </style>
</head>
<body>
    <div class="header">
        <input type="text" id="input" />
        <input type="button" id="search" value="search" />
    </div>
    <div class="main">
        <div id="results-header">
            Bookmark Manager
        </div>
        <div id="results">
        </div>
    </div>
    <div id="templates" style="display: hidden !important;">
        <div id="bookmark-template">
            <ol class="bookmark">
                <li class="lhs"></li>
                <li class="rhs">
                    <ol class="bookmark-box">
                        <li><div class="title"><a></a></div></li>
                        <li><div class="tags"></div></li>
                    </ol>
                </li>
                <li class="del"><a href="#">Delete</a></li>
            </ol>
        </div>
    </div>
</body>
]==]


local main_js = [=[
$(document).ready(function () {
    var default_limit = 100;

    var bookmark_html = $("#bookmark-template").html();
    var $results = $("#results");

    $("#templates").empty();

    var delete_link = function(element, id) {
        var del = element.find(".del");

        element.mouseenter(function() {
            del.show();
            element.find(".tag a").css("visibility", "visible");
        });

        element.mouseleave(function() {
            del.hide();
            element.find(".tag a").css("visibility", "hidden");
        });

        del.find("a").click(function() {
            delete_bookmark(id);
            element.hide(100, function() { element.remove(); });
        });
    };

    var add_tag = function(element, name, bid) {
        var tag = $("<div class=\"tag\">" + name + "</div>");
        var remove = $("<a href=\"#\">X</a>");

        remove.click(function() {
            remove_tag(bid, name);
            tag.hide(100, function() { tag.remove(); });
        });

        tag.append(remove);
        element.append(tag);
    };

    var process_results = function(results) {

        if (results.length === "undefined") {
            return;
        }

        /* clear results container */
        $results.empty();

        /* add new results */
        for (var i = 0; i < results.length; i++) {
            var b = results[i];

            var $e = $(bookmark_html);
            $e.find(".title a").attr("href", b.uri).text(b.title || b.uri);
            $e.find(".lhs").text(b.date);

            /* add tags if specified */
            if (b.tags) {
                var $tags = $e.find(".tags");
                $tags.empty();

                var tags = (b.tags || "").split(",");

                for (var j = 0; j < tags.length; j++) {
                    add_tag($tags, tags[j], b.id);
                }
            }

            /* add callbacks to 'delete' link */
            delete_link($e, b.id);

            /* add result to container */
            $results.append($e);
        }
    };

    var input = $("#input");
    var handle = function() {
        var query = input.val();
        process_results(bookmarks_search({
            limit : default_limit,
            query : query }));
    };

    input.keydown(function(ev) {
        if (ev.which == 13) handle();
    });

    var search = $("#search");
    search.click(handle);

    process_results(bookmarks_search({ limit: default_limit }));
});
]=]

export_funcs = {
    bookmarks_search = function (opts)
        if not bookmarks.db then bookmarks.init() end

        local limit = opts.limit or 100
        local has_query = opts.query and opts.query ~= ""

        local rows = has_query and bookmarks.db:exec(string.format([[
            SELECT b.*, group_concat(t.name) AS tags
            FROM bookmarks AS b LEFT JOIN tagmap AS map LEFT JOIN tags AS t
            ON map.bookmark_id = b.id AND map.tag_id = t.id
            WHERE lower(b.uri) GLOB %s
            GROUP BY b.id
            LIMIT ?
        ]], sql_escape("*"..string.lower(opts.query).."*")), { limit })
        or bookmarks.db:exec([[
            SELECT b.*, group_concat(t.name) AS tags
            FROM bookmarks AS b LEFT JOIN tagmap AS map LEFT JOIN tags AS t
            ON map.bookmark_id = b.id AND map.tag_id = t.id
            GROUP BY b.id
            LIMIT ?
        ]], { limit })

        for i, row in ipairs(rows) do
            rawset(row, "date", os.date("%d %b %Y", rawget(row, "created")))
        end

        return rows
    end,

    delete_bookmark = function (id)
        if not id then return end
        local bookmark_id = type(id) == "number" and id or tonumber(id)

        bookmarks.remove(bookmark_id)
    end,

    remove_tag = function (bookmark, tag)
        if not bookmark or not tag then return end
        local bookmark_id = type(bookmark) == "number" and bookmark or tonumber(bookmark)

        bookmarks.untag(bookmark_id, tag)
    end
}

chrome.add("bookmarks", function (view, meta)
    local uri = "luakit://bookmarks/"
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

chrome_page = "luakit://bookmarks/"

local key, buf = lousy.bind.key, lousy.bind.buf
add_binds("normal", {
    key({}, "B", "Shortcut to add a bookmark to the current URL",
        function(w)
            w:enter_cmd(":bookmark " .. (w.view.uri or "http://") .. " ")
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
                w:error("Missing bookmark arguments (use: `:bookmark <uri> [<tags>]`)")
                return
            end
            local args = lousy.util.string.split(a)
            local uri = table.remove(args, 1)
            bookmarks.add(uri, { tags = args })
        end),
})
