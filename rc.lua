tab.add_signal('new', function (view)
    print("The new tab signal works!")
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

print("Removing something")

tabs.remove(t)
tabs.remove(tabs[1])

print(tabs.current().uri)
