/*
 * clib/luakit.c - Generic functions for Lua scripts
 *
 * Copyright © 2011 Mason Larobina <mason.larobina@gmail.com>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 */

#include "common/signal.h"
#include "clib/widget.h"
#include "clib/luakit.h"
#include "luah.h"

#include <stdlib.h>
#include <glib.h>
#include <gtk/gtk.h>
#include <sys/wait.h>
#include <time.h>
#include <webkit/webkit.h>

/* setup luakit module signals */
LUA_CLASS_FUNCS(luakit, luakit_class)

GtkClipboard*
luaH_clipboard_get(lua_State *L, gint idx)
{
#define CB_CASE(t) case L_TK_##t: return gtk_clipboard_get(GDK_SELECTION_##t);
    switch(l_tokenize(luaL_checkstring(L, idx)))
    {
      CB_CASE(PRIMARY)
      CB_CASE(SECONDARY)
      CB_CASE(CLIPBOARD)
      default: break;
    }
    return NULL;
#undef CB_CASE
}

/** __index metamethod for the luakit.selection table which
 * returns text from an X selection.
 * \see http://en.wikipedia.org/wiki/X_Window_selection
 * \see http://developer.gnome.org/gtk/stable/gtk-Clipboards.html#gtk-clipboard-wait-for-text
 *
 * \param  L The Lua VM state.
 * \return   The number of elements pushed on stack.
 */
static gint
luaH_luakit_selection_index(lua_State *L)
{
    GtkClipboard *selection = luaH_clipboard_get(L, 2);
    if (selection) {
        gchar *text = gtk_clipboard_wait_for_text(selection);
        if (text) {
            lua_pushstring(L, text);
            g_free(text);
            return 1;
        }
    }
    return 0;
}

/** __newindex metamethod for the luakit.selection table which
 * sets an X selection.
 * \see http://en.wikipedia.org/wiki/X_Window_selection
 * \see http://developer.gnome.org/gtk/stable/gtk-Clipboards.html#gtk-clipboard-set-text
 *
 * \param  L The Lua VM state.
 * \return   The number of elements pushed on stack (0).
 *
 * \lcode
 * luakit.selection.primary = "Malcolm Reynolds"
 * luakit.selection.clipboard = "John Crichton"
 * print(luakit.selection.primary) // outputs "Malcolm Reynolds"
 * luakit.selection.primary = nil  // clears the primary selection
 * print(luakit.selection.primary) // outputs nothing
 * \endcode
 */
static gint
luaH_luakit_selection_newindex(lua_State *L)
{
    GtkClipboard *selection = luaH_clipboard_get(L, 2);
    if (selection) {
        const gchar *text = !lua_isnil(L, 3) ? luaL_checkstring(L, 3) : NULL;
        if (text && *text)
            gtk_clipboard_set_text(selection, text, -1);
        else
            gtk_clipboard_clear(selection);
    }
    return 0;
}

static gint
luaH_luakit_selection_table_push(lua_State *L)
{
    /* create selection table */
    lua_newtable(L);
    /* setup metatable */
    lua_createtable(L, 0, 2);
    lua_pushliteral(L, "__index");
    lua_pushcfunction(L, luaH_luakit_selection_index);
    lua_rawset(L, -3);
    lua_pushliteral(L, "__newindex");
    lua_pushcfunction(L, luaH_luakit_selection_newindex);
    lua_rawset(L, -3);
    lua_setmetatable(L, -2);
    return 1;
}

/** Escapes a string for use in a URI.
 * \see http://developer.gnome.org/glib/stable/glib-URI-Functions.html#g-uri-escape-string
 *
 * \param  L The Lua VM state.
 * \return   The number of elements pushed on stack.
 *
 * \luastack
 * \lparam string  The string to escape for use in a URI.
 * \lparam allowed Optional string of allowed characters to leave unescaped in
 *                 the \c string.
 * \lreturn        The escaped string.
 */
static gint
luaH_luakit_uri_encode(lua_State *L)
{
    const gchar *string = luaL_checkstring(L, 1);
    const gchar *allowed = NULL;

    /* get list of reserved characters that are allowed in the string */
    if (1 < lua_gettop(L) && !lua_isnil(L, 2))
        allowed = luaL_checkstring(L, 2);

    gchar *res = g_uri_escape_string(string, allowed, true);
    lua_pushstring(L, res);
    g_free(res);
    return 1;
}

