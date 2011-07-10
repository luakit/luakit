-----------------------------------------------------------------
-- Luakit formfiller                                           --
-- © 2011 Fabian Streitel (karottenreibe) <k@rottenrei.be>     --
-- © 2011 Mason Larobina  (mason-l) <mason.larobina@gmail.com> --
-----------------------------------------------------------------

local lousy = require("lousy")
local string = string
local io = io
local loadstring, pcall = loadstring, pcall
local setfenv = setfenv
local warn = warn
local print = print
local capi = {
    luakit = luakit
}

local new_mode, add_binds = new_mode, add_binds

--- Provides functionaliy to auto-fill forms based on a Lua DSL
module("formfiller")

-- The formfiller rules.
-- Basically a table of functions that either return nil to indicate
-- that the rule doesn't match, another table of functions (sub-rules)
-- that must be evaluated or true to indicate that the rule matched.
local rules = {}

-- The Lua DSL file containing the formfiller rules
local file = capi.luakit.data_dir .. "/formfiller.lua"

-- The global formfiller JS code
local formfiller_js = [=[
    formfiller = {
        forms = [],
        input = null,
        AttributeMatcher: function (tag, attrs) {
            var toA = function (arr) {
                return Array.prototype.slice.call(arr);
            };
            var keys = []
            for (var k in attrs) {
                keys.push(k);
            }
            this.getAll = function () {
                return toA(document.getElementsByTagName(tag)).filter(function (element) {
                    return keys.every(function (key) {
                        return new RegExp(attrs[key]).test(element[key]);
                    });
                });
            };
        },
    }
]=]

-- DSL method to match a page by it's URI
local function on(pattern)
    return function (table)
        table.insert(rules, function (w, v)
            if string.match(v.uri, pattern) then
                return table
            else
                return nil
            end
        end)
    end
end

-- DSL method to match a form by it's attributes
local function form(table)
    return function (w, v)
        local js_template = [=[
            var matcher = new formfiller.AttributeMatcher("form", {
                {attrs}
            });
            var forms = matcher.getAll();
            formfiller.forms = forms;
            return forms.length > 0;
        ]=]
        -- ensure all attributes are there
        local attrs = ""
        for _, k in ipairs({"method", "name", "id", "action", "className"}) do
            if table[k] then
                attrs = attrs .. string.format("%s: %q, ", k, table[k])
            end
        end
        local js = string.gsub(html_template, "{(%w+)}", {attrs = attrs})
        local ret = w:eval_js(js, "(formfiller.lua)")
        if ret == "true" then
            local t = {}
            for _, v in ipairs(table) do
                table.insert(t, v)
            end
            return #t == 0 and true or t
        else
            return false
        end
    end
end

--
-- Reads the rules from the formfiller DSL file
function init()
    -- the environment of the DSL script
    local env = {
        print = print,
        on = on,
        form = form,
    }
    -- load the script
    local f = io.open(file, "r")
    local code = f:read("*all")
    f:close()
    local dsl, message = loadstring(code)
    if not dsl then
        warn(string.format("loading formfiller data failed: %s", message))
        return
    end
    -- execute in sandbox
    setfenv(dsl, env)
    local success, err = pcall(dsl)
    if not success then
        warn("error in " .. file .. ": " .. err)
    end
end

--- Adds a new entry to the formfiller based on the current webpage.
function add(w)
end

--- Edits the formfiller rules.
function edit(w)
end

--- Fills the current page from the formfiller rules.
function fill(w)
end


-- Initialize the formfiller
init()

-- Add formfiller mode
new_mode("formfiller", {
    leave = function (w)
        w.menu:hide()
    end,
})

-- Setup formfiller binds
local buf = lousy.bind.buf
add_binds("normal", {
    buf("^za$", add),
    buf("^ze$", edit),
    buf("^zl$", fill),
})

