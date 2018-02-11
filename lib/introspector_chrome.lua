--- Provided luakit://introspector/ page.
--
-- **DEPRECTATION NOTICE**
-- This module has been moved to binds_chrome.lua and should not be used.
--
-- This module provides the luakit://introspector/ page. It is useful for
-- viewing all keybindings and modes on a single page, as well as searching for
-- a keybinding for a particular task.
--
-- @module introspector_chrome
-- @copyright 2016 Aidan Holm <aidanholm@gmail.com>
-- @copyright 2012 Mason Larobina <mason.larobina@gmail.com>

msg.warn("'require \"introspector_chrome\"' is deprecated!")
msg.warn("Please use 'require \"binds_chrome\"' instead.")

return require "binds_chrome"

-- vim: et:sw=4:ts=8:sts=4:tw=80
