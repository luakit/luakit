-- Error pages - web module.
--
-- @submodule error_page
-- @copyright 2016 Aidan Holm <aidanholm@gmail.com>

local ui = ipc_channel("error_page_wm")

ui:add_signal("listen", function(_, page)
    -- Register Lua callback that JavaScript can call
    page:register_js_callback("luakit_error_page_button_click", function(button_index)
        ui:emit_signal("click", page.id, button_index)
    end)

    -- Use JavaScript to attach event listeners (no WebKitDOM API needed)
    page:eval_js([[
        (function() {
            var buttons = document.querySelectorAll('input[type=button]');
            buttons.forEach(function(btn, index) {
                btn.addEventListener('click', function() {
                    // Call the Lua callback we registered
                    luakit_error_page_button_click(index + 1); // Lua uses 1-based indexing
                });
            });
        })();
    ]])
end)

-- vim: et:sw=4:ts=8:sts=4:tw=80
