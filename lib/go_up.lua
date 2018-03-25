--- Go one step upward in the URI path structure.
--
-- This module adds keybindings that allow you to easily navigate upwards in the
-- URI hierarchy of the current page. For example, if the current page is
-- `www.example.com/photos/pets/`, then going up once will navigate to
-- `www.example.com/photos/`, and going up once more will navigate to
-- `www.example.com`.
--
-- It is possible to go up multiple steps at once.
--
-- # Finer details
--
-- When using this module to navigate websites, generally you don't need to
-- worry about the finer details of how the current page URI is transformed.
-- The steps taken to transform the curent page URI, however, are listed here for
-- completeness.
--
-- When going up a single step, several checks are done on the current page URI:
--
-- 1. If there is a URI fragment, that is removed.
--    For example: `www.example.com/photos/#cool-photos-section` will become `www.example.com/photos/`.
-- 2. Otherwise, if there are any query parameters, they are removed.
--    For example: `www.example.com/photos/?cool=very` will become `www.example.com/photos/`.
-- 3. Otherwise, if there is a sub-path, one section of that is removed.
--    For example: `www.example.com/photos/` will become `www.example.com/`.
-- 4. Finally, if there are sub-domains in the host, the most specific
--    will be removed. This also applies to `www`.
--    For example: `www.example.com` will become `example.com`.
--
-- @module go_up
-- @copyright 2010-2012 Mason Larobina <mason.larobina@gmail.com>
-- @copyright 2012 LokiChaos <loki.chaos@gmail.com>

-- TODO check host against public TLD list to prevent returning only
-- top-level domain.

local modes = require("modes")
local add_binds = modes.add_binds
local match = string.match

local _M = {}

local function go_up_step(u)
    -- Step 1: remove fragment
    if u.fragment then
        u.fragment = nil
        return
    end

    -- Step 2: remove query params
    if u.query then
        u.query = nil
        return
    end

    -- Step 3: remove sub-path from uri
    local path = u.path
    if path and path ~= "/" then
        u.path = match(path, "(.*/)[^/]*/$") or match(path, "(.*/)[^/]+$")
        return
    end

    -- Step 4: remove sub-domains from host
    local host = u.host
    if host then
        u.user = nil
        u.password = nil
        u.host = match(host, "%.(.+)$") or host
        return
    end
end

--- Go up a number of steps in the path structure for a given URI.
-- @tparam string uri The initial URI.
-- @tparam number n The number of steps to traverse up the path structure of the
-- URI.
-- @treturn string The modified URI.
function _M.go_up(uri, n)
    local u = soup.parse_uri(uri)
    if not u then error("invalid uri: " .. tostring(uri)) end
    for _ = 1, (n or 1) do
        go_up_step(u)
    end
    return soup.uri_tostring(u)
end

--- Remove any fragment and query from a given URI, and set the path to `/`.
-- @tparam string uri The initial URI.
-- @treturn string The modified URI.
function _M.go_upmost(uri)
    local u = soup.parse_uri(uri)
    if not u then error("invalid uri: " .. tostring(uri)) end
    u.path = "/"
    u.fragment = nil
    u.query = nil
    return soup.uri_tostring(u)
end

-- Add `gu` & `gU` binds to the normal mode.
add_binds("normal", {
    { "^gu$", "Go `[count=1]` step upward in the URI path structure.",
        function (w, m)
            local uri = w.view.uri
            if not uri or uri == "about:blank" then return end
            w.view.uri = _M.go_up(uri, m.count or 1)
        end },

    { "^gU$", "Go to up-most URI (maintains host).",
        function (w)
            local uri = w.view.uri
            if not uri or uri == "about:blank" then return end
            w.view.uri = _M.go_upmost(uri)
        end },
})

-- Return module table
return setmetatable(_M, { __call = function (_, ...) return _M.go_up(...) end })

-- vim: et:sw=4:ts=8:sts=4:tw=80
