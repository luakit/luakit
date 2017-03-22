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
        local props = {domain_props.all or {}, domain_props[domain] or {}}
        repeat
            table.insert(props, 2, domain_props["."..domain] or {})
            domain = string.match(domain, "%.(.+)")
        until not domain
        -- Join all property tables
        for k, prop in pairs(lousy.util.table.join(unpack(props))) do
            msg.info("Domain prop: %s = %s (%s)", k, tostring(prop), domain)
            view[k] = prop
        end
    end)
end)

return _M

-- vim: et:sw=4:ts=8:sts=4:tw=80
