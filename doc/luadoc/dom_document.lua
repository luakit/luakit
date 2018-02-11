--- Web process Lua interface to the DOM
-- @class dom_document
-- @author Aidan Holm
-- @copyright 2017 Aidan Holm <aidanholm@gmail.com>
-- @prefix document
--
-- DOCMACRO(available:web)
--
-- # Retrieving the DOM document for a `page`:
--
-- To retrieve the DOM document loaded in a page, use the @ref{page/document} property.

--- @method create_element
-- Create a new element for the DOM document.
-- @tparam string tag_name The tag name of the element to create.
-- @tparam[opt] table attributes A table of attributes to set on the new element. All keys and values must be strings.
-- @tparam[opt] string inner_text The inner text to set on the element.

--- @method element_from_point
-- Find the DOM element at the given point.
-- @tparam integer x The X coordinate of the point.
-- @tparam integer y The Y coordinate of the point.
-- @treturn dom_element The element at the given point.

--- @property body
-- The body of the DOM document.
-- @type dom_element
-- @readonly

--- @property window.scroll_x
-- The horizontal scroll position of the document view.
-- @type integer
-- @readonly

--- @property window.scroll_y
-- The vertical scroll position of the document view.
-- @type integer
-- @readonly

--- @property window.inner_width
-- The inner width of the DOM document.
-- @type integer
-- @readonly

--- @property window.inner_height
-- The inner height of the DOM document.
-- @type integer
-- @readonly

-- vim: et:sw=4:ts=8:sts=4:tw=80
