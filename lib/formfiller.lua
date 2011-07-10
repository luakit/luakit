-----------------------------------------------------------------
-- Luakit formfiller                                           --
-- © 2011 Fabian Streitel (karottenreibe) <k@rottenrei.be>     --
-- © 2011 Mason Larobina  (mason-l) <mason.larobina@gmail.com> --
-----------------------------------------------------------------

local lousy = require("lousy")
local string, table, io = string, table, io
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
        inputs = [],
        input = null,
        AttributeMatcher: function (tag, attrs, parents) {
            parents = parents || [document];
            var toA = function (arr) {
                return Array.prototype.slice.call(arr);
            };
            var keys = []
            for (var k in attrs) {
                keys.push(k);
            }
            this.getAll = function () {
                var elements = [];
                parents.forEach(function (p) {
                    toA(p.getElementsByTagName(tag)).filter(function (element) {
                        return keys.every(function (key) {
                            return new RegExp(attrs[key]).test(element[key]);
                        });
                    }).forEach(function (e) {
                        elements.push(e);
                    });
                });
                return elements;
            };
        },
    }
]=]

-- DSL method to match a page by it's URI
local function on(pattern)
    return function (data)
        table.insert(rules, function (w, v)
            if string.match(v.uri, pattern) then
                return data
            else
                return nil
            end
        end)
    end
end

-- Invokes an AttributeMatcher for the given tag and attributes with the
-- given data on the given parents.
local function match(tag, attributes, data, parents)
    local js_template = [=[
        var matcher = new formfiller.AttributeMatcher("{tag}", {
            {attrs}
        }, {parents});
        var elements = matcher.getAll();
        formfiller.{tag}s = elements;
        return elements.length > 0;
    ]=]
    -- ensure all attributes are there
    local attrs = ""
    for _, k in ipairs(attributes) do
        if data[k] then
            attrs = attrs .. string.format("%s: %q, ", k, data[k])
        end
    end
    local js = string.gsub(html_template, "{(%w+)}", {
        attrs = attrs,
        tag = tag,
        parents = parents and string.format("formfiller.%s", parents) or "null",
    })
    local ret = w:eval_js(js, "(formfiller.lua)")
    if ret == "true" then
        local t = lousy.util.table.toarray(data)
        return #t == 0 and true or t
    else
        return false
    end
end

-- DSL method to match a form by it's attributes
local function form(data)
    return function (w, v)
        return match("form", {"method", "name", "id", "action", "className"}, data)
    end
end

-- DSL method to match an input element by it's attributes
local function input(table)
    return function (w, v)
        return match("input", {"name", "id", "className"}, data, "forms")
    end
end

-- DSL method to fill an input element
local function fill(str)
    return function (w, v)
        local js_template = [=[
            if (formfiller.inputs) {
                formfiller.inputs.forEach(function (i) {
                    i.value = {str};
                });
            }
        ]=]
        local js = string.gsub(html_template, "{(%w+)}", {
            str = string.format("%q", str)
        })
        w:eval_js(js, "(formfiller.lua)")
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
        input = input,
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

