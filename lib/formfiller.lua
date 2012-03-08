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
-- The configuration is stored in $XDG_DATA_DIR/luakit/forms.lua
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
-- <br>        value = "myUsername",
-- <br>      },
-- <br>      input {
-- <br>        name = "password",
-- <br>        value = "myPassword",
-- <br>      },
-- <br>      input {
-- <br>        name = "autologin",
-- <br>        type = "checkbox",
-- <br>        checked = true,
-- <br>      },
-- <br>      submit = true,
-- <br>    },
-- <br>  }
-- </pre>
--
-- <ul>
-- <li> The <code>form</code> function's string argument is optional.
--      It allows you to define multiple profiles for use with the
--      <code>zL</code> binding.
-- <li> All entries are matched top to bottom, until one fully matches
--      or calls <code>submit()</code>.
-- <li> The <code>submit</code> attribute of a form can also be a number, which
--      gives index of the submit button to click (starting with <code>1</code>).
--      If there is no such button ore the argument is <code>true</code>,
--      <code>form.submit()</code> will be called instead.
-- <li> Instead of <code>submit</code>, you can also use <code>focus = true</code>
--      inside an <code>input</code> to focus that element or <code>select = true</code>
--      to select the text inside it.
--      <code>focus</code> will trigger input mode.
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
local file = capi.luakit.data_dir .. "/forms.lua"

-- The global formfiller JS code
local formfiller_js = [=[
    formfiller = {
        toA: function (arr) {
            var ret = [];
            for (var i = 0; i < arr.length; ++i) {
                ret.push(arr[i]);
            }
            return ret;
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

-- Invokes an AttributeMatcher for the given tag and attributes with the
-- given data on the given parents.
-- Saves all found elements in an array under formfiller.{tag}s
-- @param w The window to fill the forms on
-- @param tag The element tag name to match against
-- @param attributes The attributes to match
-- @param data The attribute data to use for matching
-- @param parents Start the search using formfiller.{parents}
-- @return true iff something matched
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
    return (ret == "true")
end

-- The function environment for the formfiller script
local DSL = {
    print = function (s, ...) print(...) end,

    -- DSL method to match a page by its URI
    on = function (s, pattern)
        return function (forms)
            table.insert(s.rules, {
                pattern = pattern,
                forms = forms,
            })
        end
    end,

    -- DSL method to match a form by its attributes
    form = function (s, data)
        local transform = function (inputs, profile)
            local form = {
                profile = profile,
                inputs = {},
            }
            for k, v in pairs(inputs) do
                if type(k) == "number" then
                    form.inputs[k] = v
                else
                    form[k] = v
                end
            end
            return form
        end
        if type(data) == "string" then
            local profile = data
            return function (inputs)
                return transform(inputs, profile)
            end
        else
            return transform(data)
        end
    end,

    -- DSL method to match an input element by its attributes
    input = function (s, attrs)
        return attrs
    end,
}

--- Reads the rules from the formfiller DSL file
function init(w)
    w.formfiller_state = {
        rules = {},
        menu_cache = {},
    }
    -- the environment of the DSL script
    -- load the script
    local f = io.open(file, "r")
    if not f then return end -- file doesn't exist
    local code = f:read("*all")
    f:close()
    local dsl, message = loadstring(code)
    if not dsl then
        warn(string.format("loading formfiller data failed: %s", message))
        return
    end
    -- execute in sandbox
    local env = {}
    -- wrap the DSL functions so they can access the state
    for k, fun in pairs(DSL) do
        env[k] = function (...) return DSL[k](w.formfiller_state, ...) end
    end
    setfenv(dsl, env)
    local success, err = pcall(dsl)
    if not success then
        warn("error in " .. file .. ": " .. err)
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
        var addAttr = function (str, elem, attr, indent, tail) {
            if (typeof(elem[attr]) == "string" && elem[attr] !== "") {
                str += indent + attr + ' = ' + formfiller.toLuaString(formfiller.rexEscape(elem[attr])) + tail;
            }
            return str;
        }

        var rendered_something = false;
        var str = 'on ' + formfiller.toLuaString(formfiller.rexEscape(location.href)) + ' {\n';
        formfiller.toA(document.forms).forEach(function (form) {
            var inputs = formfiller.toA(form.getElementsByTagName("input")).filter(function (input) {
                return (input.type !== "button" && input.type !== "submit" && input.type !== "hidden");
            });
            if (inputs.length === 0) {
                return;
            }
            str += "  form {\n";
            ["method", "action", "id", "className", "name"].forEach(function (attr) {
                str = addAttr(str, form, attr, "    ", ",\n");
            });
            inputs.forEach(function (input) {
                str += "    input {\n      ";
                ["id", "className", "name", "type"].forEach(function (attr) {
                    str = addAttr(str, input, attr, "", ", ");
                });
                if (input.type === "radio" || input.type === "checkbox") {
                    str += "\n      checked = " + input.checked + ",\n";
                } else {
                    str += "\n      value = " + formfiller.toLuaString(input.value) + ",\n";
                }
                str += "    },\n";
            });
            str += "    submit = true,\n";
            str += "  },\n";
            rendered_something = true;
        });
        str += "}\n\n";
        rendered_something ? str : false;
    ]=]
    local ret = w:eval_js(js, "(formfiller.lua)")
    if ret == "false" then return w:error("no forms with inputs found") end
    local f = io.open(file, "a")
    f:write(ret)
    f:close()
    edit()
end

-- Matches all rules against the current view's URI.
-- @param w The window on which to fill the forms
-- @param rules The rules to filter
-- @return A new table containing only the rules that matched the URI
local function filter_rules(w, rules)
    local filtered = {}
    for _, rule in ipairs(rules) do
        -- match page URI in JS so we don't mix JS and Lua regexes in the formfiller config
        local js_template = [=[
            (new RegExp({pattern}).test(location.href));
        ]=]
        local js = string.gsub(js_template, "{(%w+)}", {
            pattern = string.format("%q", rule.pattern)
        })
        local ret = w:eval_js(js, "(formfiller.lua)")
        if ret == "true" then table.insert(filtered, rule) end
    end
    return filtered
end

-- Matches all forms against the current view.
-- @param w The window on which to fill the forms
-- @param forms The forms to filter
-- @return A new table containing only the forms that matched the current view
local function filter_forms(w, forms)
    local filtered = {}
    for _, form in ipairs(forms) do
        if match(w, "form", {"method", "name", "id", "action", "className"}, form) then
            table.insert(filtered, form)
        end
    end
    return filtered
end

-- Shows a menu with all forms that contain a profile if there is more than one.
-- @param w The window on which to fill the forms
-- @param forms The forms to search for profiles
-- @return true iff the menu was shown
local function show_menu(w, forms)
    local menu = {}
    for _, form in ipairs(forms) do
        if form.profile then
            table.insert(menu, { form.profile, form = form })
        end
    end
    -- show menu if necessary
    if #menu < 2 then
        return false
    else
        w.formfiller_state.menu_cache = menu
        w:set_mode("formfiller")
        return true
    end
end

-- Fills the currently selected input with the given value
-- @param w The window on which to fill the forms
-- @param val The value to fill the input with
local function fill_input(w, val)
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
        str = string.format("%q", tostring(val))
    })
    w:eval_js(js, "(formfiller.lua)")
