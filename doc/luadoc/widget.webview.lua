--- WebKitGTK+ webview widget
--
-- DOCMACRO(available:ui)
--
-- # Creating a new webview widget
--
-- To create a new webview widget, use the `widget` constructor:
--
--     local view = widget{ type = "webview" }
--
-- 	print(type(view)) -- Prints "widget"
-- 	print(view.type)  -- Prints "webview"
--
-- # Destroying a webview widget
--
--     view:destroy()
--
-- @class widget:webview
-- @prefix view
-- @author Mason Larobina
-- @copyright 2010 Mason Larobina <mason.larobina@gmail.com>

--- @property inspector
-- Whether the web inspector is open for the webview.
-- @type boolean
-- @readonly

--- @method search
-- Begin searching the contents of the webview.
--
-- This will end any current search, as if `clear_search()` had been called.
-- @tparam string text The text to search for.
-- @tparam boolean case_sensitive Whether the search should be case-sensitive.
-- @tparam boolean forwards Search direction; `true` for forwards, `false` for backwards.
-- @tparam boolean wrap Whether searching should wrap at the beginning and end of the document.

--- @method search_next
-- Focus the next occurrence of the text in the webview.

--- @method search_previous
-- Focus the previous occurrence of the text in the webview.

--- @method clear_search
-- Finish searching the contents of the webview.
-- This will cause all highlighted matches within the webview to be un-highlighted.


--- @method go_back
-- Load the previous item in the webview history.
-- @treturn boolean Whether the history item was loaded.

--- @method go_forward
-- Load the next item in the webview history.
-- @treturn boolean Whether the history item was loaded.

--- @method can_go_back
-- Determine whether the webview has a previous history item.
-- @treturn boolean Whether the webview has a previous history item.

--- @method can_go_forward
-- Determine whether the webview has a subsequent history item.
-- @treturn boolean Whether the webview has a subsequent history item.


--- @method eval_js
--
-- Asynchronously run a string of JavaScript code in the context of the
-- webview. The JavaScript will run even if the `enable_javascript`
-- property of the webview is `false`, as it is run within a separate
-- JavaScript script world.
--
-- To evaluate a string of JavaScript, provide a callback function within
-- the `options` table:
--
--     view:eval_js("document.body.clientHeight", { callback = function (ret, err)
-- 	    assert(not err, err) -- Check for any error
-- 	    msg.info("The document height is %d pixels", ret)
-- 	end })
--
-- # Calling options
--
-- The following keys can be set in the `options` argument:
--
-- * `source` : A string to be used in error messages.
-- * `no_return` : A boolean; if `false`, no result _or error_ will be returned.
-- * `callback` : A callback function.
--
-- @tparam string script The JavaScript string to evaluate.
-- @tparam table options Additional arguments.

--- @method load_string
-- Load the given string `string` into the webview, and set the webview URI
-- to `content_uri`. This replaces the existing contents of the webview.
--
-- In order to display an error page, it's recommended to use the `error_page`
-- module. This module automatically implements a number of features, such as
-- preventing user styles or userscripts from interfering with error pages, and
-- error pages using this module have a consistent theme.
--
-- @tparam string string The string to load into the webview.
-- @tparam string content_uri The URI to display.

--- @method reload
-- Reload the current contents of the webview.

--- @method reload_bypass_cache
-- Reload the current contents of the webview, without using any cached data.

--- @method stop
-- Stop any current load operation within the within the webview. If there is no
-- such operation, this method does nothing. Otherwise, the `load-failed` signal
-- will be emitted with `"cancelled"` as the failure reason.

--- @method ssl_trusted
-- Determine whether any problems have been found with the certificate associated
-- with the contents of the webview.
--
-- If the contents of the webview were not loaded over HTTPS, `nil` is returned.
--
-- The return value is valid after `load-status` is emitted on the webview
-- with the `"committed"` status.
--
-- @treturn boolean? `false` if any problems have been found, `true` if no problems
-- were found, and `nil` if the contents of the webview were not loaded over HTTPS.

--- @method show_inspector
-- Show the web inspector for the webview.

--- @method close_inspector
-- Close the web inspector for the webview.

--- @method allow_certificate
-- Allow a certificate.

--- @property uri
-- The URI of the current web page.
-- @type string
-- @readwrite
-- @default "about:blank"

