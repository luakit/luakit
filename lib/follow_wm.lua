-- Link hinting for luakit - web module.
--
-- @submodule follow_wm
-- @copyright 2016 Aidan Holm <aidanholm@gmail.com>

local select = require("select_wm")
local lousy = require("lousy")
local ui = ipc_channel("follow_wm")

local evaluators = {
    click = function(element, page)
        local tag = element.tag_name
        if tag == "INPUT" or tag == "TEXTAREA" then
            local t = element.attr.type
            if t == "radio" or t == "checkbox" or t == "submit" or t == "reset" or t == "button" then
                element:click()
                return
            else
                element:focus()
                return "form-active"
            end
        end
        -- Handle <a target=_blank> indirectly; WebKit prevents opening a new
        -- window if not initiated by the user directly
        if tag == "A" and element.attr.target == "_blank" then
            ui:emit_signal("click_a_target_blank", page.id, element.href)
            return
        end
        -- Find the element directly in the centre of the link
        if element.child_count > 0 then
            local r = element.rect
            local doc = element.owner_document
            element = doc:element_from_point(r.left + r.width/2, r.top + r.height/2) or element
        end
        element:click()
    end,
    focus = function(element)
        element:focus()
        local tag = element.tag_name
        if tag == "INPUT" or tag == "TEXTAREA" then
            return "form-active"
        else
            return "root-active"
        end
    end,
    uri = function(element)
        return element.src or element.href
    end,
    desc = function(element)
        local attrs = element.attr
        return attrs.title or attrs.alt
    end,
    src = function(element)
        return element.src
    end,
    parent_href = function(element)
        return element.parent.href
    end,
}

local page_mode = {}

local function follow_hint(page, mode, hint)
    local evaluator
    if type(mode.evaluator) == "string" then
        evaluator = evaluators[mode.evaluator]
    elseif type(mode.evaluator) == "function" then
        evaluator = mode.evaluator
    else
        error("bad evaluator type '%s'", type(mode.evaluator))
    end

    local overlay_style = hint.overlay_elem.attr.style
    hint.overlay_elem.attr.style = "display: none;"
    local ret = evaluator(hint.elem, page)
    hint.overlay_elem.attr.style = overlay_style

    ui:emit_signal("follow_func", page.id, ret)
end

local function follow(page, all)
    -- Build array of hints to follow
    local hints = all and select.hints(page) or { select.focused_hint(page) }
    hints = lousy.util.table.filter_array(hints, function (_, hint)
        return not hint.hidden
    end)

    -- Close hint select UI first if not persisting in follow mode
    local mode = page_mode[page]
    if not mode.persist then
        select.leave(page)
        page_mode[page] = nil
    end

    -- Follow hints in idle cb to ensure select UI is closed if necessary
    luakit.idle_add(function ()
        for _, hint in pairs(hints) do
            follow_hint(page, mode, hint)
        end
    end)
end

ui:add_signal("follow", function(_, page, all)
    follow(page, all)
end)

ui:add_signal("focus", function(_, page, step)
    select.focus(page, step)
end)

ui:add_signal("enter", function(_, page, mode, ignore_case)
    page_mode[page] = mode
    select.enter(page, mode.selector, mode.stylesheet, ignore_case)

    local num_visible_hints = #(select.hints(page))
    ui:emit_signal("matches", page.id, num_visible_hints)
end)

ui:add_signal("changed", function(_, page, hint_pat, text_pat, text)
    local _, num_visible_hints = select.changed(page, hint_pat, text_pat, text)
    ui:emit_signal("matches", page.id, num_visible_hints)
    if num_visible_hints == 1 and text ~= "" then
        follow(page, false)
    end
end)

ui:add_signal("leave", function (_, page)
    if page_mode[page] then
        page_mode[page] = nil
        select.leave(page)
    end
end)

-- vim: et:sw=4:ts=8:sts=4:tw=80
