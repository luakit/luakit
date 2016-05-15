#include "globalconf.h"
#include "msg.h"

#include <assert.h>
#include <webkit2/webkit2.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <sys/un.h>

void webview_scroll_recv(void *d, const msg_scroll_t *msg);

static gboolean
msg_hup(GIOChannel *channel, GIOCondition cond, gpointer UNUSED(user_data))
{
    assert(cond & G_IO_HUP);
    g_io_channel_unref(channel);
    return FALSE;
}

void
msg_recv_lua_require_module(const msg_lua_require_module_t *UNUSED(msg), guint UNUSED(length))
{
    fatal("UI process should never receive message of this type");
}

void
msg_recv_lua_msg(const msg_lua_msg_t *msg, guint length)
{
    const guint module = msg->module;
    const char *arg = msg->arg;

    web_module_recv(globalconf.L, module, arg, length-sizeof(module));
}

void
msg_recv_scroll(const msg_scroll_t *msg, guint length)
{
    g_ptr_array_foreach(globalconf.webviews, webview_scroll_recv, msg);
}

void
msg_recv_rc_loaded(const msg_lua_require_module_t *UNUSED(msg), guint UNUSED(length))
{
    fatal("UI process should never receive message of this type");
}

static gpointer
web_extension_connect(gpointer user_data)
{
    const gchar *socket_path = user_data;

    int sock, web_socket;
    struct sockaddr_un local, remote;
    local.sun_family = AF_UNIX;
    strcpy(local.sun_path, socket_path);
    int len = strlen(local.sun_path) + sizeof(local.sun_family);

    if ((sock = socket(AF_UNIX, SOCK_STREAM, 0)) == -1)
        fatal("Can't open new socket");

    /* Remove any pre-existing socket, before opening */
    unlink(local.sun_path);

    if (bind(sock, (struct sockaddr *)&local, len) == -1)
        fatal("Can't bind socket to %s", socket_path);

    if (listen(sock, 5) == -1)
        fatal("Can't listen on %s", socket_path);

    debug("Waiting for a connection...");

    socklen_t size = sizeof(remote);
    if ((web_socket = accept(sock, (struct sockaddr *)&remote, &size)) == -1)
        fatal("Can't accept on %s", socket_path);

    close(sock);

    debug("Creating channel...");

    GIOChannel *channel = g_io_channel_unix_new(web_socket);
    g_io_channel_set_encoding(channel, NULL, NULL);
    g_io_channel_set_buffered(channel, FALSE);
    g_io_add_watch(channel, G_IO_IN, msg_recv, NULL);
    g_io_add_watch(channel, G_IO_HUP, msg_hup, NULL);

    globalconf.web_channel = channel;

    /* Send all queued messages */
    g_io_channel_write_chars(globalconf.web_channel, (gchar*)globalconf.web_channel_queue->data, globalconf.web_channel_queue->len, NULL, NULL);
    g_byte_array_unref(globalconf.web_channel_queue);
    globalconf.web_channel_queue = NULL;

    return NULL;
}

static void
initialize_web_extensions_cb(WebKitWebContext *context, gpointer UNUSED(user_data))
{
    const gchar *socket_path = g_build_filename(globalconf.cache_dir, "socket", NULL);
    /* const gchar *extension_dir = "/home/aidan/Programming/luakit/luakit/"; */
    const gchar *extension_dir = LUAKIT_INSTALL_PATH;

    /* Set up connection to web extension process */
    g_thread_new("accept_thread", web_extension_connect, (void*)socket_path);

    /* There's a potential race condition here; the accept thread might not run
     * until after the web extension process has already started (and failed to
     * connect). TODO: add a busy wait */

    GVariant *payload = g_variant_new_string(socket_path);
    webkit_web_context_set_web_extensions_initialization_user_data(context, payload);
    webkit_web_context_set_web_extensions_directory(context, extension_dir);
}

void
msg_init(void)
{
    globalconf.web_channel_queue = g_byte_array_new();
    g_signal_connect(webkit_web_context_get_default(), "initialize-web-extensions",
            G_CALLBACK (initialize_web_extensions_cb), NULL);
}

void
msg_send(const msg_header_t *header, const void *data)
{
    if (globalconf.web_channel) {
        g_io_channel_write_chars(globalconf.web_channel, (gchar*)header, sizeof(*header), NULL, NULL);
        g_io_channel_write_chars(globalconf.web_channel, (gchar*)data, header->length, NULL, NULL);
    } else {
        g_byte_array_append(globalconf.web_channel_queue, (guint8*)header, sizeof(*header));
        g_byte_array_append(globalconf.web_channel_queue, (guint8*)data, header->length);
    }
}

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
