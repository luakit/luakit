local pairs, ipairs = pairs, ipairs
local table, string = table, string
local assert, type = assert, type
local floor = math.floor
local rawset, rawget = rawset, rawget
local ui_process = ui_process
local dom_document = dom_document
local page = page
local extension = extension
local os = os
local socket = require "socket"

module("formfiller_webmodule")

local ui = ui_process()

local function element_attributes_match(element, attrs)
    for attr, value in pairs(attrs) do
        if not string.find(value, element.attr[attr] or "") then
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
    local attr_table = {}
    for k, v in ipairs(attrs) do
        if form[v] then
            attr_table[v] = form[v]
        end
    end
    if parents == nil then
        parents = state.documents
        state.matches = {}
    else
        parents = state.matches[parents]
    end

    local matches = attribute_matches(tag, attr_table, parents)
    state.matches[tag] = matches
    return #matches > 0
end

local function filter_list(tbl, fn)
    local ret = {}
    for k, v in ipairs(tbl) do
        if fn(v) then
            ret[#ret+1] = v
        end
    end
    return ret
end

local function filter_rules(rules, uri)
    return filter_list(rules, function(rule)
        return string.find(rule.pattern, uri)
    end)
end

local function filter_forms(forms)
    return filter_list(forms, function(form)
        return match("form", {"method", "name", "id", "action", "className"}, form, nil)
    end)
end

local function fill_input(value)
    local inputs = state.matches.input
    for _, input in pairs(inputs) do
        if input.type == "radio" or input.type == "checkbox" then
            input.checked = value and value ~= "false"
        else
            input.value = value
        end
    end
end

local function focus_input()
    local inputs = state.matches.input
    if inputs and inputs[1] then
        inputs[1]:focus()
        return true
    end
    return false
end

local function select_input()
    local inputs = state.matches.input
    if inputs and inputs[1] then
        inputs[1]:select()
        return true
    end
    return false
end

local function submit_form(n)
    local forms = state.matches.form
    if not forms or not forms[1] then
        return
    end
    local inputs = forms[1]:query("input")
    inputs = filter_list(inputs, function(input)
        return string.find(input.type, "submit")
    end)
    if n > 0 then
        inputs[n]:click()
    else
        forms[1]:submit()
    end
end

local function apply_form(form)
    local full_match = true
    for _, input in ipairs(form.inputs) do
        if match("input", {"name", "id", "className", "type"}, input, "form") then
            local val = input.value or input.checked
            if val then fill_input(val) end
            if input.focus then focus_input() end
            if input.select then select_input() end
        else
            full_match = false
        end
    end
    local s = form.submit
    if s then
        submit_form(type(s) == "number" and s or 0)
        return true
    else
        return full_match
    end
end

local function apply_forms(forms)
    for _, form in ipairs(forms) do
        if apply_form(form) then
            return
        end
    end
end

local function show_menu()
    ui:emit_signal("unimplemented")
    return true
end

local function load(fast, page_id)
    state.documents = { dom_document(page_id).body }
    local uri = page(page_id).uri
    local rules = filter_rules(state.rules, uri)
    for _, rule in ipairs(rules) do
        local forms = filter_forms(rule.forms)
        if fast or not show_menu() then
            apply_forms(forms)
        end
    end
end

ui:add_signal("init", function(_, s) state = s end)
ui:add_signal("load", function(_, f, page_id) load(f, page_id) end)
