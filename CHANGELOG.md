# Changelog

## [Unreleased]

### Migrating from version 2017-08-10

 1. Remove the two `if unique then ... end` blocks from your `rc.lua`.
 2. Add `require "unique_instance"` to your `rc.lua`, before all other `require` statements.
 4. Remove all configuration files except `rc.lua` and `theme.lua`. Any changes to `globals.lua`
    need to be migrated to `rc.lua` and changed to use the `settings` API.

### Added

 - Added `luakit.install_paths` table. `luakit.install_path` is now deprecated.
 - Added `Control-Y` readline binding.
 - Added ability to control whether links from secondary instances open in a new window.
 - Added `luakit.resource_path` property to control where luakit searches for resource files.
 - Added `lousy.util.find_resource` function.
 - Added `scroll` signal.
 - Added ability to bind actions to webview scroll events.
 - Added ability to set the default zoom level.
 - Added `webview` widget `"permission-request"` signal.
 - Added `webview` widget `hardware_acceleration_policy` property.
 - Added `webview` widget `allow_file_access_from_file_urls` and `allow_universal_access_from_file_urls` properties.
 - Added `settings` module and APIs. This replaces the `domain_props` module.
 - Added `tablist.always_visible` setting.
 - Added `utf8.len` (same as `string.wlen`) and `utf8.offset` methods.

### Changed

 - It is no longer necessary to add bindings to tables with `lousy.bind.add_binds()`.
 - Readline bindings have been moved to `readline.lua`.
 - Readline bindings are now automatically bound when the input bar is visible.
 - Unique instance support has been moved to `unique_instance.lua`.
 - The `image` widget now uses `luakit.resource_path` to locate local files.
 - The log viewer now shows errors logged by a user-defined rc.lua failing to load.
 - Luakit will now remove its IPC socket file before restarting.
 - The editor command now defaults to using `xdg-open` to edit files.  The `default` builtin
   command has been renamed `autodetect`.
 - Changed `luakit://introspector/` to `luakit://binds/`.

### Removed

 - Removed `domain_props` module. It is replaced by the `settings` module and its APIs.
 - Removed all configuration files except `rc.lua` and `theme.lua`.
 - Removed `enable_private_browsing` webview property.

### Fixed

 - Fixed <luakit://help/> not finding documentation with custom DOCDIR
 - Various minor documentation fixes.
 - Fixed `Control-Scroll` and `Shift-Scroll` key bindings not working with smooth scrolling.
 - Fixed inability to switch focus between web page elements with `Tab` and `Shift-Tab`.
 - Fixed log page bug when logging messages with newlines.
 - Fixed `Up` and `Down` keybindings being broken on completion menu.
 - Fixed hardcoded path to luakit icon.
 - Fixed luakit:// pages not working and spewing errors when not using LuaJIT.
 - Fixed thumbnail hinting not retrieving thumbnail links correctly.
 - Fixed inability to bind `Modifier-Minus`.
 - Fixed readline handling of wide characters.

## [2017-08-10]

 - Required WebKitGTK+ version: 2.16+

### Breaking changes

 - Support for WebKitGTK+ versions older than 2.16 has been removed.
 - It is no longer possible to override built-in luakit modules with Lua
   files in one's personal configuration directory.
 - The configuration files `binds.lua` and `modes.lua` have become built-in luakit modules.
   Configuration files named `binds.lua` or `modes.lua` will not be loaded. Any custom
   bindings should be moved to `rc.lua`.

### Added

 - New `history.frozen` API allows temporarily freezing history collection.
 - New `lousy.widget.zoom` statusbar widget: shows current page zoom level.
 - Added `log` signal, emitted whenever a message is logged.
 - New `widget.is_alive` property. Can be accessed even if the widget has been destroyed.
 - Added `luakit://log/` chrome page: displays log messages.
 - Added status bar widget that notifies of any Lua warnings or errors.
 - Added migration, quick-start, and files and directories guides to documentation.
 - Added frequently-asked questions to documentation.
 - Added `luakit.wch_upper` and `luakit.wch_lower` key case conversion utility functions.
 - Added `formfiller.extend` function for extending the formfiller DSL.
 - Added context-aware command completion.

