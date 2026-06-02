-- Block tracking pings used in the ping attribute of html <a>
-- Displays message in Web Inspector when a ping is blocked.
-- require_web_module("hyperlink_auditing")
-- @module hyperlink_auditing


local _M = {}

luakit.add_signal("page-created", function(page)
        page:add_signal("send-request", function(p, _, headers)
            header = headers["Content-Type"]
            if header and header == "text/ping" then
                local msg = "Blocked Tracking Ping "
                if headers["Ping-To"] then
                    msg = msg .. "to: " .. headers["Ping-To"]
                end
                return msg
            end
        end)
end)

return _M
