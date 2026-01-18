-- Customize how single images are displayed in the browser.
--
-- @submodule image_css
-- @copyright 2017 Aidan Holm <aidanholm@gmail.com>

local ui = ipc_channel("image_css_wm")

local recalc_funcs = setmetatable({}, { __mode = "k" })

ui:add_signal("image", function (_, page)
    -- Use JavaScript to check if document has a body and an image
    local has_image = page:eval_js([[
        (function() {
            var body = document.body;
            if (!body) return false;
            var img = body.querySelector('img');
            return img !== null;
        })()
    ]])

    if not has_image then return end

    -- Inject JavaScript function to handle vertical overflow calculation
    page:eval_js([[
        (function() {
            var body = document.body;
            var img = body.querySelector('img');
            if (!img) return;

            // Define recalculation function in page scope
            window.luakit_recalc_image_overflow = function() {
                var body_height = body.getBoundingClientRect().height;
                var img_height = img.getBoundingClientRect().height;
                var vert_overflow = img_height > body_height;
                img.className = vert_overflow ? 'verticalOverflow' : '';
            };

            // Attach click handler to recalculate on click
            img.addEventListener('click', window.luakit_recalc_image_overflow);

            // Initial calculation
            window.luakit_recalc_image_overflow();
        })()
    ]])

    -- Create Lua function that triggers JavaScript recalculation
    recalc_funcs[page] = function ()
        page:eval_js('window.luakit_recalc_image_overflow && window.luakit_recalc_image_overflow()')
    end

    -- Note: We don't need explicit cleanup since the page destruction
    -- will automatically clear the weak reference table entry
end)

ui:add_signal("recalc", function (_, page)
    return recalc_funcs[page] and recalc_funcs[page]()
end)

-- vim: et:sw=4:ts=8:sts=4:tw=80
