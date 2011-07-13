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
local print, type = print, type
local pairs, ipairs = pairs, ipairs
local tostring = tostring
local capi = {
    luakit = luakit
}

local new_mode, add_binds = new_mode, add_binds
local menu_binds = menu_binds

local term       = globals.term   or "xterm"
local editor     = globals.editor or (os.getenv("EDITOR") or "vim")
local editor_cmd = string.format("%s -e %s", term, editor)

--- Provides functionaliy to auto-fill forms based on a Lua DSL
module("formfiller")

-- The formfiller rules.
-- Basically a table of functions that either return nil to indicate
-- that the rule doesn't match or another table of functions (sub-rules)
-- that must be evaluated.
local rules = {}

-- The menu cache that stores menu entries while evaluating.
local menu_cache = {}

-- The Lua DSL file containing the formfiller rules
local file = capi.luakit.data_dir .. "/formfiller.lua"

-- The global formfiller JS code
local formfiller_js = [=[
    formfiller = {
        toA: function (arr) {
            return Array.prototype.slice.call(arr);
        },
        rexEscape: function (str) {
            return str.replace(/[-[\]{}()*+?.,\\^$|#]/g, "\\$&");
        },
        toLuaString: function (str) {
            return "'" + str.replace(/[\\'']/g, "\\$&") + "'";
        },
        forms: [],
        inputs: [],
        AttributeMatcher: function (tag, attrs, parents) {
            parents = parents || [document];
            var keys = []
            for (var k in attrs) {
                keys.push(k);
            }
            this.getAll = function () {
                var elements = [];
                parents.forEach(function (p) {
                    formfiller.toA(p.getElementsByTagName(tag)).filter(function (element) {
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

-- DSL helper method.
-- Invokes an AttributeMatcher for the given tag and attributes with the
-- given data on the given parents.
local function match(w, tag, attributes, data, parents)
    local js_template = [=[
        var matcher = new formfiller.AttributeMatcher("{tag}", {
            {attrs}
        }, {parents});
        var elements = matcher.getAll();
        formfiller.{tag}s = elements;
        (elements.length > 0);
    ]=]
    -- ensure all attributes are there
    local attrs = ""
    for _, k in ipairs(attributes) do
        if data[k] then
            attrs = attrs .. string.format("%s: %q, ", k, data[k])
        end
    end
    local js = string.gsub(js_template, "{(%w+)}", {
        attrs = attrs,
        tag = tag,
        parents = parents and string.format("formfiller.%s", parents) or "null",
    })
    local ret = w:eval_js(js, "(formfiller.lua)")
    if ret == "true" then
        local t = lousy.util.table.toarray(data)
        return #t == 0 and true or t
    else
        return nil
    end
end

-- The function environment for the formfiller script
local DSL = {
    print = print,

    -- DSL method to match a page by it's URI
    on = function (pattern)
        return function (data)
            table.insert(rules, function (w, v)
                -- show menu if necessary
                if #(menu_cache) == 0 then
                    -- continue matching
                    return {}
                elseif #(menu_cache) == 1 then
                    -- evaluate that cache function
                    return {menu_cache[1].fun}
                else
                    -- show menu
                    w:set_mode("formfiller")
                    -- suspend evaluation
                    return false
                end
            end)
            table.insert(rules, function (w, v)
                -- match page URI in JS so we don't mix JS and Lua regexes in the formfiller config
                local js_template = [=[
                    (new RegExp({pattern}).test(location.href));
                ]=]
                local js = string.gsub(js_template, "{(%w+)}", {
                    pattern = string.format("%q", pattern)
                })
                local ret = w:eval_js(js, "(formfiller.lua)")
                if ret == "true" then
                    return data
                else
                    return nil
                end
            end)
        end
    end,

    -- DSL method to match a form by it's attributes
    form = function (data)
        if type(data) == "string" then
            -- add a menu entry for the profile
            local profile = data
            return function (data)
                table.insert(menu_cache, {
                    profile,
                    fun = function (w, v)
                        return match(w, "form", {"method", "name", "id", "action", "className"}, data)
                    end,
                })
                -- continue matching
                return {}
            end
        else
            -- return a form matcher
            return function (w, v)
                return match(w, "form", {"method", "name", "id", "action", "className"}, data)
            end
        end
    end,

    -- DSL method to match an input element by it's attributes
    input = function (data)
        return function (w, v)
            return match(w, "input", {"name", "id", "className", "type"}, data, "forms")
        end
    end,

    -- DSL method to fill an input element
    fill = function (str)
        return function (w, v)
            local js_template = [=[
                if (formfiller.inputs) {
                    var val = {str};
                    formfiller.inputs.forEach(function (i) {
                        if (i.type === "radio" || i.type === "checkbox") {
                            i.checked = (val && val !== "false");
                        } else {
                            i.value = val;
                        }
                    });
                }
            ]=]
            local js = string.gsub(js_template, "{(%w+)}", {
                str = string.format("%q", tostring(str))
            })
            w:eval_js(js, "(formfiller.lua)")
            return {}
        end
    end,

    -- DSL method to submit a form
    submit = function ()
        return function (w, v)
            local js = [=[
                if (formfiller.forms && formfiller.forms[0]) {
                    formfiller.forms[0].submit();
                }
            ]=]
            w:eval_js(js, "(formfiller.lua)")
            -- abort after a form has been submitted (page will reload!)
            return nil
        end
    end,
}

--- Reads the rules from the formfiller DSL file
function init()
    -- reset variables
    menu_cache = {}
    -- the environment of the DSL script
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
    setfenv(dsl, DSL)
    local success, err = pcall(dsl)
    if not success then
        warn("error in " .. file .. ": " .. err)
    end
    -- ensure we only have functions on the rule stack
    for i,f in pairs(rules) do
        if type(f) ~= "function" then
            warn("formfiller: rule stack contains non-function at index " .. i)
            rules = {}
        end
    end
end

--- Edits the formfiller rules.
function edit(w)
    capi.luakit.spawn(string.format("%s %q", editor_cmd, file))
end

--- Adds a new entry to the formfiller based on the current webpage.
function add(w)
    -- load JS prerequisites
    w:eval_js(formfiller_js, "(formfiller.lua)")
    local js = [=[
        var addAttr = function (str, elem, attr, indent) {
            if (elem[attr]) {
                str += indent + attr + ' = ' + formfiller.toLuaString(formfiller.rexEscape(elem[attr])) + ',\n';
            }
            return str;
        }

        var str = 'on ' + formfiller.toLuaString(formfiller.rexEscape(location.href)) + ' {\n';
        formfiller.toA(document.forms).forEach(function (form) {
            str += "  form {\n";
            ["method", "action", "id", "className", "name"].forEach(function (attr) {
                str = addAttr(str, form, attr, "    ");
            });
            formfiller.toA(form.getElementsByTagName("input")).forEach(function (input) {
                if (input.type === "button" || input.type === "submit" || input.type === "hidden") {
                    return;
                }
                str += "    input {\n";
                ["id", "className", "name", "type"].forEach(function (attr) {
                    str = addAttr(str, input, attr, "      ");
                });
                if (input.type === "radio" || input.type === "checkbox") {
                    str += "      fill(" + input.checked + "),\n";
                } else {
                    str += "      fill(" + formfiller.toLuaString(input.value) + "),\n";
                }
                str += "    },\n";
            });
            str += "  },\n";
        });
        str += "}\n\n";
    ]=]
    local ret = w:eval_js(js, "(formfiller.lua)")
    local f = io.open(file, "a")
    f:write(ret)
    f:close()
    edit()
end

--- Fills the current page from the formfiller rules.
-- @param w The window on which to fill the forms
-- @param skip_init Prevents re-initialization of the window
function load(w, skip_init)
    if not skip_init then
        -- reload the DSL
        init()
        -- load JS prerequisites
        w:eval_js(formfiller_js, "(formfiller.lua)")
    end
    -- the function stack. pushed functions are evaluated until there is none
    -- left or one of them returns false
    while #rules > 0 do
        local fun = table.remove(rules)
        local ret = fun(w, w:get_current())
        if ret then
            ret = lousy.util.table.reverse(ret)
            for _,f in ipairs(ret) do
                if type(f) == "function" then
                    table.insert(rules, f)
                end
            end
        else
            break
        end
    end
end

-- Add formfiller mode
new_mode("formfiller", {
    enter = function (w)
        local rows = {{ "Profile", title = true }}
        for _, m in ipairs(menu_cache) do
            table.insert(rows, m)
        end
        w.menu:build(rows)
    end,

    leave = function (w)
        w.menu:hide()
    end,
})

local key = lousy.bind.key
add_binds("formfiller", lousy.util.table.join({
    -- use profile
    key({}, "Return", function (w)
        local row = w.menu:get()
        table.insert(rules, row.fun)
        w:set_mode()
        load(w, true)
    end),
}, menu_binds))

-- Setup formfiller binds
local buf = lousy.bind.buf
add_binds("normal", {
    buf("^za$", function (w) add(w)  end),
    buf("^ze$", function (w) edit(w) end),
    buf("^zl$", function (w) load(w) end),
})

