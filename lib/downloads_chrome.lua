--- Downloads for luakit - chrome page.
--
-- This module allows you to monitor the progress of ongoing downloads through a
-- webpage at <luakit://downloads/>.
--
-- @module downloads_chrome
-- @copyright 2010-2012 Mason Larobina <mason.larobina@gmail.com>
-- @copyright 2010 Fabian Streitel <karottenreibe@gmail.com>

-- Grab the luakit environment we need
local downloads = require("downloads")
local chrome = require("chrome")
local modes = require("modes")
local add_binds, add_cmds = modes.add_binds, modes.add_cmds
local webview = require("webview")
local window = require("window")

local _M = {}

local html_template = [==[
<!doctype html>
<html>
<head>
    <meta charset="utf-8">
    <title>Downloads</title>
    <style type="text/css">
        {style}
    </style>
</head>
<body>
    <header id="page-header">
        <h1>Downloads</h1>
    </header>
    <div id="downloads-list" class="content-margin">
    <script>{%javascript}</script>
</body>
</html>
]==]

--- CSS for downloads chrome page.
-- @type string
-- @readwrite
_M.stylesheet = [==[
    .download {
        padding-left: 10px;
        position: relative;
        display: block;
        margin: 10px 0 10px 90px;
    }

    .download .date {
        left: -90px;
        width: 90px;
        position: absolute;
        display: block;
        color: #888;
    }

    .download .title a {
        color: #3F6EC2;
        padding-right: 16px;
    }

    .download .status {
        display: inline;
        color: #999;
        white-space: nowrap;
    }

    .download .uri a {
        color: #56D;
        text-overflow: ellipsis;
        display: inline-block;
        white-space: nowrap;
        text-decoration: none;
        overflow: hidden;
        max-width: 500px;
    }

    .download .controls a {
        color: #777;
        margin-right: 16px;
    }
]==]

local main_js = [=[
const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']
const downloads_stats = ["status", "speed", "current_size", "total_size",
        "destination", "created", "uri"]

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

function readableSize (bytes, precision) {
    const prefixes = ['B', 'kiB', 'MiB', 'GiB', 'TiB', 'PiB', 'EiB', 'ZiB', 'YiB']
    bytes = bytes || 0
    precision = precision || 0
    let i
    for (i = 0; i < prefixes.length && 1023 < bytes; i++, bytes /= 1024);
    return `${bytes.toFixed(precision)} ${prefixes[i]}`
}

function getId ($child) {
    do { $el = $el.parentNode } while ($el && !$el.classList.contains('download'))
    return $el
}

function makeDownload (d) {
    let dt = new Date(1000 * d.created)
    let dateStr = `${dt.getDate()} ${months[dt.getMonth()]} ${dt.getFullYear()}`
    let href = d.destination.substring(d.destination.lastIndexOf('/') + 1)
    let uri = encodeURI(d.uri)

    return createElement('div', { id: d.id, 'data-created': d.created }, [

        createElement('div', { class: 'date' }, [
            document.createTextNode(dateStr)
        ]),

        createElement('div', { class: 'details' }, [

            createElement('div', { class: 'title' }, [
                createElement('a', { href: `file://${escape(d.destination)` }, [
                    document.createTextNode(href)
                ], { click: event => download_open(getId(event.target)) }),
                createElement('div', { class: 'status' }, [
                    document.createTextNode('waiting')
                ])
            ]),

            createElement('div', { class: 'uri' }, [
                createElement('a', { href: uri }, [
                    document.createTextNode(uri)
                ])
            ])

        ]),

        createElement('div', { class: 'controls' }, [

            createElement('a', { class: 'show' }, [
                document.createTextNode('Show in folder')
            ], { click: event => download_show(getId(event.target)) }),

            createElement('a', { class: 'restart' }, [
                document.createTextNode('Retry download')
            ], { click: event => download_restart(getId(event.target)) }),

            createElement('a', { class: 'remove' }, [
                document.createTextNode('Remove from list')
            ], {
                click: event => {
                    let id = getId(event.target)
                    download_remove(id)
                    document.getElementById(id).style.display = 'none'
                }
            }),

            createElement('a', { class: 'cancel' }, [
                document.createTextNode('Cancel')
            ], { click: event => download_open(getId(event.target)) })

        ])
    ])
}

function updateListFinish (downloads) {
    const $list = document.getElementById('downloads-list')
    empty($list)

    if (downloads.length == null) {
        setTimeout(update, 1000)
        return
    }

    downloads
        .sort((a, b) => b.created - a.created)
        .map(makeDownload)
        .forEach($list.appendChild)
}

function updateList () {
    downloads_get_all(downloads_stats).then(updateListFinish)
}

window.addEventListener('load', () => {
    updateList()
})

]=]

