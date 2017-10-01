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
    padding: 1em;
    width: 36.6em;

    background-color: #eee;
    border-radius: 0.3em;
    box-shadow: 0 0.5em 2em rgba(0, 0, 0, 0.3);
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

#edit-dialog input[type="button"], #edit-dialog input[type="submit"] {
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
        <form id="edit-dialog" method="get" action="#">
            <input name="id"      type="hidden" />
            <input name="created" type="hidden" />
            <table>
                <tr><td>Title:</td> <td><input name="title" type="text" /></td> </tr>
                <tr><td>URI:</td>   <td><input name="uri"   type="text" /></td> </tr>
                <tr><td>Tags:</td>  <td><input name="tags"  type="text" /></td> </tr>
                <tr><td>Info:</td>  <td><textarea name="desc"></textarea></td>  </tr>
                <tr>
                    <td></td>
                    <td>
                        <input type="submit" class="submit-button" value="Save" />
                        <input type="button" class="cancel-button" value="Cancel" />
                    </td>
                </tr>
            </table>
        </form>
    </div>

    <script>{%javascript}</script>
</body>
]==]

local main_js = [=[
function empty ($el) {
    while ($el.firstChild) $el.removeChild($el.firstChild)
}

window.addEventListener('load', () => {
    const limit = 100
    let resultsLen = 0
    const $editDialog = document.getElementById('edit-dialog')
    const $editView = document.getElementById('edit-view')
    const $next = document.getElementById('nav-next')
    const $page = document.getElementById('page')
    const $prev = document.getElementById('nav-prev')
    const $results = document.getElementById('results')
    const $search = document.getElementById('search')

    $page.value = $page.value || 1

    function makeBookmark (b) {
        b.tags = b.tags || ''
        let tagArray = b.tags.split(' ').filter(tag => tag)

        function escapeHTML(string) {
            let entityMap = {
                '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;',
                "'": '&#39;', '/': '&#x2F;', '`': '&#x60;', '=': '&#x3D;'
            }
            return String(string).replace(/[&<>"'`=\/]/g, s => entityMap[s]);
        }

        return `
            <div class=bookmark data-id="${b.id}">
                <div class=title>
                    <a href="${b.uri}">${escapeHTML(b.title || b.uri)}</a>
                </div>
                <div class=uri style="${b.title ? 'display: block;' : ''}">${b.uri}</div>
                <div class=desc style="${b.markdown_desc ? 'display: block;' : ''}">
                    ${b.markdown_desc}
                </div>
                <div class=bottom>
                    <span class=date>${b.date}</span>
                    <span class=tags>${ tagArray.map(tag => '<a href=#>'+tag+'</a>').join('') }</span>
                    <span class=controls>
                        <a href=# class=edit>edit</a>
                        <a href=# class=delete>delete</a>
                    </span>
                </div>
            </div>
        `
    }

    function search () {
        bookmarks_search({
            query: $search.value,
            limit: limit,
            page: parseInt($page.value, 10)
        }).then(results => {
            resultsLen = results.length || 0
            empty($results)

            if (results.length == null) {
                updateNavButtons()
                return
            }

            $results.innerHTML = results.map(makeBookmark).join('')
        })
    }

    function updateNavButtons () {
        $next.style.display = resultsLen === limit ? 'inline' : 'none'
        $prev.style.display = parseInt($page.value, 10) > 1 ? 'inline' : 'none'
    }

    function getID ($el) {
        do { $el = $el.parentNode } while ($el && !$el.classList.contains('bookmark'))
        return parseInt($el.dataset.id, 10)
    }

    function showEdit (b) {
        b = b || {}
        $editDialog.id.value = b.id || ''
        $editDialog.created.value = b.created || ''
        $editDialog.title.value = b.title || ''
        $editDialog.uri.value = b.uri || ''
        $editDialog.tags.value = b.tags || ''
        $editDialog.desc.value = b.desc || ''
        $editView.style.display = 'block'
        $editDialog.title.focus()
    }

    $search.addEventListener('keydown', event => {
        if (event.which === 13) { // 13 is the code for the 'Return' key
            $page.value = 1
            search()
            $search.blur()
            reset_mode()
        }
    })

    $editDialog.addEventListener('submit', event => {
        event.preventDefault()
        let id = $editDialog.id.value
        let created = $editDialog.created.value
            ? parseInt($editDialog.created.value)
            : undefined
        let title = $editDialog.title.value
        let uri = $editDialog.uri.value
        let tags = $editDialog.tags.value
        let desc = $editDialog.desc.value

        bookmarks_add(uri, { title, tags, desc, created })
        if (id) bookmarks_remove(parseInt(id))
        search()
        $editView.style.display = 'none'
    })

    document.getElementsByClassName('cancel-button')[0]
        .addEventListener('click', () => {
            $editView.style.display = 'none'
        })

    document.getElementById('new-button').addEventListener('click', showEdit)

    document.getElementById('clear-button')
        .addEventListener('click', () => {
            $search.value = ''
            $page.value = 1
            search()
        })

    document.getElementById('search-button')
        .addEventListener('click', () => {
            $page.value = 1
            search()
        })

    $next.addEventListener('click', () => {
        let page = parseInt($page.value, 10)
        $page.value = page + 1
        search()
    })

    $prev.addEventListener('click', () => {
        let page = parseInt($page.value, 10)
        $page.value = Math.max(page - 1, 1)
        search()
    })

    document.addEventListener('click', event => {
        if (event.target.matches('.tags > a')) {
            $search.value = event.target.textContent
            search()
        } else if (event.target.matches('.controls > .edit')) {
            bookmarks_get(getID(event.target)).then(showEdit)
        } else if (event.target.matches('.controls > .delete')) {
            bookmarks_remove(getID(event.target))
            search()
        }
    })

    search()
    new_bookmark_values().then(values => {
        if (values) showEdit(values)
    })
})
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

    local html = string.gsub(html_template, "{%%(%w+)}", {
        stylesheet = style,
        javascript = main_js,
    })
    return html
end, nil, export_funcs)

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
