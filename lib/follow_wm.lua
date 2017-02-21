local select = require("select_wm")
local ui = ipc_channel("follow_wm")

local evaluators = {
    click = function(element)
        local tag = element.tag_name
        if tag == "INPUT" or tag == "TEXTAREA" then
            local t = element.attr.type
            if t == "radio" or t == "checkbox" or t == "submit" or t == "reset" or t == "button" then
                element:click()
            else
                element:focus()
                return "form-active"
            end
        elseif element.child_count > 0 then
            -- Find the element directly in the centre of the link,
            -- and click that
            local r = element.rect
            local doc = element.owner_document
            local mid_elem = doc:element_from_point(r.left + r.width/2, r.top + r.height/2)
            mid_elem:click()
        else
            element:click()
        end
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
        return element.parent.src
    end,
}

local page_mode = {}

local function follow_hint(page, hint)
    local evaluator = evaluators[page_mode[page].evaluator]

    local overlay_style = hint.overlay_elem.attr.style
    hint.overlay_elem.attr.style = "display: none;"
    local ret = evaluator(hint.elem)
    hint.overlay_elem.attr.style = overlay_style

    ui:emit_signal("follow_func", page.id, ret)
end

local function follow(page, all)
    local hints = select.hints(page)
    if all then
        for _, hint in pairs(hints) do
            if not hint.hidden then
                follow_hint(page, hint)
            end
        end
    else
        local hint = select.focused_hint(page)
        assert(not hint.hidden)
        follow_hint(page, hint)
    end
    ui:emit_signal("follow", page.id)
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
    page_mode[page] = nil
    select.leave(page)
end)
