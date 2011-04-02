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
local print = print

-- Get luakit environment
local lousy = require "lousy"
local webview = webview
local capi = { soup = soup }

module("chrome")

-- Ordered list of chrome page generation rules
local rules = {}

function add(pat, func)
    assert(type(pat) == "string", "invalid pattern")
    assert(type(func) == "function", "invalid function")
    if string.match(pat, '^^') then pat = string.sub(pat, 2) end
    table.insert(rules, { pat = '^' .. pat, func = func })
end

function del(pat)
    for i, r in ipairs(rules) do
        if r.pat == pat then
            return table.remove(rules, i)
        end
    end
end

webview.init_funcs.chrome = function (view, w)
    view:add_signal("navigation-request", function (v, ustr)
        uri = lousy.uri.parse(ustr)
        if not uri then
            return
        elseif uri.scheme == "chrome" then
            uri.scheme = "luakit"
        elseif uri.scheme ~= "luakit" then
            return
        end
        -- Match chrome pattern against "host/path"
        local path = uri.host .. (uri.path or "/")
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
