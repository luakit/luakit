# luakit 2012.03.25

The focus for this release has been a re-work of the Lua API to make it more
human readable and Lua-like.

We also have `WebKitWebInspector` support for the first time and several other
performance and stability improvements.

## Lua API Changes:

* New wrappers for `GtkVPaned`/`GtkHPaned` widgets (construct with `"vpaned"`
  & `"hpaned"`).
* Box widgets `:pack_{start,end}` methods replaced with `:pack(widget [, {
  options }])`.
* All `GtkBin` widgets now have a settable/gettable `.child` property.
* All `GtkContainer` widgets now have `.children` property. Removed
  `:get_children` methods where implemented.
* Replaced `label` widget `:set_{alignment,padding}` methods with `.align` and
  `.padding` properties. Set with `label.align = { x = 0.5, y = 1.0 }`.
* Replaced `label` widget `:set_width` method with `.width` int property.
* Removed `notebook` & `entry` widgets `:append` methods. Made `:insert`
  methods work like `table.insert` (append when no index arg given).
* Replaced `webview` widget `:{get,set}_scroll_{horiz,vert}` methods with
  `.scroll` table with settable/gettable `.x .y .xmax .ymax .xpage_size
  .ypage_size` properties.
* Replaced `luakit.{set,get}_selection` functions with `.selection` table with
  settable/gettable `.primary .secondary .selection` properties. Clearing
selections is simple with `luakit.selection.primary = nil`.
* Replaced `socket:add_id` method with `.id` property.
* Renamed `socket.is_plugged` to `.plugged`.
* Replaced `notebook:atindex(idx)` method with `notebook[idx]`.
* New function `os.abspath(path)` turns relative paths into absolute paths.
* All `WebKitWebView` and `WebKitWebSettings` properties are now set/get
  directly on the `view` instance. For example:
  `view:set_property("enforce-96-dpi", true)` is now `view.enforce_96_dpi =
  true`.
* Similarly the `soup:{get,set}_property` functions have been removed and
  properties are now set directly on the `soup` module.
* Replaced `window:set_screen` method with settable/gettable `.screen`
  property.
* Replaced `window:{fullscreen,unfullscreen,maximize,unmaximize}` methods with
  settable/gettable `.fullscreen .maximized` properties.
* Replaced `webview:{get,set}_view_source` method with `.view_source`
  property.
* Replaced `luakit.webkit_{major,micro,minor}_version` with concatenated
  "major.micro.minor" version string. Likewise with
`luakit.webkit_user_agent_{major,minor}_version`.
* Removed `luakit.get_special_dir(ATOM)` function. Added small `xdg` module
  with `.{cache,config,data,desktop,documents,download,..}_dir` fields
  pointing to their respective `$XDG_???_DIR` paths.
* Add settable `window.urgency_hint` property.
* Add settable/gettable `.visible` property to all widgets.
* Add `webview:{show,close}_inspector` to show/hide the `WebKitWebInspector`.

## Luakit Library Changes:

* Formfiller now stores form data in new Lua DSL format. To automatically
  convert old forms to new format use `extras/convert_formfiller.rb`.
* Add bookmark follow mode `;B` and quickmark follow mode `;M[a-zA-Z0-9]`.
* Add `follow.styles.upper` which makes all hints upper-case and the matching
  process case-insensitive.
* Add multi-download follow mode `;S`.
* Bugfix: when toggling noscript plugins on a page with no entry.
* Get homepage with `globals.homepage` in `binds.lua`. Allows user to edit
  homepage anywhere in their `rc.lua`.
* Several follow & formfiller bugs fixed.
* Print `info()` messages to `stdout`.
* Window `.view` property dynamically points to the current visible webview
  widget in the notebook of that window. Also caches result cutting out a huge
  number of unnecessary calls to the old `w:get_current()`.
* Add `"(KHTML, like Gecko)"` to the default useragent to make Google Plus and
  other websites work with luakit out of the box.
* Reduce useragent 'identifiability', only give a luakit version if it matches
  the `YYYY.MM.DD` format.
* Added vim's `:noh[lsearch]` command to un-highlight the last search results.
* When follow hints are on links that span multiple lines only hint the first
  rect region.
* `domain_props` table updated to use the new `view.<property-name>` form.
* Store `session` file in `xdg.data_dir`. As per XDG spec: cache dir is only
  for non-essential files.
* Bugfix: Escape `lousy.util.mkdir` paths.

## C Source Changes:

* New `luaH_rawfield` function returns `1` if given table field is non-`nil`.
* New `token_tostring` function returns the string literal for each
  `luakit_token_t` token.
* New `luaH_{class,object}_property_signal` functions give us simple emitting
  of class and object `"property::name"` signals.
* Use `Content-Type` soup header to determine the mime-type of
  `WebkitDownload` files.
* Pass `luakit_token_t` to widget constructor, index and newindex functions.
* Use `UNUSED(arg)` macro to silence compiler warnings about unused arguments.
* Refactor GObject property setting/getting functions to use `luakit_token_t`
  tokens directly. Faster lookups, cleaner code.
* Get property signal names from `luakit_token_t` tokens & add class property
  signal emitting functi
* Bugfix: Make `luaH_unique_is_running` ping the other instance to ensure it
  is running/responding. Several reports of `unique.is_running()` returning
  true when it clearly shouldn't causing luakit to quit.
* Add missing `javascriptcoregtk-1.0` package after `WebKitGtk+` split into
  two packages.
* Move more common functions, signal handlers, index and newindex properties
  to `widgets/common.{c,h}`.
* Use `GOBJECT_TO_LUAKIT_WIDGET` macro to convert GObject into `widget_t*`
  widget struct in all signal callbacks.
* And move the `g_object_set_data` call which saves the `widget_t*` pointer in
  each GObject to the `luaH_widget_set_type` function.
* Removed individual glib header includes (no longer supported).
* Remove the never used `luaH_hasitem`, `luaH_isloop` & `luaH_isloop_check`
  functions (from the awesomewm codebase).
