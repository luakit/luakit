local pairs, ipairs = pairs, ipairs
local table, string = table, string
local assert, type = assert, type
local floor = math.floor
local rawset, rawget = rawset, rawget
local ui_process = ui_process
local dom_document = dom_document

module("follow_webmodule")

local ui = ui_process()

-- Label making

-- Calculates the minimum number of characters needed in a hint given a
-- charset of a certain length (I.e. the base)
local function max_hint_len(size, base)
    local floor, len = floor, 0
    while size > 0 do size, len = floor(size / base), len + 1 end
    return len
end

local function charset(seq, size)
    local floor, sub, reverse = floor, string.sub, string.reverse
    local insert, concat = table.insert, table.concat

    local base, digits, labels = #seq, {}, {}
    for i = 1, base do rawset(digits, i, sub(seq, i, i)) end

    local maxlen = max_hint_len(size, base)
    local zeroseq = string.rep(rawget(digits, 1), maxlen)

    for n = 1, size do
        local t, i, j, d = {}, 1, n
        repeat
            d, n = (n % base) + 1, floor(n / base)
            rawset(t, i, rawget(digits, d))
            i = i + 1
        until n == 0

        rawset(labels, j, sub(zeroseq, 1, maxlen - i + 1)
            .. reverse(concat(t, "")))
    end
    return labels
end

