local msg       = msg
local assert    = assert
local string    = string
local webview   = require("webview")
local setmetatable = setmetatable

module("mixed_content")

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

function load_status(v, status)
    if status == "provisional" then
        top_level[v] = true
        has_mixed[v] = nil
    elseif status == "committed" then
        top_level[v] = nil
    end
end

-- Request interception
function resource_request_starting(v, uri)
    -- Don't block requests to top-level requests (page changes)
    if top_level[v] then return end

    -- The view uri should be set once sub-resource requests start
    assert(v.uri ~= nil)
    assert(uri ~= nil)

    function starts_with(a, b)
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
webview.init_funcs.mixed_content_signals = function (view, w)
    view:add_signal("resource-request-starting", resource_request_starting)
    view:add_signal("load-status", load_status)
end

-- API
webview.methods.has_mixed = function (view, w)
    return has_mixed[view]
end

webview.methods.toggle_mixed_content = function (view, w)
    allow_mixed[view] = not allow_mixed[view]
end
