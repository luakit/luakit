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

#if WITH_UNIQUE

#include "clib/unique.h"
#include "luah.h"

#include <gtk/gtk.h>
#include <glib.h>

/* setup unique module signals */
lua_class_t unique_class;
LUA_CLASS_FUNCS(unique, unique_class);

static GtkApplication *application = NULL;

static void
message_cb(GSimpleAction* UNUSED(a), GVariant *message_data, lua_State *L)
{
    if (message_data &&
            g_variant_is_of_type(message_data, G_VARIANT_TYPE_STRING)) {
        const gchar *text = g_variant_get_string (message_data, NULL);
        lua_pushstring(L, text);

        GdkScreen *screen = gtk_window_get_screen(gtk_application_get_active_window(application));
        lua_pushlightuserdata(L, screen);

        signal_object_emit(L, unique_class.signals, "message", 2, 0);
    }
}

static gint
luaH_unique_new(lua_State *L)
{
    if (application && g_application_get_is_registered(G_APPLICATION(application)))
        luaL_error(L, "GApplication already setup");

    const gchar *name = luaL_checkstring(L, 1);
    GError *error = NULL;
    if (!application)
        application = gtk_application_new(name, G_APPLICATION_FLAGS_NONE);

    g_application_register(G_APPLICATION(application), NULL, &error);
    if (error != NULL) {
        luaL_error(L, "unable to register GApplication");
        g_error_free(error);
        error = NULL;
    }

    const GActionEntry entries[] = {
        {"message", (void (*) (GSimpleAction *, GVariant *, gpointer)) message_cb,
         "s", NULL, NULL, {0,0,0}}
    };
    g_action_map_add_action_entries (G_ACTION_MAP(application),
            entries, G_N_ELEMENTS(entries), L);
    return 0;
}

static gint
luaH_unique_is_running(lua_State *L)
{
    if (!application || !g_application_get_is_registered(G_APPLICATION(application)))
        luaL_error(L, "GApplication is not registered");

    gboolean running = g_application_get_is_remote(G_APPLICATION(application));

    lua_pushboolean(L, running);
    return 1;
}

static gint
luaH_unique_send_message(lua_State *L)
{
    if (!application || !g_application_get_is_registered(G_APPLICATION(application)))
        luaL_error(L, "GApplication is not registered");

    if (!g_application_get_is_remote(G_APPLICATION(application)))
        luaL_error(L, "no other instances running");

    GVariant *text = g_variant_new_string(luaL_checkstring(L, 1));

    g_action_group_activate_action(G_ACTION_GROUP(application), "message", text);
    return 0;
}

void
unique_lib_setup(lua_State *L)
{
    static const struct luaL_reg unique_lib[] =
    {
        LUA_CLASS_METHODS(unique)
        { "new", luaH_unique_new },
        { "send_message", luaH_unique_send_message },
        { "is_running", luaH_unique_is_running },
        { NULL, NULL }
    };

    /* create signals array */
    unique_class.signals = signal_new();

    /* export unique lib */
    luaH_openlib(L, "unique", unique_lib, unique_lib);
}

#endif /* #if WITH_UNIQUE */

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
