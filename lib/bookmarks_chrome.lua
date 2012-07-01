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

        .bookmark .lhs {
            width: 7em;
            margin: 0;
            padding: 0;
            color: #888;
            overflow: hidden;
            white-space: nowrap;
            text-overflow: ellipsis;
            -webkit-user-select: none;
            cursor: default;
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
            </ol>
        </div>
    </div>
</body>
]==]


local main_js = [=[
$(document).ready(function () {
    var results = bookmarks_search({ limit: 100 })

    if (results.length === "undefined") {
        return;
    }

    var $results = $("#results").eq(0);

    var bookmark_html = $("#bookmark-template").html();

    $("#templates").empty();

    for (var i = 0; i < results.length; i++) {
        var b = results[i];

        var $e = $(bookmark_html);
        $e.find(".title a").attr("href", b.uri).text(b.title || b.uri);
       // $e.find(".uri").text(b.uri);
        $e.find(".lhs").text(b.date);

        if (b.tags) {
            var $tags = $e.find(".tags");
            $tags.empty();

            var tags = (b.tags || "").split(",");

            for (var j = 0; j < tags.length; j++) {
                $tags.append($("<div></div>").addClass("tag").text(tags[j]));
            }
        }

        $results.append($e);
    }

});
]=]

export_funcs = {
    bookmarks_search = function (opts)
        if not bookmarks.db then bookmarks.init() end

        local rows = bookmarks.db:exec [[
            SELECT b.*, group_concat(t.name) AS tags
            FROM bookmarks AS b LEFT JOIN tagmap AS map LEFT JOIN tags AS t
            ON map.bookmark_id = b.id AND map.tag_id = t.id
            GROUP BY b.id
            LIMIT 100
        ]]

        for i, row in ipairs(rows) do
            rawset(row, "date", os.date("%d %b %Y", rawget(row, "created")))
        end

        return rows
    end,
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

local cmd = lousy.bind.cmd
add_cmds({
    cmd("bookmarks", function (w)
        w:new_tab("luakit://bookmarks/")
    end),
})
