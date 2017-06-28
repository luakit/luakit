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

#include <assert.h>

#include "common/clib/ipc.h"
#include "common/ipc.h"
#include "luah.h"
#include "common/tokenize.h"
#include "common/luaserialize.h"
#include "common/luauniq.h"

#define REG_KEY "luakit.registry.ipc_channel"

static lua_class_t ipc_channel_class;

LUA_OBJECT_FUNCS(ipc_channel_class, ipc_channel_t, ipc_channel);

ipc_channel_t *
luaH_check_ipc_channel(lua_State *L, gint idx)
{
    return luaH_checkudata(L, idx, &ipc_channel_class);
}

int
luaH_ipc_channel_new(lua_State *L)
{
    const char *name = luaL_checkstring(L, -1);

    if (luaH_uniq_get(L, REG_KEY, -1))
        return 1;

    lua_newtable(L);
    luaH_class_new(L, &ipc_channel_class);
    lua_remove(L, -2);
    ipc_channel_t *ipc_channel = luaH_check_ipc_channel(L, -1);
    ipc_channel->name = g_strdup(name);

    luaH_uniq_add(L, REG_KEY, -2, -1);
    return 1;
}

static gint
luaH_ipc_channel_gc(lua_State *L)
{
    ipc_channel_t *ipc_channel = luaH_check_ipc_channel(L, -1);
    g_free(ipc_channel->name);
    return luaH_object_gc(L);
}

void
ipc_channel_class_setup(lua_State *L)
{
    static const struct luaL_Reg ipc_channel_methods[] =
    {
        LUA_CLASS_METHODS(ipc_channel)
        { "__call", luaH_ipc_channel_new },
        { NULL, NULL }
    };

    static const struct luaL_Reg ipc_channel_meta[] =
    {
        LUA_OBJECT_META(ipc_channel)
        { "emit_signal", ipc_channel_send },
        { "__gc", luaH_ipc_channel_gc },
        { NULL, NULL }
    };

    luaH_class_setup(L, &ipc_channel_class, "ipc_channel",
            (lua_class_allocator_t) ipc_channel_new,
            NULL, NULL,
            ipc_channel_methods, ipc_channel_meta);

    lua_pushstring(L, REG_KEY);
    lua_newtable(L);
    lua_rawset(L, LUA_REGISTRYINDEX);
}

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
