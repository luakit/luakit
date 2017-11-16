-- Luakit formfiller - web module.
--
-- @submodule formfiller_wm
-- @copyright 2016 Aidan Holm <aidanholm@gmail.com>

local select = require("select_wm")
local lousy = require("lousy")
local ui = ipc_channel("formfiller_wm")
local filter = lousy.util.table.filter_array

local function element_attributes_match(element, attrs)
    for attr, value in pairs(attrs) do
        if not string.find(value, element.attr[attr] or "", 1, true) then
            return false
        end
    end
    return true
end

local function attribute_matches(tag, attrs, parents)
    local documents = {}
    parents = parents and parents or documents

    local elements = {}
    for _, parent in ipairs(parents) do
        local e = parent:query(tag)
        for _, element in ipairs(e) do
            if element_attributes_match(element, attrs) then
                elements[#elements+1] = element
            end
        end
    end
    return elements
end

local function match(tag, attrs, form, parents)
    assert(type(parents) == "table")

    local attr_table = {}
    for _, v in ipairs(attrs) do
        if form[v] then
            attr_table[v] = form[v]
        end
    end

    local matches = attribute_matches(tag, attr_table, parents)
    return matches
end

local function fill_input(inputs, value)
    assert(type(inputs) == "table")
    for _, input in pairs(inputs) do
        assert(type(input) == "dom_element")
        if input.type == "radio" or input.type == "checkbox" then
            -- Click the input if it isn't already in the desired state
            local checked = input.checked == "checked"
            if value and value ~= checked then
                input:click()
            end
        else
            input.value = value
        end
    end
end

local function submit_form(form, n)
    assert(type(form) == "dom_element" and form.tag_name == "FORM")
    assert(type(n) == "number")

    local submits = form:query("input[type=submit]")
    local submit = submits[n == 0 and 1 or n]
    assert(submit)

    -- Fall back to clicking if submit input has onclick handler
    if n > 0 or submit.attr.onclick then
        submit:click()
    else
        form:submit()
    end
end

local function contains(tbl, item)
    for _, v in ipairs(tbl) do
        if v == item then return true end
    end
    return false
end

local stylesheet = [===[
#luakit_select_overlay {
    position: absolute;
    left: 0;
    top: 0;
    z-index: 2147483647; /* Maximum allowable on WebKit */
}

#luakit_select_overlay .hint_overlay {
    display: block;
    position: absolute;
    background-color: #ffff99;
    border: 1px dotted #000;
    opacity: 0.3;
}

#luakit_select_overlay .hint_label {
    display: block;
    position: absolute;
    background-color: #000088;
    border: 1px dashed #000;
    color: #fff;
    font-size: 10px;
    font-family: monospace, courier, sans-serif;
    opacity: 0.4;
}

#luakit_select_overlay .hint_selected {
    background-color: #00ff00 !important;
}
]===]

local dsl_coroutines = {}

ui:add_signal("dsl_extension_reply", function(_, _, v, view_id)
    coroutine.resume(dsl_coroutines[view_id],v)
end)

local function traverse(view_id, t)
    if type(t) == "table" and t.sentinel then
        ui:emit_signal("dsl_extension_query", t.key,t.arg,view_id)
        return coroutine.yield(dsl_coroutines[view_id])
    elseif type(t) == "table" then
        for k,v in pairs(t) do t[k] = traverse(view_id, v) end
    end
    return t
end

local function apply (form, form_spec, page)
    local co = coroutine.create(function ()
        -- Map of attr -> value that form has to match
        local attrs = {}
        for _, v in ipairs({"method", "name", "id", "action", "className"}) do
            attrs[v] = traverse(page.id, form_spec[v]) -- traverse and evaluate attributes
            form_spec[v] = attrs[v] -- write them back to the form_spec
        end
        if not element_attributes_match(form, attrs) then
            return false
        end
        traverse(page.id, form_spec) -- traverse the rest of the form_spec
        for _, input_spec in ipairs(form_spec.inputs) do
            local matches = match("input", {"name", "id", "className", "type"}, input_spec, {form})
            if #matches > 0 then
                local val = input_spec.value or input_spec.checked
                if val then fill_input(matches, val) end
                if input_spec.focus then matches[1]:focus() end
                if input_spec.select then matches[1]:select() end
            end
        end
        if form_spec.submit then
            submit_form(form, type(form_spec.submit) == "number" and form_spec.submit or 0)
        end

        dsl_coroutines[page.id] = nil
        return true
    end)
    dsl_coroutines[page.id] = co
    coroutine.resume(co)
end

local function formfiller_fill (page, form, form_specs)
    assert(type(page) == "page")
    assert(type(form) == "dom_element" and form.tag_name == "FORM")

    for _, form_spec in ipairs(form_specs) do
        if apply(form, form_spec, page) then
            break
        end
    end

    ui:emit_signal("finished")
