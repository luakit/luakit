view.add_signal('new', function (view)
    print("New view lua callback")
end)

uris = { "luakit.org", "http://github.com/mason-larobina/luakit" }

for _, uri in ipairs(uris) do
    view({uri = uri})
end
