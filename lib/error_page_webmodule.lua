local ui_process = ui_process
local dom_document = dom_document
local ipairs = ipairs

module("error_page_webmodule")

local ui = ui_process()

ui:add_signal("listen", function(_, page)
    local doc = dom_document(page.id)
    for i, elem in ipairs(doc.body:query("input[type=button]")) do
        elem:add_event_listener("click", true, function (_)
            ui:emit_signal("click", i)
        end)
    end
end)