--- @property hovered_uri
-- The URI of the link the mouse cursor is currently hovering over, or
-- `nil` if the mouse cursor is not currently hovering over a link.
-- @type string?
-- @readonly

--- @property source
-- The source of the current web page.
-- @readonly

--- @property session_state
-- The session state of the current web page.
-- @type string
-- @readwrite

--- @property stylesheets
-- The stylesheets of the webview.
-- @type table
-- @readonly

--- @property history
-- The history of the webview.
-- @type table
-- @readonly

--- @property scroll
-- The scroll of the webview.
-- @type table
-- @readonly

--- @property favicon
-- The favicon of the webview.
-- @type widget
-- @readonly

--- @property certificate
-- The certificate of the webview.
-- @type string
-- @readonly

--- @property allow_file_access_from_file_urls
-- Whether `file://` access is allowed for `file://` URIs.
-- @type boolean
-- @default `false`
-- @readwrite

--- @property allow_universal_access_from_file_urls
-- Whether Javascript running in the `file://` scheme is allowed to access
-- content from any origin.
-- @type boolean
-- @default `false`
-- @readwrite

--- @property hardware_acceleration_policy
-- The policy for using hardware acceleration. Can be one of
-- `"on-demand"`, `"always"`, and `"never"`.
-- @type string
-- @readwrite

--- @signal scheme-request::*
--
-- Emitted when the webview attempts to load a URI on a custom URI scheme.
-- The signal detail is always present and is equal to the URI scheme.
--
-- # Example
--
-- A signal `scheme-request::foo` will be emitted on a webview in
-- response to a `foo://` load attempt. To display content for this request,
-- return a string with the content to display, as well as (optionally) the
-- content MIME type.
--
-- The type of content to display isn't limited to HTML or other textual
-- formats; images and other binary content types are acceptable, as long as the
-- MIME type parameter is returned.
--
-- @tparam string uri The URI that the webview is attempting to load.
-- @treturn string The content to display. Embedded NUL bytes are handled
-- correctly.
-- @treturn string The MIME type of the content. Default: `text/html`.

--- @signal property::*
--
-- Emitted when the value of a webview property may have been updated.
-- For example, the `"property::uri"` signal is emitted on a `webview`
-- widget when its @ref{widget:webview/uri} property changes.

--- @signal link-hover
-- Emitted when the mouse cursor is moved over a link.
-- @deprecated use `property::hovered_uri` signal instead.
-- @tparam string uri The hovered URI.

--- @signal link-unhover
-- Emitted when the mouse cursor was over a link and is moved off.
-- @deprecated use `property::hovered_uri` signal instead.
-- @tparam string uri The just-unhovered URI.

--- @signal button-press
-- Emitted when a mouse button was pressed with the cursor inside the `webview` widget.
--
-- @tparam table modifiers An array of strings, one for each modifier key held
-- at the time of the event.
-- @tparam integer button The number of the button pressed, beginning
-- from `1`; i.e. `1` corresponds to the left mouse button.
-- @tparam table hit_test A table representing the type of element under the
-- cursor at the time of the event.
-- @treturn boolean `true` if the event has been handled and should not be
-- propagated further.

--- @signal button-release
-- Emitted when a mouse button was released with the cursor inside the `webview` widget.
--
-- @tparam table modifiers An array of strings, one for each modifier key held
-- at the time of the event.
-- @tparam integer button The number of the button pressed, beginning
-- from `1`; i.e. `1` corresponds to the left mouse button.
-- @tparam table hit_test A table representing the type of element under the
-- cursor at the time of the event.
-- @treturn boolean `true` if the event has been handled and should not be
-- propagated further.

--- @signal button-double-click
-- Emitted when a mouse button was double-clicked with the cursor inside the `webview` widget.
--
-- @tparam table modifiers An array of strings, one for each modifier key held
-- at the time of the event.
-- @tparam integer button The number of the button pressed, beginning
-- from `1`; i.e. `1` corresponds to the left mouse button.
-- @tparam table hit_test A table representing the type of element under the
-- cursor at the time of the event.
-- @treturn boolean `true` if the event has been handled and should not be
-- propagated further.

--- @signal mouse-enter
-- Emitted when the mouse cursor enters the `webview` widget.
-- @tparam table modifiers An array of strings, one for each modifier key held.
-- @treturn boolean `true` if the event has been handled and should not be
-- propagated further.

