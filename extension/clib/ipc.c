#include "extension/msg.h"
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
    msg_send_lua(extension.ipc, MSG_TYPE_lua_msg, L, 2, lua_gettop(L));
    return 0;
}

void
ipc_channel_recv(lua_State *L, const gchar *arg, guint arglen)
{
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
    lua_insert(L, -n-1);
    luaH_object_emit_signal(L, -n-1, signame, n, 0);
    lua_pop(L, 1);
}

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
