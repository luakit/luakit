-- Create main widgets
win = window{}

win:add_signal("destroy", function (w)
    -- TODO Add some logic to check if this is the last window closing
    -- before calling quit
    luakit.quit()
end)

layout = widget{type = "vbox"}
win:set_child(layout)


-- Create tabbed notebook to store webviews
nbook = widget{type = "notebook"}
layout:pack_start(nbook, true, true, 0)

-- Create "status bar"
sbar = widget{type = "textarea"}
layout:pack_start(sbar, false, true, 0)

if #uris == 0 then
    uris = { "http://github.com/mason-larobina/luakit" }
end

for _, uri in ipairs(uris) do
    view = widget{type = "webview"}
    nbook:append(view)

    view:add_signal("property::title", function (v)
        nbook:set_title(v, v.title)
        sbar.text = v.title
        win.title = v.title
    end)

    view.uri = uri
end
