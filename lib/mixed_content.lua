--- Blocks insecure content on secure (HTTPS) pages.
--
-- @module mixed_content
-- @copyright 2016 Aidan Holm

local webview = require("webview")

local _M = {}

-- Indexed by view:
--  nil   -> no mixed content in view
--  true  -> mixed content allowed to load
--  false -> mixed content blocked
local has_mixed = setmetatable({}, { __mode = 'k' })

-- Indexed by view
-- Whether to allow or blocked mixed content for a view
local allow_mixed = setmetatable({}, { __mode = 'k' })

-- Used to detect resource-request-starting signals in between provisional
-- and committed load-status signals; these correspond to top level page
-- navigation requests and redirects, not sub-resource fetch requests
local top_level = {}

local function load_status(v, status)
    if status == "provisional" then
        top_level[v] = true
        has_mixed[v] = nil
    elseif status == "committed" then
        top_level[v] = nil
    end
end

-- Request interception
local function resource_request_starting(v, uri)
    -- Don't block requests to top-level requests (page changes)
    if top_level[v] then return end

    -- The view uri should be set once sub-resource requests start
    assert(v.uri ~= nil)
    assert(uri ~= nil)

    local function starts_with(a, b)
        return string.sub(a, 1, string.len(b)) == b
    end

    if starts_with(v.uri, "https://") and starts_with(uri, "http://") then
        if allow_mixed[v] then
            msg.info("Allowed mixed request from %s to %s", v.uri, uri)
            has_mixed[v] = true
            return
        else
            msg.info("Blocked mixed request from %s to %s", v.uri, uri)
            has_mixed[v] = false
            return false
        end
    end
end

-- Hooks
webview.add_signal("init", function (view)
    view:add_signal("resource-request-starting", resource_request_starting)
    view:add_signal("load-status", load_status)
end)

-- API
webview.methods.has_mixed = function (view)
    return has_mixed[view]
end

webview.methods.toggle_mixed_content = function (view)
    allow_mixed[view] = not allow_mixed[view]
end

return _M

-- vim: et:sw=4:ts=8:sts=4:tw=80
