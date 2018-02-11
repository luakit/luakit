--- Save history in sqlite3 database - chrome page.
--
-- This module provides the luakit://history/ chrome page - a user interface for
-- searching the web browsing history.
--
-- @module history_chrome
-- @copyright 2010-2011 Mason Larobina <mason.larobina@gmail.com>

-- Grab the luakit environment we need
local history = require("history")
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

    <script>{%javascript}</script>
</body>
]==]

local main_js = [=[
function createElement (tag, attributes, children, events) {
    let $node = document.createElement(tag)

    for (let a in attributes) {
        $node.setAttribute(a, attributes[a])
    }

    for (let $child of children) {
        $node.appendChild($child)
    }

    if (events) {
        for (let eventType in events) {
            let action = events[eventType]
            $node.addEventListener(eventType, action)
        }
    }

    return $node
}

function empty ($el) {
    while ($el.firstChild) $el.removeChild($el.firstChild)
}

window.addEventListener('load', () => {
    const limit = 100
    let resultsLen = 0
    const $clearAll = document.getElementById('clear-all-button')
    const $clearResults = document.getElementById('clear-results-button')
    const $clearSelected = document.getElementById('clear-selected-button')
    const $next = document.getElementById('nav-next')
    const $page = document.getElementById('page')
    const $prev = document.getElementById('nav-prev')
    const $results = document.getElementById('results')
    const $search = document.getElementById('search')

    $page.value = $page.value || 1

    function makeHistoryItem (h) {
        let domain = /https?:\/\/([^/]+)\//.exec(h.uri)
        domain = domain ? domain[1] : ''

        function escapeHTML(string) {
            let entityMap = {
                '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;',
                "'": '&#39;', '/': '&#x2F;', '`': '&#x60;', '=': '&#x3D;'
            }
            return String(string).replace(/[&<>"'`=\/]/g, s => entityMap[s]);
        }

        return `
            <div class=item data-id="${h.id}">
                <span class=time>${h.time}</span>
                <span class=title>
                    <a href="${h.uri}">${escapeHTML(h.title || h.uri)}</a>
                </span>
                <span class=domain>
                    <a href=#>${domain}</a>
                </span>
            </div>
        `

        // return createElement('div', { class: 'item', 'data-id': h.id }, [

        //     createElement('span', { class: 'time' }, [
        //         document.createTextNode(h.time)
        //     ]),

        //     createElement('span', { class: 'title' }, [
        //         createElement('a', { href: h.uri }, [
        //             document.createTextNode(h.title || h.uri)
        //         ])
        //     ]),

        //     createElement('span', { class: 'domain' }, [
        //         createElement('a', { href: '#' }, [
        //             document.createTextNode(domain)
        //         ], {
        //             click: event => {
        //                 $search.value = event.target.textContent
        //                 search()
        //             }
        //         })
        //     ])
        // ], {
        //     click: event => {
        //         event.target.classList.toggle('selected')
        //         $clearSelected.disabled = $results.getElementsByClassName('selected').length === 0
        //     }
        // })
    }

    function updateClearButtons (all, results, selected) {
        $clearAll.disabled = !!all
        $clearResults.disabled = !!results
        $clearSelected.disabled = !!selected
    }

    function updateNavButtons () {
        $next.style.display = resultsLen === limit ? 'inline-block' : 'none'
        $prev.style.display = parseInt($page.value, 10) > 1 ? 'inline-block' : 'none'
    }

    function search () {
        let query = $search.value
        history_search({
            query: query,
            limit: limit,
            page: parseInt($page.value, 10)
        }).then(results => {
            resultsLen = results.length || 0
            updateClearButtons(query, !query, true)
            empty($results)

            if (!results.length) {
                updateNavButtons()
                return
            }

            $results.innerHTML = results.map((item, i) => {
                let lastItem = results[i - 1] || {}
                let html = item.date !== lastItem.date ? `<div class=day-heading>${item.date}</div>`
                    : (lastItem.last_visit - item.last_visit) > 3600 ? `<div class=day-sep></div>`
                    : "";
                return html + makeHistoryItem(item)
            }).join('')

            updateNavButtons()
        })
    }

    function clearEls (className) {
        let ids = Array.from(document.getElementsByClassName(className))
            .map($el => $el.dataset.id)

        if (ids.length > 0) history_clear_list(ids)

        search()
    }

    $search.addEventListener('keydown', event => {
        if (event.which === 13) { // 13 is the code for the 'Return' key
            $page.value = 1
            search()
            $search.blur()
            reset_mode()
        }
    })

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

    $clearAll.addEventListener('click', () => {
        if (!window.confirm('Clear all browser history?')) return
        history_clear_all()
        search()
        $clearAll.blur()
    })

    $clearResults.addEventListener('click', () => {
        clearEls('item')
        $clearResults.blur()
    })

    $clearSelected.addEventListener('click', () => {
        clearEls('selected')
        $clearSelected.blur()
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
        if (event.target.matches(".item > .domain > a")) {
            $search.value = event.target.textContent
            search()
        } else if (event.target.matches(".item")) {
            event.target.classList.toggle('selected')
            $clearSelected.disabled = $results.getElementsByClassName('selected').length === 0
        }
    })

    initial_search_term().then(query => {
        if (query) $search.value = query
        search(query)
    })
})
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
        stylesheet = chrome.stylesheet .. _M.stylesheet,
        javascript = main_js,
    })
    return html
end, nil, export_funcs)

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
