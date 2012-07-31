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
            font-size: 1.2em;
            display: block;
            padding: .5em;
            margin: 0.2em 0;
            left: 0;
            right: 0;
            border: 1px solid #fff;
            -webkit-border-radius: 0.3em;
        }

        .bookmark:hover {
            background-color: #f8f8f8;
        }

        .bookmark .top, .bookmark .bottom {
            display: block;
        }

        .bookmark .top {
            max-width: 700px;
            overflow: hidden;
            text-overflow: ellipsis;
            white-space: nowrap;
            font-size: 1em;
        }

        .bookmark .top .title {
            text-decoration: none;
            font-size: 1.1em;
        }

        .bookmark .top .title:hover {
            text-decoration: underline;
        }

        .bookmark .bottom {
            margin: .5em 0 0 .5em;
            font-size: 0.9em;
            vertical-align: middle;
            white-space: nowrap;
        }

        .bookmark .bottom a {
            text-decoration: none;
            -webkit-user-select: none;
            cursor: default;
        }

        .bookmark .tags a {
            margin: 0 .3em;
            padding: .2em .4em;
            color: #666;
            background-color: #f0f0f0;
            border-left: 1px solid #f5f5f5;
            border-top: 1px solid #f5f5f5;
            border-bottom: 1px solid #bbb;
            border-right: 1px solid #bbb;
            -webkit-border-radius: 0.3em;
        }

        .bookmark .tags a:hover {
            color: #222;
            cursor: pointer;
        }

        .bookmark .controls a {
            color: #aaa;
            margin: 0 .3em;
        }

        .bookmark .controls a:hover {
            color: #11c;
            text-decoration: underline;
            cursor: pointer;
        }

        .bookmark .hidden {
            opacity: 0;
        }

        .bookmark .desc {
            border-left: 1px solid #aaa;
            padding: 0.3em 0 0.3em 0.5em;
            width: 500px;
            display: block;
            margin: 0.2em 0 0 0.5em;
        }

        .bookmark .desc :first-child {
            margin-top: 0;
        }

        .bookmark .desc :last-child {
            margin-bottom: 0;
        }

        .edit {
            margin: 1em 0 0 0.5em;
            left: 0;
            right: 0;
        }

        .edit li {
            margin-left: 4em;
            display: block;
        }

        .edit li span {
            display: inline-block;
            width: 4em;
            margin-left: -4em;
            text-align: right;
            margin-top: 0.7em;
            vertical-align: top;
            line-height: 1.4em;
        }

        .edit .field input {
            margin: 0.3em;
            font-size: 1.1em;
            display: inline-block;
            width: 400px;
            outline: none;
            padding: 0.3em;
        }

        .edit li textarea {
            outline: none;
            width: 350px;
            padding: 0.3em;
            margin: 0.3em;
            height: 4em;
        }

        .editing, .editing:hover {
            border: 1px solid #aaa;
            background-color: #f8f8f8;
        }

        .edit .submit-button {
            display: inline-block;
            min-width: 0;
            padding: 0.3em 0.5em;
        }

        #templates {
            display: none;
        }
    </style>
</head>
<body>
    <div class="header">
        <input type="text" id="input" />
        <input type="button" id="search" value="search" />
    </div>
    <div class="main">
        <div id="results-header">Bookmark Manager</div>
        <ol id="results">
        </ol>
    </div>

    <div id="templates">
        <div id="bookmark-skelly">
            <li class="bookmark">
                <div class="top"><a class="title"></a></div>
                <div class="desc"></div>
                <div class="bottom">
                    <span class="date"></span>
                    <span class="tags"></span>
                    <span class="controls hidden">
                        <a class="edit-button">edit</a>
                        <a class="delete-button">delete</a>
                    </span>
                </div>
            </li>
        </div>
        <div id="edit-skelly">
            <ol class="edit">
                <li class="field title"><span>Title:&nbsp;</span><input /></li>
                <li class="field uri"><span>URI:&nbsp;</span><input /></li>
                <li class="field tags"><span>Tags:&nbsp;</span><input /></li>
                <li class="edit-desc"><span>Info:&nbsp;</span><textarea></textarea></li>
                <li>
                    <input type="button" class="submit-button" value="Update" />
                    <input type="button" class="cancel-button" value="Cancel" />
                </li>
            </ol>
        </div>
    </div>
