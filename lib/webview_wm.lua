-- Webview widget wrapper - web module.
--
-- The webview module wraps the webview widget provided by luakit, adding
-- several convenience APIs and providing basic functionality.
--
-- @submodule webview
-- @copyright 2017 Aidan Holm <aidanholm@gmail.com>
-- @copyright 2012 Mason Larobina <mason.larobina@gmail.com>

local ui = ipc_channel("webview_wm")

ui:add_signal("load-finished", function(_, page)
    if not page then return end

    -- Check if document has body using JavaScript
    local has_body = page:eval_js('document.body !== null')
    if not has_body then return end

    if page.uri:find("luakit://", 1, true) == 1 then
        -- Register callback for file:// link navigation
        page:register_js_callback("luakit_navigate_file_link", function(href)
            ui:emit_signal("navigate", page.id, href)
        end)

        -- Use JavaScript to handle click events on file:// links
        page:eval_js([[
            (function() {
                document.body.addEventListener('click', function(event) {
                    // Only handle left-click (button 0)
                    if (event.button !== 0) return;

                    // Check if clicked element is an anchor tag
                    if (event.target.tagName !== 'A') return;

                    // Get href attribute
                    var href = event.target.getAttribute('href') || '';

                    // Check if it's a file:// link
                    if (href.indexOf('file://') !== 0) return;

                    // Call Lua callback to handle navigation
                    luakit_navigate_file_link(href);
                });
            })();
        ]])
    end

end)

-- vim: et:sw=4:ts=8:sts=4:tw=80