/** Unescapes an escaped string used in a URI.
 * \see http://developer.gnome.org/glib/stable/glib-URI-Functions.html#g-uri-unescape-string
 *
 * \param  L The Lua VM state.
 * \return   The number of elements pushed on stack.
 *
 * \luastack
 * \lparam string  The string to unescape.
 * \lparam illegal Optional string of illegal chars which should not appear in
 *                 the unescaped string.
 * \lreturn        The unescaped string or \c nil if illegal chars found.
 */
static gint
luaH_luakit_uri_decode(lua_State *L)
{
    const gchar *string = luaL_checkstring(L, 1);
    const gchar *illegal = NULL;

    /* get list of illegal chars not to be found in the unescaped string */
    if (1 < lua_gettop(L) && !lua_isnil(L, 2))
        illegal = luaL_checkstring(L, 2);

    gchar *res = g_uri_unescape_string(string, illegal);
    if (!res)
        return 0;

    lua_pushstring(L, res);
    g_free(res);
    return 1;
}

/** Shows a Gtk save dialog.
 * \see http://developer.gnome.org/gtk/stable/GtkDialog.html
 *
 * \param L The Lua VM state.
 * \return The number of elements pushed on stack.
 *
 * \luastack
 * \lparam title          The title of the dialog window.
 * \lparam parent         The parent window of the dialog or \c nil.
 * \lparam default_folder The folder to initially display in the file dialog.
 * \lparam default_name   The filename to preselect in the dialog.
 * \lreturn               The name of the selected file or \c nil if the
 *                        dialog was cancelled.
 */
static gint
luaH_luakit_save_file(lua_State *L)
{
    const gchar *title = luaL_checkstring(L, 1);

    /* get window to display dialog over */
    GtkWindow *parent_window = NULL;
    if (!lua_isnil(L, 2)) {
        widget_t *parent = luaH_checkudata(L, 2, &widget_class);
        if (!GTK_IS_WINDOW(parent->widget))
            luaL_argerror(L, 2, "window widget");
        parent_window = GTK_WINDOW(parent->widget);
    }

    const gchar *default_folder = luaL_checkstring(L, 3);
    const gchar *default_name = luaL_checkstring(L, 4);

    GtkWidget *dialog = gtk_file_chooser_dialog_new(title,
            parent_window,
            GTK_FILE_CHOOSER_ACTION_SAVE,
            GTK_STOCK_CANCEL, GTK_RESPONSE_CANCEL,
            GTK_STOCK_SAVE, GTK_RESPONSE_ACCEPT,
            NULL);

    /* set default folder, name and overwrite confirmation policy */
    gtk_file_chooser_set_current_folder(GTK_FILE_CHOOSER(dialog), default_folder);
    gtk_file_chooser_set_current_name(GTK_FILE_CHOOSER(dialog), default_name);
    gtk_file_chooser_set_do_overwrite_confirmation(GTK_FILE_CHOOSER(dialog), TRUE);

    if (gtk_dialog_run(GTK_DIALOG(dialog)) == GTK_RESPONSE_ACCEPT) {
        gchar *filename = gtk_file_chooser_get_filename(GTK_FILE_CHOOSER(dialog));
        lua_pushstring(L, filename);
        g_free(filename);
    } else
        lua_pushnil(L);

    gtk_widget_destroy(dialog);
    return 1;
}

/** Executes a child synchronously (waits for the child to exit before
 * returning). The exit status and all stdout and stderr output from the
 * child is returned.
 * \see http://developer.gnome.org/glib/stable/glib-Spawning-Processes.html#g-spawn-command-line-sync
 *
 * \param  L The Lua VM state.
 * \return   The number of elements pushed on stack (3).
 *
 * \luastack
 * \lparam cmd The command to run (from a shell).
 * \lreturn The exit status of the child.
 * \lreturn The childs stdout.
 * \lreturn The childs stderr.
 */
