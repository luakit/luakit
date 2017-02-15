------------------------------------------------------------------
-- Luakit formfiller                                            --
-- © 2011 Fabian Streitel (karottenreibe) <luakit@rottenrei.be> --
-- © 2011 Mason Larobina  (mason-l) <mason.larobina@gmail.com>  --
------------------------------------------------------------------

local lousy = require("lousy")
local editor = require("editor")
local capi = { luakit = luakit }

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

local formfiller_wm = web_module("formfiller_webmodule")

-- The Lua DSL file containing the formfiller rules
local file = capi.luakit.data_dir .. "/forms.lua"

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

local function pattern_from_js_regex(re)
    -- TODO: This needs work
    local special = ".-+*?^$%"
    re = re:gsub("%%", "%%%%")
    for c in special:gmatch"." do
        re = re:gsub("\\%" .. c, "%%" .. c)
    end
    return re
end

--- Reads the rules from the formfiller DSL file
local function init(w)
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
        msg.warn(string.format("loading formfiller data failed: %s", message))
        return
    end
    -- execute in sandbox
    local env = {}
    -- wrap the DSL functions so they can access the state
    for k in pairs(DSL) do
        env[k] = function (...) return DSL[k](w.formfiller_state, ...) end
    end
    setfenv(dsl, env)
    local success, err = pcall(dsl)
    if not success then
        msg.warn("error in " .. file .. ": " .. err)
    end
    -- Convert JS regexes to Lua patterns
    for _, rule in ipairs(w.formfiller_state.rules) do
        rule.pattern = pattern_from_js_regex(rule.pattern)
        for _, form in ipairs(rule.forms) do
            form.action = form.action:gsub("\\", "")
        end
    end
    formfiller_wm:emit_signal(w.view, "init", w.formfiller_state)
end

--- Edits the formfiller rules.
local function edit()
    editor.edit(file)
end

--- Adds a new entry to the formfiller based on the current webpage.
-- @param w The window for which to add an entry.
local function add(w)
    -- load JS prerequisites
    local function add(_, ret)
        formfiller_wm:remove_signal("add", add)
        if not ret then
            return w:error("no forms with inputs found")
        end
        local f = io.open(file, "a")
        f:write(ret)
        f:close()
        edit()
    end

    formfiller_wm:add_signal("add", add)
    formfiller_wm:emit_signal(w.view, "add", w.view.id)
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
    if #menu == 0 then
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
local function load(w, fast)
    -- reload the DSL
    init(w)

    local function filtered(_, rules)
        local forms = {}
        for _, rule in ipairs(rules) do
            for _, form in ipairs(rule.forms) do
                table.insert(forms, form)
            end
        end
        show_menu(w, forms)
    end

    local function failed(_, msg)
        w:error(msg)
    end

    local function finished(_)
        formfiller_wm:remove_signal("filtered", filtered)
        formfiller_wm:remove_signal("failed", failed)
        formfiller_wm:remove_signal("finished", finished)
    end

    formfiller_wm:add_signal("filtered", filtered)
    formfiller_wm:add_signal("failed", failed)
    formfiller_wm:add_signal("finished", finished)
    formfiller_wm:emit_signal(w.view, "load", fast, w.view.id)
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
            formfiller_wm:emit_signal(w.view, "apply_form", form)
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
