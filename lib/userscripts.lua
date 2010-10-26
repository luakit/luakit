---------------------------------------------------------
-- Userscript support for luakit                       --
-- (C) 2010 Fabian Streitel <karottenreibe@gmail.com>  --
-- (C) 2010 Mason Larobina  <mason.larobina@gmail.com> --
---------------------------------------------------------

-- Grab environment we need
local io = io
local ipairs = ipairs
local os = os
local pairs = pairs
local setmetatable = setmetatable
local string = string
local table = table
local webview = webview
local util = require("lousy.util")
local lfs = require("lfs")
local capi = { luakit = luakit }

local warn = function (fmt, ...)
    io.stderr:write(string.format("(userscripts.lua): "..fmt.."\n", ...))
end

--- Evaluates and manages userscripts.
-- JavaScript userscripts must end in <code>.user.js</code>
module("userscripts")

--- Stores all the scripts.
local scripts = {}

--- The directory, in which to search for userscripts.
-- By default, this is $XDG_DATA_HOME/luakit/scripts
dir = capi.luakit.data_dir .. "/scripts"

-- Userscript class methods
local prototype = {
    -- Run the userscript on the given webview widget
    run = function (s, view)
        view:eval_js(s.js, string.format("(userscript:%s)", s.file))
    end,
    -- Check if the given uri matches the userscripts include/exclude patterns
    match = function (s, uri)
        local matches = false
        for _, p in ipairs(s.include) do
            if string.match(uri, p) then
                matches = true
                break
            end
        end
        if matches then
            for _, p in ipairs(s.exclude) do
                if string.match(uri, p) then return false end
            end
        end
        return matches
    end,
}

-- Parse and convert a simple glob matching pattern in the `@include`,
-- `@exclude` or `@match` userscript header options into an RE.
local function parse_pattern(pat)
    pat = string.gsub(string.gsub(pat, "[%^%$%(%)%%%.%[%]%+%-%?]", "%%%1"), "*", ".*")
    return '^' .. pat .. '$'
end

local function parse_header(header, file)
    local ret = { file = file, include = {}, exclude = {} }
    for i, line in ipairs(util.string.split(header, "\n")) do
        -- Parse `// @key value` line in header.
        local key, val = string.match(line, "^// @([%w%-]+)%s+(.+)$")
        if key then
            val = util.string.strip(val or "")
            -- Populate header table
            if key == "name" or key == "description" or key == "version" then
                -- Only grab the first of its kind
                if not ret[key] then ret[key] = val end
            elseif key == "include" or key == "exclude" then
                table.insert(ret[key], parse_pattern(val))
            elseif key == "run-at" and val == "document-start" then
                ret.on_start = true
            end
        else
            warn("Invalid line in header: %s:%d:%s", file, i, line)
        end
    end
    return ret
end

--- Loads a js userscript.
local function load_js(file)
    -- Open script
    local f = io.open(file, "r")
    local js = f:read("*all")
    f:close()

    -- Inspect userscript header
    local header = string.match(js, "^//%s*==UserScript==%s*\n(.*)\n//%s*==/UserScript==")
    if header then
        local script = parse_header(header, file)
        script.js = js
        scripts[file] = setmetatable(script, { __index = prototype })
    else
        warn("Invalid userscript header in file: %s", file)
    end
end

--- Loads all userscripts from the <code>userscripts.dir</code>.
local function load_all()
    if not os.exists(dir) then return end
    for file in lfs.dir(dir) do
        if string.match(file, "%.user%.js$") then
            load_js(dir .. "/" .. file)
        end
    end
end

-- Invoke all userscripts for a given webviews current uri
local function invoke(view, on_start)
    local uri = view.uri or "about:blank"
    for _, script in pairs(scripts) do
        if on_start == script.on_start then
            if script:match(uri) then
                script:run(view)
            end
        end
    end
end

--- Hook on the webview's load-status signal to invoke the userscripts.
webview.init_funcs.userscripts = function (view, w)
    view:add_signal("load-status", function (v, status)
        if status == "first-visual" then
            invoke(v, true)
        elseif status == "finished" then
            invoke(v)
        end
    end)
end

-- Initialize the userscripts
load_all()
