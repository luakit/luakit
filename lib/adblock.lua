------------------------------------------------------------------------
-- Simple URI-based content filter v0.3.1a                            --
-- (C) 2010 Chris van Dijk (quigybo) <quigybo@hotmail.com>            --
-- (C) 2010 Mason Larobina (mason-l) <mason.larobina@gmail.com>       --
-- © 2012 Plaque FCC <Reslayer@ya.ru>                                 --
-- © 2010 adblock chromepage from bookmarks.lua by Henning Hasemann & --
-- Mason Larobina taken by Plaque FCC.                                --
--                                                                    --
-- Download an Adblock Plus compatible filter lists to luakit data    --
-- dir into "/adblock/" directory for multiple lists support or into  --
-- data dir root to use single file. EasyList is the most popular     --
-- Adblock Plus filter list: http://easylist.adblockplus.org/         --
-- Filterlists need to be updated regularly (~weekly), use cron!      --
------------------------------------------------------------------------

local info      = info
local pairs     = pairs
local ipairs    = ipairs
local assert    = assert
local unpack    = unpack
local type      = type
local io        = io
local os        = os
local string    = string
local table     = table
local tostring  = tostring
local tonumber  = tonumber
local webview   = webview
local lousy     = require("lousy")
local util      = lousy.util
local chrome    = require("chrome")
local capi      = { luakit = luakit }
local add_binds, add_cmds = add_binds, add_cmds
local lfs       = require("lfs")
local window    = window


module("adblock")

--- Module global variables
local enabled = true
-- Adblock Plus compatible filter lists
local adblock_dir = capi.luakit.data_dir .. "/adblock/"

local filterfiles = {}
local simple_mode = true
local subscriptions_file = adblock_dir .. "/subscriptions"
subscriptions = {}



-- String patterns to filter URI's with
rules = {}

-- Functions to filter URI's by
-- Return true or false to allow or block respectively, nil to continue matching
local filterfuncs = {}

-- Fitting for adblock.chrome.refresh_views()
refresh_views = function()
    -- Dummy.
end

-- Enable or disable filtering
enable = function ()
    enabled = true
    refresh_views()
end
disable = function ()
    enabled = false
    refresh_views()
end

-- Report AdBlock state: «Enabled» or «Disabled»
state = function()
    if enabled then
        return "Enabled"
    else
        return "Disabled"
    end
end

mode = function()
    if simple_mode then
        return "simple"
    else
        return "normal"
    end
end

-- Detect files to read rules from
function detect_files()
    local curdir = lfs.currentdir()
    -- Try to find subscriptions directory:
    if not lfs.chdir(adblock_dir) then
        lfs.mkdir(adblock_dir)
    else
        simple_mode = false
        -- Look for filters lists:
        lfs.chdir(curdir)
        for filename in lfs.dir(adblock_dir) do
            if string.find(filename, ".txt$") then
                info("adblock: Found adblock list: " .. filename)
                table.insert(filterfiles, filename)
            end
        end
    end
    
    if table.maxn(filterfiles) < 1 then
        simple_mode = true
        filterfiles = { "/easylist.txt" }
    end
    
    if not simple_mode then
        info( "adblock: Found " .. table.maxn(filterfiles) .. " rules lists.\n" )
    end
    
    return
end

local function get_abp_opts(s)
    local opts = {}
    local pos = string.find(s, "%$")
    if pos then
        local op = string.sub(s, pos+1)
        s = string.sub(s, 1, pos-1)
        for key in string.gmatch(op, "[^,]+") do
            local val
            local pos = string.find(key, "=")
            if pos then
                val = string.sub(key, pos+1)
                key = string.sub(key, 1, pos-1)
            end

            local negative = false
            if string.sub(key, 1, 1) == "~" then
                negative = true
                key = string.sub(key, 2)
            end

            if key == "domain" and val then
                local domains = {}
                for v in string.gmatch(val, "[^|]+") do
                    table.insert(domains, v)
                end
                if #domains > 0 then opts["domain"] = domains end
            elseif key == "third-party" then
                opts["third-party"] = not negative
            else
                opts["unknown"] = true
            end
        end
    end
    return s, opts
end

