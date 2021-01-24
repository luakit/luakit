## Migration information

Luakit has undergone some major refactorings in the last years. If you're
coming from a luakit version older than July 2017, you need to redo your
configuration.

The following files used to be configuration files, but are not anymore:

 * binds.lua      -- is now a built-in module providing the default bindings.
                     Bindings should be changed with the `modes` APIs.
 * modes.lua      -- is now a built-in module providing built-in modes, as well
                     as providing APIs to manage bindings within those modes.
 * window.lua     -- is now a built-in module.
 * webview.lua    -- is now a built-in module.
 * webview_wm.lua -- is now a built-in module.
 * globals.lua    -- global settings have been moved to other modules.

These files will be silently ignored on startup so as to prevent errors; users
wishing to override the built-in modules should change `package.path`.
