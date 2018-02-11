--- Only send Referer header if coming from the same domain - web module.
--
-- The Referer HTTP header is sent automatically to websites to inform them of
-- the referring website; i.e. the website that you were just on. This allows
-- website owners to see where web traffic is coming from, but can also be a
-- privacy concern.
--
-- To help mitigate this concern, this module prevents this information
-- from being sent whenever you navigate between two different domains.
-- For example, if you navigate from `https://example.com/test/` to
-- `https://google.com`, no Referer hreader will be sent. If you navigate
-- from `https://example.com/test/` to `https://example.com/`, however, the
-- Referer header will be sent. This is because some websites depend on
-- this functionality.
--
-- *Note: the word 'referer' is intentionally misspelled for historic reasons.*
--
-- # Usage
--
-- As this is a web module, it will not function if loaded on the main UI Lua
-- process through `require()`. Instead, it should be loaded with
-- `require_web_module()`:
--
--     require_web_module("referer_control_wm")
--
-- @module referer_control_wm
-- @copyright 2016 Aidan Holm <aidanholm@gmail.com>

local _M = {}

local function domain_from_uri(uri)
    local domain = (uri and string.match(string.lower(uri), "^%a+://([^/]*)/?"))
    -- Strip leading www. www2. etc
    domain = string.match(domain or "", "^www%d?%.(.+)") or domain
    return domain or ""
end

luakit.add_signal("page-created", function(page)
    page:add_signal("send-request", function(p, _, headers)
        if not headers.Referer then return end
        if domain_from_uri(p.uri) ~= domain_from_uri(headers.Referer) then
            msg.verbose("Removing referer '%s'", headers.Referer)
            headers.Referer = nil
        end
    end)
end)

return _M

-- vim: et:sw=4:ts=8:sts=4:tw=80