-- Convert Adblock Plus filter description to lua string pattern
-- See http://adblockplus.org/en/filters for more information
abp_to_pattern = function (s)
    -- Strip filter options
    local opts
    s, opts = get_abp_opts(s)
    if opts and opts.unknown == true then return {} end -- Skip rules with unknown options

    local domain = nil

    if string.len(s) > 0 then
        -- Optimize for domain anchor rules
        if string.match(s, "^||") then
            -- Extract the domain from the pattern
            local d = string.sub(s, 3)
            d = string.gsub(d, "/.*", "")
            d = string.gsub(d, "%^.*", "")

            -- We don't bother with wildcard domains since they aren't frequent enough
            if not string.find(d, "*") then
                domain = d
            end
        end

        -- Protect magic characters (^$()%.[]*+-?) not used by ABP (^$()[]*)
        s = string.gsub(s, "([%%%.%+%-%?])", "%%%1")

        -- Wildcards are globbing
        s = string.gsub(s, "%*", "%.%*")

        -- Caret is separator (anything but a letter, a digit, or one of the following:Â - . %)
        s = string.gsub(s, "%^", "[^%%w%%-%%.%%%%]")

        -- Double pipe is domain anchor (beginning only)
        if string.match(s, "^||") then
            local p = string.sub(s, 3) -- Clip off first two || characters
            s = { "^https?://" .. p, "^https?://[^/]*%." .. p }
        else
            s = { s }
        end

        for k, v in ipairs(s) do
			-- Pipe is anchor
            v = string.gsub(v, "^|", "%^")
            v = string.gsub(v, "|$", "%$")

            -- Convert to lowercase ($match-case option is not honoured)
            v = string.lower(v)
            s[k] = v
        end
    end

    return s, opts, domain
end

add_unique_cached = function (pattern, opts, tab, cache_tab)
    if cache_tab[pattern] then
        return false
    else
        --cache_tab[pattern], tab[pattern] = true, pattern
        cache_tab[pattern], tab[pattern] = true, opts
        return true
    end
end

-- Parses an Adblock Plus compatible filter list
parse_abpfilterlist = function (filename, cache)
    if os.exists(filename) then
        info("adblock: loading filterlist %s", filename)
    else
        info("adblock: error loading filter list (%s: No such file or directory)", filename)
    end
    --***
    --local f = io.open(filename .. "~", "w")
    --***
    local pat, opts
    local wlen, blen, icnt = 0, 0, 0
    local white, black = { patterns = {}, domains = {} }, { patterns = {}, domains = {}, ad_patterns = {} }
    for line in io.lines(filename) do
        -- Ignore comments, header and blank lines
        if line:match("^[![]") or line:match("^$") then
            -- dammitwhydoesntluahaveacontinuestatement

        -- Ignore element hiding
        elseif line:match("#") then
            --icnt = icnt + 1

        -- Check for exceptions (whitelist)
        elseif line:match("^@@") then
            pats, opts, domain = abp_to_pattern(string.sub(line, 3))
            for _, pat in ipairs(pats) do
                if pat ~= "^http://" then
                    local new
                    if domain then
                        if not white.domains[domain] then white.domains[domain] = {} end
                        new = add_unique_cached(pat, opts, white.domains[domain], cache.white)
                    else
                        new = add_unique_cached(pat, opts, white.patterns, cache.white)
                    end
                    if new then
                        wlen = wlen + 1
                        --***
                        --f:write("W " .. pat .. "\n")
                        --***
                    else
                        icnt = icnt + 1
                    end
                    -- table.insert(white, pat)
                else
                    icnt = icnt + 1
                end
            end

        -- Add everything else to blacklist
        else
            pats, opts, domain = abp_to_pattern(line)
            for _, pat in ipairs(pats) do
                if pat ~= "^http:" and pat ~= ".*" then
                    local new
                    if domain then
                        if not black.domains[domain] then black.domains[domain] = {} end
                        new = add_unique_cached(pat, opts, black.domains[domain], cache.black)
                    elseif string.find(line, "ad") then
                        new = add_unique_cached(pat, opts, black.ad_patterns, cache.black)
                    else
                        new = add_unique_cached(pat, opts, black.patterns, cache.black)
                    end
                    if new then
                        blen = blen + 1
                        --***
                        --f:write("B " .. pat .. "\n")
                        --***
                    else
                        icnt = icnt + 1
                    end
                    -- table.insert(black, pat)
                else
                    icnt = icnt + 1
                end
            end
        end
    end
    --***
    --f:close()
    --***

    return white, black, wlen, blen, icnt
end

