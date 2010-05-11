view.add_signal('new', function (view)
    print("The new view signal works!")
end)

uris = { "luakit.org", "http://github.com/mason-larobina/luakit", "google.com", "uzbl.org" }

for _, uri in ipairs(uris) do
    view({uri = uri})
end

function dumptabs()
    for i = 1, tabs.count() do
        print("tab " .. i .. " " .. tabs[i].uri)
    end
end

dumptabs()
