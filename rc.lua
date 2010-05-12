tab.add_signal('new', function (t)
    t.title = "Untitled"

    t:add_signal('webview::title_changed', function (t, title)
        print(t, title)
        -- Now set the notebook tab title
        t.title = title or t.uri
    end)
    t:add_signal('webview::uri', function (t, uri)
        print(t, uri)
    end)
end)

uris = { "luakit.org", "http://github.com/mason-larobina/luakit", "google.com", "uzbl.org" }

for _, uri in ipairs(uris) do
    t = tab({uri = uri})
    tabs.append(t)
end

function dumptabs()
    for i = 1, tabs.count() do
        print("tab " .. i .. " " .. tabs[i].uri)
        print("index " .. tabs.indexof(tabs[i]))
    end
end

dumptabs()

t = tab({})
tabs.insert(tabs.count(), t)

tabs.remove(t)
tabs.remove(tabs[1])

print(tabs.current().uri)