end

-- Focuses the currently selected input.
-- @param w The window on which to fill the forms
local function focus_input(w)
    local js = [=[
        if (formfiller.inputs && formfiller.inputs[0]) {
            formfiller.inputs[0].focus();
            "true";
        } else {
            "false";
        }
    ]=]
    local ret = w:eval_js(js, "(formfiller.lua)")
    if ret == "true" then w:set_mode("insert") end
end

-- Selects all text in the currently selected input.
-- @param w The window on which to fill the forms
local function select_input(w)
    local js = [=[
        if (formfiller.inputs && formfiller.inputs[0]) {
            formfiller.inputs[0].select();
        }
    ]=]
    local ret = w:eval_js(js, "(formfiller.lua)")
end

-- Submits the currently selected form by clicking the nth button or
-- calling form.submit().
-- @param w The window on which to fill the forms
-- @param n The index of the button to click or -1 to use form.submit()
local function submit_form(w, n)
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
    ]=], n)
    w:eval_js(js, "(formfiller.lua)")
end

-- Applies all values to all matching inputs in a form and optionally focuses and selects
-- the inputs or submits the form.
-- @param w The window on which to fill the forms
-- @returns true iff the form matched fully or was submitted
local function apply_form(w, form)
    local full_match = true
    for _, input in ipairs(form.inputs) do
        if match(w, "input", {"name", "id", "className", "type"}, input, "forms") then
            local val = input.value or input.checked
            if val then fill_input(w, val) end
            if input.focus then focus_input(w) end
            if input.select then select_input(w) end
        else
            full_match = false
        end
    end
    local s = form.submit
    if s then
        submit_form(w, type(s) == "number" and s or -1)
        return true
    else
        return full_match
    end
end

--- Fills the current page from the formfiller rules.
-- @param w The window on which to fill the forms
-- @param fast Prevents any menus from being shown
function load(w, fast)
    -- reload the DSL
    init(w)
    -- load JS prerequisites
    w:eval_js(formfiller_js, "(formfiller.lua)")
    -- filter out all rules that do not match the current URI
    local rules = filter_rules(w, w.formfiller_state.rules)
    for _, rule in ipairs(rules) do
        -- filter out all forms that do not match the current page
        local forms = filter_forms(w, rule.forms)
        -- assemble a list of menu items to display, if any exist
        if fast or not show_menu(w, forms) then
            -- apply until the first form submits
            for _, form in ipairs(forms) do
                if apply_form(w, form) then return end
            end
        end
    end
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
        local form = row.form
        w:set_mode()
        for _, f in ipairs(w.view.frames) do
            if apply_form(w, f, form) then return end
        end
    end),
}, menu_binds))

-- Setup formfiller binds
local buf = lousy.bind.buf
add_binds("normal", {
    buf("^za$", function (w) add(w)        end),
    buf("^ze$", function (w) edit()        end),
    buf("^zl$", function (w) load(w, true) end),
    buf("^zL$", function (w) load(w)       end),
})
