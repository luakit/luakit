--- Provides luakit://binds/ page.
--
-- This module provides the luakit://binds/ page. It is useful for viewing all
-- bindings and modes on a single page, as well as searching for a
-- binding for a particular task.
--
-- @module binds_chrome
-- @copyright 2016 Aidan Holm <aidanholm@gmail.com>
-- @copyright 2012 Mason Larobina <mason.larobina@gmail.com>

local lousy = require("lousy")
local dedent = lousy.util.string.dedent
local escape = lousy.util.escape
local chrome = require("chrome")
local history = require("history")
local markdown = require("markdown")
local editor = require("editor")
local get_modes = require("modes").get_modes
local add_cmds = require("modes").add_cmds

local _M = {}

local html_template = [==[
<!doctype html>
<html>
<head>
    <meta charset="utf-8">
    <title>Luakit Bindings</title>
    <style type="text/css">
        {style}
        body {
            background-color: white;
            color: black;
            font-family: sans-serif;
            width: 700px;
            margin: 0 auto;
        }

        header {
            padding: 0.5em 0 0.5em 0;
            margin: 2em 0 0.5em 0;
            border-bottom: 1px solid #888;
        }

        h1 {
            font-weight: bold;
            line-height: 1.4em;
            margin: 0;
            padding: 0;
        }

        h3.mode-name {
            color: black;
            margin-bottom: 1.0em;
            line-height: 1.4em;
            border-bottom: 1px solid #888;
        }

        h1, h2, h3, h4 {
            -webkit-user-select: none;
        }

        ol, li {
            margin: 0;
            padding: 0;
            list-style: none;
        }

        pre {
            margin: 0;
            padding: 0;
        }


        .mode {
            float: left;
            margin-bottom: 1em;
        }

        .mode .mode-name {
            font-family: monospace, sans-serif;
        }

        .mode .binds {
            clear: both;
            display: block;
        }

        .bind {
            float: left;
            width: 690px;
            padding: 5px;
        }

        .bind:hover {
            background-color: #f8f8f8;
            -webkit-border-radius: 0.5em;
        }

        .bind .link-box {
            font-size: 0.8em;
            float: right;
            font-family: monospace, sans-serif;
            text-decoration: none;
        }

        .bind .link-box a {
            color: #11c;
            text-decoration: none;
        }

        .bind .link-box a:hover {
            color: #11c;
            text-decoration: underline;
        }

        .bind .key {
            font-family: monospace, sans-serif;
            float: left;
            color: #2E4483;
            font-weight: bold;
            font-size: 0.8em;
        }

        .bind .box {
            float: right;
            width: 550px;
        }

        .bind .desc p:first-child {
            margin-top: 0;
        }

        .bind .desc p:last-child {
            margin-bottom: 0;
        }

        .bind code {
            color: #2525ff;
            display: inline-block;
        }

        .bind pre {
            padding: 1rem 1.2rem;
            border-left: 2px solid #69c;
            background: #f5f7f9;
            color: #334;
        }

        .bind pre code {
            color: #000;
        }

        .mode h4 {
            margin: 1em 0;
            padding: 0;
        }

        .bind .clear {
            display: block;
            width: 100%;
            height: 0;
            margin: 0;
            padding: 0;
            border: none;
        }

        .bind_type_any .key {
            color: #888;
            float: left;
        }

        #templates {
            display: none;
        }
    </style>
</head>
<body>
    <header id="page-header">
        <h1>Luakit Bindings</h1>
    </header>
    <div class="content-margin">
        {sections}
    </div>
    <script>
        {javascript}
    </script>
</body>
]==]

local mode_section_template = [==[
    <section class="mode" id="mode-{name}">
        <h3 class="mode-name">{name} mode</h3>
        <p class="mode-desc">{desc}</p>
        <pre style="display: none;" class="mode-traceback">{traceback}</pre>
        <ol class="binds">
            {binds}
        </ol>
    </section>
]==]

