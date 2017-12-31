--- Provides luakit://help/ page.
--
-- This module provides the <luakit://help/> page and all of its sub-pages,
-- including the built-in documentation browser.
--
-- @module help_chrome
-- @copyright 2016 Aidan Holm <aidanholm@gmail.com>
-- @copyright 2012 Mason Larobina <mason.larobina@gmail.com>

local lousy = require("lousy")
local chrome = require("chrome")
local history = require("history")
local add_cmds = require("modes").add_cmds
local error_page = require("error_page")
local get_modes = require("modes").get_modes
local markdown = require("markdown")

local _M = {}

local index_html_template = [==[
<!doctype html>
<html>
<head>
    <meta charset="utf-8">
    <title>Luakit Help</title>
    <style type="text/css">{style}
    </style>
</head>
<body>
    <header id="page-header"><h1>Luakit Help</h1><div class="rhs">version {version}</div></header>
    <div class=content-margin>
        <h2>About Luakit</h2>
            <p>Luakit is a highly configurable, browser framework based on the <a
            href="http://webkit.org/" target="_blank">WebKit</a> web content engine and the <a
            href="http://gtk.org/" target="_blank">GTK+</a> toolkit. It is very fast, extensible with <a
            href="http://lua.org/" target="_blank">Lua</a> and licensed under the <a
            href="https://raw.github.com/luakit/luakit/develop/COPYING.GPLv3" target="_blank">GNU GPLv3</a>
            license.  It is primarily targeted at power users, developers and any people with too much time
            on their hands who want to have fine-grained control over their web browser&rsquo;s behaviour and
            interface.</p>
        <h2>Configuration</h2>
        <h3>Settings</h3>
        <p>The available settings are displayed at:</p>
        <ul>
            <li><a href="luakit://settings/">Settings</a></li>
        </ul>
        <h3>Key bindings</h3>
        <p>Currently active bindings are listed in the following page.</p>
        <ul>
            <li><a href="luakit://binds/">Bindings</a></li>
        </ul>
        {chromepageshtml}
        <h2>API Documentation</h2>
        <ul>
            <li><a href="luakit://help/doc/index.html">API Index</a></li>
        </ul>
        <h2>Questions, Bugs, and Contributions</h2>

        <p>Please report any bugs or issues you find at the GitHub
        <a href="https://github.com/luakit/luakit/issues" target="_blank">issue tracker</a>.</p>
        <p>If you have any feature requests or questions, feel free to open an
        issue for those as well. Pull requests and patches are both welcome,
        and there are plenty of areas that could be improved, especially tests
        and documentation.</p>

        <h2>License</h2>
        <p>Luakit is licensed under the GNU General Public License version 3 or later.
        The abbreviated text of the license is as follows:</p>
        <div class=license>
            <p>This program is free software: you can redistribute it and/or modify
            it under the terms of the GNU General Public License as published by
            the Free Software Foundation, either version 3 of the License, or
            (at your option) any later version.</p>

            <p>This program is distributed in the hope that it will be useful,
            but WITHOUT ANY WARRANTY; without even the implied warranty of
            MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
            GNU General Public License for more details.</p>

            <p>You should have received a copy of the GNU General Public License
            along with this program.  If not, see
            <a href="https://www.gnu.org/licenses/">https://www.gnu.org/licenses/</a>.</p>
        </div>
    </div>
</body>
]==]

local gen_html_chrome_pages = function()
    local links = ""
    for _, v in ipairs(chrome.available_handlers()) do
        links = links .. "<li><a href=\"luakit://" .. v .. "\">" .. v .. "</a></li>\n"
    end
    return [==[
        <h3>luakit:// pages</h3>
        <p>These are all the available <code>luakit://</code> pages:</p>
        <ul>
]==] .. links .. "</ul>"
end

local help_index_page = function ()
    local html_subs = {
        style = chrome.stylesheet,
        version = luakit.version,
        chromepageshtml = gen_html_chrome_pages(),
    }
    local html = string.gsub(index_html_template, "{(%w+)}", html_subs)
    return html
end

