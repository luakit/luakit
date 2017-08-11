--- Web process Lua interface to the DOM
--
-- DOCMACRO(available:web)
--
-- The `dom_element` class allows interaction with elements on any web page.
--
-- @class dom_element
-- @author Aidan Holm
-- @copyright 2017 Aidan Holm <aidanholm@gmail.com>
-- @prefix element

--- @method query
-- Find all sub-elements which match a given CSS selector.
-- @tparam string selector A CSS selector.
-- @treturn {dom_element} All sub-elements which match the selector.

--- @method append
-- Append a new child element to the end of the element's children.
-- @tparam dom_element child The new child element.

--- @method remove
-- Remove the element from its parent element.

--- @method click
-- Simulate a mouse click on the element.

--- @method focus
-- Focus the element.

--- @method submit
-- If the element is a form element, submit the form.

--- @method add_event_listener
-- Add an event listener to this element. The callback will be called with a
-- single table argument, which will have a `target` field containing the event
-- source element. If the event is a mouse event, it will also have a `button`
-- field, containing the mouse button number.
-- @tparam string type The type of event to listen for.
-- @tparam boolean capture Whether the event should be captured.
-- @tparam function callback The callback function.

--- @property inner_html
-- The inner HTML of the element.
-- @type string
-- @readwrite

--- @property tag_name
-- The tag name of the element.
-- @type string
-- @readonly

--- @property text_content
-- The text content of the element.
-- @type string
-- @readonly

--- @property child_count
-- The number of child elements this element has.
-- @type integer
-- @readonly

--- @property src
-- The "src" attribute of the element.
-- @type string
-- @readonly

--- @property href
-- The "href" attribute of the element.
-- @type string
-- @readonly

--- @property value
-- The "value" attribute of the element.
-- @type string
-- @readwrite

--- @property checked
-- Whether this element is checked.
-- @type boolean
-- @readwrite

--- @property type
-- The "type" attribute of the element.
-- @type string
-- @readonly

--- @property parent
-- The parent element of this element.
-- @type dom_element
-- @readonly

--- @property first_child
-- The first child element of this element.
-- @type dom_element
-- @readonly

--- @property last_child
-- The last child element of this element.
-- @type dom_element
-- @readonly

--- @property prev_sibling
-- The previous sibling element of this element.
-- @type dom_element
-- @readonly

--- @property next_sibling
-- The next sibling element of this element.
-- @type dom_element
-- @readonly

--- @property rect
-- The position of the element within the containing DOM document. It has four
-- keys: `top`, `left`, `width`, and `height`.
-- @type table
-- @readonly

--- @property style
-- Table of computed styles. Index should be the name of a CSS property value.
-- @type table
-- @readonly

--- @property attr
-- The attributes of the DOM element and their values, as key/value
-- pairs. All keys and values must be strings. Iteration with `next()`
-- or `pairs()` does not work.
-- @type table
-- @readwrite

--- @property document
-- The DOM document that this element is within. If this element is within a
-- subframe, the document returned will be the DOM document for that subframe,
-- not the top-level document.
-- @type dom_document
-- @readonly

--- @property owner_document
-- The DOM document that is the top-level document object for this element.
-- one document and added to another.
-- @type dom_document
-- @readonly

--- @signal destroy
-- Emitted when the element is destroyed.

-- vim: et:sw=4:ts=8:sts=4:tw=80
