--- Scrolling wrapper widget
--
-- DOCMACRO(available:ui)
--
-- The scrolled widget allows widgets too big to fit within a desired region to
-- be scrolled. One example use for this is the tablist, which will be scrolled
-- when there are too many tabs to display all at once.
--
-- @class widget:scrolled
-- @prefix scrolled
-- @author Mason Larobina
-- @copyright 2010 Mason Larobina <mason.larobina@gmail.com>

--- @property scrollbars
-- The scrollbar policy. Two fields, `h` and `v`, specify the scrollbar policy
-- for horizontal and vertical scrollbars respectively. They can have values of
-- `"always"`, `"auto"`, `"never"`, or `"external"`.
-- @type table
-- @readwrite

--- @property scroll
-- The current scroll position. Two fields, `h` and `v`, specify the scroll
-- offset from the left and top respectively, in pixels.
-- @type table
-- @readwrite

-- vim: et:sw=4:ts=8:sts=4:tw=80
