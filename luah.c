/*
 * luah.c - Lua helper functions
 *
 * Copyright © 2010-2011 Mason Larobina <mason.larobina@gmail.com>
 * Copyright © 2008-2009 Julien Danjou <julien@danjou.info>
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

#include "luah.h"
#include "common/luah.h"
#include "common/luautil.h"

/* include clib headers */
#include "clib/download.h"
#include "clib/luakit.h"
#include "clib/request.h"
#include "clib/sqlite3.h"
#include "clib/unique.h"
#include "clib/widget.h"
#include "clib/xdg.h"
#include "clib/stylesheet.h"
#include "clib/web_module.h"
#include "common/clib/ipc.h"
#include "common/clib/msg.h"
#include "common/clib/soup.h"
#include "common/clib/timer.h"
#include "globalconf.h"

#include <glib.h>
#include <gtk/gtk.h>

void
luaH_modifier_table_push(lua_State *L, guint state) {
    gint i = 1;
    lua_newtable(L);
    if (state & GDK_MODIFIER_MASK) {

#define MODKEY(key, name)           \
    if (state & GDK_##key##_MASK) { \
        lua_pushstring(L, name);    \
        lua_rawseti(L, -2, i++);    \
    }

        MODKEY(SHIFT, "Shift");
        MODKEY(LOCK, "Lock");
        MODKEY(CONTROL, "Control");
        MODKEY(MOD1, "Mod1");
        MODKEY(MOD2, "Mod2");
        MODKEY(MOD3, "Mod3");
        MODKEY(MOD4, "Mod4");
        MODKEY(MOD5, "Mod5");

#undef MODKEY

    }
}

void
luaH_keystr_push(lua_State *L, guint keyval)
{
    gchar ucs[7];
    guint ulen;
    guint32 ukval = gdk_keyval_to_unicode(keyval);

    /* check for printable unicode character */
    if (g_unichar_isgraph(ukval)) {
        ulen = g_unichar_to_utf8(ukval, ucs);
        ucs[ulen] = 0;
        lua_pushstring(L, ucs);
    }
    /* sent keysym for non-printable characters */
    else
        lua_pushstring(L, gdk_keyval_name(keyval));
}

void
luaH_init(gchar ** uris)
{
    /* Lua VM init */
    if (common.L)
        lua_close(common.L);
    lua_State *L = common.L = globalconf.L = luaL_newstate();

    /* Set panic fuction */
    lua_atpanic(L, luaH_panic);

    /* Set error handling function */
    lualib_dofunction_on_error = luaH_dofunction_on_error;

    luaL_openlibs(L);

    luaH_fixups(L);

    luaH_object_setup(L);

    /* Export luakit lib */
    luakit_lib_setup(L);

    /* Export xdg lib */
    xdg_lib_setup(L);

    /* Export soup lib */
    soup_lib_setup(L);

    if (!globalconf.nounique)
        /* Export unique lib */
        unique_lib_setup(L);

    /* Export widget */
    widget_class_setup(L);

    /* Export download */
    download_class_setup(L);

    /* Export sqlite3 */
    sqlite3_class_setup(L);

    /* Export timer */
    timer_class_setup(L);

    /* Export request */
    request_class_setup(L);

    /* Export stylesheet */
    stylesheet_class_setup(L);

    /* Export web module */
    web_module_lib_setup(L);
    ipc_channel_class_setup(L);

    /* Export web module */
    msg_lib_setup(L);

    /* add Lua search paths */
    luaH_add_paths(L, globalconf.config_dir);

    /* push a table of the startup uris */
    const gchar *uri;
    lua_newtable(L);
    for (gint i = 0; uris && (uri = uris[i]); i++) {
        lua_pushstring(L, uri);
        lua_rawseti(L, -2, i + 1);
    }
    lua_setglobal(L, "uris");
}

static gboolean
luaH_loadrc(const gchar *confpath, gboolean run, gchar **uris)
{
    info("Loading rc: %s", confpath);

    luaH_init(uris);
    lua_State *L = common.L;

    if (luaL_loadfile(L, confpath)) {
        error("Error loading rc: %s", lua_tostring(L, -1));
        return FALSE;
    }

    if (!run) {
        lua_pop(L, 1);
        return TRUE;
    }

    return luaH_dofunction(L, 0, 0);
}

/* Load a configuration file. */
gboolean
luaH_parserc(const gchar *confpath, gboolean run, gchar **uris)
{
    const gchar* const *config_dirs = NULL;
    gboolean ret = FALSE;
    GPtrArray *paths = NULL;

    /* try to load, return if it's ok */
    if (confpath) {
        ret = luaH_loadrc(confpath, run, uris);
        goto bailout;
    }

    /* compile list of config search paths */
    paths = g_ptr_array_new_with_free_func(g_free);

#if DEVELOPMENT_PATHS
    /* allows for testing luakit in the project directory */
    g_ptr_array_add(paths, g_strdup("./config/rc.lua"));
#endif

    /* search users config dir (see: XDG_CONFIG_HOME) */
    g_ptr_array_add(paths, g_build_filename(globalconf.config_dir, "rc.lua", NULL));

    /* search system config dirs (see: XDG_CONFIG_DIRS) */
    config_dirs = g_get_system_config_dirs();
    for(; *config_dirs; config_dirs++)
        g_ptr_array_add(paths, g_build_filename(*config_dirs, "luakit", "rc.lua", NULL));

    const gchar *path;
    for (guint i = 0; i < paths->len; i++) {
        path = paths->pdata[i];
        if (file_exists(path)) {
            if (i > 0)
                warn("Falling back to rc file: %s", path);
            if(luaH_loadrc(path, run, uris)) {
                globalconf.confpath = g_strdup(path);
                ret = TRUE;
                goto bailout;
            } else if(!run)
                goto bailout;
        }
    }

bailout:

    if (paths) g_ptr_array_free(paths, TRUE);
    return ret;
}

gint
luaH_class_index_miss_property(lua_State *L, lua_object_t* UNUSED(obj))
{
    signal_object_emit(L, luakit_class.signals, "debug::index::miss", 2, 0);
    return 0;
}

gint
luaH_class_newindex_miss_property(lua_State *L, lua_object_t* UNUSED(obj))
{
    signal_object_emit(L, luakit_class.signals, "debug::newindex::miss", 3, 0);
    return 0;
}

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
