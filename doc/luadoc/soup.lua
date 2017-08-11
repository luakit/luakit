--- URI parsing utilities.
--
-- DOCMACRO(available:ui)
--
-- The soup API provides some utilities for parsing and converting URIs, written
-- in C. For historical reasons, it also provides some other miscellaneous APIs.
--
-- @module soup
-- @author Mason Larobina
-- @copyright 2012 Mason Larobina <mason.larobina@gmail.com>

--- Parse a URI.
-- @function parse_uri
-- @tparam string uri The URI to parse.
-- @treturn table A table of URI components.

--- Convert a table of URI components to a string.
-- @function uri_tostring
-- @tparam table uri A table of URI components.
-- @treturn string The URI string.

--- The URI of the proxy to use for connections. Can be a URI, the
-- string `"no_proxy"`, the string `"default"`, or `nil` (which means the same
-- as `"default"`).
-- @property proxy_uri
-- @type string
-- @readwrite
-- @default `"default"`

--- The cookie acceptance policy. Determines which cookies are accepted and
-- stored. Can be one of `"always"`, `"never"`, and
--`"no_third_party"`.
-- @property accept_policy
-- @type string
-- @readwrite
-- @default `"no_third_party"`

--- The path to the cookie database to use. Should only be set once. Initially
-- unset, meaning no cookie database will be used.
-- @property cookies_storage
-- @type string
-- @readwrite
-- @default `nil`

-- vim: et:sw=4:ts=8:sts=4:tw=80
