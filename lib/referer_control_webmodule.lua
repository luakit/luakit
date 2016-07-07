local extension = extension
local string = string

module("referer_control_webmodule")

local function domain_from_uri(uri)
    local domain = (uri and string.match(string.lower(uri), "^%a+://([^/]*)/?"))
    -- Strip leading www. www2. etc
    domain = string.match(domain or "", "^www%d?%.(.+)") or domain
    return domain or ""
end

extension:add_signal("page-created", function(_, page)
    page:add_signal("send-request", function(p, uri, headers)
        if domain_from_uri(p.uri) ~= domain_from_uri(headers.Referer) then
            headers.Referer = nil
            return nil, headers
        end
    end)
end)
