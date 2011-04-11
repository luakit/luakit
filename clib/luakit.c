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

#include <glib.h>
#include <gtk/gtk.h>
#include <sys/wait.h>
#include <time.h>
#include <webkit/webkit.h>

/* setup luakit module signals */
LUA_CLASS_FUNCS(luakit, luakit_class)

/* Returns a string from X selection.
 * \param L The Lua VM state.
 * \return The number of elements pushed on stack (1).
 */
static gint
luaH_luakit_get_selection(lua_State *L)
{
    gint n = lua_gettop(L);
    GdkAtom atom = GDK_SELECTION_PRIMARY;

    if (n) {
        const gchar *arg = luaL_checkstring(L, 1);
        /* Follow xclip(1) behavior: check only the first character of argument */
        switch (arg[0]) {
          case 'p':
            break;
          case 's':
            atom = GDK_SELECTION_SECONDARY;
            break;
          case 'c':
            atom = GDK_SELECTION_CLIPBOARD;
            break;
          default:
            luaL_argerror(L, 1, "should be 'primary', 'secondary' or 'clipboard'");
            break;
        }
    }
    GtkClipboard *selection = gtk_clipboard_get(atom);
    gchar *text = gtk_clipboard_wait_for_text(selection);
    lua_pushstring(L, text);
    g_free(text);
    return 1;
}

/* Sets an X selection.
 * \param L The Lua VM state.
 * \return The number of elements pushed on stack (0).
 */
static gint
luaH_luakit_set_selection(lua_State *L)
{
    gint n = lua_gettop(L);
    GdkAtom atom = GDK_SELECTION_PRIMARY;

    if (0 == n)
        luaL_error(L, "missing argument, string expected");
    const gchar *text = luaL_checkstring(L, 1);
    if (1 < n)
    {
        const gchar *arg = luaL_checkstring(L, 2);
        /* Follow xclip(1) behavior: check only the first character of argument */
        switch (arg[0]) {
          case 'p':
            break;
          case 's':
            atom = GDK_SELECTION_SECONDARY;
            break;
          case 'c':
            atom = GDK_SELECTION_CLIPBOARD;
            break;
          default:
            luaL_argerror(L, 1, "should be 'primary', 'secondary' or 'clipboard'");
            break;
        }
    }
    GtkClipboard *selection = gtk_clipboard_get(atom);
    glong len = g_utf8_strlen (text, -1);
    gtk_clipboard_set_text(selection, text, len);
    return 0;
}

/* Escapes a string for use in a URI.
 * \param L The Lua VM state.
 * \return The number of elements pushed on stack (1).
 */
static gint
luaH_luakit_uri_encode(lua_State *L)
{
    const gchar *string = luaL_checkstring(L, 1);
    gchar *res = g_uri_escape_string(string, NULL, false);
    lua_pushstring(L, res);
    g_free(res);
    return 1;
}

/* Unescapes a whole escaped string.
 * \param L The Lua VM state.
 * \return The number of elements pushed on stack (1).
 */
static gint
luaH_luakit_uri_decode(lua_State *L)
{
    const gchar *string = luaL_checkstring(L, 1);
    gchar *res = g_uri_unescape_string(string, NULL);
    lua_pushstring(L, res);
    g_free(res);
    return 1;
}

/* Shows a Gtk save dialog.
 * \param L The Lua VM state.
 * \return The number of objects pushed onto the stack.
 * \luastack
 * \lparam title The title of the dialog.
 * \lparam parent The parent window of the dialog or nil.
 * \lparam default_folder The folder to initially display in the dialog.
 * \lparam default_name The filename to preselect in the dialog.
 * \lreturn The name of the selected file or nil if the dialog was cancelled.
 */
