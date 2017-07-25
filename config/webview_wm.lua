local ui = ipc_channel("webview_wm")

ui:add_signal("load-finished", function(_, page)
    local doc = page.document

    -- do nothing if loaded document is not HTML
    if not doc.body then return end

    if page.uri:find("luakit://", 1, true) == 1 then
        doc.body:add_event_listener("click", true, function (event)
            if event.button ~= 0 then return end
            if event.target.tag_name ~= "A" then return end
            if (event.target.attr.href or ""):find("file://", 1, true) ~= 1 then return end

            ui:emit_signal("navigate", page.id, event.target.attr.href)
        end)
    end

end)

-- vim: et:sw=4:ts=8:sts=4:tw=80
