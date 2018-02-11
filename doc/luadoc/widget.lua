--- GTK+ user interface widgets
--
-- DOCMACRO(available:ui)
--
-- The `widget` class provides a wrapper around GTK's widget system,
-- allowing Lua code to build and modify the user interface.
--
-- This page lists functions, methods, and properties common to all widget
-- types, as well as some methods and properties that are common to a subset
-- of widget types. Documentation pages for specific widget types will list
-- only properties, methods, functions, and signals that are unique to each
-- type of widget.
--
-- *Note: some user interface widgets are also provided by the `lousy.widget`
-- library.*
--
-- # Widget types
--
-- The following widget types are available:
--
-- - `box`: A box for packing other widgets vertically or horizontally.
-- - `drawing_area`: A widget used for external drawing.
-- - `entry`: A text input box.
-- - `event_box`: A widget used to receive events for some kinds of sub-widgets.
-- - `image`: A widget used to display an image.
-- - `label`: A text label that displays short strings of formatted text.
-- - `notebook`: Groups a set of widgets, only one of which will be visible at a time.
-- - `overlay`: Allows laying widgets over the top of other widgets.
-- - `paned`: A two-pane interface widget, with a draggable slider between panes.
-- - `scrolled`: A widget that allows its contents to be scrolled.
-- - `socket`: A widget that allows drawing from an external GTK program.
-- - `spinner`: A loading spinner, used to indicate activity of indefinite duration.
-- - `webview`: Shows the contents of a web page and allows page interaction.
-- - `window`: A window contains all other user interface elements.
--
-- # Creating a new widget
--
-- To create a new widget, use the `widget` constructor:
--
--     local view = widget{ type = ... }
--
-- The `type` field must be provided.
--
-- # Destroying a webview widget
--
--     view:destroy()
--
-- @class widget
-- @author Mason Larobina
-- @copyright 2010 Mason Larobina <mason.larobina@gmail.com>

--- @function __call
-- Create a new widget. It is mandatory to specify a `type` as an
-- initial property, as this is needed to construct the widget internally.
-- @tparam table props Initial widget properties. A `type` field is mandatory.
-- @treturn widget The newly-constructed widget.

--- @property type
-- The type of the widget. Must be specified during creation, and cannot be modified
-- later.
-- @type string
-- @readonly

--- @property is_alive
-- Whether the widget is alive. If it is not (i.e. it has been destroyed), then
-- this is the only property that can be accessed without raising an error.
-- @type boolean
-- @readonly

--- @property margin
-- Combined property for all widget margins, in pixels.
-- @type integer
-- @readwrite

--- @property margin_top
-- The margin above the widget, in pixels.
-- @type integer
-- @readwrite

--- @property margin_bottom
-- The margin below the widget, in pixels.
-- @type integer
-- @readwrite

--- @property margin_left
-- The margin to the left of the widget, in pixels.
-- @type integer
-- @readwrite

--- @property margin_right
-- The margin to the right of the widget, in pixels.
-- @type integer
-- @readwrite

--- @property parent
-- The widget's parent widget, if it has one.
-- @type widget|nil
-- @readonly

--- @property child
-- The widget's single child widget, if it has one. Only certain types of
-- widgets have this property; specifically, the event box, overlay, scrolled,
-- and window widgets.
-- @type widget|nil
-- @readwrite

--- @property focused
-- Whether the widget has the input focus.
-- @type boolean
-- @readonly

--- @property visible
-- Whether the widget is visible.
-- @type boolean
-- @readwrite

--- @property tooltip
-- The text displayed in the tooltip shown when the cursor is hovered above the
-- widget, or `nil` if no tooltip should be displayed.
-- @type string
-- @readwrite
-- @default `nil`

--- @property width
-- The width of the widget, in pixels.
-- @type integer
-- @readonly

--- @property height
-- The height of the widget, in pixels.
-- @type integer
-- @readonly

--- @property min_size
-- The minimum size of the widget, in pixels.
-- @type table
-- @readwrite

--- @property children
-- A newly-created array of the widget's children. Modification of this array does not affect
-- the user interface. Only certain types of widgets have this property:
-- specifically, the box, event box, notebook, paned, and window widgets.
-- @type {widget}
-- @readonly

--- @method show
-- Show the widget.

--- @method hide
-- Hide the widget.

--- @method focus
-- Move the input focus for the widget's window to the widget. If the widget is
-- a window, it will instead unfocus the currently focused widget within the
-- window.

--- @method destroy
-- Destroy the widget.

--- @method replace
-- Remove the widget from its parent, replacing it with `other`. All child
-- properties, such as the arrangement and relative position of the widget
-- within its parent, are maintained.
--
-- If the widget does not have a parent, this method does nothing.
-- @tparam widget other The replacement widget.

--- @method remove
-- Remove a specific child widget from the widget. Only certain types of
-- widgets have this property: specifically, the box, event box, notebook,
-- paned, and window widgets.
-- @tparam widget child The child widget to remove.

--- @method send_key
-- Send synthetic key events to the widget. This function parses a vim-like
-- keystring into single keys and sends them to the widget. When
-- `window.act_on_synthetic_keys` is disabled, synthetic key events will not trigger
-- other key bindings.
-- @tparam string keystring The string representing the keys to send.
-- @tparam table modifiers The key modifiers table.

--- @signal create
-- Emitted on the `widget` library when a new widget has been created.
-- @tparam widget widget The newly-created widget.

--- @signal destroy
-- Emitted when the widget is about to be destroyed.

--- @signal resize
-- Emitted when the widget has been resized.

--- @signal focus
-- Emitted when the `webview` widget gains the input focus.
-- @treturn boolean `true` if the event has been handled and should not be
-- propagated further.

--- @signal unfocus
-- Emitted when the `webview` widget loses the input focus.
-- @treturn boolean `true` if the event has been handled and should not be
-- propagated further.

--- @signal parent-set
-- Emitted when the widget is either added or removed from a parent widget.
-- @tparam widget|nil parent The widget's parent, or `nil`.

-- vim: et:sw=4:ts=8:sts=4:tw=80
