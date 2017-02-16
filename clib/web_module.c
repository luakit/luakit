#include <webkit2/webkit2.h>

#include "clib/web_module.h"
#include "clib/widget.h"
#include "common/tokenize.h"
#include "common/luauniq.h"
#include "common/luaserialize.h"
#include "widgets/webview.h"
#include "common/clib/ipc.h"

#define REG_KEY "luakit.registry.ipc_channel"

LUA_OBJECT_FUNCS(web_module_class, web_module_t, web_module);

#define luaH_check_web_module(L, idx) luaH_checkudata(L, idx, &(web_module_class))

static int
luaH_web_module_new(lua_State *L)
{
    return luaH_ipc_channel_new(L);
}

void
web_module_load_modules_on_endpoint(msg_endpoint_t *ipc, lua_State *L)
{
    lua_pushstring(L, REG_KEY);
    lua_rawget(L, LUA_REGISTRYINDEX);
    lua_pushnil(L);
    while (lua_next(L, -2)) {
        const gchar *name = lua_tostring(L, -2);
        msg_header_t header = {
            .type = MSG_TYPE_lua_require_module,
            .length = strlen(name)+1
        };
        msg_send(ipc, &header, name);
        lua_pop(L, 1);
    }
    lua_pop(L, 1);
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
}

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
