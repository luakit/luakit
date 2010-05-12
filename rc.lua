tab.add_signal('new', function (t)
    t.title = "Untitled"

    t:add_signal('webview::title-changed', function (t, title)
        -- Set the notebook tab title
        t.title = title or t.uri
    end)

    t:add_signal('property::title', function (t)
        print(t, "Title changed", t.title)
    end)

    t:add_signal('property::uri', function (t)
        print(t, "Uri changed", t.uri)
    end)

    t:add_signal('property::progress', function (t)
        print(t, "Progress changed", t.progress .. "%")
    end)

end)

-- Load uris passed to luakit at launch
for _, uri in ipairs(uris) do
    t = tab{uri = uri}
    tabs.append(t)
end

-- If there were no uris passed on the command line go luakit.org
if #uris == 0 then
    t = tab{uri = "luakit.org", title = "Homepage"}
    tabs.append(t)
end

-- Focus the first tab
tabs[1]:focus()