local mode_bind_template = [==[
    <li class="bind bind_type_{type}">
        <div class="link-box">
            <a href="#" class="linedefined" data-filename="{filename}"
            data-line="{linedefined}">{filename}:{linedefined}</a>
        </div>
        <hr class="clear" />
        <div class="key">{key}</div>
        <div class="box desc">{desc}</div>
        <div class="box func-source hidden">
            <h4>Function source:</h4>
            <pre><code>{func}</code></pre>
        </div>
    </li>
]==]

local main_js = [=[
document.addEventListener('click', event => {
    if (event.target.matches('.linedefined')) {
        event.preventDefault()
        let { filename, line } = event.target.dataset
        open_editor(filename, line)
    } else if (event.target.matches('.bind, .bind *')) {
        let $el = event.target
        while ($el && !$el.classList.contains('bind')) $el = $el.parentNode
        let src = $el.getElementsByClassName('func-source')[0]
        if (src) src.classList.toggle('hidden')
    }
})
]=]

local source_lines = {}
local function function_source_range(_, info)
    local lines = source_lines[info.source]

    if not lines then
        local source = lousy.load(info.source)
        lines = {}
        string.gsub(source, "([^\n]*)\n", function (line)
            table.insert(lines, line)
        end)
        source_lines[info.source] = lines
    end

    return dedent(table.concat(lines, "\n", info.linedefined,
        info.lastlinedefined), true)
end

local help_get_modes = function ()
    local ret = {}
    local modes = lousy.util.table.values(get_modes())
    table.sort(modes, function (a, b) return a.order < b.order end)

    for _, mode in pairs(modes) do
        local binds = {}

        if mode.binds then
            for i, m in pairs(mode.binds) do
                local b, a = unpack(m)
                local info = debug.getinfo(a.func, "uS")
                info.source = info.source:sub(2)
                binds[i] = {
                    type = b.type,
                    key = lousy.bind.bind_to_string(b) or "???",
                    desc = a.desc and markdown(dedent(a.desc)) or nil,
                    filename = info.source,
                    linedefined = info.linedefined,
                    lastlinedefined = info.lastlinedefined,
                    func = function_source_range(b.func, info),
                }
            end
        end

        table.insert(ret, {
            name = mode.name,
            desc = mode.desc and markdown(dedent(mode.desc)) or nil,
            binds = binds,
            traceback = mode.traceback
        })
    end
    -- Clear source file cache
    source_lines = {}
    return ret
end

chrome.add("binds", function ()
    local sections = {}
    local modes = help_get_modes()

    for _, mode in ipairs(modes) do
        local binds = {}
        for _, bind in ipairs(mode.binds) do
            bind.key = escape(bind.key)
            bind.desc = bind.desc or ""
            binds[#binds+1] = string.gsub(mode_bind_template, "{(%w+)}", bind)
        end

        local section_html_subs = {
            name = mode.name,
            desc = mode.desc or "",
            traceback = mode.traceback,
            binds = table.concat(binds, "\n")
        }
        sections[#sections+1] = string.gsub(mode_section_template, "{(%w+)}", section_html_subs)
    end

    local sections_html = table.concat(sections, "\n")
    local html_subs = {
        sections = sections_html,
        style  = chrome.stylesheet,
        javascript = main_js,
    }
    local html = string.gsub(html_template, "{(%w+)}", html_subs)
    return html
end, nil, {
    open_editor = function(_, ...) return editor.edit(...) end,
})

add_cmds({
    { ":binds", "Open <luakit://binds/> in a new tab.",
        function (w) w:new_tab("luakit://binds/") end },
})

-- Prevent history items from turning up in history
history.add_signal("add", function (uri)
    if string.match(uri, "^luakit://binds/") then return false end
end)

return _M

-- vim: et:sw=4:ts=8:sts=4:tw=80
