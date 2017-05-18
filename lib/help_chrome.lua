--- Provides luakit://help/ page.
--
-- @module help_chrome
-- @copyright 2016 Aidan Holm
-- @copyright 2012 Mason Larobina <mason.larobina@gmail.com>

local lousy = require("lousy")
local chrome = require("chrome")
local history = require("history")
local editor = require("editor")
local add_cmds = require("binds").add_cmds

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
    <header id="page-header"><h1>Luakit Help</h1></header>
    <div class=content-margin>
        <h2>About Luakit</h2>
            <p>Luakit is a highly configurable, browser framework based on the <a
            href="http://webkit.org/" target="_blank">WebKit</a> web content engine and the <a
            href="http://gtk.org/" target="_blank">GTK+</a> toolkit. It is very fast, extensible with <a
            href="http://lua.org/" target="_blank">Lua</a> and licensed under the <a
            href="https://raw.github.com/aidanholm/luakit/develop/COPYING.GPLv3" target="_blank">GNU GPLv3</a>
            license.  It is primarily targeted at power users, developers and any people with too much time
            on their hands who want to have fine-grained control over their web browser&rsquo;s behaviour and
            interface.</p>
        <h2>Introspector</h2>
        <p> To view the automatically generated documentation for currently loaded
        modules and available keybinds, open the Luakit introspector.</p>
        <ul>
            <li><a href="luakit://introspector/">Introspector</a></li>
        </ul>
        <h2>API Documentation</h2>
        <ul>
            <li><a href="luakit://help/doc/index.html">API Index</a></li>
        </ul>
        <h2>Questions, Bugs, and Contributions</h2>

        <p>Please report any bugs or issues you find at the GitHub
        <a href="https://github.com/aidanholm/luakit/issues" target="_blank">issue tracker</a>.</p>
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

local help_index_page = function ()
    local html_subs = { style = chrome.stylesheet, }
    local html = string.gsub(index_html_template, "{(%w+)}", html_subs)
    return html
end

local help_doc_page = function (path)
    local extract_doc_html = function (file_path)
        local ok, blob = pcall(lousy.load, file_path)
        if not ok then return "<h2>Documentation not found</h2>", "" end
        local style = blob:match("<style>(.*)</style>")
        -- Remove some css rules
        style = style:gsub("html %b{}", ""):gsub("#hdr %b{}", ""):gsub("#hdr > h1 %b{}", "")
        local inner = blob:match("(<div id=wrap>.*</div>)%s*</body>")
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
        #wrap { padding: 2em 0; }
        #content > h1 { font-size: 28px; }
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
    local doc_root = "doc/apidocs/"
    local doc_html, doc_style = extract_doc_html(doc_root .. path)
    local html_subs = {
        style = doc_style .. chrome.stylesheet,
        doc_html = doc_html,
    }
    local html = string.gsub(doc_html_template, "{([%w_]+)}", html_subs)
    return html
end

chrome.add("help", function (_, meta)
    if meta.path:match("^/?$") then
        return help_index_page()
    elseif meta.path:match("^doc/?") then
        return help_doc_page(({meta.path:match("^doc/?(.*)$")})[1])
    end
end, nil, {
    open_editor = function(_, ...) return editor.edit(...) end,
})

local cmd = lousy.bind.cmd
add_cmds({
    cmd("help", "Open [luakit://help/](luakit://help/) in a new tab.",
        function (w) w:new_tab("luakit://help/") end),
})

-- Prevent history items from turning up in history
history.add_signal("add", function (uri)
    if string.match(uri, "^luakit://help/") then return false end
end)

return _M

-- vim: et:sw=4:ts=8:sts=4:tw=80