### Fixed

 - Fixed code-blocks in documentation being formatted incorrectly.
 - Fixed incompatibility of `editor.lua` with urxvt.
 - Fixed slow performance while beginning a search.
 - Fixed `lousy.util.table.join` merging tables in unpredictable order.
 - Fixed `image_css` raising errors on page zoom in/out.
 - Worked around `image_css` breaking slightly when using non-1.0 zoom_level.
 - Fixed sessions failing to save with a mix of tabs and private tabs.
 - Worked around webview widgets self-focusing on click.

### Changed

 - `editor.lua` now uses substitution strings, rather than `global` to determine which editor to open.
 - `open_editor.lua` now uses `editor.lua` rather than always using `xdg-open`.
 - `--log` can now set different log levels for different modules, similarly to `mpv`.
 - Documentation now has inter-page references.
 - The adblock page-blocked page now has a "Continue anyway" button.
 - Serializing Lua functions now includes their upvalues.
 - `adblock` and `styles` now log the directory searched for files.
 - `<ctrl-a>` and `<Ctrl-x>` bindings now take an optional count.
 - Luakit's IPC socket files are now opened in `/tmp/`.
 - Luakit now checks for accidental use of DEVELOPMENT_PATHS.
 - IPC endpoints' `emit_signal()` method now accepts a webview ID as its first argument, as well as a webview.
   This specifies a single destination for the IPC call.
 - `modes.add_binds()` now verifies that modes with the given names already exist, to guard against typos.
 - Scrolling keybinds now take a count.

### Contributors to this release:

 - Aidan Holm    (150 commits)
 - gleachkr      (10 commits)
 - Zhong Jianxin (4 commits)
 - Stefan Hagen  (3 commits)
 - Aric Belsito  (1 commit)
 - Ygrex         (1 commit)

## [2017-07-26]

 - Required WebKitGTK+ version: 2.14+
 - A relatively recent version of GTK+ 3 is required; some features are not available on older versions.

### Added

#### Adblock module

The adblock module previously available at <https://github.com/luakit/luakit-plugins>
has been included into the main luakit repository, with the following changes:

 - Ported adblock module to use WebKit 2 compatible APIs. This breaks compatibility with WebKit 1.
 - Added color-coding to adblock filter list status indicator.
 - The Adblock chrome page CSS has been updated to be more consistent with other luakit chrome pages.
 - An enable/disable button has been added to the Adblock chrome page.
 - The adblock chrome page has received several other refactors and improvements.
 - Adblock no longer blocks ads on local files (pages on the `file://` scheme).
 - Adblock no longer blocks data URIs for performance reasons.
 - Added links for quickly enabling/disabling filter lists to adblock chrome page.
 - Made `adblock.enabled` writeable, and removed `adblock.state()` function.
 - Adblock now blocks pages from being loaded until all filter list rules are fully loaded.
 - Adblock now enables newly-added filter lists by default.
 - Fixed a bug where luakit would not start if the adblock subscriptions file was missing.
 - Fixed broken `:adblock-reload` command.
 - Improved the consistency and formatting of adblock log messages.
 - Fixed a bug where the adblock subscriptions file would become corrupted.
 - Adblock simple mode has been removed.
 - Fixed parsing of adblock filter list rules containing '#'.
 - Fixed a bug where adblock would incorrectly block URIs on many domains, due to an design flaw.
 - Adblock now displays an error page when the adblock module blocks a page navigation.
 - Improved filter list rule length and ignore count calculation.
 - Added several optimizations for rule matching that significantly improve performance.

See also:

 - <luakit://help/doc/modules/adblock.html>
 - <luakit://help/doc/modules/adblock_chrome.html>

#### Error pages

A new module, `error_page.lua`, allows customization of luakit error
pages, such as those displayed when a page fails to load.

 - Luakit error pages are now displayed with a nicer interface, provided by `error_page.lua`
 - Chrome page errors are now displayed with the `error_page.lua` module interface.
 - Error pages now show information about the current proxy, as unintended proxy use can be responsible for page load failures.
 - Error pages can now be customized with user CSS.

See also:

 - <luakit://help/doc/modules/error_page.html>

#### User styles

A new module, `styles.lua`, supports user stylesheets with
`@-moz-document` sections. User stylesheets from <https://userstyles.org> are
supported.

 - Luakit now automatically detects and parses user stylesheets on startup.
 - Added support for enabling/disabling user stylesheets immediately, without refreshing the page.
 - Added the `:styles-list` command to display the user stylesheets menu.
 - Added the `:styles-reload` command to reload all user stylesheet files from disk.
 - Removed the site-specific `user_stylesheet_uri` interface.

