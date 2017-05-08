--- Add custom luakit:// scheme rendering functions.
-- @module chrome
-- @copyright 2010-2012 Mason Larobina (mason.larobina@gmail.com)
-- @copyright 2010 Fabian Streitel (karottenreibe@gmail.com)

local error_page = require("error_page")
local webview = require("webview")
local window = require("window")

local _M = {}

--- Common stylesheet that can be sourced from several chrome modules
-- for a consitent looking theme.
-- @type string
_M.stylesheet = [===[
    body {
        background-color: white;
        color: black;
        display: block;
        font-size: 62.5%; /* 1em == 10px @ 96dpi */
        margin: 0;
        padding: 0;
        font-family: sans-serif;
    }

    #page-header {
        font-size: 1.3em;
        background-color: #eee;
        position: fixed;
        top: 0;
        left: 0;
        width: 100%;
        margin: 0;
        padding: 0;
        border-bottom: 1px solid #ddd;
        -webkit-box-shadow: 0 0.5em 2em #fff;
        overflow: hidden;
        white-space: nowrap;
    }

    header > h1 {
        font-size: 1.3em;
        margin: 1em;
        display: inline-block;
    }

    header input {
        font-size: inherit;
        font-weight: 100;
        padding: 0.5em 0.75em;
        border: none;
        outline: none;
        margin: 0;
        background-color: #fff;
    }

    header #search-box {
        display: inline-block;
        margin: 1em 0 1em 1em;
        padding: 0;
        background-color: #fff;
        border-radius: 0.25em;
        box-shadow: 0 1px 1px #888;
    }

    header #search {
        width: 20em;
        font-weight: normal;
        color: #111;
        border-radius: 0.25em 0 0 0.25em;
        margin: 0;
        padding-right: 0;
    }

    header #clear-button {
        margin-left: 0;
        font-weight: 100;
        color: #444;
        border-radius: 0 0.25em 0.25em 0;
    }

    header #clear-button:hover {
        color: #000;
    }

    header #clear-button:active {
        background-color: #eee;
    }

    .button {
        box-shadow: 0 1px 1px #888;
        margin: 1em 0 1em 0.5em;
        border-radius: 0.25em;
        color: #444;
    }

    .button:hover {
        color: #000;
    }

    .button:active {
        background-color: #eee;
    }

    .button[disabled] {
        color: #888;
        background-color: #eee;
    }

    header .rhs {
        position: absolute;
        right: 0;
        padding: 0 1em 0.5em 0;
        margin: 0;
        display: inline-block;
        background-color: inherit;
        box-shadow: -1em 0 1em #eee;
    }

    header .rhs .button {
        margin-bottom: 0;
    }

    .content-margin {
        padding: 6.5em 1em 1em 1em;
    }

    .hidden {
        display: none;
    }
]===]

-- luakit:// page handlers
local handlers = {}
local on_first_visual_handlers = {}

--- Register a chrome page URI with an associated handler function.
-- @tparam string page The name of the chrome page to register.
-- @tparam function func The handler function for the chrome page.
-- @tparam function on_first_visual_func An optional handler function
-- for the chrome page, called when the page first finishes loading.
-- @tparam table export_funcs An optional table of functions to
-- export to JavaScript.
function _M.add(page, func, on_first_visual_func, export_funcs)
    -- Do some sanity checking
    assert(type(page) == "string",
        "invalid chrome page name (string expected, got "..type(page)..")")
    assert(string.match(page, "^[%w%-]+$"),
        "illegal characters in chrome page name: " .. page)
    assert(type(func) == "function",
        "invalid chrome handler (function expected, got "..type(func)..")")
    assert(type(on_first_visual_func) == "nil"
        or type(on_first_visual_func) == "function",
        "invalid chrome handler (function/nil expected, got "..type(on_first_visual_func)..")")

    for name, export_func in pairs(export_funcs or {}) do
        local pattern = "^luakit://" .. page .. "/?(.*)"
        assert(type(name) == "string")
        assert(type(export_func) == "function")
        luakit.register_function(pattern, name, export_func)
    end

    handlers[page] = func
    on_first_visual_handlers[page] = on_first_visual_func
end

--- Remove a regeistered chrome page.
-- @tparam string page The name of the chrome page to remove.
function _M.remove(page)
    handlers[page] = nil
    on_first_visual_handlers[page] = nil
end

luakit.register_scheme("luakit")

-- Catch all navigations to the luakit:// scheme
webview.add_signal("init", function (view)
    view:add_signal("scheme-request::luakit", function (v, uri, request)
        -- Match "luakit://page/path"
        local page, path = string.match(uri, "^luakit://([^/]+)/?(.*)")
        if not page then return end

        local func = handlers[page]
        if func then
            -- Give the handler function everything it may need
            local w = webview.window(v)
            local meta = { page = page, path = path, w = w,
                uri = "luakit://" .. page .. "/" .. path }

            -- Render error output in webview with traceback
            local function error_handler(err)
                error_page.show_error_page(v, {
                    heading = "Chrome handler error",
                    content = [==[
                        <div class="errorMessage">
                            <p>An error occurred in the <code>luakit://{page}/</code> handler function:
                            <pre>{traceback}</pre>
                        </div>
                    ]==],
                    buttons = {},
                    page = page,
                    traceback = debug.traceback(err, 2),
                    request = request,
                })
            end

            -- Call luakit:// page handler
            local ok, html, mime = xpcall(function () return func(v, meta) end,
                error_handler)
            if ok then request:finish(html, mime) end
            return
        end

        -- Load error page
        error_page.show_error_page(v, {
            heading = "Chrome handler error",
            content = [==[
                <div class="errorMessage">
                    <p>No chrome handler for <code>luakit://{page}/</code></p>
                </div>
            ]==],
            buttons = {},
            page = page,
            request = request,
        })
    end)

    view:add_signal("load-status", function (v, status)
        -- Wait for new page to be created
        if status ~= "finished" then return end

        -- Match "luakit://page/path"
        local page, path = string.match(v.uri, "^luakit://([^/]+)/?(.*)")
        if not page then return end

        -- Ensure we have a hook to call
        local on_first_visual_func = on_first_visual_handlers[page]
        if not on_first_visual_func then return end

        local w = webview.window(v)
        local meta = { page = page, path = path, w = w,
            uri = "luakit://" .. page .. "/" .. path }

        -- Call the supplied handler
        on_first_visual_func(v, meta)
    end)
    -- Always enable JavaScript on luakit:// pages; without this, chrome
    -- pages which depend upon javascript will break
    view:add_signal("enable-scripts", function (v)
        if v.uri:match("^luakit://") then return true end
    end)
end)

luakit.register_function("^luakit://(.*)", "reset_mode", function (view)
    for _, w in pairs(window.bywidget) do
        if w.view == view then
            w:set_mode()
        end
    end
end)

return _M

-- vim: et:sw=4:ts=8:sts=4:tw=80
