#!./luakit -c

-- Widget construction aliases
function eventbox() return widget{type="eventbox"} end
function hbox()     return widget{type="hbox"}     end
function label()    return widget{type="label"}    end
function notebook() return widget{type="notebook"} end
function vbox()     return widget{type="vbox"}     end
function webview()  return widget{type="webview"}  end
function window()   return widget{type="window"}   end

function widget_setup(w)
    print("new widget", w.type)
    if w.type == "window" then
        -- Call the quit function if this was the last window left
        w:add_signal("destroy", function ()
            if #luakit.windows == 0 then luakit.quit() end
        end)
    end
end

widget.add_signal("new", function(w)
    w:add_signal("init", function(w)
        widget_setup(w)
    end)
end)

-- Create main widgets
win = window()
layout = vbox()
win:set_child(layout)

-- Create tabbed notebook to store webviews
tabs = notebook()
layout:pack_start(tabs, true, true, 0)

-- Create "status bar"

left = label()
left.text = "left"
left:set_alignment(0.0, 0.0)

right = label()
right.text = "right"
right:set_alignment(1.0, 0.0)

sbar_layout = hbox()
sbar_layout:pack_start(left, true, true, 2)
sbar_layout:pack_start(right, false, false, 2)

statusbar = eventbox()
statusbar:set_child(sbar_layout)

layout:pack_start(statusbar, false, false, 0)

if #uris == 0 then
    uris = { "http://github.com/mason-larobina/luakit" }
end

for _, uri in ipairs(uris) do
    view = webview()
    tabs:append(view)

    view:add_signal("title-changed", function (v)
        local title = v:get_prop("title")
        tabs:set_title(v, title)
        win.title = title
        left.text = title
        right.text = v:get_prop("uri")
    end)

    view:add_signal("link-hover", function(v, link)
        print(view, link)
    end)

    view:add_signal("link-unhover", function(v, link)
        print(view, link)
    end)

    view.uri = uri
end