See also:

 - <luakit://help/doc/modules/styles.html>

#### Other new modules

 - `open_editor.lua`: Adds support for editing text areas and input fields in an external text editor.
 - `newtab_chrome.lua`: Adds support for customizing the new/blank tab page (`luakit://newtab/`) with HTML and CSS.
 - `image_css.lua`: Improves how images are displayed by WebKit.
 - `vertical_tabs.lua`: Displays tabs in a vertical tab bar to the left of the tab content.
 - `referer_control_wm.lua`: Adds support for blocking the `Referer` header on cross-origin requests.
 - `viewpdf.lua`: Adds support for automatically viewing downloaded PDF files.

#### New APIs

Core APIs:

 - Added `luakit.process_limit` to control the maximum number of web processes.
 - Added `luakit.options` and `luakit.webkit2` properties.
 - Added `lousy.util.table.filter_array()` and `lousy.util.lua_escape()`.
 - Added luakit spell checking API. A suitable language to check spelling with is automatically detected.
 - Added website data retrieval and removal APIs.
 - Added user stylesheet APIs, used by `styles.lua`. Stylesheet objects can be created from Lua code and enabled/disabled for individual `webview` widgets.
 - Added request API. This supports handling custom URI scheme requests asynchronously.
 - Added `msg` logging library. This replaces the `info()` and `warn()` functions.
 - Added more log levels. Luakit now has `fatal`, `error`, `warn`, `info`, `verbose`, and `debug` log levels.
 - Added `regex` class, to provide JavaScript- and PCRE-compatible regular expressions.
 - Added `lousy.pickle` library for Lua table serializing.
 - Added missing `remove_signals` method to Lua objects.
 - Added `soup.cookies_storage` to control the path to the cookies SQLite database.
 - Added IPC endpoint and web module APIs.
 - Added API for registering Lua functions accessible from JavaScript.
 - Added API for intercepting and modifying outgoing requests.

New widget APIs:

 - Added `drawing_area`, `spinner`, `image`, `overlay` widgets.
 - Added unique IDs to `window` widgets.
 - Added widget `parent`, `focused` properties.
 - Added widget `"resize"` signal.
 - Added `"mouse-enter"` and `"mouse-leave"` signals to `eventbox` widget.
 - Added `window.ancestor()` method to retrieve the `window` widget that a given widget is contained in.
 - Added support for getting/setting `scrolled` widget scroll position and scrollbar settings.
 - Added support for displaying tooltips over widgets.
 - Added support for customizing individual widgets with GTK 3's CSS support.
 - Added `nrows()` getter to `lousy.widget.menu` widget instances.

New webview APIs:

 - Added `webview` widget properties `editable` and `is_playing_audio`.
 - Added `webview.modify_load_block()` API. This allows Lua code to suspend page load operations.
 - Added `webview` widget `private` property.
 - Added `webview` widget `"crashed"` and `"go-back-forward"` signals.
 - Added APIs to get the web process ID of `webview` widgets and the current web extension ID.
 - Added APIs to save/restore the internal state of a `webview` widget.
 - Added `"enable-scripts"`, `"enable-styles"`, `"enable-userscripts"` signal APIs to customize module behavior for individual `webview` widgets.
 - Added signal for tab save decisions.

#### Miscellaneous

 - Added `globals.page_step` to control the size of the scrolling step.
 - Added the `:tabdetach` command to detach a tab into a separate window. The tab is not destroyed and recreated, so any ongoing work in the tab will not be lost.
 - Added build options to specify more system paths, easing installation and packaging for a variety of systems.
 - The build system now uses the correct Lua/LuaJIT binary for build scripts.
 - A testing framework has been added that supports asynchronous tests.
 - Automatically generated documentation is now included in luakit installations.
 - Mode and bind information is now included in generated documentation.
 - The documentation index now displays which modules are loaded.
 - Added support for private browsing on a per-tab basis.
 - Added support for defining search engines as Lua functions. This allows more complex input, such as specifying multiple fields in technical search engines.
 - Added support for getting/setting the text alignment of `label` widgets.
 - Added support for getting/setting the divider position of `paned` widgets.
 - Added support for getting/setting the background color of `box` and `label` widgets.
 - Added support for getting the width and height of widgets.
 - Added support for setting the minimum width and height of widgets.
 - Added basic profile support.
 - Added options to control externally editing text files.
 - Added a crash recovery session that is automatically saved regularly.
 - Improved the formatting of error tracebacks. Improved tracebacks are now used for `debug.traceback()` as well as error messages.
 - The `xdg` module now has new properties `system_data_dirs` and `system_config_dirs`.
 - The `xdg` module now ensures that the paths it returns do not end in a trailing slash, regardless of how the relevant environment variables are set.

