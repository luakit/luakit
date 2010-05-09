view.add_signal('new', function (view)
    print("The new view signal works!")
end)

uris = { "luakit.org", "http://github.com/mason-larobina/luakit", "google.com", "uzbl.org" }

for _, uri in ipairs(uris) do
    view({uri = uri})
end

print("There are " .. tabs.count() .. " views created")

-- This code will fail as I have not been able to figure how to return
-- view class instances from C in the index meta method.
for i = 1, tabs.count() do
    print("This views uri is " .. tabs[i].uri)
end
