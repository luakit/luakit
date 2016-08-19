#include <glib.h>
#include <stdio.h>
#include <stdlib.h>
#include <assert.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <sys/un.h>

#include "extension/extension.h"
#include "extension/clib/extension.h"
#include "extension/msg.h"
#include "extension/scroll.h"
#include "extension/clib/ui_process.h"
#include "common/util.h"
#include "common/luajs.h"
#include "common/luaserialize.h"

void
msg_recv_lua_require_module(msg_endpoint_t *UNUSED(ipc), const msg_lua_require_module_t *msg, guint length)
{
    const char *module_name = msg->module_name;
    assert(strlen(module_name) > 0);
    assert(strlen(module_name) == length-1);

    ui_process_set_module(extension.WL, module_name);

    lua_getglobal(extension.WL, "require");
    lua_pushstring(extension.WL, module_name);
    lua_call(extension.WL, 1, 0);

    ui_process_set_module(extension.WL, NULL);
}

void
msg_recv_lua_msg(msg_endpoint_t *UNUSED(ipc), const msg_lua_msg_t *msg, guint length)
{
    ui_process_recv(extension.WL, msg->arg, length);
}

void
msg_recv_web_lua_loaded(msg_endpoint_t *UNUSED(ipc), gpointer UNUSED(msg), guint UNUSED(length))
{
    extension_class_emit_pending_signals(extension.WL);

    msg_header_t header = { .type = MSG_TYPE_web_extension_loaded, .length = 0 };
    msg_send(&extension.ipc, &header, NULL);
}

void
msg_recv_scroll(msg_endpoint_t *UNUSED(ipc), const guint8 *msg, guint length)
{
    lua_State *L = extension.WL;
    gint n = lua_deserialize_range(L, msg, length);
    g_assert_cmpint(n, ==, 3);

    guint64 page_id = lua_tointeger(L, -3);
    gint scroll_x = lua_tointeger(L, -2);
    gint scroll_y = lua_tointeger(L, -1);

    web_scroll_to(page_id, scroll_x, scroll_y);

    lua_pop(L, 3);
}

void
msg_recv_eval_js(msg_endpoint_t *UNUSED(ipc), const guint8 *msg, guint length)
{
    lua_State *L = extension.WL;
    gint n = lua_deserialize_range(L, msg, length);
    g_assert_cmpint(n, ==, 5);

    gboolean no_return = lua_toboolean(L, -5);
    guint64 page_id = lua_tointeger(L, -4);
    const gchar *script = lua_tostring(L, -3);
    const gchar *source = lua_tostring(L, -2);
    /* cb ref is index -1 */

    WebKitWebPage *page = webkit_web_extension_get_page(extension.ext, page_id);
    if (!page) {
        /* Do nothing if eval'ing on page that's been closed */
        lua_pop(L, 5);
        return;
    }
    WebKitFrame *frame = webkit_web_page_get_main_frame(page);
    WebKitScriptWorld *world = webkit_script_world_get_default();
    JSGlobalContextRef ctx = webkit_frame_get_javascript_context_for_script_world(frame, world);

    n = luaJS_eval_js(L, ctx, script, source, no_return);
    /* Send source and callback ref back again as well */
    if (n) /* Don't send if no_return == true and no errors */
        msg_send_lua(&extension.ipc, MSG_TYPE_eval_js, L, -n-2, -1);
    lua_pop(L, 5 + n);
}

static void
web_page_created_cb(WebKitWebExtension *UNUSED(ext), WebKitWebPage *web_page, gpointer UNUSED(user_data))
{
    guint64 page_id = webkit_web_page_get_id(web_page);

    msg_header_t header = { .type = MSG_TYPE_page_created, .length = sizeof(page_id) };
    msg_send(&extension.ipc, &header, &page_id);
}

int
web_extension_connect(const gchar *socket_path)
{
    int sock;

    struct sockaddr_un remote;
    remote.sun_family = AF_UNIX;
    strcpy(remote.sun_path, socket_path);
    int len = sizeof(remote.sun_family) + strlen(remote.sun_path);

    debug("luakit web process: connecting to %s", socket_path);

    if ((sock = socket(AF_UNIX, SOCK_STREAM, 0)) == -1) {
        perror("socket");
        goto fail_socket;
    }

    if (connect(sock, (struct sockaddr *)&remote, len) == -1) {
        perror("connect");
        goto fail_connect;
    }

    debug("luakit web process: connected");

    msg_endpoint_connect_to_socket(&extension.ipc, sock);

    g_signal_connect(extension.ext, "page-created", G_CALLBACK(web_page_created_cb), NULL);

    return 0;
fail_connect:
    close(sock);
fail_socket:
    return 1;
}

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
