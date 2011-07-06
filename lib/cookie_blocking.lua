------------------------------------------------------
-- Simple domain-based cookie blocking              --
-- © 2011 Mason Larobina <mason.larobina@gmail.com> --
------------------------------------------------------

require "cookies"

cookies.whitelist_path = luakit.config_dir .. "/cookie.whitelist"
cookies.blacklist_path = luakit.config_dir .. "/cookie.blacklist"

local cache = {}

local function mkglob(s)
    s = string.gsub(s, "[%^%$%(%)%%%.%[%]%+%-%?]", "%%%1")
    s = string.gsub(s, "*", "%%S*")
    return "^"..s.."$"
end

local function load_rules(file)
    assert(file, "invalid path")
    local strip = lousy.util.string.strip
    if os.exists(file) then
        local rules = {}
        for line in io.lines(file) do
            table.insert(rules, mkglob(strip(line)))
        end
        return rules
    end
end

function cookies.reload_lists()
    cache = {} -- clear cache
    cookies.whitelist = load_rules(cookies.whitelist_path)
    cookies.blacklist = load_rules(cookies.blacklist_path)
end

function match_domain(rules, domain)
    local match = string.match
    for _, pat in ipairs(rules) do
        if match(domain, pat) then return true end
    end
end

cookies.add_signal("accept-cookie", function (cookie)
    local domain = cookie.domain

    -- Get cached block/allow result for given domain
    if cache[domain] ~= nil then
        return cache[domain]
    end

    local wl, bl = cookies.whitelist, cookies.blacklist

    -- Check if domain in whitelist
    if wl and wl[1] and match_domain(wl, domain) then
        cache[domain] = true
        return true
    end

    -- Check if domain in blacklist
    if bl and bl[1] and match_domain(bl, domain) then
        cache[domain] = false
        return false
    end

    cache[domain] = cookies.default_allow
    return cache[domain]
end)

-- Initial load of users cookie.whitelist / cookie.blacklist files
cookies.reload_lists()

-- vim: et:sw=4:ts=8:sts=4:tw=80