-- Load filter list files
load = function (reload, single_list)
    if reload then subscriptions, filterfiles = {}, {} end
    detect_files()
    if not simple_mode and not single_list then
        read_subscriptions()
        local files_list = {}
        for _, filename in ipairs(filterfiles) do
            local list = subscriptions[filename]
            if list and util.table.hasitem(list.opts, "Enabled") then
                table.insert(files_list, filename)
            else
                add_list("", filename, "Disabled", true, false)
            end
        end
        filterfiles = files_list
        -- Yes we may have changed subscriptions and even fixed something with them.
        write_subscriptions()
    end

    -- [re-]loading:
    if reload then rules = {} end
    local filters_dir = adblock_dir
    if simple_mode then
        filters_dir = capi.luakit.data_dir
    end
    local filterfiles_loading = {}
    if single_list and not reload then
        filterfiles_loading = { single_list }
    else
        filterfiles_loading = filterfiles
    end
    local rules_cache = {
        black = {},
        white = {}
    } -- This cache should let us avoid unnecessary filters duplication.
    
    for _, filename in ipairs(filterfiles_loading) do
        local white, black, wlen, blen, icnt = parse_abpfilterlist(filters_dir .. filename, rules_cache)
        local list = {}
        if not simple_mode then
            list = subscriptions[filename]
        else
            local list_found = rules[filename]
            if list_found then
                list = list_found
            end
        end
        if not util.table.hasitem(rules, list) then
            rules[filename] = list
        end
        list.title, list.white, list.black, list.ignored = filename, wlen or 0, blen or 0, icnt or 0
        list.whitelist, list.blacklist = white or {}, black or {}
    end
    
    rules_cache.white, rules_cache.black = nil, nil
    rules_cache = nil
    refresh_views()
end

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

local function third_party_match(page_domain, domain2, opts)
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

-- Tests URI against user-defined filter functions, then whitelist, then blacklist
match = function (uri, signame, page_uri)
    -- Always allow data: URIs
    if string.sub(uri, 1, 5) == "data:" then
        info("adblock: allowing data URI")
        return
    end

    -- Matching is not case sensitive
    uri = string.lower(uri)

    signame = signame or ""

    local page_domain, uri_domain
    if signame ~= "navigation-request" then
        page_domain = domain_from_uri(page_uri)
        uri_domain = domain_from_uri(uri)
    else
        page_domain = domain_from_uri(uri)
        uri_domain = page_uri
    end

    -- Test uri against filterfuncs
    for _, func in ipairs(filterfuncs) do
        local ret = func(uri)
        if ret ~= nil then
            info("adblock: filter function %s returned %s to uri %s", tostring(func), tostring(ret), uri)
            return ret
        end
    end

    -- Build a table of all domains this URI falls under
    local uri_domains = {}
    do
        local d = uri_domain
        while d do
            uri_domains[d] = true
            d = string.match(d, "%.(.+)")
        end
    end
    
    -- Test against each list's whitelist rules first
    for _, list in pairs(rules) do
        -- First, check for domain name anchor (||) rules
        for domain, _ in pairs(uri_domains) do
            for pattern, opts in pairs(list.whitelist.domains[domain] or {}) do
                if third_party_match(page_domain, uri_domain, opts) then
                    if domain_match(page_domain, opts) and string.match(uri, pattern) then
                        info("adblock: allowing %q as domain %q matched to uri %s", signame, domain, uri)
                        return true
                    end
                end
            end
        end

        -- Check for a match to whitelist
        for pattern, opts in pairs(list.whitelist.patterns or {}) do
            if third_party_match(page_domain, uri_domain, opts) then
                if domain_match(page_domain, opts) and string.match(uri, pattern) then
                    info("adblock: allowing %q as pattern %q matched to uri %s", signame, pattern, uri)
                    return true
                end
            end
        end
    end
    
    -- Test against each list's blacklist rules
    for _, list in pairs(rules) do
        -- First, check for domain name anchor (||) rules
        for domain, _ in pairs(uri_domains) do
            for pattern, opts in pairs(list.blacklist.domains[domain] or {}) do
                if third_party_match(page_domain, uri_domain, opts) then
                    if domain_match(page_domain, opts) and string.match(uri, pattern) then
                        info("adblock: blocking %q as domain %q matched to uri %s", signame, domain, uri)
                        return false
                    end
                end
            end
        end

        -- If the URI contains "ad", check the ad_patterns blacklist as well
        if string.find(uri, "ad") then
            for pattern, opts in pairs(list.blacklist.ad_patterns or {}) do
                if third_party_match(page_domain, uri_domain, opts) then
                    if domain_match(page_domain, opts) and string.match(uri, pattern) then
                        info("adblock: blocking %q as pattern %q matched to uri %s", signame, pattern, uri)
                        return false
                    end
                end
            end
        end

        -- Check for a match to blacklist
        for pattern, opts in pairs(list.blacklist.patterns or {}) do
            if third_party_match(page_domain, uri_domain, opts) then
                if domain_match(page_domain, opts) and string.match(uri, pattern) then
                    info("adblock: blocking %q as pattern %q matched to uri %s", signame, pattern, uri)
                    return false
                end
            end
        end
    end
end

-- Direct requests to match function
filter = function (v, uri, signame)
    -- Don't adblock on local files
    local file_uri = v.uri and string.sub(v.uri, 1, 7) == "file://"

    if enabled and not file_uri then
        return match(uri, signame or "", v.uri)
    end
end

function table.itemid(t, item)
    local pos = 0
    for id, v in pairs(t) do
        pos = pos + 1
        if v == item then
            return pos
        end
    end