static gint
luaH_luakit_spawn_sync(lua_State *L)
{
    GError *e = NULL;
    gchar *_stdout = NULL;
    gchar *_stderr = NULL;
    gint rv;
    struct sigaction sigact;
    struct sigaction oldact;

    const gchar *command = luaL_checkstring(L, 1);

    /* Note: we have to temporarily clear the SIGCHLD handler. Otherwise
     * g_spawn_sync wouldn't be able to read subprocess' return value. */
    sigact.sa_handler=SIG_DFL;
    sigemptyset (&sigact.sa_mask);
    sigact.sa_flags=0;
    if (sigaction(SIGCHLD, &sigact, &oldact))
        fatal("Can't clear SIGCHLD handler");

    g_spawn_command_line_sync(command, &_stdout, &_stderr, &rv, &e);

    /* restore SIGCHLD handler */
    if (sigaction(SIGCHLD, &oldact, NULL))
        fatal("Can't restore SIGCHLD handler");

    /* raise error on spawn function error */
    if(e) {
        lua_pushstring(L, e->message);
        g_clear_error(&e);
        lua_error(L);
    }

    /* push exit status, stdout, stderr on to stack and return */
    lua_pushinteger(L, WEXITSTATUS(rv));
    lua_pushstring(L, _stdout);
    lua_pushstring(L, _stderr);
    g_free(_stdout);
    g_free(_stderr);
    return 3;
}

/* Calls the Lua function defined as callback for a (async) spawned process
 * The called Lua function receives 2 arguments:
 * Exit type: one of: "exit" (normal exit), "signal" (terminated by
 *            signal), "unknown" (another reason)
 * Exit number: When normal exit happened, the exit code of the process. When
 *              finished by a signal, the signal number. -1 otherwise.
 */
void async_callback_handler(GPid pid, gint status, gpointer cb_ref)
{
    lua_State *L = globalconf.L;
    /* push callback function onto stack */
    luaH_object_push(L, cb_ref);

    /* push exit reason & exit status onto lua stack */
    if (WIFEXITED(status)) {
        lua_pushliteral(L, "exit");
        lua_pushinteger(L, WEXITSTATUS(status));
    } else if (WIFSIGNALED(status)) {
        lua_pushliteral(L, "signal");
        lua_pushinteger(L, WTERMSIG(status));
    } else {
        lua_pushliteral(L, "unknown");
        lua_pushinteger(L, -1);
    }

    if (lua_pcall(L, 2, 0, 0)) {
        warn("error in callback function: %s", lua_tostring(L, -1));
        lua_pop(L, 1);
    }

    luaH_object_unref(L, cb_ref);
    g_spawn_close_pid(pid);
}

/** Executes a child program asynchronously (your program will not block waiting
 * for the child to exit).
 *
 * \see \ref async_callback_handler
 * \see http://developer.gnome.org/glib/stable/glib-Shell-related-Utilities.html#g-shell-parse-argv
 * \see http://developer.gnome.org/glib/stable/glib-Spawning-Processes.html#g-spawn-async
 *
 * \param  L The Lua VM state.
 * \return   The number of elements pushed on stack (0).
 *
 * \luastack
 * \lparam command  The command to execute a child program.
 * \lparam callback Optional Lua callback function.
 * \lreturn The child pid.
 *
 * \lcode
 * local editor = "gvim"
 * local filename = "config"
 *
 * function editor_callback(exit_reason, exit_status)
 *     if exit_reason == "exit" then
 *         print(string.format("Contents of %q:", filename))
 *         for line in io.lines(filename) do
 *             print(line)
 *         end
 *     else
 *         print("Editor exited with status: " .. exit_status)
 *     end
 * end
 *
 * luakit.spawn(string.format("%s %q", editor, filename), editor_callback)
 * \endcode
 */