static gint
luaH_luakit_save_file(lua_State *L)
{
    const gchar *title = luaL_checkstring(L, 1);
    // decipher the parent
    GtkWindow *parent_window;
    if (lua_isnil(L, 2)) {
        parent_window = NULL;
    } else {
        widget_t *parent = luaH_checkudata(L, 2, &widget_class);
        if (GTK_IS_WINDOW(parent->widget)) {
            parent_window = GTK_WINDOW(parent->widget);
        } else {
            luaH_warn(L, "dialog expects a window as parent, but some other widget was given");
            parent_window = NULL;
        }
    }
    const gchar *default_folder = luaL_checkstring(L, 3);
    const gchar *default_name = luaL_checkstring(L, 4);
    GtkWidget *dialog = gtk_file_chooser_dialog_new(title,
            parent_window,
            GTK_FILE_CHOOSER_ACTION_SAVE,
            GTK_STOCK_CANCEL, GTK_RESPONSE_CANCEL,
            GTK_STOCK_SAVE, GTK_RESPONSE_ACCEPT,
            NULL);
    // set default folder, name and overwrite confirmation policy
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

static gint
luaH_luakit_get_special_dir(lua_State *L)
{
    const gchar *name = luaL_checkstring(L, 1);
    luakit_token_t token = l_tokenize(name);
    GUserDirectory atom;
    /* match token with G_USER_DIR_* atom */
    switch(token) {
#define UD_CASE(TOK) case L_TK_##TOK: atom = G_USER_DIRECTORY_##TOK; break;
      UD_CASE(DESKTOP)
      UD_CASE(DOCUMENTS)
      UD_CASE(DOWNLOAD)
      UD_CASE(MUSIC)
      UD_CASE(PICTURES)
      UD_CASE(PUBLIC_SHARE)
      UD_CASE(TEMPLATES)
      UD_CASE(VIDEOS)
#undef UD_CASE
      default:
        warn("unknown atom G_USER_DIRECTORY_%s", name);
        luaL_argerror(L, 1, "invalid G_USER_DIRECTORY_* atom");
        return 0;
    }
    lua_pushstring(L, g_get_user_special_dir(atom));
    return 1;
}

/* Spawns a command synchonously.
 * \param L The Lua VM state.
 * \return The number of elements pushed on stack (3).
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
    if (sigaction(SIGCHLD, &oldact, NULL))
        fatal("Can't restore SIGCHLD handler");

    if(e) {
        lua_pushstring(L, e->message);
        g_clear_error(&e);
        lua_error(L);
    }
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
void async_callback_handler(GPid pid, gint status, gpointer cb_ref) {
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

/* Spawns a command.
 * \param L The Lua VM state. Contains a Lua function, the callback handler to use
 * when the command finishes.
 * \return The number of elements pushed on stack (0).
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

    /* parse arguments */
    g_shell_parse_argv(command, &argc, &argv, &e);
    if (e) {
        lua_pushstring(L, e->message);
        g_clear_error(&e);
        g_strfreev(argv);
        lua_error(L);
    }

    /* check callback function type */
    if (lua_gettop(L) > 1 && !lua_isnil(L, 2)) {
        if (lua_type(L, 2) == LUA_TFUNCTION)
            cb_ref = luaH_object_ref(L, 2);
        else
            luaL_typerror(L, 2, lua_typename(L, LUA_TFUNCTION));
    }

    /* spawn command */
    g_spawn_async(NULL, argv, NULL,
            G_SPAWN_DO_NOT_REAP_CHILD|G_SPAWN_SEARCH_PATH, NULL, NULL, &pid,
            &e);
    g_strfreev(argv);
    if(e) {
        luaH_object_unref(L, cb_ref);
        lua_pushstring(L, e->message);
        g_clear_error(&e);
        lua_error(L);
    }

    if (cb_ref)
        g_child_watch_add(pid, async_callback_handler, cb_ref);

    return 0;
}

static gint
luaH_luakit_time(lua_State *L)
{
    struct timespec ts;
    clock_gettime(CLOCK_REALTIME, &ts);
    lua_pushnumber(L, ts.tv_sec + (ts.tv_nsec / 1e9));
    return 1;
}

static gint
luaH_luakit_exec(lua_State *L)
{
    const gchar *cmd = luaL_checkstring(L, 1);
    l_exec(cmd);
    return 0;
}

/* luakit global table.
 * \param L The Lua VM state.
 * \return The number of elements pushed on stack.
 * \luastack
 * \lfield font The default font.
 * \lfield font_height The default font height.
 * \lfield conffile The configuration file which has been loaded.
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
      /* push integer properties */
      PI_CASE(WEBKIT_MAJOR_VERSION, webkit_major_version())
      PI_CASE(WEBKIT_MINOR_VERSION, webkit_minor_version())
      PI_CASE(WEBKIT_MICRO_VERSION, webkit_micro_version())
      PI_CASE(WEBKIT_USER_AGENT_MAJOR_VERSION, WEBKIT_USER_AGENT_MAJOR_VERSION)
      PI_CASE(WEBKIT_USER_AGENT_MINOR_VERSION, WEBKIT_USER_AGENT_MINOR_VERSION)

      case L_TK_WINDOWS:
        lua_newtable(L);
        for (guint i = 0; i < globalconf.windows->len; i++) {
            w = globalconf.windows->pdata[i];
            luaH_object_push(L, w->ref);
            lua_rawseti(L, -2, i+1);
        }
        return 1;

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

/* exit main gtk loop */
static gint
luaH_luakit_quit(lua_State *L)
{
    (void) L;
    gtk_main_quit();
    return 0;
}

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
        warn("error in idle func: %s", lua_tostring(L, -1));
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

static gint
luaH_luakit_idle_add(lua_State *L)
{
    luaH_checkfunction(L, 1);
    gpointer func = luaH_object_ref(L, 1);
    g_idle_add(idle_cb, func);
    return 0;
}

static gint
luaH_luakit_idle_remove(lua_State *L)
{
    luaH_checkfunction(L, 1);
    gpointer func = luaH_object_ref(L, 1);
    lua_pushboolean(L, g_idle_remove_by_data(func));
    return 1;
}

void
luakit_lib_setup(lua_State *L)
{
    static const struct luaL_reg luakit_lib[] =
    {
        LUA_CLASS_METHODS(luakit)
        { "__index",         luaH_luakit_index },
        { "exec",            luaH_luakit_exec },
        { "get_special_dir", luaH_luakit_get_special_dir },
        { "quit",            luaH_luakit_quit },
        { "save_file",       luaH_luakit_save_file },
        { "set_selection",   luaH_luakit_set_selection },
        { "get_selection",   luaH_luakit_get_selection },
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