end

-- Connect signals to all webview widgets on creation
webview.init_funcs.adblock_signals = function (view, w)
    --view:add_signal("navigation-request",        function (v, uri) return filter(v, uri, "navigation-request")        end)
    view:add_signal("resource-request-starting", function (v, uri) return filter(v, uri, "resource-request-starting") end)
end

-- Remove options and add new ones to list
-- @param list_index Index of the list to modify
-- @param opt_ex Options to exclude
-- @param opt_inc Options to include
function list_opts_modify(list_index, opt_ex, opt_inc)
    assert( simple_mode == false, "adblock list management: not supported in simple mode" )
    assert(type(list_index) == "number", "list options modify: invalid list index")
    assert(list_index > 0, "list options modify: index has to be > 0")
    if not opt_ex then opt_ex = {} end
    if not opt_inc then opt_inc = {} end
    
    if type(opt_ex) == "string" then opt_ex = util.string.split(opt_ex) end
    if type(opt_inc) == "string" then opt_inc = util.string.split(opt_inc) end
    
    local list = util.table.values(subscriptions)[list_index]
    local opts = opt_inc
    for _, opt in ipairs(list.opts) do
        if not util.table.hasitem(opt_ex, opt) then
            table.insert(opts, opt)
        end
    end
    
    -- Manage list's rules
    local listIDfound = table.itemid(rules, list)
    if util.table.hasitem(opt_inc, "Enabled") then
        if not listIDfound then
            load(false, list.title)
        end
    elseif util.table.hasitem(opt_inc, "Disabled") then
        rules[list.title] = nil
    end
    
    list.opts = opts
    write_subscriptions()
    refresh_views()
end

--- Add a list to the in-memory lists table
function add_list(uri, title, opts, replace, save_lists)
    assert( (title ~= nil) and (title ~= ""), "adblock list add: no title given")
    if not opts then opts = {} end

    -- Create tags table from string
    if type(opts) == "string" then opts = util.string.split(opts) end
    if table.maxn(opts) == 0 then table.insert(opts, "Disabled") end
    if not replace and ( subscriptions[title] or subscriptions[uri] ) then
        local list = subscriptions[title] or subscriptions[uri]
        -- Merge tags
        for _, opts in ipairs(opts) do
            if not util.table.hasitem(list, opts) then table.insert(list, opts) end
        end
    else
        -- Insert new adblock list
        local list = { uri = uri, title = title, opts = opts }
        if not (uri == "" or uri == nil) then
            subscriptions[uri] = list
        end
        if not (title == "" or title == nil) then
            subscriptions[title] = list
        end
    end

    -- Save by default
    if save_lists ~= false then write_subscriptions() end
end

--- Save the in-memory subscriptions to flatfile.
-- @param file The destination file or the default location if nil.
function write_subscriptions(file)
    if not file then file = subscriptions_file end

    local lines = {}
    local added = {}
    for _, list in pairs(subscriptions) do
        if not util.table.hasitem(added, list) then
            local subs = { uri = list.uri, title = list.title, opts = table.concat(list.opts or {}, " "), }
            local line = string.gsub("{title}\t{uri}\t{opts}", "{(%w+)}", subs)
            table.insert(added, list)
            table.insert(lines, line)
        end
    end

    -- Write table to disk
    local fh = io.open(file, "w")
    fh:write(table.concat(lines, "\n"))
    io.close(fh)
end

--- Load subscriptions from a flatfile to memory.
-- @param file The subscriptions file or the default subscriptions location if nil.
-- @param clear_first Should the subscriptions in memory be dumped before loading.
function read_subscriptions(file, clear_first)
    if clear_first then clear() end

    -- Find a subscriptions file
    if not file then file = subscriptions_file end
    if not os.exists(file) then return end

    -- Read lines into subscriptions data table
    for line in io.lines(file or subscriptions_file) do
        local title, uri, opts = unpack(util.string.split(line, "\t"))
        if title ~= "" then add_list(uri, title, opts, false, false) end
    end
end


-- Add commands.
local cmd = lousy.bind.cmd
add_cmds({
    cmd({"adblock-reload", "abr"}, function (w)
        info("adblock: Reloading filters.")
        load(true)
        info("adblock: Reloading filters complete.")
    end),
    
    cmd({"adblock-list-enable", "able"}, function (w, a)
        list_opts_modify(tonumber(a), "Disabled", "Enabled")
    end),
    
    cmd({"adblock-list-disable", "abld"}, function (w, a)
        list_opts_modify(tonumber(a), "Enabled", "Disabled")
    end),
    cmd({"adblock-enable", "abe"}, function (w)
    enable()
    end),
    
    cmd({"adblock-disable", "abd"}, function (w)
    disable()
    end),
})

-- Initialise module
load()
