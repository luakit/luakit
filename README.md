# Luakit

luakit is a fast, light and simple to use micro-browser framework
extensible by Lua using the WebKit web content engine and the GTK+
toolkit.

### Don't Panic!

You don't have to be a developer to use luakit on a daily basis. If you
are familiar with vimperator, pentadactyl, jumanji, uzbl & etc you will
find luakit behaves similarly out of the box.


## Requirements

 * GTK+ 3
 * Lua 5.1 or LuaJIT 2
 * lfs (lua file system)
 * webkit2gtk
 * sqlite3
 * gstreamer (for video playback)


## Installing

Luakit is available on most Linux Distributions and BSD system via their
package managers. A few examples below:

 * Debian/Ubuntu: apt-get install luakit
 * Gentoo: emerge luakit
 * Guix: guix install luakit
 * Arch: pacman -S luakit
 * FreeBSD: pkg install luakit
 * OpenBSD: pkg\_add luakit
 * Void Linux: xbps-install luakit

Packaging status:

[![Packaging Status](https://repology.org/badge/vertical-allrepos/luakit.svg?header=)](https://repology.org/project/luakit/versions)

## Installing from source

Make sure you system fulfills the requirements listed above, then
install luakit with the following commands:

    $ git clone https://github.com/luakit/luakit.git
    $ cd luakit
    $ make
    $ sudo make install

Uninstall with:

    $ sudo make uninstall

Note: If you are on BSD, you might need to use `gmake`.

## Use Luakit

Just run:

    $ luakit [URI..]

Or to see the full list of luakit launch options run:

    $ luakit -h

Luakit works with vim-style bindings. To find out more, type `:help`
within luakit.


## Configuration

Luakit configuration files are written in `lua`. This means you can
program within the config files, which make the configuration options
endless.

There are three ways to customize luakit.

**1. within luakit**

After starting luakit, type `:settings`. This page shows you webkit
engine related settings.

**2. userconf.lua**

Create a file called `$HOME/.config/luakit/userconf.lua`. Then add
your configuration there. Configuration in this file supersedes
configuration set in `:settings`

**3. copy rc.lua**

The most powerful customization is to copy `rc.lua` from
`/etc/xdg/luakit/rc.lua` to `$HOME/.config/luakit/rc.lua`

When this file is found, `/etc/xdg/luakit/rc.lua` is ignored.

Be informed that when luakit is updated, you may need to adapt changes
from `/etc/xdg/luakit/rc.lua` to your own copy.


## Colors and fonts

Copy the `/etc/xdg/luakit/theme.lua` to
`$HOME/.config/luakit/theme.lua`. You can change fonts and colors there.


## Development Information

This section contains information about the compile and testing process.

Luakit honors the PREFIX variable. The default is `/usr/local`.

    $ make PREFIX=/usr
    $ sudo make PREFIX=/usr install

Notes:
  - You also have to set the PREFIX when uninstalling.
  - If you want to change PREFIX after a previous build, you need to `make clean` first.

Luakit uses `luajit` by default, to use `lua` you can turn off luajit
with:

    $ make USE_LUAJIT=0

To build with local paths (interesting for package maintainer and
contributers). You may wish to build luakit with:

    $ make DEVELOPMENT_PATHS=1

This lets you start luakit from the build directory, using the config
and libraries within the same.

Take a look at `config.mk` for more options.

If you made changes and want to know if luakit is still working properly,
you can execute the test suite with:

    $ make test


## Tips and fixes:

**Video playback**

If you're having issues with video playback, this is often related to
buggy graphic drivers. It often helps to set LIBGL\_DRI3\_DISABLE before
starting luakit:

    $ export LIBGL_DRI3_DISABLE=1

**Webkit process limit**

Since Webkit 2.26, the webkit engine used in luakit is creating a new
process for each tab. This has the benefit that a webkit webview crash
will only crash one tab. The downside is lower performance and increased
memory use.

If you value speed over stability, you can ask webkit to use one process
for all tabs by setting WEBKIT\_USE\_SINGLE\_WEB\_PROCESS before
starting luakit:

    $ export WEBKIT_USE_SINGLE_WEB_PROCESS=1

**HiDPI Monitor Configuration**

If you have a HiDPI monitor (> 1920x1080) and find that web pages are
too small, you can change the `webview.zoom_level` on the settings page
(luakit://settings/) to 150 or 200 as per your taste.


## Reporting Bugs

Please note that most rendering related issues come from the used webkit
engine and can not be fixed by luakit. If you think your issue is luakit
related, please use the bug tracker at:

  https://github.com/luakit/luakit/issues

Coming from a very old luakit version? Look at the
[MIGRATION](MIGRATE.md) document.


## IRC

Join us in `#luakit` on the `irc.oftc.net` network.

