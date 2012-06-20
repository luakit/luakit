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

-- Catch all navigations to the luakit:// scheme
webview.init_funcs.chrome = function (view, w)
    view:add_signal("navigation-request", function (_, uri)
        -- Match "luakit://page/path"
        local page, path = string.match(uri, "^luakit://([^/]+)/?(.*)")
        if not page then return end

        local func = handlers[page]
        if func then
            -- Give the handler function everything it may need
            local meta = { uri = uri, page = page, path = path, w = w }

            -- Render error output in webview with traceback
            local function error_handler(err)
                view:load_string("<p><b>Error in <code>luakit://" .. page
                    .. "/</code> handler function:</b></p><pre>"
                    .. debug.traceback(err, 2) .. "</pre>", uri)
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
        view:load_string("<p><b>No chrome handler for <code>" .. uri
            .. "</code></b></p>", uri)
    end)
end

-- vim: et:sw=4:ts=8:sts=4:tw=80
