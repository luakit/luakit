-- Get environment we need from luakit libs
local new_mode = new_mode
local add_cmds = add_cmds
local add_binds = add_binds
local menu_binds = menu_binds
local webview = webview
local lousy = require "lousy"

history = {}
history.mode = "command"

-- We register each visited page
webview.init_funcs.save_hist = function (view)
    view:add_signal("load-status", function (v, status)

        if status == "first-visual" then
            -- We remove extra parameters from the request
            local url = string.gsub(v.uri, "?.*", "")
            pcall(database.insert_url, url, v:get_prop("title"))
        end

    end)
end

-- Request the database for getting the history
-- The urls are returned by popularity ( frequency )
function show_history(w, text)
    if text then
        local cmd = string.sub(text, 2)
        text = "%"..cmd.."%"
    end
    rows = database.get_urls(text)
    local urls = {}
    for result = 1, #rows do
        local url = rows[result].url
        table.insert(urls, {url, uri = url })
    end
    w.menu:build(urls)
end

-- Go to the requested url
function navigate(w)
    local row = w.menu:get()
    if row and row.uri then
        w:navigate(row.uri)
        w:set_mode()
    end
end

-- Switch to insert or command mode
function switch(mode, w)
    if mode == "command" then
        history.mode = "command"
        w:set_input()
        w:notify("Use j/k to move,f filter, o open, t tabopen, w winopen.", false)
    else
        w:set_input(":")
        history.mode = "insert"
        w:notify("Filter the url and press return to validate", false)
    end
end

-- Set the mode
new_mode("history", {
    enter = function (w)
        show_history(w)
        switch("insert", w)
    end,
    
    changed = function (w, text)
        -- Return to command mode
        if not string.match(text, "^:") then 
            switch("command", w)
            return
        end
        show_history(w, text)

    end,
    
    leave = function (w)
        w.menu:hide()
    end,

})

local cmd = lousy.bind.cmd
add_cmds({
    cmd("hist[ory]",
        function (w) w:set_mode("history") end),
})

local key = lousy.bind.key
add_binds("history", lousy.util.table.join({

    -- Open hist item
    key({}, "Return",
        function (w)
            if history.mode == "command" then
                navigate(w)
            else
                switch("command", w)
            end
        end),

    key({}, "j",
        function (w)
            if history.mode == "insert" then
                w:insert_cmd("j")
            else
                w.menu:move_down()
            end
        end),

    key({}, "k",
        function (w)
            if history.mode == "insert" then
                w:insert_cmd("k")
            else
                w.menu:move_up()
            end
        end),

    -- Filter the history
    key({}, "f",
        function (w)
            if history.mode == "command" then
                switch("insert", w)
            else
                w:insert_cmd("f")
            end
        end),

    -- Open hist item
    key({}, "o",
        function (w)
            if history.mode == "command" then
                navigate(w)
            else
                w:insert_cmd("o")
            end
        end),

    -- Open hist item in background tab
    key({}, "t",
        function (w)
            if history.mode == "command" then
                local row = w.menu:get()
                if row and row.uri then
                    w:set_mode()
                    w:new_tab(row.uri, false)
                end
            else
                w:insert_cmd("t")
            end
        end),

    -- Open hist item in new window
    key({}, "w",
        function (w)
            if history.mode == "command" then
                local row = w.menu:get()
                if row and row.uri then
                    w:set_mode()
                    window.new({row.uri})
                end
            else
                w:insert_cmd("w")
            end
        end),


}, menu_binds))
