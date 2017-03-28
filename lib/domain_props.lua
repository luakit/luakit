--- Automatically apply per-domain webview properties.
--
-- @module domain_props
-- @copyright 2012 Mason Larobina

local lousy = require("lousy")
local webview = require("webview")
local globals = require("globals")
local domain_props = globals.domain_props

local _M = {}

webview.add_signal("init", function (view)
    view:add_signal("load-status", function (v, status)
        if status ~= "committed" or v.uri == "about:blank" then return end
        -- Get domain
        local domain = lousy.uri.parse(v.uri).host
        -- Strip leading www.
        domain = string.match(domain or "", "^www%.(.+)") or domain or "all"
        -- Build list of domain props tables to join & load.
        -- I.e. for luakit.org load .luakit.org, luakit.org, .org
        local prop_sets = {
            { domain = "all", props = domain_props.all or {} },
            { domain = domain, props = domain_props[domain] or {} },
        }
        repeat
            table.insert(prop_sets, { domain = "."..domain, props = domain_props["."..domain] or {} })
            domain = string.match(domain, "%.(.+)")
        until not domain

        -- Sort by rule precedence: "all" first, then by increasing specificity
        table.sort(prop_sets, function (a, b)
            if a.domain == "all" then return true end
            if b.domain == "all" then return false end
            return #a.domain < #b.domain
        end)

        -- Apply all properties
        for _, props in ipairs(prop_sets) do
            for k, prop in pairs(props.props) do
                msg.info("Domain prop: %s = %s (%s)", k, prop, props.domain)
                view[k] = prop
            end
        end
    end)
end)

return _M

-- vim: et:sw=4:ts=8:sts=4:tw=80
