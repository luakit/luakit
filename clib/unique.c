/*
 * clib/unique.c - libunique bindings for writing single instance
 * applications if built against GTK2, and the equivalent using
 * GApplications if built against GTK3.
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

#include "clib/unique.h"
#include "globalconf.h"
#include "luah.h"

#include <gtk/gtk.h>
#include <glib.h>

/* setup unique module signals */
static lua_class_t unique_class;
LUA_CLASS_FUNCS(unique, unique_class);

static void
message_cb(GSimpleAction* UNUSED(a), GVariant *message_data, lua_State *L)
{
    if (message_data &&
            g_variant_is_of_type(message_data, G_VARIANT_TYPE_STRING)) {
        const gchar *text = g_variant_get_string (message_data, NULL);
        lua_pushstring(L, text);

        GtkWindow *window = gtk_application_get_active_window(globalconf.application);
        if (!window)
            warn("It's not a window!!!");
        GdkScreen *screen = gtk_window_get_screen(window);
        lua_pushlightuserdata(L, screen);

        signal_object_emit(L, unique_class.signals, "message", 2, 0);
    }
}

static gboolean
unique_is_registered(void)
{
    if (!globalconf.application)
        return FALSE;
    if (!g_application_get_is_registered(G_APPLICATION(globalconf.application)))
        return FALSE;
    return TRUE;
}

static gint
luaH_unique_new(lua_State *L)
{
    const gchar *name = luaL_checkstring(L, 1);
    if (!g_application_id_is_valid(name))
        return luaL_error(L, "invalid application name");

    if (unique_is_registered()) {
        const gchar *other = g_application_get_application_id(
                G_APPLICATION(globalconf.application));
        if (!g_str_equal(name, other))
            luaL_error(L, "GApplication '%s' already setup", other);
        else
            verbose("GApplication '%s' already setup", name);
        return 0;
    }

    GError *error = NULL;
    if (!globalconf.application)
        globalconf.application = gtk_application_new(name, G_APPLICATION_FLAGS_NONE);

    g_application_register(G_APPLICATION(globalconf.application), NULL, &error);
    if (error != NULL) {
        luaL_error(L, "unable to register GApplication: %s", error->message);
        g_error_free(error);
        g_object_unref(G_OBJECT(globalconf.application));
        globalconf.application = NULL;
        return 0;
    }

    const GActionEntry entries[] = {{
        .name = "message",
        .activate = (void (*) (GSimpleAction *, GVariant *, gpointer)) message_cb,
        .parameter_type = "s"
    }};
    g_action_map_add_action_entries (G_ACTION_MAP(globalconf.application),
            entries, G_N_ELEMENTS(entries), L);
    return 0;
}

static gint
luaH_unique_is_running(lua_State *L)
{
    if (!unique_is_registered())
        luaL_error(L, "GApplication is not registered");

    gboolean running = g_application_get_is_remote(G_APPLICATION(globalconf.application));

    lua_pushboolean(L, running);
    return 1;
}

static gint
luaH_unique_send_message(lua_State *L)
{
    if (!unique_is_registered())
        luaL_error(L, "GApplication is not registered");

    if (!g_application_get_is_remote(G_APPLICATION(globalconf.application)))
        luaL_error(L, "no other instances running");

    GVariant *text = g_variant_new_string(luaL_checkstring(L, 1));

    g_action_group_activate_action(G_ACTION_GROUP(globalconf.application), "message", text);
    return 0;
}

static void
luaH_open_luakit_unique(lua_State *L, const struct luaL_Reg methods[], const struct luaL_Reg meta[])
{
    luaL_newmetatable(L, "unique");                                    /* 1 */
    lua_pushvalue(L, -1);           /* dup metatable                      2 */
    lua_setfield(L, -2, "__index"); /* metatable.__index = metatable      1 */

    luaL_register(L, NULL, meta);                                      /* 1 */

    /* No point checking for package.loaded["luakit.unique"] here */
    lua_newtable(L);
    luaL_register(L, NULL, methods);
    /* Set package.loaded["luakit.unique"] */
    lua_getfield(L, LUA_GLOBALSINDEX, "package");
    lua_getfield(L, -1, "loaded");
    lua_pushvalue(L, -3);
    lua_setfield(L, -2, "luakit.unique");
    lua_pop(L, 2);
    /* Set luakit.unique: rawset since lib has an __index metamethod */
    lua_getfield(L, LUA_GLOBALSINDEX, "luakit");
    lua_pushliteral(L, "unique");
    lua_pushvalue(L, -3);
    lua_rawset(L, -3);
    lua_pop(L, 1);

    lua_pushvalue(L, -1);           /* dup self as metatable              3 */
    lua_setmetatable(L, -2);        /* set self as metatable              2 */
    lua_pop(L, 2);
}

static gboolean warned = FALSE;

static int
luaH_unique_proxy_index(lua_State *L)
{
    if (!warned) {
        warned = TRUE;
        warn("the unique library has been moved to luakit.unique");
        warn("this compatibility wrapper will be removed in a future version");
        warn("you should remove the two `if unique then ... end` blocks from your rc.lua");
        warn("then, at the start of your rc.lua, add `require \"unique_instance\"`");
    }

    lua_getfield(L, LUA_GLOBALSINDEX, "luakit");
    lua_getfield(L, -1, "unique");
    lua_pushvalue(L, 2);
    lua_gettable(L, -2);
    return 1;
}

static void
luaH_open_unique_proxy(lua_State *L)
{
    /* Construct proxy metatable */
    lua_newtable(L);
    lua_newtable(L);
    lua_pushcfunction(L, &luaH_unique_proxy_index);
    lua_setfield(L, -2, "__index");
    lua_setmetatable(L, -2);
    /* Set package.loaded["unique"] */
    lua_getfield(L, LUA_GLOBALSINDEX, "package");
    lua_getfield(L, -1, "loaded");
    lua_pushvalue(L, -3);
    lua_setfield(L, -2, "unique");
    lua_pop(L, 2);
    /* Set luakit.unique: rawset since lib has an __index metamethod */
    lua_setglobal(L, "unique");
}

void
unique_lib_setup(lua_State *L)
{
    static const struct luaL_Reg unique_lib[] =
    {
        LUA_CLASS_METHODS(unique)
        { "new", luaH_unique_new },
        { "send_message", luaH_unique_send_message },
        { "is_running", luaH_unique_is_running },
        { NULL, NULL }
    };

    /* create signals array */
    unique_class.signals = signal_new();

    luaH_open_luakit_unique(L, unique_lib, unique_lib);
    luaH_open_unique_proxy(L);
}

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