</body>
]==]

local main_js = [=[
$(document).ready(function () {
    var default_limit = 100;

    var bookmarks = {};

    var bookmark_html = $("#bookmark-skelly").html(),
        edit_html = $("#edit-skelly").html(),
        $results = $("#results");

    $("#templates").remove();

    function make_bookmark(b) {
        bookmarks[b.id] = b;

        var $b = $(bookmark_html);
        $b.attr("bookmark_id", b.id);
        $b.find(".title").attr("href", b.uri).text(b.title || b.uri);
        $b.find(".date").text(b.date);

        if (b.markdown_desc)
            $b.find(".desc").html(b.markdown_desc);
        else
            $b.find(".desc").remove();

        /* add tags if specified */
        if (b.tags) {
            var $tags = $b.find(".tags").eq(0);
            var tags = (b.tags || "").split(","), len = tags.length;
            for (var i = 0; i < len; i++)
                $tags.append($("<a></a>").text(tags[i]));
        }

        return $b;
    }

    function render_results(results) {
        if (results.length === "undefined") return;

        /* clear results container */
        $results.empty();

        /* add new results */
        for (var i = 0; i < results.length; i++)
            $results.append(make_bookmark(results[i]));

        // Show bookmark controls when hovering directly over buttons
        $results.on("mouseenter", ".bookmark .controls", function () {
            $(this).removeClass("hidden");
        });

        // Hide controls when leaving bookmark
        $results.on("mouseleave", ".bookmark", function () {
            $(this).find(".bottom .controls").addClass("hidden");
        });

        $results.on("click", ".bookmark .controls .edit-button", function (e) {
            var $b = $(this).parents(".bookmark").eq(0), $e = $(edit_html);

            // Remove previous edit form
            $b.find(".edit").remove();

            $b.addClass("editing");

            // Animate out & delete form
            $e.find(".cancel-button").click(function (e) {
                $b.removeClass("editing");
                $e.slideUp(function () { $e.remove(); })
            });

            var b = bookmarks[$b.attr("bookmark_id")],
                $title = $e.find(".title input").eq(0).val(b.title),
                $uri = $e.find(".uri input").eq(0).val(b.uri),
                $tags = $e.find(".tags input").eq(0).val(b.tags);
                $desc = $e.find(".edit-desc textarea").eq(0).val(b.desc);

            $e.find(".submit-button").click(function (e) {
                // Add new bookmark
                bookmarks_add($uri.val(), { title: $title.val(), tags: $tags.val(),
                    desc: $desc.val(), created: b.created });
                // Remove old bookmark
                bookmarks_remove(b.id);
                $e.slideUp(function () {
                    render_results(bookmarks_search({ limit: default_limit }));
                });
            });

            $e.hide();
            $b.append($e);
            $e.slideDown();
        });
    };

    var input = $("#input");
    var search = function() {
        var query = input.val();
        render_results(bookmarks_search({
            limit : default_limit,
            query : query
        }));
    };

    /* input field callback */
    input.keydown(function(ev) {
        if (ev.which == 13) search();
    });

    /* search button callback */
    $("#search").click(search);

    render_results(bookmarks_search({ limit: default_limit }));
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
            rawset(row, "date", os.date("%d %B %Y", rawget(row, "created")))
            local desc = rawget(row, "desc")
            if desc then
                rawset(row, "markdown_desc", markdown(desc))
            end
        end

        return rows
    end,

    bookmarks_add = bookmarks.add,
    bookmarks_remove = bookmarks.remove,
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