local update_list_js = [=[updateList();]=]

-- default filter
local default_filter = { destination = true, status = true, created = true,
    current_size = true, total_size = true, mime_type = true, uri = true,
    opening = true }

local function collate_download_data(d, data, filter)
    local f = filter or default_filter
    local ret = { id = data.id }
    -- download object properties
    if rawget(f, "destination")  then rawset(ret, "destination", d.destination)    end
    if rawget(f, "status")       then rawset(ret, "status", d.status)              end
    if rawget(f, "uri")          then rawset(ret, "uri", d.uri)                    end
    if rawget(f, "current_size") then rawset(ret, "current_size", d.current_size)  end
    if rawget(f, "total_size")   then rawset(ret, "total_size", d.total_size)      end
    if rawget(f, "mime_type")    then rawset(ret, "mime_type", d.mime_type)        end
    -- data table properties
    if rawget(f, "created")      then rawset(ret, "created", data.created)         end
    if rawget(f, "opening")      then rawset(ret, "opening", not not data.opening) end
    if rawget(f, "speed")        then rawset(ret, "speed", data.speed)             end
    return ret
end

local export_funcs = {
    download_get = function (_, id, filter)
        local d, data = downloads.get(id)
        if filter then
            assert(type(filter) == "table", "invalid filter table")
            for _, key in ipairs(filter) do rawset(filter, key, true) end
        end
        return collate_download_data(d, data, filter)
    end,

    downloads_get_all = function (_, filter)
        local ret = {}
        if filter then
            assert(type(filter) == "table", "invalid filter table")
            for _, key in ipairs(filter) do rawset(filter, key, true) end
        end
        for d, data in pairs(downloads.get_all()) do
            table.insert(ret, collate_download_data(d, data, filter))
        end
        return ret
    end,

    download_show = function (view, id)
        local d = downloads.get(id)
        local dirname = string.gsub(d.destination, "(.*/)(.*)", "%1")
        if downloads.emit_signal("open-file", dirname, "inode/directory") ~= true then
            local w = webview.window(view)
            w:error("Couldn't show download directory (no inode/directory handler)")
        end
    end,

    download_cancel  = function (_, id) return downloads.cancel(id) end,
    download_restart = function (_, id) return downloads.restart(id) end,
    download_open    = function (_, id) return downloads.open(id) end,
    download_remove  = function (_, id) return downloads.remove(id) end,
    downloads_clear  = function (_, id) return downloads.clear(id) end,
}

downloads.add_signal("status-tick", function (running)
    if running == 0 then
        for _, data in pairs(downloads.get_all()) do data.speed = nil end
    end
    for d, data in pairs(downloads.get_all()) do
        if d.status == "started" then
            local last, curr = rawget(data, "last_size") or 0, d.current_size
            rawset(data, "speed", curr - last)
            rawset(data, "last_size", curr)
        end
    end

    -- Update all download pages when a change occurrs
    for _, w in pairs(window.bywidget) do
        for _, v in ipairs(w.tabs.children) do
            if string.match(v.uri or "", "^luakit://downloads/?") then
                v:eval_js(update_list_js, { no_return = true })
            end
        end
    end
end)

chrome.add("downloads", function ()
    local html_subs = {
        style  = chrome.stylesheet .. _M.stylesheet,
        javascript = main_js,
    }
    local html = string.gsub(html_template, "{(%w+)}", html_subs)
    return html
end, nil, export_funcs)

--- URI of the downloads chrome page.
-- @type string
-- @readonly
_M.chrome_page = "luakit://downloads/"

add_binds("normal", {
    { "gd", [[Open <luakit://downloads> in current tab.]],
        function (w) w:navigate(_M.chrome_page) end },

    { "gD", [[Open <luakit://downloads> in new tab.]],
        function (w) w:new_tab(_M.chrome_page) end },
})

add_cmds({
    { ":downloads", [[Open <luakit://downloads> in new tab.]],
        function (w) w:new_tab(_M.chrome_page) end },
})

return _M

-- vim: et:sw=4:ts=8:sts=4:tw=80
