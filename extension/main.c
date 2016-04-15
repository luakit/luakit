#include <webkit2/webkit-web-extension.h>
#include <stdlib.h>
#include <glib.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <sys/un.h>
#include <lauxlib.h>
#include <lualib.h>

#include "common/util.h"
#include "common/luaobject.h"

lua_State *WL;

gboolean
msg_recv(GIOChannel *channel, GIOCondition cond, gpointer UNUSED(user_data))
{
    if (cond & G_IO_HUP) {
        g_io_channel_unref(channel);
        return FALSE;
    }

    if (cond & G_IO_IN) {
        printf("luakit web process: message received\n");
    }

    return TRUE;
}

static int
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

    GIOChannel *channel = g_io_channel_unix_new(sock);
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
web_lua_init(void)
{
    printf("luakit web process: Lua initializing...\n");

    WL = luaL_newstate();
    luaL_openlibs(WL);
    luaH_object_setup(WL);

    printf("luakit web process: Lua initialized\n");
}

G_MODULE_EXPORT void
webkit_web_extension_initialize_with_user_data(WebKitWebExtension *UNUSED(extension), GVariant *payload)
{
    const gchar *socket_path = g_variant_get_string(payload, NULL);

    if (web_extension_connect(socket_path)) {
        printf("luakit web process: connecting to UI thread failed\n");
        exit(EXIT_FAILURE);
    }

    web_lua_init();

    printf("luakit web process: ready for messages\n");
}

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
