#include <glib.h>
#include <stdio.h>
#include <stdlib.h>
#include <assert.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <sys/un.h>

#include "extension/msg.h"
#include "extension/clib/ui_process.h"
#include "common/util.h"

extern lua_State *WL;
static GIOChannel *channel;

void
msg_recv_lua_require_module(const msg_lua_require_module_t *msg, guint length)
{
    const char *module_name = msg->module_name;
    assert(strlen(module_name) > 0);
    assert(strlen(module_name) == length-1);

    ui_process_set_module(WL, module_name);

    lua_getglobal(WL, "require");
    lua_pushstring(WL, module_name);
    lua_call(WL, 1, 0);

    ui_process_set_module(WL, NULL);
}

void
msg_recv_lua_msg(const msg_lua_msg_t *msg, guint length)
{
    const guint module = msg->module;
    const char *arg = msg->arg;
    assert(strlen(arg) > 0);
    assert(sizeof(module) + strlen(arg)+1 == length);

    ui_process_recv(WL, module, arg);
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

    channel = g_io_channel_unix_new(sock);
    g_io_channel_set_encoding(channel, NULL, NULL);
    g_io_channel_set_buffered(channel, FALSE);
    g_io_add_watch (channel, G_IO_IN | G_IO_HUP, msg_recv, NULL);

    return 0;
fail_connect:
    close(sock);
fail_socket:
    return 1;
}

void
msg_send(const msg_header_t *header, const void *data)
{
    g_io_channel_write_chars(channel, (gchar*)header, sizeof(*header), NULL, NULL);
    g_io_channel_write_chars(channel, (gchar*)data, header->length, NULL, NULL);
}

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
