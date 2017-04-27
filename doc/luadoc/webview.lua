--- WebKitGTK+ webview widget
--
-- ### Creating a new webview widget
--
-- To create a new webview widget, use the `widget` constructor:
--
--     local view = widget{ type = "webview" }
--
-- 	print(type(view)) -- Prints "widget"
-- 	print(view.type)  -- Prints "webview"
--
-- ### Destroying a webview widget
--
--     view:destroy()
--
-- @class widget.webview
-- @author Mason Larobina
-- @copyright 2010 Mason Larobina

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
-- #### Calling options
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
-- Allow a certificate


--- @property uri
-- The URI of the current web page
-- @type string
-- @readwrite
-- @default "about:blank"

--- @property hovered_uri
-- The URI of the link the mouse cursor is currently hovering over, or
-- `nil` if the mouse cursor is not currently hovering over a link.
-- @type string?
-- @readonly

--- @property source
-- The source of the current web page
-- @readonly

--- @property session_state
-- The session state of the current web page
-- @type string
-- @readwrite

--- @property stylesheets
-- The stylesheets of the webview
-- @type table
-- @readonly

--- @property history
-- The history of the webview
-- @type table
-- @readonly

--- @property scroll
-- The scroll of the webview
-- @type table
-- @readonly

--- @property favicon
-- The favicon of the webview
-- @type widget
-- @readonly

--- @property certificate
-- The certificate of the webview
-- @type string
-- @readonly

--- @signal scheme-request
--
-- Emitted when the webview attempts to load a URI on a custom URI scheme.
-- The signal detail is always present and is equal to the URI scheme.
--
-- #### Example
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

-- vim: et:sw=4:ts=8:sts=4:tw=80