static gint
luaH_luakit_spawn(lua_State *L)
{
    GError *e = NULL;
    GPid pid = 0;
    const gchar *command = luaL_checkstring(L, 1);
    gint argc = 0;
    gchar **argv = NULL;
    gpointer cb_ref = NULL;

    /* check callback function type */
    if (lua_gettop(L) > 1 && !lua_isnil(L, 2)) {
        if (lua_isfunction(L, 2))
            cb_ref = luaH_object_ref(L, 2);
        else
            luaL_typerror(L, 2, lua_typename(L, LUA_TFUNCTION));
    }

    /* parse arguments */
    if (!g_shell_parse_argv(command, &argc, &argv, &e))
        goto spawn_error;

    /* spawn command */
    if (!g_spawn_async(NULL, argv, NULL,
            G_SPAWN_DO_NOT_REAP_CHILD|G_SPAWN_SEARCH_PATH, NULL, NULL, &pid,
            &e))
        goto spawn_error;

    /* attach users Lua callback */
    if (cb_ref)
        g_child_watch_add(pid, async_callback_handler, cb_ref);

    g_strfreev(argv);
    lua_pushnumber(L, pid);
    return 1;

spawn_error:
    luaH_object_unref(L, cb_ref);
    lua_pushstring(L, e->message);
    g_clear_error(&e);
    g_strfreev(argv);
    lua_error(L);
    return 0;
}

/** Get seconds from unix epoch with nanosecond precision (or nearest
 * supported by the users system).
 * \see http://www.kernel.org/doc/man-pages/online/pages/man2/clock_gettime.2.html
 *
 * \param L The Lua VM state.
 * \return  The number of elements pushed on the stack (1).
 */
static gint
luaH_luakit_time(lua_State *L)
{
    struct timespec ts;
    clock_gettime(CLOCK_REALTIME, &ts);
    lua_pushnumber(L, ts.tv_sec + (ts.tv_nsec / 1e9));
    return 1;
}

/** Wrapper around the execl POSIX function. The exec family of functions
 * replaces the current process image with a new process image. This function
 * will only return if there was an error with the execl call.
 * \see http://en.wikipedia.org/wiki/Execl
 *
 * \param L The Lua VM state.
 * \return  The number of elements pushed on the stack (0).
 */
static gint
luaH_luakit_exec(lua_State *L)
{
    static const gchar *shell = NULL;
    if (!shell && !(shell = g_getenv("SHELL")))
        shell = "/bin/sh";
    execl(shell, shell, "-c", luaL_checkstring(L, 1), NULL);
    return 0;
}

/** luakit module index metamethod.
 *
 * \param  L The Lua VM state.
 * \return   The number of elements pushed on stack.
 */
static gint
luaH_luakit_index(lua_State *L)
{
    if(luaH_usemetatable(L, 1, 2))
        return 1;

    widget_t *w;
    const gchar *prop = luaL_checkstring(L, 2);
    luakit_token_t token = l_tokenize(prop);

    switch(token) {

      /* push string properties */
      PS_CASE(CACHE_DIR,        globalconf.cache_dir)
      PS_CASE(CONFIG_DIR,       globalconf.config_dir)
      PS_CASE(DATA_DIR,         globalconf.data_dir)
      PS_CASE(EXECPATH,         globalconf.execpath)
      PS_CASE(CONFPATH,         globalconf.confpath)
      /* push boolean properties */
      PB_CASE(VERBOSE,          globalconf.verbose)
      PB_CASE(NOUNIQUE,         globalconf.nounique)

      case L_TK_WINDOWS:
        lua_newtable(L);
        for (guint i = 0; i < globalconf.windows->len; i++) {
            w = globalconf.windows->pdata[i];
            luaH_object_push(L, w->ref);
            lua_rawseti(L, -2, i+1);
        }
        return 1;

      case L_TK_WEBKIT_VERSION:
        lua_pushfstring(L, "%d.%d.%d", WEBKIT_MAJOR_VERSION,
                WEBKIT_MINOR_VERSION, WEBKIT_MICRO_VERSION);
        return 1;

      case L_TK_WEBKIT_USER_AGENT_VERSION:
        lua_pushfstring(L, "%d.%d", WEBKIT_USER_AGENT_MAJOR_VERSION,
                WEBKIT_USER_AGENT_MINOR_VERSION);
        return 1;

      case L_TK_SELECTION:
        return luaH_luakit_selection_table_push(L);

      case L_TK_INSTALL_PATH:
        lua_pushliteral(L, LUAKIT_INSTALL_PATH);
        return 1;

      case L_TK_VERSION:
        lua_pushliteral(L, VERSION);
        return 1;

      case L_TK_DEV_PATHS:
#ifdef DEVELOPMENT_PATHS
        lua_pushboolean(L, TRUE);
#else
        lua_pushboolean(L, FALSE);
#endif
        return 1;

      default:
        break;
    }
    return 0;
}

