/*
 * extension/clib/luakit.c - Generic functions for Lua scripts
 *
 * Copyright © 2016 Aidan Holm <aidanholm@gmail.com>
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

#include "extension/extension.h"
#include "extension/luajs.h"
#include "extension/clib/luakit.h"
#include "extension/clib/page.h"
#include "common/clib/luakit.h"
#include "common/resource.h"
#include "common/signal.h"

#include <glib.h>
#include <gtk/gtk.h>
#include <stdlib.h>
#include <sys/wait.h>
#include <time.h>

/* lua luakit class for signals */
static lua_class_t luakit_class;
static GPtrArray *queued_emissions;

/* setup luakit module signals */
LUA_CLASS_FUNCS(luakit, luakit_class)

static void
emit_page_created_signal(WebKitWebPage *web_page, lua_State *L)
{
    luaH_page_from_web_page(L, web_page);
    signal_object_emit(L, luakit_class.signals, "page-created", 1, 0);
}

static void
page_created_cb(WebKitWebExtension *UNUSED(extension), WebKitWebPage *web_page, lua_State *L)
{
    /* Since web modules are loaded after the first web page is created, signal
     * handlers bound to the page-created signal will not be called for the
     * first web page... unless we queue the signal and emit it later, when the
     * configuration file (and therefore all modules) has been loaded */
    if (queued_emissions)
        g_ptr_array_add(queued_emissions, web_page);
    else
        emit_page_created_signal(web_page, L);
}

static gint
luaH_luakit_index(lua_State *L)
{
    if (luaH_usemetatable(L, 1, 2))
        return 1;

    const gchar *prop = luaL_checkstring(L, 2);
    luakit_token_t token = l_tokenize(prop);

    switch (token) {
        PI_CASE(WEB_PROCESS_ID, getpid())
        PS_CASE(RESOURCE_PATH, resource_path_get())

        case L_TK_WEBKIT_VERSION:
            lua_pushfstring(L, "%d.%d.%d", WEBKIT_MAJOR_VERSION,
                    WEBKIT_MINOR_VERSION, WEBKIT_MICRO_VERSION);
            return 1;

        default: return 0;
    }
}

static gint
luaH_luakit_newindex(lua_State *L)
{
    if (!lua_isstring(L, 2))
        return 0;
    luakit_token_t token = l_tokenize(lua_tostring(L, 2));

    switch (token) {
        case L_TK_RESOURCE_PATH:
            resource_path_set(luaL_checkstring(L, 3));
            break;
        default:
            return 0;
    }

    return 0;
}

static gint
luaH_luakit_register_function(lua_State *L)
{
    luaL_checkstring(L, 1);
    luaL_checkstring(L, 2);
    if (strlen(lua_tostring(L, 1)) == 0)
        return luaL_error(L, "pattern cannot be empty");
    if (strlen(lua_tostring(L, 2)) == 0)
        return luaL_error(L, "function name cannot be empty");
    luaH_checkfunction(L, 3);

    luaJS_register_function(L);

    return 0;
}

/** Setup luakit module.
 *
 * \param L The Lua VM state.
 */
void
luakit_lib_setup(lua_State *L)
{
    static const struct luaL_Reg luakit_lib[] =
    {
        LUA_CLASS_METHODS(luakit)
        LUAKIT_LIB_COMMON_METHODS
        { "__index",           luaH_luakit_index },
        { "__newindex",        luaH_luakit_newindex },
        { "register_function", luaH_luakit_register_function },
        { NULL,              NULL }
    };

    /* create signals array */
    luakit_class.signals = signal_new();

    /* export luakit lib */
    luaH_openlib(L, "luakit", luakit_lib, luakit_lib);

    queued_emissions = g_ptr_array_sized_new(1);
    g_signal_connect(extension.ext, "page-created", G_CALLBACK(page_created_cb), L);
}

void
luakit_lib_emit_pending_signals(lua_State *L)
{
    g_ptr_array_foreach(queued_emissions, (GFunc)emit_page_created_signal, L);
    g_ptr_array_free(queued_emissions, TRUE);
    queued_emissions = NULL;
}

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
