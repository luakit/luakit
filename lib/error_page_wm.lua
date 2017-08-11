-- Error pages - web module.
--
-- @submodule error_page
-- @copyright 2016 Aidan Holm <aidanholm@gmail.com>

local ui = ipc_channel("error_page_wm")

ui:add_signal("listen", function(_, page)
    local doc = page.document
    for i, elem in ipairs(doc.body:query("input[type=button]")) do
        elem:add_event_listener("click", true, function (_)
            ui:emit_signal("click", page.id, i)
        end)
    end
end)

-- vim: et:sw=4:ts=8:sts=4:tw=80
