/*
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

#include "extension/ipc.h"
#include "extension/extension.h"
#include "extension/clib/page.h"
#include "common/clib/ipc.h"
#include "common/luaserialize.h"

#define REG_KEY "luakit.registry.ipc_channel"

gint
ipc_channel_send(lua_State *L)
{
    ipc_channel_t *ipc_channel = luaH_check_ipc_channel(L, 1);
    luaL_checkstring(L, 2);
    lua_pushstring(L, ipc_channel->name);
    ipc_send_lua(extension.ipc, IPC_TYPE_lua_ipc, L, 2, lua_gettop(L));
    return 0;
}

void
ipc_channel_recv(lua_State *L, const gchar *arg, guint arglen)
{
    gint top = lua_gettop(L);
    int n = lua_deserialize_range(L, (guint8*)arg, arglen);

    /* Remove signal name, module_name and page_id from the stack */
    const char *signame = lua_tostring(L, -n);
    lua_remove(L, -n);
    const char *module_name = lua_tostring(L, -2);
    guint64 page_id = lua_tointeger(L, -1);
    lua_pop(L, 2);
    n -= 3;

    /* Prepend the page object, or nil */
    if (page_id) {
        WebKitWebPage *web_page = webkit_web_extension_get_page(extension.ext, page_id);
        luaH_page_from_web_page(L, web_page);
    } else
        lua_pushnil(L);
    lua_insert(L, -n-1);
    n++;

    /* Push the right module object onto the stack */
    lua_pushstring(L, REG_KEY);
    lua_rawget(L, LUA_REGISTRYINDEX);
    lua_pushstring(L, module_name);
    lua_rawget(L, -2);
    lua_remove(L, -2);

    /* Move the module before arguments, and emit signal */
    if (!lua_isnil(L, -1)) {
        lua_insert(L, -n-1);
        luaH_object_emit_signal(L, -n-1, signame, n, 0);
    }
    lua_settop(L, top);
}

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
