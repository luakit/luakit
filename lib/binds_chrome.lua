--------------------------------------------------------
-- chrome://help/ to list all luakit bindings         --
-- (C) 2011 Mason Larobina <mason.larobina@gmail.com> --
--------------------------------------------------------

local string = string
local table = table
local ipairs = ipairs
local pairs = pairs
local get_modes = get_modes
local lousy = require "lousy"
local chrome = require "chrome"
local add_cmds = add_cmds
local print = print
local error = error

module "help_chrome"

html_template = [==[
<html>
<head>
    <title>Bindings</title>
    <style type="text/css">
        body {
            background-color: white;
            color: black;
            margin: 10px;
            display: block;
            font-size: 84%;
            font-family: sans-serif;
        }

        div {
            display: block;
        }

        #header {
            font-size:200%;
            font-weight: bold;
        }

        .group-heading {
            border-top: 1px solid #888;
            background-color: #ddd;
            padding: 3px;
            font-weight: bold;
            margin-top: 10px;
            margin-bottom: 8px;
        }

        .group-table {
            margin: 6px 0 6px 16px;

        }

        .bind {
            padding-bottom: 50px;
        }

        .bind .tostring {
            font-family: monospace;
            min-width: 200px;
        }

    </style>
</head>
<body>
    <div id="header">
        luakit bindings
    </div>
    <div class="main">
        {modes}
    </div>
</body>
]==]

group_template = [==[
<div class="group">
    <div class="group-heading">Mode "{title}"</div>
    <table class="group-table">
        <tbody>
            {binds}
        </tbody>
    </table>
</div>
]==]

bind_template = [==[
<tr class="bind">
    <td class="tostring">{tostring}</td>
    <td class="desc">{desc}</td>
</tr>
]==]

function bind_tostring(b)
    local escape = lousy.util.escape
    -- Allow users to override
    if b.opts.tostring then return escape(b.opts.tostring) end
    if b.pattern then
        return escape(string.match(b.pattern, "^^(.+)$$"))
    end
    local s = b.key or (b.button and "Button" .. b.button)
    if b.mods and #(b.mods) > 0 then
        return escape(string.format("<%s-%s>", table.concat(b.mods, "-"), s))
    elseif b.mods and #s > 1 then
        return escape(string.format("<%s>", s))
    elseif b.mods then
        return escape(s)
    end
end

function build_bind(b)
    local h = string.gsub(bind_template, "{(%w+)}",
        { tostring = bind_tostring(b), desc = b.opts.desc or "" })
    return h
end

function build_mode(name, data)
    local binds = {}
    for _, b in ipairs(data.binds or {}) do
        table.insert(binds, build_bind(b))
    end
    if binds[1] then
        local h = string.gsub(group_template, "{(%w+)}",
            { title = name, binds = table.concat(binds, "\n") })
        return h
    end
end

function build_html(view, uri)
    local modes = {}

    for name, data in pairs(get_modes()) do
        local h = build_mode(name, data)
        if h then table.insert(modes, h) end
    end

    local h = string.gsub(html_template, "{(%w+)}",
        { modes = table.concat(modes, "\n") })

    view:load_string(h, uri)
end

chrome.add("^chrome://binds/?", build_html)

local cmd = lousy.bind.cmd
add_cmds({
    cmd("binds", function (w, mode)
        w:new_tab("chrome://binds")
    end),
})
