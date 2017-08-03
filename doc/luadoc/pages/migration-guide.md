@name Migration Guide
#Migration Guide

## Migrating from a pre-WebKit2 Version

The latest luakit release is built around the WebKit 2 APIs. Changes in the APIs
provided by WebKit have necessitated some corresponding changes in luakit's
APIs, and as a result there have been many breaking changes.

### Remove any existing personal configuration

Luakit's configuration file has seen many changes; as a result, you are likely
to encounter errors unless you remove any personal configuration for a previous
luakit version. You may wish to back up your configuration if you have made
extensive changes; such changes can then be merged in to the up-to-date
configuration.

**_Note:_** It is inadvisable to copy luakit's entire system configuration
directory to make a personal copy, as was previously encouraged. This
makes it harder for you to upgrade luakit, as you have more files to
merge upstream changes into, and you are more likely to experience
errors caused by such upstream changes (until those changes are merged with your
personal configuration).

### Remove use of `module()`

Lua's `module()` function sets a global variable of the same name as the module,
which pollutes the global namespace for _all_ Lua code. A recent effort
was made to remove all usage of `module()` within Luakit. While `module()` is
still accessible, its use is not advised.

This has the side effect that many variables once assumed globally accessible
must now be retrieved with a call to `require()`.

### Remove use of `init_funcs`

The `window` and `webview` classes previously had a method of registering
functions to be called when a new window or webview was created, called
`init_funcs`. This has been removed entirely in favor of a signals-based
approach, which does not run the risk of name collision.

The `window` and `webview` classes now emit the `"init"` signal. To replace any
functions previously registered via `init_funcs`, add a signal handler:

	webview.add_signal("init", function (view)
	    -- Do something with new view
	end)

The `window` class also emits a `"build"` signal _before_ emitting the
init signal. This provides an opportunity for modules to change the layout and
arrangement of widgets within the window, before the `"init"` signal is emitted.

### Remove use of `local capi` table

Some old code wraps references to several builtin variables in a `capi` table.
This does `not` namespace the builtin variables wrapped in this manner; they are
still globally accessible (and otherwise could not be wrapped in this fashion),
and so all this accomplishes is the addition of more code, more indirection, and
confusion about luakit's and Lua's namespacing rules, for no actual advantage.

As such, it is advised to remove any such wrapper tables, and reference the
globally-accessible builtin luakit libraries directly.
