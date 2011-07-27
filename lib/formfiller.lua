------------------------------------------------------------------
-- Luakit formfiller                                            --
-- © 2011 Fabian Streitel (karottenreibe) <luakit@rottenrei.be> --
-- © 2011 Mason Larobina  (mason-l) <mason.larobina@gmail.com>  --
------------------------------------------------------------------

local lousy = require("lousy")
local string, table, io = string, table, io
local loadstring, pcall = loadstring, pcall
local setfenv = setfenv
local warn = warn
local print, type = print, type
local pairs, ipairs = pairs, ipairs
local tostring, tonumber = tostring, tonumber
local capi = {
    luakit = luakit
}

local new_mode, add_binds = new_mode, add_binds
local menu_binds = menu_binds

local term       = globals.term   or "xterm"
local editor     = globals.editor or (os.getenv("EDITOR") or "vim")
local editor_cmd = string.format("%s -e %s", term, editor)

--- Provides functionaliy to auto-fill forms based on a Lua DSL.
-- The configuration is stored in $XDG_DATA_DIR/luakit/formfiller.lua
--
-- The following is an example for a formfiller definition:
--
-- <pre>
-- <br>  on "luakit.org" {
-- <br>    form "profile1" {
-- <br>      method = "post",
-- <br>      action = "/login",
-- <br>      className = "someFormClass",
-- <br>      id = "form_id",
-- <br>      input {
-- <br>        name = "username",
-- <br>        type = "text",
-- <br>        className = "someClass",
-- <br>        id = "username_field",
-- <br>        fill("myUsername"),
-- <br>      },
-- <br>      input {
-- <br>        name = "password",
-- <br>        fill("myPassword"),
-- <br>      },
-- <br>      input {
-- <br>        name = "autologin",
-- <br>        type = "checkbox",
-- <br>        fill(true),
-- <br>      },
-- <br>      submit(),
-- <br>    },
-- <br>  }
-- </pre>
--
-- <ul>
-- <li> The <code>form</code> function's string argument is optional.
--      It allows you to define multiple profiles.
-- <li> All entries are matched top to bottom, until one fully matches
--      or calls <code>submit()</code>.
-- <li> The submit function takes an optional argument that gives the
--      index of the submit button to click (starting with <code>1</code>).
--      If there is no such button (e.g. with a negative index),
--      <code>form.submit()</code> will be called instead.
-- <li> Instead of <code>submit()</code>, you can also use <code>focus()</code>
--      inside an <code>input</code> to focus that element. If <code>true</code>
--      is given as an argument to the function, the text of the input will be
--      selected.
-- <li> The string argument to the <code>on</code> function and all of
--      the attributes of the <code>form</code> and <code>input</code>
--      tables take JavaScript regular expressions.
--      BEWARE their escaping!
-- </ul>
--
-- There is a conversion script in the luakit repository that converts
-- from the old formfiller format to the new one. For more information,
-- see the converter script under <code>extras/convert_formfiller.rb</code>
--

