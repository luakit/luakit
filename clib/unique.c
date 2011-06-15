/*
 * clib/unique.c - libunique bindings for writing single instance
 * applications
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

#include <glib.h>
#include <unique/unique.h>

/* setup unique module signals */
lua_class_t unique_class;
LUA_CLASS_FUNCS(unique, unique_class);

UniqueApp *application = NULL;

UniqueResponse
message_cb(UniqueApp *a, gint id, UniqueMessageData *message_data,
        guint time, gpointer data)
{
    (void) a;
    (void) id;
    (void) time;

    if (message_data) {
        lua_State *L = (lua_State*)data;
        /* get message text */
        gchar *text = unique_message_data_get_text(message_data);
        lua_pushstring(L, text);
        g_free(text);
        /* get message screen */
        GdkScreen *screen = unique_message_data_get_screen(message_data);
        lua_pushlightuserdata(L, screen);
        /* emit signal */
        signal_object_emit(L, unique_class.signals, "message", 2, 0);
    }

    return UNIQUE_RESPONSE_OK;
}

static gint
luaH_unique_new(lua_State *L)
{
    if (application)
        luaL_error(L, "unique app already setup");

    const gchar *name = luaL_checkstring(L, 1);
    application = unique_app_new_with_commands(name, NULL, "message", 1, NULL);
    g_signal_connect(G_OBJECT(application), "message-received",
            G_CALLBACK(message_cb), L);
    return 0;
}

static gint
luaH_unique_is_running(lua_State *L)
{
    if (!application)
        luaL_error(L, "unique app not setup");

    lua_pushboolean(L, unique_app_is_running(application) ? TRUE : FALSE);
    return 1;
}

static gint
luaH_unique_send_message(lua_State *L)
{
    if (!application)
        luaL_error(L, "unique app not setup");

    if (!unique_app_is_running(application))
        luaL_error(L, "no other instances running");

    const gchar *text = luaL_checkstring(L, 1);
    UniqueMessageData *data = unique_message_data_new();
    unique_message_data_set_text(data, text, -1);
    unique_app_send_message(application, 1, data);
    unique_message_data_free(data);
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