/** Quit the main GTK loop.
 * \see http://developer.gnome.org/gtk/stable/gtk-General.html#gtk-main-quit
 *
 * \param  L The Lua VM state.
 * \return   The number of elements pushed on stack.
 */
static gint
luaH_luakit_quit(lua_State* UNUSED(L))
{
    if (gtk_main_level())
        gtk_main_quit();
    else
        exit(EXIT_SUCCESS);
    return 0;
}

/** Calls the idle callback function. If the callback function returns false the
 * idle source is removed, the Lua function is unreffed and will not be called
 * again.
 * \see luaH_luakit_idle_add
 *
 * \param func Lua callback function.
 * \return TRUE to keep source alive, FALSE to remove.
 */
static gboolean
idle_cb(gpointer func)
{
    lua_State *L = globalconf.L;

    /* get original stack size */
    gint top = lua_gettop(L);
    gboolean keep = FALSE;

    /* call function */
    luaH_object_push(L, func);
    if (lua_pcall(L, 0, 1, 0))
        /* remove idle source if error in callback */
        warn("error in idle callback: %s", lua_tostring(L, -1));
    else
        /* keep the source alive? */
        keep = lua_toboolean(L, -1);

    /* allow collection of idle callback func */
    if (!keep)
        luaH_object_unref(L, func);

    /* leave stack how we found it */
    lua_settop(L, top);

    return keep;
}

/** Adds a function to be called whenever there are no higher priority GTK
 * events pending in the default main loop. If the function returns false it
 * is automatically removed from the list of event sources and will not be
 * called again.
 * \see http://developer.gnome.org/glib/unstable/glib-The-Main-Event-Loop.html#g-idle-add
 *
 * \param  L The Lua VM state.
 * \return   The number of elements pushed on the stack (0).
 *
 * \luastack
 * \lparam func The callback function.
 */
static gint
luaH_luakit_idle_add(lua_State *L)
{
    luaH_checkfunction(L, 1);
    gpointer func = luaH_object_ref(L, 1);
    g_idle_add(idle_cb, func);
    return 0;
}

/** Removes an idle callback by function.
 * \see http://developer.gnome.org/glib/unstable/glib-The-Main-Event-Loop.html#g-idle-remove-by-data
 *
 * \param  L The Lua VM state.
 * \return   The number of elements pushed on the stack (0).
 *
 * \luastack
 * \lparam func The callback function.
 * \lreturn true if callback removed.
 */
static gint
luaH_luakit_idle_remove(lua_State *L)
{
    luaH_checkfunction(L, 1);
    gpointer func = (gpointer)lua_topointer(L, 1);
    lua_pushboolean(L, g_idle_remove_by_data(func));
    luaH_object_unref(L, func);
    return 1;
}

/** Setup luakit module.
 *
 * \param L The Lua VM state.
 */
void
luakit_lib_setup(lua_State *L)
{
    static const struct luaL_reg luakit_lib[] =
    {
        LUA_CLASS_METHODS(luakit)
        { "__index",         luaH_luakit_index },
        { "exec",            luaH_luakit_exec },
        { "quit",            luaH_luakit_quit },
        { "save_file",       luaH_luakit_save_file },
        { "spawn",           luaH_luakit_spawn },
        { "spawn_sync",      luaH_luakit_spawn_sync },
        { "time",            luaH_luakit_time },
        { "uri_decode",      luaH_luakit_uri_decode },
        { "uri_encode",      luaH_luakit_uri_encode },
        { "idle_add",        luaH_luakit_idle_add },
        { "idle_remove",     luaH_luakit_idle_remove },
        { NULL,              NULL }
    };

    /* create signals array */
    luakit_class.signals = signal_new();

    /* export luakit lib */
    luaH_openlib(L, "luakit", luakit_lib, luakit_lib);
}

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
