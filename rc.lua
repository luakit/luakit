-- Create main widgets
win = window{}
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
        sbar.text = v.title
    end)

    view.uri = uri
end