-- Different hint label styles
label_styles = {
    charset = function (seq)
        assert(type(seq) == "string" and #seq > 0, "invalid sequence")
        return function (size) return charset(seq, size) end
    end,

    numbers = function ()
        return function (size) return charset("0123456789", size) end
    end,

    -- Chainable style: sorts labels
    sort = function (make_labels)
        return function (size)
            local labels = make_labels(size)
            table.sort(labels)
            return labels
        end
    end,

    -- Chainable style: reverses label strings
    reverse = function (make_labels)
        return function (size)
            local rawset, rawget, reverse = rawset, rawget, string.reverse
            local labels = make_labels(size)
            for i = 1, #labels do
                rawset(labels, i, reverse(rawget(labels, i)))
            end
            return labels
        end
    end,
}

-- Default follow style
local s = label_styles
local label_maker = s.sort(s.reverse(s.numbers()))

evaluators = {
    click = function(element)
        local tag = element.tag_name
        if tag == "INPUT" or tag == "TEXTAREA" then
            local t = element.attr.type
            if t == "radio" or t == "checkbox" then
                element.attr.checked = "checked"
            elseif t == "submit" or t == "reset" or t == "button" then
                element:click()
            else
                element:focus()
                return "form-active"
            end
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

local function bounding_boxes_intersect(a, b)
    if a.x + a.w < b.x then return false end
    if b.x + b.w < a.x then return false end
    if a.y + a.h < b.y then return false end
    if b.y + b.h < a.y then return false end
    return true
end

local function get_element_bb_if_visible(element, wbb)
    -- Find the element bounding box
    local r = element.rect
    local rbb = {
        x = wbb.x + r.left,
        y = wbb.y + r.top,
        w = r.width,
        h = r.height,
    }

    if rbb.w == 0 or rbb.h == 0 then return nil end

    local style = element.style
    local display = style.display
    local visibility = style.visibility

    if display == 'none' or visibility == 'hidden' then return nil end

    -- Clip bounding box!
    if display == "inline" then
        local parent = element.parent
        local pd = parent.style.display
        if pd == "block" or pd == "inline-block" then
            local w = parent.rect.width
            w = w - (r.left - parent.rect.left)
            if rbb.w > w then rbb.w = w end
        end
    end

    if not bounding_boxes_intersect(wbb, rbb) then return nil end

    return rbb
end

local function frame_find_hints(frame, selector)
    local hints = {}
    local elements = frame.body:query(selector)

    -- Find the visible bounding box
    local w = frame.doc.window
    local wbb = {
        x = w.scroll_x,
        y = w.scroll_y,
        w = w.inner_width,
        h = w.inner_height,
    }

    for _, element in ipairs(elements) do
        local rbb = get_element_bb_if_visible(element,wbb)

        if rbb then
            local text = element.text_content
            if text == "" then text = element.value or "" end
            hints[#hints+1] = { elem = element, bb = rbb, text = text }
        end
    end

    return hints
end

local function sort_hints_top_left(a, b)
    local dtop = a.bb.y - b.bb.y
    if dtop ~= 0 then
        return dtop < 0
    else
        return a.bb.x - b.bb.x < 0
    end
end

local function make_labels(num)
    return label_maker(num)
end

local function find_frames(root_frame)
    local subframes = root_frame.body:query("frame, iframe")
    local frames = { root_frame }

    -- For each frame/iframe element, recurse
    for _, frame in ipairs(subframes) do
        local f = { doc = frame.document, body = frame.document.body }
        local s = find_frames(f)
        for _, sf in ipairs(s) do
            frames[#frames + 1] = sf
        end
    end

    return frames
end

local window_states = {}

local function init_frame(frame, stylesheet)
    assert(frame.doc)
    assert(frame.body)

    frame.overlay = frame.doc:create_element("div", { id = "luakit_follow_overlay" })
    frame.stylesheet = frame.doc:create_element("style", { id = "luakit_follow_stylesheet" }, stylesheet)

    frame.body:append(frame.overlay)
    frame.body:append(frame.stylesheet)
end

local function cleanup_frame(frame)
    frame.overlay:remove()
    frame.stylesheet:remove()
    frame.overlay = nil
    frame.stylesheet = nil
end

local function hint_matches(hint, hint_pat, text_pat)
    if hint_pat ~= nil and string.find(hint.label, hint_pat) then return true end
    if text_pat ~= nil and string.find(hint.text, text_pat) then return true end
    return false
end

local function filter(state, hint_pat, text_pat)
    state.num_visible_hints = 0
    for _, hint in pairs(state.hints) do
        local old_hidden = hint.hidden
        hint.hidden = not hint_matches(hint, hint_pat, text_pat)

        if not hint.hidden then
            state.num_visible_hints = state.num_visible_hints + 1
        end

        if not old_hidden and hint.hidden then
            -- Save old style, set new style to "display: none"
            hint.overlay_style = hint.overlay_elem.attr.style
            hint.label_style = hint.label_elem.attr.style
            hint.overlay_elem.attr.style = "display: none;"
            hint.label_elem.attr.style = "display: none;"
        elseif old_hidden and not hint.hidden then
            -- Restore saved style
            hint.overlay_elem.attr.style = hint.overlay_style
            hint.label_elem.attr.style = hint.label_style
        end
    end
    ui:emit_signal("matches", state.wid, state.num_visible_hints)
end

local function focus(state, step)
    local last = state.focused
    local index

    local function sign(n) return n > 0 and 1 or n < 0 and -1 or 0 end

    if state.num_visible_hints == 0 then return end

    -- Advance index to the first non-hidden item
    if step == 0 then
        index = last and last or 1
        while state.hints[index].hidden do
            index = index + 1
            if index > #state.hints then index = 1 end
        end
        if index == last then return end
    end

    -- Which hint to focus?
    if step ~= 0 and last then
        index = last
        while step ~= 0 do
            repeat
                index = index + sign(step)
                if index < 1 then index = #state.hints end
                if index > #state.hints then index = 1 end
            until not state.hints[index].hidden
            step = step - sign(step)
        end
    end

    assert(index ~= last)

    local new_hint = state.hints[index]

    -- Save and update class for the new hint
    new_hint.orig_class = new_hint.overlay_elem.attr.class
    new_hint.overlay_elem.attr.class = new_hint.orig_class .. " hint_selected"

    -- Restore the original class for the old hint
    if last then
        local old_hint = state.hints[last]
        old_hint.overlay_elem.attr.class = old_hint.orig_class
        old_hint.orig_class = nil
    end

    state.focused = index
end

ui:add_signal("focus", function(_, wid, step)
    local state = window_states[wid]
    focus(state, step)
end)

local function leave(_, wid)
    local state = window_states[wid]
    for _, frame in ipairs(state.frames) do
        cleanup_frame(frame)
    end
    window_states[wid] = nil
end

local function follow_hint(state, hint)
    local evaluator = evaluators[state.evaluator]
    local ret = evaluator(hint.elem)
    ui:emit_signal("follow_func", state.wid, ret)
end

local function follow(state, all)
    if all then
        for _, hint in pairs(state.hints) do
            if not hint.hidden then
                follow_hint(state, hint)
            end
        end
    else
        local hint = state.hints[state.focused]
        assert(not hint.hidden)
        follow_hint(state, hint)
    end
    ui:emit_signal("follow", state.wid)
end

ui:add_signal("follow", function(_, wid, all)
    local state = window_states[wid]
    follow(state, all)
end)

ui:add_signal("enter", function(_, wid, mode, page_id, ignore_case)
    local root = dom_document(page_id)
    local root_frame = { doc = root, body = root.body }

    local state = {}

    state.wid = wid
    state.frames = find_frames(root_frame)
    state.evaluator = mode.evaluator
    state.focused = nil
    state.hints = {}
    state.ignore_case = ignore_case or false

    -- Find all hints in the viewport
    for i, frame in ipairs(state.frames) do
        -- Set up the frame, and find hints
        init_frame(frame, mode.stylesheet)
        frame.hints = frame_find_hints(frame, mode.selector)
        -- Build an array of all hints
        for _, hint in ipairs(frame.hints) do
            state.hints[#state.hints+1] = hint
        end
    end

    -- Sort them by on-screen position, and assign labels
    local labels = make_labels(#state.hints)
    assert(#state.hints == #labels)

    table.sort(state.hints, sort_hints_top_left)

    for i, hint in ipairs(state.hints) do
        hint.label = labels[i]
    end

    for _, frame in ipairs(state.frames) do
        for i, hint in ipairs(frame.hints) do
            -- Append hint elements to overlay
            local e = hint.elem
            local r = hint.bb

            local overlay_style = string.format("left: %dpx; top: %dpx; width: %dpx; height: %dpx;", r.x, r.y, r.w, r.h)
            local label_style = string.format("left: %dpx; top: %dpx;", r.x-10, r.y-10, r.w, r.h)

            hint.overlay_elem = frame.doc:create_element("span", {class = "hint_overlay hint_overlay_" .. e.tag_name, style = overlay_style})
            hint.label_elem = frame.doc:create_element("span", {class = "hint_label hint_label_" .. e.tag_name, style = label_style}, hint.label)

            frame.overlay:append(hint.overlay_elem)
            frame.overlay:append(hint.label_elem)
        end
    end

    filter(state, "", "")
    focus(state, 0)
    window_states[wid] = state
end)

ui:add_signal("changed", function(_, wid, hint_pat, text_pat, text)
    local state = window_states[wid]
    if state.ignore_case then
        local convert = function(pat)
            local converter = function (ch) return '[' .. string.upper(ch) .. string.lower(ch) .. ']' end
            return string.gsub(pat, '(%a)', converter)
        end
        hint_pat = convert(hint_pat)
        text_pat = convert(text_pat)
    end

    filter(state, hint_pat, text_pat)
    focus(state, 0)

    if state.num_visible_hints == 1 and text ~= "" then
        follow(state, false)
    end
end)

ui:add_signal("leave", leave)
