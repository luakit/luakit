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

/***
 * IPC interface for communication between UI and Web processes.
 *
 * In Luakit there is a single UI Lua state, but there may be multiple web
 * processes, each of which has a separate Lua state. This interface can be used
 * to communicate between the UI and web processes.
 *
 * An interface similar to Luakit's signals handling is provided, and supports
 * serializing multiple Lua parameters.
 *
 * _This library is available from both UI and web process Lua states._
 *
 * @usage
 * -- In UI process
 * local wm = require_web_module("test_wm")
 * wm:add_signal("test", function (_, text)
 *     msg.info("Web process said %s!", text)
 * end)
 *
 * -- In test_wm web module
 * local ui = ipc_channel("test_wm")
 * ui:emit_signal("test", "hello")
 *
 * @module ipc
 * @copyright 2016 Aidan Holm
 */

#include <assert.h>

#include "common/clib/ipc.h"
#include "common/msg.h"
#include "luah.h"
#include "common/tokenize.h"
#include "common/luaserialize.h"
#include "common/luauniq.h"

#define REG_KEY "luakit.registry.ipc_channel"

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

/***
 * Open an IPC channel.
 *
 * Open an IPC channel and create an `ipc_channel` object. Signals
 * emitted on this object on the web process will call signal handlers
 * on the UI process, and vice versa.
 *
 * @function ipc_channel
 * @tparam string name A name that identifies the channel.
 * @treturn ipc_channel An IPC channel endpoint object.
 */

/***
 * Require a Lua module on the web process.
 *
 * Load the named module on all web process Lua states. The module will
 * be loaded on any future web process Lua states.
 *
 * For convenience, this function returns an IPC channel with the same name as
 * the web module.
 *
 * @function require_web_module
 * @tparam string name The name of the module to load.
 * @treturn ipc_channel An IPC channel endpoint object.
 */

void
ipc_channel_class_setup(lua_State *L)
{
    static const struct luaL_reg ipc_channel_methods[] =
    {
        LUA_CLASS_METHODS(ipc_channel)
        { "__call", luaH_ipc_channel_new },
        { NULL, NULL }
    };

    static const struct luaL_reg ipc_channel_meta[] =
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
