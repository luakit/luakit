local ui = ipc_channel("webview_wm")

local mousedown_cb = function (event, page_id)
    -- Only consider left-click
    if event.button ~= 0 then return end

    -- Only consider editable text inputs
    local elem = event.target
    local tag = elem.tag_name
    if tag ~= "INPUT" and tag ~= "TEXTAREA" then return end
    if tag == "INPUT" and (elem.attr.type or ""):lower() == "button" then return end
    if elem.attr.disabled or elem.attr.readonly then return end

    ui:emit_signal("form-active", page_id)
end

ui:add_signal("load-finished", function(_, page)
    local doc = page.document
    doc.body:add_event_listener("mousedown", true, function (e)
        mousedown_cb(e, page.id)
    end)

    if page.uri:find("luakit://", 1, true) == 1 then
        doc.body:add_event_listener("click", true, function (event)
            if event.button ~= 0 then return end
            if event.target.tag_name ~= "A" then return end
            if event.target.attr.href:find("file://", 1, true) ~= 1 then return end

            ui:emit_signal("navigate", page.id, event.target.attr.href)
        end)
    end

end)

-- vim: et:sw=4:ts=8:sts=4:tw=80