end

local function get_form_spec_matches_on_page(page, form_specs)
    assert(type(page) == "page")
    assert(type(form_specs) == "table")

    local forms = {}
    for _, form_spec in ipairs(form_specs) do
        local attrs = {"method", "name", "id", "action", "className"}
        local matches = match("form", attrs, form_spec, { page.document.body })
        for _, form in ipairs(matches) do
            forms[#forms+1] = form
        end
    end

    return forms
end

local function formfiller_fill_fast (page, form_specs)
    -- Build list of matchable form elements
    local forms = get_form_spec_matches_on_page(page, form_specs)

    if #forms == 0 then
        ui:emit_signal("failed", page.id, "page has no matchable forms")
        return
    end
    if #forms > 1 then
        ui:emit_signal("failed", page.id, "page has more than one matchable form")
        return
    end

    formfiller_fill(page, forms[1], form_specs)
end

local function formfiller_add (page, form)
    assert(type(page) == "page")
    assert(type(form) == "dom_element" and form.tag_name == "FORM")

    local function to_lua_str(str)
        return "'" .. str:gsub("([\\'])", "\\%1").. "'"
    end
    local function to_lua_pat(str)
        return to_lua_str(lousy.util.lua_escape(str))
    end

    local function add_attr(elem, attr, indent, tail)
        local a = elem.attr[attr]
        if type(a) == "string" and a ~= "" then
            return indent .. attr .. " = " .. to_lua_str(a) .. tail
        else
            return ""
        end
    end

    local inputs = filter(form:query("input"), function(_, input)
        return not contains({"button", "submit", "hidden"}, input.type)
    end)

    -- Build formfiller config for form
    local str = { "on " .. to_lua_pat(page.uri) .. " {\n"}
    table.insert(str, "  form {\n")
    for _, attr in ipairs({"method", "action", "id", "className", "name"}) do
        table.insert(str, add_attr(form, attr, "    ", ",\n"))
    end
    for _, input in ipairs(inputs) do
        table.insert(str, "    input {\n      ")
        for _, attr in ipairs({"id", "className", "name", "type"}) do
            table.insert(str, add_attr(input, attr, "", ", "))
        end
        if contains({"radio", "checkbox"}, input.type) then
            table.insert(str, "\n      checked = " .. (input.checked or "false") .. ",\n")
        else
            table.insert(str, "\n      value = " .. to_lua_str(input.value or "") .. ",\n")
        end
        table.insert(str, "    },\n")
    end
    table.insert(str, "    submit = true,\n")
    table.insert(str, "    autofill = true,\n")
    table.insert(str, "  },\n")
    table.insert(str, "}\n\n")
    str = table.concat(str)

    ui:emit_signal("add", page.id, str)
end

ui:add_signal("fill-fast", function(_, page, form_specs)
    formfiller_fill_fast(page, form_specs)
end)

ui:add_signal("apply_form", function(_, page, form)
    formfiller_fill_fast(page, {form})
end)

ui:add_signal("leave", function (_, page)
    select.leave(page)
end)

ui:add_signal("focus", function (_, page, step)
    select.focus(page, step)
end)

-- Visual formfiller add

ui:add_signal("enter", function (_, page)
    -- Filter forms to those with valid inputs
    local forms = page.document.body:query("form")
    forms = filter(forms, function(_, form)
        local inputs = form:query("input")
        inputs = filter(inputs, function(_, input)
            return not contains({"button", "submit", "hidden"}, input.type)
        end)
        return #inputs > 0
    end)
    -- Error out if there aren't any forms to add
    if #forms == 0 then
        ui:emit_signal("failed", page.id, "page has no forms that can be added")
    end
    select.enter(page, forms, stylesheet, true)
end)

ui:add_signal("changed", function (_, page, text)
    local _, num_visible_hints = select.changed(page, "^" .. text, nil, text)
    if num_visible_hints == 1 and text ~= "" then
        local hint = select.focused_hint(page)
        formfiller_add(page, hint.elem)
    end
end)

ui:add_signal("select", function (_, page)
    local hint = select.focused_hint(page)
    formfiller_add(page, hint.elem)
end)

ui:add_signal("filter", function (_, page, form_specs)
    local matching_form_specs = {}
    local roots = { page.document.body }
    for _, form_spec in ipairs(form_specs) do
        local matches = match("form", {"method", "name", "id", "action", "className"}, form_spec, roots)
        if #matches > 0 then
            matching_form_specs[#matching_form_specs+1] = form_spec
        end
    end
    ui:emit_signal("filter", page.id, matching_form_specs)
end)

-- vim: et:sw=4:ts=8:sts=4:tw=80
