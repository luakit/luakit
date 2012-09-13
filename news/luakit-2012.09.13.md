# luakit 2012.09.13

## Overview

* Follow module refactored, ~1200% performance increase (from 250ms to 20ms
  @ 2500 hints).
* First release with `:help` command (`luakit://help`) which auto-documents the
  users key bindings. Also shows in which file each binding is defined and
  other goodies (click to open editor at line of bind definition, view
  callback function source in the browser). Also all bindings have been
  decorated with a description.
* Bookmarks moved to sqlite database.
* `luakit://history`, `luakit://bookmarks`, `luakit://downloads` pages all
  re-written after updates to the Lua JS API allowing modules to export
  Lua functions in the JavaScript global context.
* Sqlite3 bindings updated to allow binding query arguments.
* By default expire all session cookies after 1 hour (previous behaviour:
  keep all session cookies forever).
* Buttons to clear all history, history search results and selected history items.
* Fixed input field focusing issues.
* Support for Mac OSX.

## Shortlog

    Bartłomiej Piotrowski (1):
          Don't mark desktop file as executable.

    Ben Armston (9):
          Command to run given commands in new tab
          run_cmd function to enter_cmd and activate it
          tabdo command to run given command on each tab
          Fix method call
          window:each_tab iterates over the tabs sensibly
          Add tabduplicate command
          Allow tabd as an alias for tabdo
          tabfirst and tablast commands and bindings
          tabnext and tabprevious commands

    Dmitry Medvinsky (1):
          Fixes #62 web inspector detaching unexpectedly

    Johannes Schilling (1):
          Overwrite argv after initialization

    John Tyree (3):
          Update webkitgtk properties documentation link.
          Link directly to WebKitWebSettings page.
          Add page num to history uri

    Mason Larobina (147):
          Merge pull request #64 from johntyree/develop
          Eval "javascript:.." links on focused frame
          Merge pull request #67 from johntyree/develop
          Merge pull request #72 from Barthalion/develop
          Use Lua->C entry point as default JS source
          Remove useless functions in webview.methods table
          s/w:stop()/w.view:stop()/
          Update view:eval_js usage
          Duplicate history & hist position in `:tabduplicate` command
          Merge branch 'tab-commands' into develop
          Add Ben Armston to AUTHORS
          Add `:stop` command
          Add first luakit unit tests. Run with `make run-tests`
          Merge pull request #87 from vain/patch-1
          Merge pull request #91 from Plaque-fcc/develop
          Fix locale issues with w:scroll(), use x, xrel, xpage, ... fields
          Update mouse scroll binds
          Fix off-by-one error in command completion binds
          Use second column for cmd descriptions
          Allow optional lousy.bind.cmd description
          Re-tabulate cmds in binds.lua
          Add Jonas Höglund to authors file
          Merge branch 'cmd-desc' into develop
          JS can return Lua types and registered Lua functions can take JS args
          Add unit tests for webview registered functions & eval_js functionality
          Add missing error message and more registered func tests
          Update eval_js usage in follow, follow_selected & formfiller libs
          Make eval_js behave like pcall, returns `nil, err msg` on error
          Seamless type conversion from Lua tables <-> JS objects / arrays
          Forgot to free JSPropertyNameArrayRef on error
          Add eval_js `no_return` opt for loading JS where ret val/type is unknown
          Rewrite downloads{,_chrome} libs to use jQuery magic
          Bugfix: lua_next knows best
          Just emit number of running downloads in "status-tick"
          Performance edit, reduce amount of data crossing Lua<->JS boundary
          Make downloads_chrome lib look in luakit install path for jquery.js
          Add some simple speed reporting
          Had the assert_equal args reversed
          luaH_class_setup can setup classes which can only be created C-side
          Modify sqlite3 lib to compile SQL statements & bind values from tables
          Refactor luaH_sqlite3_exec
          Add new userdata object for compiled sqlite3 statements
          Use escape not encodeURI for filename anchor
          Add lunit/ to .gitignore
          luaH_rawfield returns lua type instead of 1
          Execute all statements in the SQL query given to db:exec
          Add some soup tests
          Refactor cookiejar.c & cookies.lua, remove checktimer, deletes session
          Missing add_binds after rebase
          Merge branch 'jquery-and-downloads' into develop
          Merge pull request #97 from grodzik/develop
          Refactor lib/history.lua to use compiled statements
          Allow users to change cookies.db/history.db path in their rc.lua
          Simplify chrome.lua & use load_string to print chrome func errors
          Add lousy.load function to load luakit resources from install dir
          Use lousy.load to load the jquery lib
          Remove invalid chars from chrome.add() handler names, both broken still
          Call init manually if idle_add callback hasn't had a chance to run
          Only need one d.status lookup
          Render luakit:// handler debug traceback in browser window
          luakit://history works again, still needs work
          eval_js calls in userscripts.lua do not return values
          Style luakit://history & search by domain
          Make sure cookies db handle open when needed
          Allow user to change cookies.db path
          Add simple sqlite bookmarks lib with full tagging support
          Comment out soup.ssl_ca_file test (highly system dependant)
          Merge branch 'develop' into chrome-upgrade
          Auto-delete orphaned tags when untagging/removing bookmark
          Display history item uri as title if title null
          find_tag returns tag row from database
          Add example in rc.lua for opening downloads with xdg-open
          Comment out 'new-window-decision' in webview.lua
          Refactor element creation in luakit://history & use em not px in style
          Remove unused compiled statement from history.lua
          luakit://bookmarks so far (tags are shown)
          Merge branch 'ymln/follow-optimization' into develop
          Readable color debug messages with relative timestamp & signal origin
          Merge branch 'develop' into chrome-upgrade
          Ensure luakit:// link has trailing slash in chrome lib
          Remove instant search, allow hist nav & `:history <term>` works again
          Prevent luakit://history from being added to the users history.db
          Add buttons to clear all history, hist results and or selected items
          Add pagination to luakit://history & custom limits
          Update buttons & uri fragment correctly in do_search
          First follow refactor
          Simplify mode setting
          Second wave of performance improvements
          Allow view:register_function to take specific frame argument
          Add remaining follow functionality from old follow lib
          Allow arguments to: w:set_mode(name, ...) -> mode.enter(w, ...)
          Only need to save width/height info
          Allow different patterns for hint label/text & add ;x, ;X binds
          No longer need unlink function
          Initial commit of luakit://help chrome page
          Probably helps if I add the lib/introspector.lua
          Update search engines, fix imdb redirect & -sourceforge +github example
          Remove platform specific debbugs search engine & use https by default
          Revert "No longer need unlink function" -- turns out we do
          Comment more bindings
          Call cleanup() in init() function
          Optimize follow_selected.lua javascript
          Forgot to save desc in any binds
          Format bind & mode descriptions with markdown
          Show callback function source code in luakit://help
          Update follow binding comments
          Fix links inside bind descriptions
          Merge branch 'develop' into introspector
          Read users globals.term & globals.editor in open_editor func
          Add :help command to open luakit://help
          Merge branch 'introspector' into develop
          Snaz up bookmarks display, edit bookmarks & markdown bookmark desc
          Hide all templates, notice some flashing while loading otherwise
          Refactor go_up.lua into native Lua code (and thanks LokiChaos)
          Allow complex "this -not -these" bookmark searching & search tags
          Fixes #117 link hints with absolute positions in non-absolute container
          Add follow pattern matching style to regex match label & text
          Only catch navigation policy signal when ignoring request
          Use parseInt instead of bookmark lookup. closes #122
          Show error traceback in statusbar
          KISS - Refactor bookmarks db & source to store keys in bookmark rows
          New luakit://bookmarks look and all missing functionality back in
          Default to http:// scheme in bookmark uris
          `:bookmark` command opens bookmarks page and edit dialog
          Merge branch 'bookmarks' into develop
          Forgot to remove hidden tag
          Update visual style of luakit://history to match bookmarks
          Simulate mouse clicks in go_next_prev when element doesn't have a href
          Update history sql query generation code
          Reduce title font size
          `:bookmark` with no args bookmarks current page
          Update history & bookmarks completion
          Set WebKitWebView size requests on parent scrolled window
          Add script to migrate bookmarks from old database schema
          Make luakit://bookmarks more compact, style bookmark desc
          Mark param unused
          Bug squash, argc is changed by g_option_context_parse
          Silence errors in `p` & `P` binds, notify no selection instead
          Use single `y` yank binding for uri
          Use strings to represent modifier state in binds.
          Spruce up config.mk, several more platform specific build options
          Refer to follow selectors/evaluators by name
          Stop jumping through hoops in follow JS loading
          Re-introduce the follow ignore key delay
          Fix webview focusing, prevent scrolled window from being focused
          Focus webview when entering insert mode
          Emit form-active, root-active signals from follow callbacks again

    Nathan Gass (3):
          Use gettimeofday instead of clock_gettime for portability.
          Remove --export-dynamic flag for Mac OSX.
          Also remove empty and unnecessary -Wl to compile again on debian.

    P. Hofmann (1):
          follow_selected: eval_js is gone from webview.

    Paweł Tomak (2):
          removed unneeded argument causing error with mutli profiles
          Removed unneeded 'for' loop in apply_form

    Peter Hofmann (1):
          Fixed typo in new cookie code.

    Plaque FCC (1):
          locale-dependent Lua 'tonumber()' behaviour.

    Steven Allen (1):
          Allow the user to redirect requests.

    Yuriy Melnyk (1):
          Optimize hint following

    firefly (1):
          Add command descriptions.

    kongo2002 (15):
          add commands/bindings for bookmarks
          modify :bookmark command to add tags
          adjust bookmark descriptions
          show bookmark ID in luakit://bookmarks/
          add basic search to luakit://bookmarks/
          adjust 'search' button style
          add 'delete' link to bookmarks chrome
          add delete functionality to bookmarks chrome
          remove id from bookmarks chrome
          refactor bookmark deletion
          add simple bookmarks completion
          bookmarks chrome: add tag removal
          show tag remove links on hover only
          readd bookmarks search
          readd bookmark removal in chrome
