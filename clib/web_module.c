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

#include "clib/web_module.h"
#include "common/clib/ipc.h"

static GPtrArray *required_web_modules;

static int
luaH_require_web_module(lua_State *L)
{
    const char *name = luaL_checkstring(L, -1);
    g_ptr_array_add(required_web_modules, g_strdup(name));

    /* Return an IPC channel with the same name for convenience */
    return luaH_ipc_channel_new(L);
}

void
web_module_load_modules_on_endpoint(ipc_endpoint_t *ipc)
{
    for (unsigned i = 0; i < required_web_modules->len; i++) {
        const gchar *module_name = required_web_modules->pdata[i];
        ipc_header_t header = {
            .type = IPC_TYPE_lua_require_module,
            .length = strlen(module_name)+1
        };
        ipc_send(ipc, &header, module_name);
    }
}

void
web_module_lib_setup(lua_State *L)
{
    static const struct luaL_Reg web_module_methods[] =
    {
        { "__call", luaH_require_web_module },
        { NULL, NULL }
    };

    luaH_openlib(L, "require_web_module", web_module_methods, web_module_methods);

    required_web_modules = g_ptr_array_new();
}

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
