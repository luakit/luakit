/*
 * Copyright © 2016 Aidan Holm <aidanholm@gmail.com>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 */

#include "globalconf.h"
#include "ipc.h"

#include <assert.h>
#include <webkit2/webkit2.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <sys/un.h>
#include <glib.h>
#include <glib/gstdio.h>
#include <errno.h>
#include <stdlib.h>

#include "clib/web_module.h"
#include "clib/luakit.h"
#include "clib/widget.h"
#include "common/luaserialize.h"
#include "common/clib/ipc.h"
#include "web_context.h"
#include "widgets/webview.h"

void webview_scroll_recv(void *d, const ipc_scroll_t *ipc);
void run_javascript_finished(const guint8 *msg, guint length);

static char *socket_path;
GMutex socket_path_lock;
GCond socket_path_cond;

IPC_NO_HANDLER(lua_require_module)
IPC_NO_HANDLER(web_extension_loaded)
IPC_NO_HANDLER(crash)

void
ipc_recv_extension_init(ipc_endpoint_t *ipc, const gpointer UNUSED(msg), guint UNUSED(length))
{
    web_module_load_modules_on_endpoint(ipc);

    /* Notify web extension that pending signals can be released */
    ipc_header_t header = { .type = IPC_TYPE_extension_init, .length = 0 };
    ipc_send(ipc, &header, NULL);
}

void
ipc_recv_lua_ipc(ipc_endpoint_t *UNUSED(ipc), const ipc_lua_ipc_t *msg, guint length)
{
    ipc_channel_recv(common.L, msg->arg, length);
}

void
ipc_recv_scroll(ipc_endpoint_t *UNUSED(ipc), ipc_scroll_t *msg, guint UNUSED(length))
{
    g_ptr_array_foreach(globalconf.webviews, (GFunc)webview_scroll_recv, msg);
}

void
ipc_recv_eval_js(ipc_endpoint_t *UNUSED(ipc), const guint8 *msg, guint length)
{
    run_javascript_finished(msg, length);
}

void
ipc_recv_page_created(ipc_endpoint_t *ipc, const ipc_page_created_t *msg, guint UNUSED(length))
{
    widget_t *w = webview_get_by_id(msg->page_id);

    /* Page may already have been closed */
    if (!w) return;

    webview_connect_to_endpoint(w, ipc);
    webview_set_web_process_id(w, msg->pid);
}

static gchar *
build_socket_path(void)
{
    char suffix[11] = {0};
retry:
    for (unsigned i=0; i < sizeof(suffix)-1; i++) {
        int c = g_random_int_range(0, 10+26+26), base = '0';
        if (c >= 10) { base = 'A'; c -= 10; }
        if (c >= 26) { base = 'a'; c -= 26; }
        suffix[i] = base + c;
    }
    gchar *socket_name = g_strdup_printf("luakit-ipc-%d-%s", getpid(), suffix);
    gchar *socket_path = g_build_filename(g_get_tmp_dir(), socket_name, NULL);
    g_free(socket_name);

    if (g_file_test(socket_path, G_FILE_TEST_EXISTS)) {
        g_free(socket_path);
        goto retry;
    }
    return socket_path;
}

static gpointer
web_extension_connect_thread(gpointer UNUSED(data))
{
    gchar *path = build_socket_path();

    int sock;
    if ((sock = socket(AF_UNIX, SOCK_STREAM, 0)) == -1)
        fatal("Error calling socket(): %s", strerror(errno));

    struct sockaddr_un local;
    memset(&local, 0, sizeof(local));
    local.sun_family = AF_UNIX;
    strcpy(local.sun_path, path);
    int len = offsetof(struct sockaddr_un, sun_path) + strlen(local.sun_path);

    /* Remove any pre-existing socket, before opening */
    unlink(local.sun_path);

    if (bind(sock, (struct sockaddr *)&local, len) == -1)
        fatal("Error calling bind(): %s", strerror(errno));

    if (listen(sock, 5) == -1)
        fatal("Error calling listen(): %s", strerror(errno));

    g_mutex_lock(&socket_path_lock);
    socket_path = path;
    g_cond_signal(&socket_path_cond);
    g_mutex_unlock(&socket_path_lock);

    while (TRUE) {
        debug("Waiting for a connection...");

        int web_socket;
        struct sockaddr_un remote;
        socklen_t size = sizeof(remote);
        if ((web_socket = accept(sock, (struct sockaddr *)&remote, &size)) == -1)
            fatal("Error calling accept(): %s", strerror(errno));

        ipc_endpoint_t *ipc = ipc_endpoint_new("UI");
        ipc_endpoint_connect_to_socket(ipc, web_socket);
    }

    return NULL;
}

static void
initialize_web_extensions_cb(WebKitWebContext *context, gpointer UNUSED(data))
{
    char *dirs[] = { g_get_current_dir(), LUAKIT_LIB_PATH }, *dir = NULL;

    for (unsigned i = 0; !dir && i < LENGTH(dirs); ++i) {
        char *extension_file = g_build_filename(dirs[i],  "luakit.so", NULL);
        verbose("checking for luakit extension at '%s'", dirs[i]);
        if (!access(extension_file, R_OK))
            dir = dirs[i];
        g_free(extension_file);
    }

    if (dir)
        verbose("found luakit extension at '%s'", dir);
    else
        fatal("cannot find luakit extension 'luakit.so'");

    const char *path;
    g_mutex_lock (&socket_path_lock);
    while (!socket_path)
        g_cond_wait (&socket_path_cond, &socket_path_lock);
    path = socket_path;
    g_mutex_unlock (&socket_path_lock);

    lua_getglobal(common.L, "package");
    lua_getfield(common.L, -1, "path");
    const char *package_path = lua_tostring(common.L, -1);
    lua_getfield(common.L, -2, "cpath");
    const char *package_cpath = lua_tostring(common.L, -1);
    lua_pop(common.L, 3);

    GVariant *payload = g_variant_new("(sss)", path, package_path, package_cpath);
    webkit_web_context_set_web_extensions_initialization_user_data(context, payload);
    webkit_web_context_set_web_extensions_directory(context, dir);

    g_free(dirs[0]);
}

void
ipc_remove_socket_file(void)
{
    g_mutex_lock(&socket_path_lock);
    g_unlink(socket_path);
    g_free(socket_path);
    socket_path = NULL;
    g_mutex_unlock(&socket_path_lock);
}

void
ipc_init(void)
{
    /* Start web extension connection accept thread */
    g_thread_new("accept_thread", web_extension_connect_thread, NULL);
    g_signal_connect(web_context_get(), "initialize-web-extensions",
            G_CALLBACK (initialize_web_extensions_cb), NULL);
    atexit(ipc_remove_socket_file);
}

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