module("formfiller")

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
        click: function (element) {
            var mouseEvent = document.createEvent("MouseEvent");
            mouseEvent.initMouseEvent("click", true, true, window, 0, 0, 0, 0, 0, false, false, false, false, 0, null);
            element.dispatchEvent(mouseEvent);
        },
        forms: [],
        inputs: [],
        AttributeMatcher: function (tag, attrs, parents) {
            var documents = formfiller.toA(window.frames).map(function (frame) {
                return frame.document;
            });
            documents.push(document);
            this.parents = parents || documents;
            var keys = []
            for (var k in attrs) {
                keys.push(k);
            }
            this.getAll = function () {
                var elements = [];
                this.parents.forEach(function (p) {
                    try {
                        formfiller.toA(p.getElementsByTagName(tag)).filter(function (element) {
                            return keys.every(function (key) {
                                return new RegExp(attrs[key]).test(element[key]);
                            });
                        }).forEach(function (e) {
                            elements.push(e);
                        });
                    } catch (e) {
                        // ignore errors, is probably cross-domain stuff
                    }
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
        return t
    else
        return {}
    end
end

-- The function environment for the formfiller script
local DSL
DSL = {
    print = print,

    -- DSL method that allows the emission of debug messages
    debug = function (message)
        return function ()
            print(message)
            return {}
        end
    end,

    -- DSL method to match a page by its URI
    on = function (rules, pattern)
        return function (data)
            table.insert(rules, 1, function (w, v)
                w.formfiller_state.menu_cache = {}
                w.formfiller_state.insert_mode = false
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
                    return {}
                end
            end)
            table.insert(rules, 1, function (w, v)
                -- show menu if necessary
                if #(w.formfiller_state.menu_cache) == 0 then
                    -- continue matching
                    return {}
                elseif #(w.formfiller_state.menu_cache) == 1 then
                    -- evaluate that cache function
                    return {w.formfiller_state.menu_cache[1].fun}
                else
                    -- show menu
                    w:set_mode("formfiller")
                    -- suspend evaluation
                    return nil
                end
            end)
            table.insert(rules, 1, function (w, v)
                if w.formfiller_state.insert_mode then
                    w:set_mode("insert")
                end
                return {}
            end)
        end
    end,

    -- DSL method to match a form by its attributes
    form = function (data)
        if type(data) == "string" then
            -- add a menu entry for the profile
            local profile = data
            return function (data)
                return function (w, v)
                    table.insert(w.formfiller_state.menu_cache, {
                        profile,
                        fun = function (w, v)
                            return match(w, "form", {"method", "name", "id", "action", "className"}, data)
                        end,
                    })
                    return {}
                end
            end
        else
            -- return a form matcher
            return function (w, v)
                return match(w, "form", {"method", "name", "id", "action", "className"}, data)
            end
        end
    end,

    -- Alternative version of the `form` method that ignores profiles
    fast_form = function (data)
        if type(data) == "string" then
            -- ignore profiles
            return DSL.fast_form
        else
            -- return a form matcher
            return function (w, v)
                return match(w, "form", {"method", "name", "id", "action", "className"}, data)
            end
        end
    end,

    -- DSL method to match an input element by its attributes
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

    -- DSL method to focus an input element
    focus = function (do_select)
        return function (w, v)
            local js = string.format([=[
                if (formfiller.inputs && formfiller.inputs[0]) {
                    formfiller.inputs[0].focus();
                    if (%s) {
                        formfiller.inputs[0].select();
                    }
                    "true";
                } else {
                    "false";
                }
            ]=], do_select and "true" or "false")
            local ret = w:eval_js(js, "(formfiller.lua)")
            w.formfiller_state.insert_mode = (ret == "true")
            return {}
        end
    end,

    -- DSL method to submit a form
    submit = function (n)
        return function (w, v)
            local js = string.format([=[
                if (formfiller.forms && formfiller.forms[0]) {
                    var inputs = formfiller.forms[0].getElementsByTagName('input');
                    inputs = formfiller.toA(inputs).filter(function (input) {
                        return /submit/i.test(input.type);
                    });
                    var n = %i - 1;
                    if (inputs[n]) {
                        formfiller.click(inputs[n]);
                    } else {
                        formfiller.forms[0].submit();
                    }
                }
            ]=], tonumber(n) or 1)
            w:eval_js(js, "(formfiller.lua)")
            -- abort after a form has been submitted (page will reload!)
            return nil
        end
    end,
}

--- Reads the rules from the formfiller DSL file
function init(w)
    w.formfiller_state = {
        rules = {},
    }
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
    local env = lousy.util.table.clone(DSL)
    -- wrap the on function so it can access the rules
    env.on = function (...) return DSL.on(w.formfiller_state.rules, ...) end
    setfenv(dsl, env)
    local success, err = pcall(dsl)
    if not success then
        warn("error in " .. file .. ": " .. err)
    end
    -- ensure we only have functions on the rule stack
    for i,f in pairs(w.formfiller_state.rules) do
        if type(f) ~= "function" then
            warn("formfiller: rule stack contains non-function at index " .. i)
            w.formfiller_state.rules = {}
        end
    end
end

--- Edits the formfiller rules.
function edit()
    capi.luakit.spawn(string.format("%s %q", editor_cmd, file))
end

--- Adds a new entry to the formfiller based on the current webpage.
-- @param w The window for which to add an entry.
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
        init(w)
        -- load JS prerequisites
        w:eval_js(formfiller_js, "(formfiller.lua)")
    end
    -- the function stack. pushed functions are evaluated until there is none
    -- left or one of them returns false
    local rules = w.formfiller_state.rules
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

--- Fills the current page from the formfiller rules, ignoring all profiles.
-- @param w The window on which to fill the forms
function load_fast(w)
    local form = DSL.form
    DSL.form = DSL.fast_form
    load(w)
    DSL.form = form
end

-- Add formfiller mode
new_mode("formfiller", {
    enter = function (w)
        local rows = {{ "Profile", title = true }}
        for _, m in ipairs(w.formfiller_state.menu_cache) do
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
        table.insert(w.formfiller_state.rules, row.fun)
        w:set_mode()
        load(w, true)
    end),
}, menu_binds))

-- Setup formfiller binds
local buf = lousy.bind.buf
add_binds("normal", {
    buf("^za$", function (w) add(w)       end),
    buf("^ze$", function (w) edit()       end),
    buf("^zl$", function (w) load_fast(w) end),
    buf("^zL$", function (w) load(w)      end),
})

