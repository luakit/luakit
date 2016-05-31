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
local editor = require "editor"
local capi = {
    luakit = luakit
}
local web_module = web_module

local new_mode, add_binds = new_mode, add_binds
local menu_binds = menu_binds

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

local formfiller_wm = web_module("formfiller_webmodule")

-- The Lua DSL file containing the formfiller rules
local file = capi.luakit.data_dir .. "/forms.lua"

-- The global formfiller JS code
local formfiller_js = [=[
    var formfiller = {
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
    };
]=]

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

function pattern_from_js_regex(re)
    -- TODO: This needs work
    local special = ".-+*?^$%"
    re = re:gsub("%%", "%%%%")
    for c in special:gmatch"." do
        re = re:gsub("\\%" .. c, "%%" .. c)
    end
    return re
end

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
    -- Convert JS regexes to Lua patterns
    for _, rule in ipairs(w.formfiller_state.rules) do
        rule.pattern = pattern_from_js_regex(rule.pattern)
        for _, form in ipairs(rule.forms) do
            form.action = form.action:gsub("\\", "")
        end
    end
    formfiller_wm:emit_signal("init", w.formfiller_state)
end

--- Edits the formfiller rules.
function edit()
    editor.edit(file)
end

--- Adds a new entry to the formfiller based on the current webpage.
-- @param w The window for which to add an entry.
function add(w)
    -- load JS prerequisites
    w.view:eval_js(formfiller_js, { no_return = true })
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
    w.view:eval_js(js, { callback = function(ret)
        if not ret then
            return w:error("no forms with inputs found")
        end
        local f = io.open(file, "a")
        f:write(ret)
        f:close()
        edit()
    end})
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

--- Fills the current page from the formfiller rules.
-- @param w The window on which to fill the forms
-- @param fast Prevents any menus from being shown
function load(w, fast)
    -- reload the DSL
    init(w)

    formfiller_wm:add_signal("unimplemented", function(_)
        w:warning("unimplemented")
    end)
    formfiller_wm:emit_signal("load", fast, w.view.id)
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
    key({}, "Return", "Select formfiller profile.",
        function (w)
            local row = w.menu:get()
            local form = row.form
            w:set_mode()
            if apply_form(w, form) then return end
        end),
}, menu_binds))

-- Setup formfiller binds
local buf = lousy.bind.buf
add_binds("normal", {
    buf("^za$", "Add formfiller form.",
        function (w) add(w) end),

    buf("^ze$", "Edit formfiller forms for current domain.",
        function (w) edit() end),

    buf("^zl$", "Load formfiller form (use first profile).",
        function (w) load(w, true) end),

    buf("^zL$", "Load formfiller form.",
        function (w) load(w) end),
})
