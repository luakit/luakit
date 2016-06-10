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
#include "common/luaserialize.h"

void
msg_recv_lua_require_module(const msg_lua_require_module_t *msg, guint length)
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
msg_recv_lua_msg(const msg_lua_msg_t *msg, guint length)
{
    ui_process_recv(extension.WL, msg->arg, length);
}

void
msg_recv_web_lua_loaded(gpointer UNUSED(msg), guint UNUSED(length))
{
    extension_class_emit_pending_signals(extension.WL);
}

void
msg_recv_scroll(const guint8 *msg, guint length)
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

int
web_extension_connect(const gchar *socket_path)
{
    int sock;

    struct sockaddr_un remote;
    remote.sun_family = AF_UNIX;
    strcpy(remote.sun_path, socket_path);
    int len = sizeof(remote.sun_family) + strlen(remote.sun_path);

    printf("luakit web process: connecting to %s\n", socket_path);

    if ((sock = socket(AF_UNIX, SOCK_STREAM, 0)) == -1) {
        perror("socket");
        goto fail_socket;
    }

    if (connect(sock, (struct sockaddr *)&remote, len) == -1) {
        perror("connect");
        goto fail_connect;
    }

    printf("luakit web process: connected\n");

    extension.ui_channel = msg_setup(sock);

    return 0;
fail_connect:
    close(sock);
fail_socket:
    return 1;
}

void
msg_send(const msg_header_t *header, const void *data)
{
    g_io_channel_write_chars(extension.ui_channel, (gchar*)header, sizeof(*header), NULL, NULL);
    g_io_channel_write_chars(extension.ui_channel, (gchar*)data, header->length, NULL, NULL);
}

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