### Changed

 - User scripts can now run even when JavaScript has been disabled. They now use an isolated script world inaccessible from the web page.
 - User scripts now show an error message on failure.
 - The status bar and the tab bar are now hidden when luakit is fullscreen.
 - GLib logs are now funneled through luakit's log system.
 - Subsequent lines in log messages with multiple lines are now indented.
 - When the input bar is shown, the status bar is hidden. This is to prevent webview resizes causing performance issues for some users.
 - Error messages within the luakit window can now be selected with the mouse and copied.
 - An error message is now shown when the formfiller module fails to fill a form.
 - The undoclose menu is now automatically closed when there are no more menu entries.
 - Closed tabs are now saved in the luakit session file, so undoclose now works across sessions.
 - Individual tab history is now saved in the luakit session file.
 - The `"navigation-request"` signal now includes the reason for the navigation.
 - Plugin errors, load cancel errors, and frame load errors are now ignored.
 - Search behavior across multiple tabs has been improved.
 - Idle callback functions that throw errors are now removed.
 - Follow mode now has a new label maker: `trim()`.
 - `w:run_cmd()` no longer adds the given command to the mode command history.
 - A compile-time check for older WebKit versions has been added.
 - All uses of `module()` in Lua code have been removed.
 - Most variables have been made non-global.
 - A follow mode heuristic has been added for links that contain a single image element.
 - Luakit no longer uses a custom luakit-specific useragent string. This mproves site compatibility with sites such as Google Maps and decreases user fingerprint.
 - All binds now have accompanying descriptions.
 - Chrome pages now have consistent CSS and page style.
 - `introspector.lua` has been renamed to `introspector_chrome.lua` for consistency with other chrome page modules.
 - Added a help chrome page.
 - Luakit now gives a full backtrace on startup failure.
 - Formfiller mode now uses visual selection to add forms to the formfiller file.
 - Formfiller mode now uses Lua patterns instead of JavaScript regular expressions.
 - Widget getters and setters now verify that the widget is still valid.
 - The widget `"created"` signal now has the new widget as an argument, making it much more useful.
 - Accessing unknown widget properties now prints a warning.
 - A developer warning is now printed if the web extension binary is not found.
 - Luakit is now completely restarted if loading a configuration file fails.
 - Luakit no longer shows follow hints for invisible elements.
 - The `:lua` command now has an implicit variable `w`, the current window table. This is for convenience.
 - The `:lua` command can now evaluate expressions as well as execute statements.
 - A `resources/` directory tree has been added.
 - Tabs now have a themable hover color.
 - The default set of key bindings now includes bindings for number pad keys.
 - A small margin has been added to the status bar.
 - The formfiller now supports automatically filling forms when pages have finished loading. This is useful for automatically logging in to certain sites.
 - Added `export_funcs` parameter to `chrome.add()`.
 - Key presses that do not prefix any valid bindings are now ignored. This prevents key bindings being ignored because the input buffer has filled up with garbage.
 - Follow mode now allows focusing inputs by their value (the text within them) and focusing empty inputs by their placeholder text.
 - The `:javascript` command now has improved error handling.
 - `luakit://` URIs are no longer added to history.
 - Download objects now have the `allow_overwrite` property.
 - Performance of the `ssl` widget has been improved.
 - The downloads chrome page now displays file size statistics.
 - Trailing newlines are now stripped from log messages.
 - The `webview` widget scrolling interface has been modified for compatibility with WebKit 2.
 - The API for retrieving page source is now asynchronous.
 - Follow mode now strips the leading `mailto:` from email links, and allows the user to configure whether to ignore case in or not.
 - Changed the `label` widget `width` property to `textwidth`.
 - The `socket` widget is no longer destroyed upon plug disconnect.
 - `go_next_prev.lua` now uses an improved heuristic for guessing page relationship.
 - Other minor changes.