--- @signal mouse-leave
-- Emitted when the mouse cursor leaves the `webview` widget.
-- @tparam table modifiers An array of strings, one for each modifier key held.
-- @treturn boolean `true` if the event has been handled and should not be
-- propagated further.

--- @signal populate-popup
-- Emitted just before the context menu is shown, usually after a right-click.
-- This signal allows Lua code to intercept and modify the menu before it is
-- shown.
-- @tparam table menu A table representing the context menu to be shown.

--- @signal web-extension-loaded
-- Emitted on a `webview` widget when its associated web process has finished
-- initialization.

--- @signal crashed
-- Emitted on a `webview` widget when its associated web process has crashed.
-- The `"web-extension-loaded"` signal will be emitted afterwards, once a
-- replacement web process has finished initialization.

--- @signal load-status
-- Emitted on a `webview` widget when its load status changes.
-- @tparam string status The current load status of the webview. Can be one of
-- `"provisional"`, `"redirected"`, `"committed"`, `"finished"`, and `"failed"`.
-- @tparam string|nil uri If the load status is `"failed"`, this will be the
-- failing URI; otherwise, it will be `nil`.
-- @tparam table|nil err If the load status is `"failed"`, this will be a table
-- with an error code and a human-readable message; otherwise, it will be `nil`.

--- @signal create-web-view
-- Emitted on a `webview` widget when it requests creation of a new `webview`
-- widget.
-- @treturn widget[type=webview] The newly created `webview` widget.

--- @signal navigation-request
-- Emitted on a `webview` widget before a navigation request is made, in either
-- the main frame or a sub-frame of the webpage.
-- @tparam string uri The URI to which navigation is being requested.
-- @tparam string reason The reason for the navigation request. Can
-- be one of `"link-clicked"`, `"form-submitted"`, `"back-forward"`,
-- `"reload"`, `"form-resubmitted"`, and `"other"`.
-- @treturn boolean Return `false` to prevent the requested
-- navigation from taking place.

--- @signal new-window-decision
--
-- Similar to the `"navigation-request"` signal, the
-- `"new-window-decision"` signal is emitted on a `webview` widget when a
-- request to open a new window is made.
-- @tparam string uri The URI that will open in the new window, if the request
-- is allowed.
-- @tparam string reason The reason for the navigation request. Can
-- be one of `"link-clicked"`, `"form-submitted"`, `"back-forward"`,
-- `"reload"`, `"form-resubmitted"`, and `"other"`.
-- @treturn boolean Return `false` to prevent the requested
-- navigation from taking place.

--- @signal mime-type-decision
-- Similar to the `"navigation-request"` signal, the
-- `"mime-type-decision"` signal is emitted on a `webview` widget after a
-- response has been received for a request, but before loading begins. This
-- signal is emitted for all sub-page resources, such as images and stylesheets.
--
-- @tparam string uri The URI of the resource for which a response has been
-- received.
-- @tparam string mime The MIME type for the resource indicated by the response.
-- @treturn boolean Return `false` to prevent the requested
-- navigation from taking place.

--- @signal favicon
-- Emitted when the favicon for the currently loaded webpage becomes available.

--- @signal expose
-- Emitted when the `webview` widget is redrawn.

--- @signal key-press
-- Emitted when a key is pressed while the `webview` widget has the
-- input focus.
-- @tparam table modifiers An array of strings, one for each modifier key held.
-- @tparam string key The key that was pressed, if printable, or a keysym
-- otherwise.
-- @treturn boolean `true` if the event has been handled and should not be
-- propagated further.

--- @signal permission-request
-- Emitted when the webview is requesting user permisison to perform some
-- action.
-- @tparam string type The type of permission requested. Can be one of
-- `"notification"`, `"geolocation"`, `"install-missing-media-plugins"`, and `"user-media"`.
-- @param arg Additional information about the permission request. For
-- `"user-media"` requests, this is a table with boolean `audio` and `video`
-- fields. For `"install-missing-media-plugins"` requests, this is a string
-- description.
-- @treturn boolean `true` to grant the permission request, and `false` to deny
-- it. If no value is returned, a default action is used.

-- vim: et:sw=4:ts=8:sts=4:tw=80