local builtin_module_set = {
    extension = true,
    ipc = true,
    luakit = true,
    msg = true,
    soup = true,
    utf8 = true,
}

local help_doc_index_page_preprocess = function (inner, style)
    -- Mark each list with the section heading just above it
    inner = inner:gsub("<h2>(%S+)</h2>%s*<ul>", "<h2>%1</h2><ul class=%1>")
    -- Customize each module link bullet
    inner = inner:gsub('<li><a href="modules/(%S+).html">', function (pkg)
        local class = package.loaded[pkg] and "enabled" or "disabled"
        if builtin_module_set[pkg] then class = "builtin" end
        return '<li class=' .. class .. '><a title="' .. pkg .. ": " .. class .. '" href="modules/' .. pkg .. '.html">'
    end)
    style = style .. [===[
        div#wrap { padding-top: 0; }
        h2 { margin: 1em 0 0.75em; }
        h2 + ul { margin: 0.5em 0; }
        ul {
            display: flex;
            flex-wrap: wrap;
            padding-left: 1rem;
            list-style-type: none;
        }
        ul > li {
            flex: 1 0 14rem;
            padding: 0.2em 0.2rem 0.2rem 1.5rem;
            margin: 0px !important;
            position: relative;
        }
        ul > li:not(.dummy):before {
            font-weight: bold;
            width: 1.5rem;
            text-align: center;
            left: 0;
            position: absolute;
        }
        ul > li:not(.dummy):before { content: "●"; transform: translate(1px, -1px); z-index: 0; }
        ul.Modules > li.enabled:before { content: "\2713 "; color: darkgreen; }
        ul.Modules > li.disabled:before { content: "\2717 "; color: darkred; }
        ul.Modules > li.enabled:before, ul.Modules > li.disabled:before {
            transform: none;
        }
        #page-header { z-index: 100; }
    ]===]
    return inner, style
end

