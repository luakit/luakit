#include "clib/web_module.h"
#include "common/clib/ipc.h"

GPtrArray *required_web_modules;

static int
luaH_require_web_module(lua_State *L)
{
    const char *name = luaL_checkstring(L, -1);
    g_ptr_array_add(required_web_modules, g_strdup(name));

    /* Return an IPC channel with the same name for convenience */
    return luaH_ipc_channel_new(L);
}

void
web_module_load_modules_on_endpoint(msg_endpoint_t *ipc)
{
    for (unsigned i = 0; i < required_web_modules->len; i++) {
        const gchar *module_name = required_web_modules->pdata[i];
        msg_header_t header = {
            .type = MSG_TYPE_lua_require_module,
            .length = strlen(module_name)+1
        };
        msg_send(ipc, &header, module_name);
    }
}

void
web_module_lib_setup(lua_State *L)
{
    static const struct luaL_reg web_module_methods[] =
    {
        { "__call", luaH_require_web_module },
        { NULL, NULL }
    };

    luaH_openlib(L, "require_web_module", web_module_methods, web_module_methods);

    required_web_modules = g_ptr_array_new();
}

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
