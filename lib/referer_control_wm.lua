--- Only send Referer header if coming from the same domain - web module.
--
-- @module referer_control_wm
-- @copyright 2016 Aidan Holm

local _M = {}

local function domain_from_uri(uri)
    local domain = (uri and string.match(string.lower(uri), "^%a+://([^/]*)/?"))
    -- Strip leading www. www2. etc
    domain = string.match(domain or "", "^www%d?%.(.+)") or domain
    return domain or ""
end

extension:add_signal("page-created", function(_, page)
    page:add_signal("send-request", function(p, _, headers)
        if not headers.Referer then return end
        if domain_from_uri(p.uri) ~= domain_from_uri(headers.Referer) then
            msg.verbose("Removing referer '%s'", headers.Referer)
            headers.Referer = nil
        end
    end)
end)

return _M
