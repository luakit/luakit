----------------------------------------------------------
-- Serve custom luakit:// pages according to user rules --
-- © 2010 Fabian Streitel <karottenreibe@gmail.com>     --
-- © 2010 Mason Larobina  <mason.larobina@gmail.com>    --
----------------------------------------------------------

-- Get lua environment
local ipairs = ipairs
local string = string
local table = table
local info = info
local assert = assert
local type = type

-- Get luakit environment
local lousy = require "lousy"
local webview = webview
local capi = { soup = soup }

module("chrome")

-- Setup signals on module
lousy.signal.setup(_M, true)

-- Ordered list of chrome page generation rules
local rules = {}

--- Registers a chrome page.
-- @param pat The pattern that identifies the page by matching it against the URL
-- @param func The function to call when the page is opened
function add(pat, func)
    assert(type(pat) == "string", "invalid pattern")
    assert(type(func) == "function", "invalid function")
    if string.match(pat, '^^') then pat = string.sub(pat, 2) end
    table.insert(rules, { pat = '^' .. pat, func = func })
end

--- Unregisters the chrome page for the given pattern.
-- @param pat The pattern that identifies the page by matching it against the URL
function del(pat)
    for i, r in ipairs(rules) do
        if r.pat == pat then
            return table.remove(rules, i)
        end
    end
end

--- Emits the "refresh" signal that tells all listeners that the chrome
-- page has been updated.
-- @param pat The pattern that identifies the page by matching it against the URL
-- @param view The view that needs to be updated
function refresh(pat, view)
    assert(type(pat) == "string", "invalid pattern")
    return _M.emit_signal("refresh", pat, view)
end

-- Extracts the relevant parts from the URI string so it can be matched against
-- the page patterns.
-- @return The relevant URI parts on nil if it's not a chrome page.
local function prepare_uri(uri)
    if not uri then
        return nil
    elseif uri.scheme == "chrome" then
        uri.scheme = "luakit"
    elseif uri.scheme ~= "luakit" then
        return nil
    end
    -- Match chrome pattern against "host/path"
    return uri.host .. (uri.path or "/")
end

webview.init_funcs.chrome = function (view, w)
    -- Catch tab switches to ensure proper updates of chrome pages
    w.tabs:add_signal("switch-page", function (nbook, view, index)
        local uri = lousy.uri.parse(view.uri or "")
        local path = prepare_uri(uri)
        if not path then return end
        for _, r in ipairs(rules) do
            if string.match(path, r.pat) then
                refresh(r.pat, view)
                return
            end
        end
    end)
    view:add_signal("navigation-request", function (v, ustr)
        local uri = lousy.uri.parse(ustr)
        local path = prepare_uri(uri)
        if not path then return true end
        for _, r in ipairs(rules) do
            if string.match(path, r.pat) then
                info("Matched chrome rule %q for uri %q", r.pat, ustr)
                -- Catch if function returns anything other than false
                if r.func(v, uri) ~= false then return false end
            end
        end
        return true
    end)
end

-- vim: et:sw=4:ts=8:sts=4:tw=80