### Removed

 - All support for building with WebKit 1 has been removed.
 - All support for building with GTK+ 2 has been removed.
 - The `"cookie-changed"` signal has been removed, due to a WebKit API limitation.
 - The download creation API has been removed, due to a WebKit API limitation.
 - The global `info()` and `warn()` functions have been removed in favor of the `msg` library.
 - The `:viewsource` command is removed, and replaced with `:view-source`.
 - The `WITH_UNIQUE` build option has been removed, as `libunique` is no longer used.
 - The `webview` widget `show_scrollbars` property has been removed. It is replaced by the `hide_scrollbars.lua` module.
 - The default mouse forward/backward bindings have been removed.
 - Support for `webview.init_funcs` and `window.init_funcs` has been removed. There are replacement signals that serve the same purpose.

### Fixed

 - Changed outdated `luaL_reg` to `luaL_Reg`.
 - Fixed a desktop file issue preventing setting luakit as default browser for GNOME.
 - Fixed evaluated scripts appearing in the web inspector debugger tab.
 - Fixed `find_config()` assuming the system configuration is located at `/etc/xdg/`.
 - Fixed luakit window losing initial focus, preventing some key bindings from working.
 - Fixed luakit icon having incorrect permissions.
 - Removed use of some deprecated functions.
 - Fixed completion for hyphenated commands not working.
 - Fixed bind activation for hyphenated commands not working.
 - Fixed completion menu not closing.
 - Fixed a segmentation fault when removing a non-present signal from an object.
 - Fixed issues in how follow mode handled clicking on `<input>` elements.
 - Fixed broken conditional in `noscript.lua`.
 - Fixed a bug where calling `view:load_string()` from `load_failed_cb()` would cause reload loops.
 - Fixed a bug where the `"link-unhover"` signal was not being emitted.
 - Fixed `click()` in `follow.lua` to trigger more events to work around glitches.
 - Fixed `go_up` breaking on `file://` URIs.
 - Fixed PKGBUILD issues.
 - Fixed contributor emails.
 - Fixed use-after-free of destroyed widgets.
 - Fixed incorrect chrome page header z-index.
 - Fixed a bug where the `bin` widget `child` property always returned itself.
 - Fixed a bug in URI `__add` operation.
 - Fixed long source paths appearing in Lua log output.
 - Fixed formfiller silently failing to add forms.
 - Fixed formfiller radio button and checkbox clicking behavior.
 - Fixed errors when handling tabs with empty titles
 - Change context menu 'New Window' items to 'New Tab' items
 - Fixed a bug where `"property::textwidth"` signal was not emitted.
 - Fixed a bug where invalid color codes were silently ignored.
 - Fixed unstable behavior when creating widgets without a specified type.
 - Fixed design flaws where several modules would not work without JavaScript enabled.
 - Fixed the bookmarks chrome page missing pagination.
 - Fixed a bug where user scripts would fail to add CSS on pages without a `<head>` element.
 - Fixed a bug where quitting luakit through the window manager circumvented luakit's exit prevention system.
 - Fixed the `<` and `>` binds not wrapping around consistently.
 - Fixed a bug where the `"destroy"` signal would not be emitted for some widget types.
 - Numerous other fixes and performance improvements.

### Contributors to this release:

 - Aidan Holm            (1585 commits)
 - Jenny Wong            (71 commits)
 - Mason Larobina        (17 commits)
 - Grégory DAVID         (8 commits)
 - karottenreibe         (7 commits)
 - Ygrex                 (6 commits)
 - Robbie Smith          (4 commits)
 - Michishige Kaito      (4 commits)
 - Ambrevar              (3 commits)
 - Yuriy Melnyk          (2 commits)
 - Plaque-fcc            (2 commits)
 - loblik                (2 commits)
 - Daniel Bolgheroni     (2 commits)
 - windowsrefund         (1 commit)
 - walt                  (1 commit)
 - Robbie                (1 commit)
 - Peter Hofmann         (1 commit)
 - Nuno Vieira           (1 commit)
 - nmeum                 (1 commit)
 - Kane Wallmann         (1 commit)
 - Jasper den Ouden      (1 commit)
 - gleachkr              (1 commit)
 - feivel                (1 commit)
 - eshizhan              (1 commit)
 - donlzx                (1 commit)
 - Bartłomiej Piotrowski (1 commit)
 - Babken Vardanyan      (1 commit)
