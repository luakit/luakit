# Luakit

luakit is a fast, light and simple to use micro-browser framework extensible
by Lua using the WebKit web content engine and the GTK+ toolkit.

## Don't Panic!

You don't have to be a developer to use luakit on a daily basis. If you are
familiar with vimperator, pentadactyl, jumanji, uzbl & etc you will find
luakit behaves similarly out of the box.

## Requirements

 * GTK+ 3
 * Lua 5.1 or LuaJIT 2
 * lfs (lua file system)
 * webkit2gtk
 * sqlite3

## Compiling

To compile the stock luakit run:

    make

To link against LuaJIT (if you have LuaJIT installed) run:

    make USE_LUAJIT=1

To build with a custom compiler run:

    make CC=clang

To build with local paths (interesting for package maintainer and contributers). You may wish to build luakit with:

    make DEVELOPMENT_PATHS=1

This lets you start luakit from the build directory, using the config and libraries within the same.

The `USE_LUAJIT=1`, `PREFIX=/path`, `DEVELOPMENT_PATHS=1`, `CC=clang`
build options do not conflict. You can use whichever you desire.

## Installing

To install luakit run:

    sudo make install

The luakit binary will be installed at:

    /usr/local/bin/luakit

And configs to:

    /etc/xdg/luakit/

And the luakit libraries to:

    /usr/local/share/luakit/lib/

To change the install prefix you will need to re-compile luakit (after a
`make clean`) with the following option:

    make PREFIX=/usr
    sudo make PREFIX=/usr install

## Use Luakit

Just run:

    luakit [URI..]

Or to see the full list of luakit launch options run:

    luakit -h

## Configuration

The configuration options are endless, the entire browser is constructed by
the config files present in `/etc/xdg/luakit`

There are several files of interest:

 * rc.lua      -- is the main config file which dictates which and in what
                  order different parts of the browser are loaded.
 * theme.lua   -- change fonts and colours used by the interface widgets.

Just copy the files you wish to change (and the rc.lua) into
`$XDG_CONFIG_HOME/luakit` (defaults to `~/.config/luakit/`) and luakit will
use those files when you next launch it.

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

## HiDPI Monitor Configuration

If you have a HiDPI monitor (> 1920x1080) and find that web pages are too small,
you can change the `webview.zoom_level` on the settings page (luakit://settings/)
to 150 or 200 as per your taste.

## Uninstall

To delete luakit from your system run:

    sudo make uninstall

If you installed with a custom prefix remember to add the identical prefix
here also, example:

    sudo make PREFIX=/usr uninstall

## Reporting Bugs

Please use the bug tracker at:

  https://github.com/luakit/luakit/issues

## IRC

Join us in `#luakit` on the `irc.oftc.net` network.
