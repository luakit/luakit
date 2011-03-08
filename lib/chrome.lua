---------------------------------------------------------
-- Render chrome pages for luakit                      --
-- (C) 2010 Fabian Streitel <karottenreibe@gmail.com>  --
-- (C) 2010 Mason Larobina  <mason.larobina@gmail.com> --
---------------------------------------------------------

local ipairs = ipairs
local string = string
local webview = webview
local table = table
local info = info

module("chrome")

-- Ordered list of chrome page generation rules
local rules = {}

function add(pat, func)
    table.insert(rules, { pat = pat, func = func })
end

function del(pat)
    for i, r in ipairs(rules) do
        if r.pat == pat then
            table.remove(rules, i)
        end
    end
end

webview.init_funcs.chrome = function (view, w)
    view:add_signal("navigation-request", function (v, uri)
        for _, r in ipairs(rules) do
            if string.match(uri, r.pat) then
                info("Matched chrome rule %q for uri %q", r.pat, uri)
                -- Catch if function returns anything other than false
                if r.func(v, uri) ~= false then return false end
            end
        end
        return true
    end)
end

-- vim: et:sw=4:ts=8:sts=4:tw=80
