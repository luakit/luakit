---------------------------------------------------------------------
-- Go one step upward in the URI path structure.                   --
-- © 2010-2012 Mason Larobina (mason-l) <mason.larobina@gmail.com> --
-- © 2012 LokiChaos <loki.chaos@gmail.com>                         --
---------------------------------------------------------------------

-- TODO check host against public TLD list to prevent returning only
-- top-level domain.

local parse_uri, uri_tostring = soup.parse_uri, soup.uri_tostring
local match = string.match

local M = {}

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

function M.go_up(uri, n)
    local u = soup.parse_uri(uri)
    if not u then error("invalid uri: " .. tostring(uri)) end
    for i = 1, (n or 1) do
        go_up_step(u)
    end
    return soup.uri_tostring(u)
end

function M.go_upmost(uri)
    local u = soup.parse_uri(uri)
    if not u then error("invalid uri: " .. tostring(uri)) end
    u.path = "/"
    u.fragment = nil
    u.query = nil
    return soup.uri_tostring(u)
end

-- Add `gu` & `gU` binds to the normal mode.
local buf = lousy.bind.buf
add_binds("normal", {
    buf("^gu$", "Go `[count=1]` step upward in the URI path structure.",
        function (w, _, m)
            local uri = w.view.uri
            if not uri or uri == "about:blank" then return end
            w.view.uri = M.go_up(uri, m.count or 1)
        end),

    buf("^gU$", "Go to up-most URI (maintains host).",
        function (w)
            local uri = w.view.uri
            if not uri or uri == "about:blank" then return end
            w.view.uri = M.go_upmost(uri)
        end),
})

-- Return module table
return setmetatable(M, { __call = function (M, ...) return M.go_up(...) end })
