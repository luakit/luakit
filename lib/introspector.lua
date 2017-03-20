-- Compatibilty wrapper for lib/help_chrome.lua.
-- @submodule help_chrome

msg.warn("================================================================================")
msg.warn("introspector.lua has been renamed to help_chrome.lua for consistency")
msg.warn("This compatibility wrapper will be removed in a future version")
msg.warn("To avoid startup errors, remove any require('" .. ({...})[1] .. "') lines from your configuration")
msg.warn("This file was required by %s", debug.getinfo(3).short_src)
msg.warn("================================================================================")
return require("help_chrome")

-- vim: et:sw=4:ts=8:sts=4:tw=80
