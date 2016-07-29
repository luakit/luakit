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

local msg       = msg
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
local web_module = web_module


module("adblock")

local adblock_wm = web_module("adblock_webmodule")

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
    adblock_wm:emit_signal("enable", enabled)
    refresh_views()
end
disable = function ()
    enabled = false
    adblock_wm:emit_signal("enable", enabled)
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
                msg.verbose("adblock: Found adblock list: " .. filename)
                table.insert(filterfiles, filename)
            end
        end
    end
    
    if table.maxn(filterfiles) < 1 then
        simple_mode = true
        filterfiles = { "/easylist.txt" }
    end
    
    if not simple_mode then
        msg.info( "adblock: Found " .. table.maxn(filterfiles) .. " rules lists." )
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
        -- If this is matchable as a plain string, return early
        local has_star = string.find(s, "*", 1, true)
        local has_caret = string.find(s, "^", 1, true)
        local domain_anchor = string.match(s, "^||")
        if not has_star and not has_caret and not domain_anchor then
            return {s}, opts, nil, true
        end

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

        if domain_anchor then
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

    return s, opts, domain, false
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

list_new = function ()
    return {
        patterns    = {},
        ad_patterns = {},
        plain       = {},
        ad_plain    = {},
        domains     = {},
        length      = 0,
        ignored     = 0,
    }
end

list_add = function(list, line, cache, pat_exclude)
    pats, opts, domain, plain = abp_to_pattern(line)
    local contains_ad = string.find(line, "ad", 1, true)

    for _, pat in ipairs(pats) do
        local new
        if plain then
            local bucket = contains_ad and list.ad_plain or list.plain
            new = add_unique_cached(pat, opts, bucket, cache)
        elseif pat ~= "^http:" and pat ~= pat_exclude then
            if domain then
                if not list.domains[domain] then
                    list.domains[domain] = {}
                end
                new = add_unique_cached(pat, opts, list.domains[domain], cache)
            else
                local bucket = contains_ad and list.ad_patterns or list.patterns
                new = add_unique_cached(pat, opts, bucket, cache)
            end
        end
        if new then
            list.length = list.length + 1
        else
            list.ignored = list.ignored + 1
        end
    end
end

-- Parses an Adblock Plus compatible filter list
parse_abpfilterlist = function (filename, cache)
    if os.exists(filename) then
        msg.verbose("adblock: loading filterlist %s", filename)
    else
        msg.warn("adblock: error loading filter list (%s: No such file or directory)", filename)
    end
    --***
    --local f = io.open(filename .. "~", "w")
    --***
    local pat, opts
    local white, black = list_new(), list_new()
    for line in io.lines(filename) do
        -- Ignore comments, header and blank lines
        if line:match("^[![]") or line:match("^$") then
            -- dammitwhydoesntluahaveacontinuestatement
        -- Ignore element hiding
        elseif line:match("#") then
            --icnt = icnt + 1
        elseif line:match("^@@") then
            list_add(white, string.sub(line, 3), cache.white)
        else
            list_add(black, line, cache.black, ".*")
        end
    end

    local wlen, blen, icnt = white.length, black.length, white.ignored + black.ignored
    --***
    --f:close()
    --***

    return white, black, wlen, blen, icnt
end

-- Load filter list files
load = function (reload, single_list, no_sync)
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
    if not no_sync then
        adblock_wm:emit_signal("update_rules", rules)
    end
    refresh_views()
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
        adblock_wm:emit_signal("update_rules", rules)
        refresh_views()
    end
    
    list.opts = opts
    write_subscriptions()
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

function list_set_enabled(a, enabled)
    if enabled then
        list_opts_modify(tonumber(a), "Disabled", "Enabled")
    else
        list_opts_modify(tonumber(a), "Enabled", "Disabled")
    end
end

adblock_wm:add_signal("navigation-blocked", function(_, id, uri)
    for _, w in pairs(window.bywidget) do
        if w.view.id == id then
            if not w.view:emit_signal("navigation-blocked", w, uri) then
                w:error("Ad Block: page load for '" .. uri .. "' blocked")
            end
        end
    end
end)

adblock_wm:add_signal("loaded", function(_)
    adblock_wm:emit_signal("update_rules", rules)
end)

-- Add commands.
local cmd = lousy.bind.cmd
add_cmds({
    cmd({"adblock-reload", "abr"}, function (w)
        info("adblock: Reloading filters.")
        load(true)
        info("adblock: Reloading filters complete.")
    end),
    
    cmd({"adblock-list-enable", "able"}, function (w, a)
        list_set_enabled(a, true)
    end),
    
    cmd({"adblock-list-disable", "abld"}, function (w, a)
        list_set_enabled(a, false)
    end),
    cmd({"adblock-enable", "abe"}, function (w)
    enable()
    end),
    
    cmd({"adblock-disable", "abd"}, function (w)
    disable()
    end),
})

-- Initialise module
load(nil, nil, true)
