tab.add_signal('new', function (t)
    t.title = "Untitled"

    t:add_signal('webview::title_changed', function (t, title)
        -- Set the notebook tab title
        t.title = title or t.uri
    end)

    t:add_signal('webview::uri', function (t, uri)
        print(t, uri)
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
