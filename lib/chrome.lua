------------------------------------------------------------
-- Add custom luakit:// scheme rendering functions        --
-- © 2010-2012 Mason Larobina  <mason.larobina@gmail.com> --
-- © 2010 Fabian Streitel <karottenreibe@gmail.com>       --
------------------------------------------------------------

-- Get lua environment
local assert = assert
local string = string
local type = type
local xpcall = xpcall
local debug = debug

-- Get luakit environment
local webview = webview

module("chrome")

-- Common stylesheet that can be sourced from several chrome modules for a
-- consitent looking theme.
stylesheet = [===[
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

function add(page, func)
    -- Do some sanity checking
    assert(type(page) == "string",
        "invalid chrome page name (string expected, got "..type(page)..")")
    assert(string.match(page, "^[%w%-]+$"),
        "illegal characters in chrome page name: " .. page)
    assert(type(func) == "function",
        "invalid chrome handler (function expected, got "..type(func)..")")

    handlers[page] = func
end

function remove(page)
    handlers[page] = nil
end

error_html = [==[
<html><head><title>Chrome handler error</title><style>
pre { border-top: 1px solid #aaa; border-bottom: 1px solid #aaa;
    margin: -5px 5px; padding: 5px; background-color: #f2f2f2; }
</style></head><body>
<p>Error in <big><code>%q</code></big> handler function:</p>
<pre>%s</pre></body></html>
]==]

-- Catch all navigations to the luakit:// scheme
webview.init_funcs.chrome = function (view, w)
    view:add_signal("navigation-request", function (_, uri)
        -- Match "luakit://page/path"
        local page, path = string.match(uri, "^luakit://([^/]+)/?(.*)")
        if not page then return end

        local func = handlers[page]
        if func then
            -- Give the handler function everything it may need
            local meta = { page = page, path = path, w = w,
                uri = "luakit://" .. page .. "/" .. path }

            -- Render error output in webview with traceback
            local function error_handler(err)
                view:load_string(string.format(error_html, uri,
                    debug.traceback(err, 2)), uri)
            end

            -- Call luakit:// page handler
            local ok, err = xpcall(function () return func(view, meta) end,
                error_handler)

            if not ok or err ~= false then
                -- Stop the navigation request
                return false
            end
        end

        -- Load blank error page
        view:load_string("<p>No chrome handler for: <big><code>" .. uri
            .. "</code></big></p>", uri)
    end)
end

-- vim: et:sw=4:ts=8:sts=4:tw=80
