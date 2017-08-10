@name Quick-start guide

# Quick-start guide

## Using Luakit

If you've used browsers like vimperator, or vimium, you'll find yourself
right at home; most if not all luakit actions are available via keyboard
commands.

Just run:

    luakit [URI..]

Or to see the full list of luakit launch options run:

    luakit -h

### Opening the help page

To open the internal help page, press `<F1>`. From there, you can open
the introspector to view current keybindings or open the included API
documentation.

### Switching to command mode

Many common operations in luakit, such as typing and opening a URL, involve the
use of _commands_. This is done by switching to command mode, typing the
command, and pressing `<Enter>`.

To switch to command mode, press `:` (i.e. `<Shift-;>`), and the command
bar will appear at the bottom of the window. In the remainder of this document,
commands will be written prefixed by a `:`; so `:open` means to first press
`:`, and then type `open`.

### Go to a URL in the current tab

Type `:open` followed by a space and the URL to navigate to, and press `<Enter>`.
For example, to open the luakit website, type `:open www.luakit.org` and then
press press `<Enter>`.

_Shortcut_: press `o` to switch to command mode with `open ` already typed.

### Search

Press `/`, and type your search query, e.g: `/luakit`. Press `<Enter>`
to finish typing your search query and switch back to normal mode.
While in normal mode with highlighted search results, press `n` to
jump to the next search result, and `N` to jump to the previous one.

### Opening, closing, and undo-closing tabs

Try the following steps in order:

1. Run `:tabopen luakit.org`, and wait until the page finishes loading.
2. Press `d`, and the new tab will close.
3. Press `u`, and the just-closed tab will reappear.

### Scrolling in a web page

There are several different keys to scroll a webview:

 - The arrow, page up/down, and home/end keys all work as one would expect.
 - The `h`, `j`, `k`, `l`, `gg`, and `G` key bindings all scroll in a vim-like manner.
 - The `<Control-e>`, `<Control-y>`, `<Control-d>`, `<Control-u>`,
   `<Control-f>`, and `<Control-b>` keys all scroll vertically by various
   amounts.

### Bookmarks

 - Press `B` to bookmark the current page.
 - Press `gb` or `gB` to open the bookmarks page in the current tab or a
   new tab, respectively.

## Configuration

### Beginning a custom configuration

Luakit loads only one configuration file: `rc.lua`; that's the entry
point for loading all the other configuration files and modules one might need,
which are all written in Lua.

Any configuration file can load ("require") another Lua configuration file by
specifying its name. When looking for a `.lua` file by name, luakit
checks the following locations, in the order specified here:

1. The current directory.
2. System directories for Lua files.
3. Luakit's collection of included modules (`/usr/share/luakit/lib/`).
4. The user's personal luakit configuration directory (`/home/$USER/.config/luakit/`).
5. The system configuration directories (`/etc/xdg/luakit/`).

When launching luakit after a fresh install, it will look for the file
`rc.lua` in these directories in order. If there is no such file in the
personal luakit configuration directory, luakit will fall back to the
global `/etc/xdg/luakit/rc.lua` file.

To list the directories luakit will search when loading modules, run the
following command:

    :lua w:notify(package.path:gsub(";","\n"))

To customize luakit, we can define our own configuration by creating a
`rc.lua` file in the `/home/$USER/.config/luakit/` directory. The easiest
way of creating a proper functional configuration is copying the global
configuration file:

    mkdir -p ~/.config/luakit/
    cp /etc/xdg/luakit/rc.lua ~/.config/luakit/

Now we can modify the configuration file, and any changes will take effect
after restarting luakit. The official `rc.lua` file might be changed in
future releases, however, and if we modify our copy
extensively, it may be difficult to merge any changes to the configuration
file into our setup. One way of minimizing the impact of future upgrades
is to add only a single line like the following to our personal copy of
`rc.lua`:

    require "userconf"

This should be added just before the end of the "User script loading" section.
Now we can create a new file, `/home/$USER/.config/luakit/userconf.lua`,
where we can introduce all the changes we want; these changes will not have to
be merged with any future changes to the `rc.lua` file.

### Changing the theme and other settings

Apart from `rc.lua`, there are some other configuration files of interest.

 - `theme.lua` specifies the fonts and colours used by the interface widgets.
 - `globals.lua` contains global options like the size of the scroll
   and zoom steps, the default window size, the useragent string, search
   engines, and more.

Just copy the files you wish to change into your personal luakit configuration
directory, and luakit will load those files when you next launch it.

### Changing key bindings

To change key bindings, use @ref{modes/add_binds} and @ref{remove_binds}
to add and remove key bindings.

<!-- vim: et:sw=4:ts=8:sts=4:tw=79 -->
