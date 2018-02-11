-- Customize how single images are displayed in the browser.
--
-- @submodule image_css
-- @copyright 2017 Aidan Holm <aidanholm@gmail.com>

local ui = ipc_channel("image_css_wm")

local recalc_funcs = setmetatable({}, { __mode = "k" })

ui:add_signal("image", function (_, page)
    local body = page.document.body

    -- do nothing if loaded document is not HTML
    if not body then return end

    local img = body:query("img")[1]
    if not img then return end

    recalc_funcs[page] = function ()
        local body_height = body.rect.height
        local img_height = img.rect.height
        local vert_overflow = img_height > body_height
        img.attr.class = vert_overflow and "verticalOverflow" or ""
    end

    img:add_signal("destroy", function ()
        recalc_funcs[page] = nil
    end)

    img:add_event_listener("click", true, recalc_funcs[page])
end)

ui:add_signal("recalc", function (_, page)
    return recalc_funcs[page] and recalc_funcs[page]();
end)

-- vim: et:sw=4:ts=8:sts=4:tw=80