local help_doc_page = function (v, path, request)
    -- Generate HTML documenting the additional bindings added by module `m`
    local generate_mode_doc_html = function (m)
        local fmt = function (str)
            -- Fix < and > being escaped inside code -_- fail
            return markdown(str):gsub("<pre><code>(.-)</code></pre>", lousy.util.unescape)
        end
        local bind_to_html = function (b)
            b = lousy.bind.bind_to_string(b) or "???"
            if b:match("^:.") then
                local cmds = {}
                for _, c in ipairs(lousy.util.string.split(b, ", ")) do
                    c = lousy.util.escape(c)
                    table.insert(cmds, ("<li><span class=cmd>%s</span>"):format(c))
                end
                return "<ul class=triggers>" .. table.concat(cmds, "") .. "</ul>"
            elseif b:match("^^.") then
                b = ("<span class=buf>%s</span>"):format(lousy.util.escape(b))
            else
                b = ("<kbd>%s</kbd>"):format(lousy.util.escape(b))
            end
            return "<ul class=triggers><li>" .. b .. "</ul>"
        end
        local modes, parts = get_modes(), {}
        for name, mode in pairs(modes) do
            local binds = {}
            for _, bm in pairs(mode.binds or {}) do
                local _, a = unpack(bm)
                local src_m = debug.getinfo(a.func, "S").source:match("lib/(.*)%.lua")
                if src_m == m then binds[#binds+1] = bm end
            end
            if #binds > 0 then
                parts[#parts+1] = string.format("<h3><code>%s</code> mode</h3>", name)
                parts[#parts+1] = "<ul class=binds>\n"
                for _, bm in ipairs(binds) do
                    local b, a = unpack(bm)
                    local b_desc = a.desc or "<i>No description</i>"
                    b_desc = fmt(lousy.util.string.dedent(b_desc)):gsub("</?p>", "", 2)
                    parts[#parts+1] = "<li><div class=two-col>" .. bind_to_html(b)
                    parts[#parts+1] = "<div class=desc>" .. b_desc .. "</div></div>"
                end
                parts[#parts+1] = "</ul>"
            end
        end
        return #parts > 0 and "<h2>Binds and Modes</h2>" .. table.concat(parts, "") or ""
    end

    local extract_doc_html = function (file)
        local prefix = luakit.dev_paths and "doc/apidocs/" or (luakit.install_paths.doc_dir .. "/")
        local ok, blob = pcall(lousy.load, prefix .. file)
        if not ok then return nil, prefix .. file end
        local style = blob:match("<style>(.*)</style>")
        local inner = blob:match("(<div id=wrap>.*</div>)%s*</body>")
        if file == "index.html" then
            inner, style = help_doc_index_page_preprocess(inner, style)
        else
            style = style .. [===[
                #wrap { padding: 1rem; }
                header#page-header { position: static; }
                div.content-margin { padding: 0; }

                .status_indicator {
                    position: absolute;
                    top: 0;
                    right: 0;
                    border-radius: .3125em;
                    padding: .3em 0.5em;
                    -webkit-user-select: none;
                    cursor: default;
                    line-height: 1.1rem;
                    font-weight: bold;
                }
                .status_indicator.active {
                    border: 2px solid #008800;
                    color: #008800;
                }
                .status_indicator.inactive {
                    border: 2px solid #880000;
                    color: #880000;
                }
                .status_indicator.builtin {
                    border: 2px solid #444444;
                    color: #444444;
                }
                .status_indicator.active::before { content: "✓ "; }
                .status_indicator.inactive::before { content: "✗ "; }
                .status_indicator.builtin::before { content: "● "; vertical-align: top; line-height: 1.2; }
            ]===]
        end
        local m = file:match("^modules/(.*)%.html$")
        if m then
            local modes_binds_html = generate_mode_doc_html(m)
            local i = inner:find("<!-- modes and binds -->", 1, true)
            inner = inner:sub(1, i-1) .. modes_binds_html .. inner:sub(i)

            local m_status = package.loaded[m] and "active" or "inactive"
            if builtin_module_set[m] then m_status = "builtin" end
            local tooltip = ({
                active = "This module is active and currently running.",
                inactive = "This module is inactive.",
                builtin =  "This module is builtin.",
            })[m_status]
            local status_indicator_html = ([==[
                <span class="status_indicator %s" title="%s">%s</span>
            ]==]):format(m_status, tooltip, m_status:gsub("^%l", string.upper))
            i = inner:find("<!-- status indicator -->", 1, true)
            inner = inner:sub(1, i-1) .. status_indicator_html .. inner:sub(i)
        end
        return inner, style
    end

    local doc_html_template = [==[
    <!doctype html>
    <html>
    <head>
        <meta charset="utf-8">
        <title>Luakit API Documentation</title>
        <style type="text/css">
        {style}
        </style>
    </head>
    <body>
        <header id="page-header">
            <h1>Luakit API Documentation</h1>
        </header>
        <div class="content-margin">
        {doc_html}
        </div>
    </body>
    ]==]

    local doc_html, doc_style = extract_doc_html(path:gsub("[?#].*", ""))
    if not doc_html then
        local file = doc_style
        error_page.show_error_page(v, {
            heading = "Documentation not found",
            content = "Opening <code>" .. file .. "</code> failed",
            buttons = { path ~= "index.html" and {
                label = "Return to API Index",
                callback = function (vv) vv.uri = "luakit://help/doc/index.html" end
            } or nil },
            request = request,
        })
        return
    end
    local html_subs = {
        style = chrome.stylesheet .. doc_style,
        doc_html = doc_html,
    }
    local html = string.gsub(doc_html_template, "{([%w_]+)}", html_subs)
    return html
end

chrome.add("help", function (v, meta)
    if meta.path:match("^/?$") then
        return help_index_page()
    elseif meta.path:match("^doc/?") then
        return help_doc_page(v, ({meta.path:match("^doc/?(.*)$")})[1], meta.request)
    end
end, nil, {})

add_cmds({
    { ":help", "Open <luakit://help/> in a new tab.",
        function (w) w:new_tab("luakit://help/") end },
})

-- Prevent history items from turning up in history
history.add_signal("add", function (uri)
    if string.match(uri, "^luakit://help/") then return false end
end)

return _M

-- vim: et:sw=4:ts=8:sts=4:tw=80
