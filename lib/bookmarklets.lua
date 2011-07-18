----------------------------------------------------------------
-- Bookmarklet support                                        --
-- © 2011 Constantin Schomburg <me@xconstruct.net>            --
----------------------------------------------------------------

-- Grab environment we need
local assert = assert
local debug = debug
local os = os
local io = io
local string = string
local lousy = require "lousy"
local add_binds, add_cmds = add_binds, add_cmds
local capi = { luakit = luakit }

local bml_globals = globals.bookmarklets or {}

module("bookmarklets")

dir = bml_globals.dir or capi.luakit.data_dir.."/bookmarklets"

-- Return selected javascript uri or first uri in selection
local return_selected = [=[
(function() {
    var selection = window.getSelection();
    var container = document.createElement('div');
    var range;
    var elements;
    var idx;
    if ('' + selection) {
        range = selection.getRangeAt(0);
        // Check for links contained within the selection
        container.appendChild(range.cloneContents());
        elements = container.getElementsByTagName('a');
        for (idx in elements) {
            if (elements[idx].href && elements[idx].href.match(/^javascript:/)) {
                return elements[idx].href;
            }
        }
        // Check for links which contain the selection
        container = range.startContainer;
        while (container != document) {
            if (container.href && container.href.match(/^javascript:/)) {
                return container.href;
            }
            container = container.parentNode;
        }
    }
    // Check for active links
    var element = document.activeElement;
    var uri = element.src || element.href;
    if (uri && uri.match(/^javascript:/)) {
        return uri;
    }
})();
]=]

--- Evalulates a bookmarklet file in the current view
-- @param w The webview
-- @param token The token/filename of the bookmarklet
function open(w, token)
    local fd_name = dir .. '/' .. token

    local file = io.open(fd_name, "r")
    if not file then return end

    js = file:read("*a")
    file:close()

    local js_encoded = string.match(js, "^javascript:(.*)$")
    if js_encoded then
        js = capi.luakit.uri_decode(js_encoded)
    end

    local str = w:get_current():eval_js(js, "(bookmarklets:"..token..")")
end

--- Saves a bookmarklet token
--@param token The token
--@param js The bookmarklet
function save(token, js)
    lousy.util.mkdir(dir)
    local fd_name = dir .. '/' .. token

    local file = io.open(fd_name, "w")
    file:write(js)
    file:close()
end

--- Deletes a bookmarklet token
-- @param token The token
function del(token)
    os.remove(dir .. '/' .. token)
end

-- Add bookmarklet binds to normal mode
local buf = lousy.bind.buf
add_binds("normal", {
    buf("^gl%w$", function (w, b, m)
        local token = string.match(b, "^gl(.)$")
        for c=1, m.count do
            open(w, token)
        end
    end, {count=1}),
})

-- Add bookmarklet commands
local cmd = lousy.bind.cmd
add_cmds({

    -- Bookmarklet add (`:bmlet f [javascript:uri]`)
    -- if no second argument is specified, grab uri from link selection
    cmd("bml[et]", function(w, a)
        a = lousy.util.string.strip(a)
        local token, uri = string.match(a, "^(%w)%s+(.+)$")
        if (not uri and #a == 1) then
            token = a
            uri = w:eval_js(return_selected)
            if uri == "" then uri = nil end
        end
        assert(token, "invalid token")
        assert(uri, "no bookmarklet found!")
        save(token, uri)
        w:notify(string.format("Saved bookmarklet %q", token))
    end),

    -- Bookmarklet del (`:delbmlet f`)
    cmd("delbml[et]", function (w, a)
        token = lousy.util.string.strip(a)
        assert(#token == 1, "invalid token length: " .. token)
        del(token)
        w:notify(string.format("Deleted bookmarklet %q", token))
    end),
})

-- vim: et:sw=4:ts=8:sts=4:tw=80
