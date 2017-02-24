#include <webkit2/webkit2.h>
#include "clib/widget.h"
#include "common/msg.h"
#include "widgets/webview.h"
#include "common/luauniq.h"

#include "common/clib/ipc.h"
#include "common/luaserialize.h"

#define REG_KEY "luakit.registry.ipc_channel"

gint
ipc_channel_send(lua_State *L)
{
    ipc_channel_t *ipc_channel = luaH_check_ipc_channel(L, 1);
    guint64 page_id = 0;
    msg_endpoint_t *ipc = NULL;

    /* Optional first argument: view to send message to */
    if (lua_isuserdata(L, 2)) {
        widget_t *w = luaH_checkwebview(L, 2);
        page_id = webkit_web_view_get_page_id(WEBKIT_WEB_VIEW(w->widget));
        ipc = webview_get_endpoint(w);
        lua_remove(L, 2);
    }

    luaL_checkstring(L, 2);
    lua_pushstring(L, ipc_channel->name);
    lua_pushinteger(L, page_id);

    if (ipc)
        msg_send_lua(ipc, MSG_TYPE_lua_msg, L, 2, lua_gettop(L));
    else {
        const GPtrArray *endpoints = msg_endpoints_get();
        for (unsigned i = 0; i < endpoints->len; i++) {
            msg_endpoint_t *ipc = g_ptr_array_index(endpoints, i);
            msg_send_lua(ipc, MSG_TYPE_lua_msg, L, 2, lua_gettop(L));
        }
    }

    return 0;
}

void
ipc_channel_recv(lua_State *L, const gchar *arg, guint arglen)
{
    gint top = lua_gettop(L);
    int n = lua_deserialize_range(L, (guint8*)arg, arglen);

    const char *signame = lua_tostring(L, -n);
    luaH_uniq_get(L, REG_KEY, -1);
    lua_remove(L, -n-1);
    lua_insert(L, -n);
    lua_remove(L, -1);
    if (!lua_isnil(L, -n+1))
        luaH_object_emit_signal(L, -n+1, signame, n-2, 0);
    lua_settop(L, top);
}

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
