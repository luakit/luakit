#include <webkit2/webkit2.h>

#include "clib/web_module.h"
#include "clib/widget.h"
#include "common/tokenize.h"
#include "common/luauniq.h"
#include "common/luaserialize.h"
#include "widgets/webview.h"
#include "common/clib/ipc.h"

LUA_OBJECT_FUNCS(web_module_class, web_module_t, web_module);

#define luaH_check_web_module(L, idx) luaH_checkudata(L, idx, &(web_module_class))

GPtrArray *required_web_modules;

static int
luaH_web_module_new(lua_State *L)
{
    const char *name = luaL_checkstring(L, -1);
    g_ptr_array_add(required_web_modules, g_strdup(name));

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
web_module_class_setup(lua_State *L)
{
    static const struct luaL_reg web_module_methods[] =
    {
        { "__call", luaH_web_module_new },
        { NULL, NULL }
    };

    static const struct luaL_reg web_module_meta[] =
    {
        { NULL, NULL }
    };

    luaH_class_setup(L, &web_module_class, "web_module",
            (lua_class_allocator_t) web_module_new,
            NULL, NULL,
            web_module_methods, web_module_meta);

    required_web_modules = g_ptr_array_new();
}

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
