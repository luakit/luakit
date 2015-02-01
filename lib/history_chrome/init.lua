-- Grab what we need from the Lua environment
local table = table
local string = string
local io = io
local print = print
local pairs = pairs
local ipairs = ipairs
local math = math
local assert = assert
local setmetatable = setmetatable
local rawget = rawget
local rawset = rawset
local type = type
local os = os
local error = error

-- Grab the luakit environment we need
local history = require("history")
local lousy = require("lousy")
local chrome = require("chrome")
local add_binds = add_binds
local add_cmds = add_cmds
local webview = webview
local capi = {
    luakit = luakit
}

local config = globals.history or {}
local item_skelly = config.item_skelly or [[<div id="item-skelly">
             <div class="item">
                 <span class="visits"></span>
                 <span class="time"></span>
                 <span class="title"><a></a></span>
                 <span class="domain"><a></a></span>
             </div>
         </div>]]
-- Not listing everything here will lead to missing things _when searching_.
local search_select = config.search_select or "id, uri, title, last_visit, visits"

module("history.chrome")
   
stylesheet = lousy.load_asset("history_chrome/style.css")
local html = lousy.load_asset("history_chrome/page.html")
local main_js = lousy.load_asset("history_chrome/js.js")

local initial_search_term

export_funcs = {
    history_search = function (opts)
        local sql = { "SELECT", "*", "FROM history" }

        local where, args, argc = {}, {}, 1

        string.gsub(opts.query or "", "(-?)([^%s]+)", function (notlike, term)
            if term ~= "" then
                table.insert(where, (notlike == "-" and "NOT " or "") ..
                    string.format("(text GLOB ?%d)", argc, argc))
                argc = argc + 1
                table.insert(args, "*"..string.lower(term).."*")
            end
        end)

        if #where ~= 0 then
            sql[2] = [[ *, lower(uri||title) AS text ]]
            table.insert(sql, "WHERE " .. table.concat(where, " AND "))
        end

        local order_by = [[ ORDER BY last_visit DESC LIMIT ?%d OFFSET ?%d ]]
        table.insert(sql, string.format(order_by, argc, argc+1))

        local limit, page = opts.limit or 100, opts.page or 1
        table.insert(args, limit)
        table.insert(args, limit > 0 and (limit * (page - 1)) or 0)

        sql = table.concat(sql, " ")

        if #where ~= 0 then
            local wrap = [[SELECT %s FROM (%s)]]
            sql = string.format(wrap, search_select, sql)
        end

        local rows = history.db:exec(sql, args)

        for i, row in ipairs(rows) do
            local time = rawget(row, "last_visit")
            
            rawset(row, "date", os.date("%A, %d %B %Y", time))
            rawset(row, "time", os.date("%H:%M", time))
        end

        return rows
    end,

    history_clear_all = function ()
        history.db:exec [[ DELETE FROM history ]]
    end,

    history_clear_list = function (ids)
        if not ids or #ids == 0 then return end
        local marks = {}
        for i=1,#ids do marks[i] = "?" end
        history.db:exec("DELETE FROM history WHERE id IN ("
            .. table.concat(marks, ",") .. " )", ids)
    end,

    initial_search_term = function ()
        local term = initial_search_term
        initial_search_term = nil
        return term
    end,
}

chrome.add("history", function (view, meta)

    local html = string.gsub(html, "{%%(%w+)}", {
        -- Merge common chrome stylesheet and history stylesheet
        stylesheet = chrome.stylesheet .. stylesheet,
        itemSkelly = item_skelly
    })

    view:load_string(html, meta.uri)

    function on_first_visual(_, status)
        -- Wait for new page to be created
        if status ~= "first-visual" then return end

        -- Hack to run-once
        view:remove_signal("load-status", on_first_visual)

        -- Double check that we are where we should be
        if view.uri ~= meta.uri then return end

        -- Export luakit JS<->Lua API functions
        for name, func in pairs(export_funcs) do
            view:register_function(name, func)
        end

        view:register_function("reset_mode", function ()
            meta.w:set_mode() -- HACK to unfocus search box
        end)

        -- Load jQuery JavaScript library
        local jquery = lousy.load("lib/jquery.min.js")
        local _, err = view:eval_js(jquery, { no_return = true })
        assert(not err, err)

        -- Load main luakit://download/ JavaScript
        local _, err = view:eval_js(main_js, { no_return = true })
        assert(not err, err)
    end

    view:add_signal("load-status", on_first_visual)
end)

-- Prevent history items from turning up in history
history.add_signal("add", function (uri)
    if string.match(uri, "^luakit://history/") then return false end
end)

local cmd = lousy.bind.cmd
add_cmds({
    cmd("history", function (w, query)
        initial_search_term = query
        w:new_tab("luakit://history/")
    end),
})
