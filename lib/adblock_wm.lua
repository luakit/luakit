-- Simple URI-based content filter - web module.
--
-- @submodule adblock_wm
-- @copyright 2016 Aidan Holm <aidanholm@gmail.com>
-- @author Aidan Holm <aidanholm@gmail.com>

local ui = ipc_channel("adblock_wm")
local lousy = require "lousy"

local enabled = true
local rules = {}
local enabled_rules = {}
local page_whitelist = {}

ui:add_signal("enable", function(_, _, e) enabled = e end)
ui:add_signal("update_rules", function(_, _, r)
    rules = r
    ui:emit_signal("rules_updated", luakit.web_process_id)
end)
ui:add_signal("update_page_whitelist", function(_, _, wl)
    page_whitelist = wl
    ui:emit_signal("rules_updated", luakit.web_process_id)
end)
ui:add_signal("list_set_enabled", function(_, _, list, enable)
    enabled_rules[list] = enable and rules[list] or nil
end)

local function domain_match(domain, opts)
    local res = false
    local cnt = 0
    local dlist = opts["domain"]
    if dlist then
        for _, s in pairs(dlist) do
            if string.len(s) > 0 then
                if string.sub(s, 1, 1) == "~" then
                    if domain == string.sub(s, 2) then return false end
                else
                    cnt = cnt + 1
                    if not res and domain == s then res = true end
                end
            end
        end
    end
    return cnt == 0 or res
end

local function third_party_match(domain1, domain2, opts)
    local thp = opts["third-party"]
    if thp ~= nil then
        if thp == true then return domain1 ~= domain2 end
        return domain1 == domain2
    end
    return true
end

local function domain_from_uri(uri)
    local domain = (uri and string.match(string.lower(uri), "^%a+://([^/]*)/?"))
    -- Strip leading www. www2. etc
    domain = string.match(domain or "", "^www%d?%.(.+)") or domain
    return domain or ""
end

local match_list = function (list, uri, uri_domains, page_domain, uri_domain)
    -- First, check for domain name anchor (||) rules
    for domain, _ in pairs(uri_domains) do
        for pattern, opts in pairs(list.domains[domain] or {}) do
            if third_party_match(page_domain, uri_domain, opts) then
                if domain_match(page_domain, opts) and string.match(uri, pattern) then
                    return true, pattern
                end
            end
        end
    end

    -- Next, match against plain text strings
    for pattern, opts in pairs(list.plain or {}) do
        if third_party_match(page_domain, uri_domain, opts) then
            if domain_match(page_domain, opts) and string.find(uri, pattern, 1, true) then
                return true, pattern
            end
        end
    end

    -- If the URI contains "ad", check those buckets as well
    if string.find(uri, "ad", 1, true) then
        -- Check plain strings with "ad" in them
        for pattern, opts in pairs(list.ad_plain or {}) do
            if third_party_match(page_domain, uri_domain, opts) then
                if domain_match(page_domain, opts) and string.find(uri, pattern, 1, true) then
                    return true, pattern
                end
            end
        end
        -- Check patterns with "ad" in them
        for pattern, opts in pairs(list.ad_patterns or {}) do
            if third_party_match(page_domain, uri_domain, opts) then
                if domain_match(page_domain, opts) and string.match(uri, pattern) then
                    return true, pattern
                end
            end
        end
    end

    -- Finally, check for a general match
    for pattern, opts in pairs(list.patterns or {}) do
        if third_party_match(page_domain, uri_domain, opts) then
            if domain_match(page_domain, opts) and string.match(uri, pattern) then
                return true, pattern
            end
        end
    end
end

-- Tests URI against user-defined filter functions, then whitelist, then blacklist
local match = function (src, dst)
    -- Always allow data: URIs
    if string.sub(dst, 1, 5) == "data:" then
        msg.debug("allowing data URI")
        return
    end

    -- Matching is not case sensitive
    dst = string.lower(dst)

    local src_domain = domain_from_uri(src)
    local dst_domain = domain_from_uri(dst)

    -- Build a table of all domains this URI falls under
    local dst_domains = {}
    do
        local d = dst_domain
        while d do
            dst_domains[d] = true
            d = string.match(d, "%.(.+)")
        end
    end

    -- Test against each list's whitelist rules first
    for _, list in pairs(enabled_rules) do
        local found, pattern = match_list(list.whitelist, dst, dst_domains, src_domain, dst_domain)
        if found then
            msg.debug("allowing request as pattern %q matched to uri %s", pattern, dst)
            return true
        end
    end

    -- Test against each list's blacklist rules
    for _, list in pairs(enabled_rules) do
        local found, pattern = match_list(list.blacklist, dst, dst_domains, src_domain, dst_domain)
        if found then
            msg.debug("blocking request as pattern %q matched to uri %s", pattern, dst)
            return false
        end
    end
end


-- Direct requests to match function
local filter = function (src, dst)
    -- Don't adblock on local files
    local file_uri = src and string.sub(src, 1, 7) == "file://"

    if enabled and not file_uri then
        return match(src, dst)
    end
end

luakit.add_signal("page-created", function(page)
    page:add_signal("send-request", function(p, uri)
        -- Prevent adblock-blocked: pages from being blocked themselves
        if uri:match("^adblock%-blocked:") then return end

        local allow = filter(p.uri, uri)
        if allow == false and p.uri == uri then
            if not lousy.util.table.hasitem(page_whitelist, lousy.uri.parse(uri).host) then
                return "adblock-blocked:" .. uri
            end
        else
            if allow == false then return false end
        end
    end)
end)

-- vim: et:sw=4:ts=8:sts=4:tw=80
