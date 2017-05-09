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

#define NO_HANDLER(type) \
void \
ipc_recv_##type(ipc_endpoint_t *UNUSED(ipc), const gpointer UNUSED(msg), guint UNUSED(length)) \
{ \
    fatal("UI process should never receive message of type %s", #type); \
} \

NO_HANDLER(lua_require_module)
NO_HANDLER(lua_js_register)
NO_HANDLER(web_extension_loaded)
NO_HANDLER(crash)

void
ipc_recv_extension_init(ipc_endpoint_t *ipc, const gpointer UNUSED(msg), guint UNUSED(length))
{
    web_module_load_modules_on_endpoint(ipc);
    luaH_register_functions_on_endpoint(ipc, globalconf.L);

    /* Notify web extension that pending signals can be released */
    ipc_header_t header = { .type = IPC_TYPE_extension_init, .length = 0 };
    ipc_send(ipc, &header, NULL);
}

void
ipc_recv_lua_ipc(ipc_endpoint_t *UNUSED(ipc), const ipc_lua_ipc_t *msg, guint length)
{
    ipc_channel_recv(globalconf.L, msg->arg, length);
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
ipc_recv_lua_js_call(ipc_endpoint_t *from, const guint8 *msg, guint length)
{
    lua_State *L = globalconf.L;
    gint top = lua_gettop(L);

    int argc = lua_deserialize_range(L, msg, length) - 1;
    g_assert_cmpint(argc, >=, 1);

    /* Retrieve and pop view id and function ref */
    guint64 view_id = lua_tointeger(L, top + 1);
    gpointer ref = lua_touserdata(L, top + 2);
    lua_remove(L, top+1);
    lua_remove(L, top+1);

    /* get webview and push into position */
    /* Page may already have been closed */
    widget_t *w = webview_get_by_id(view_id);
    if (!w) return;
    luaH_object_push(L, w->ref);
    lua_insert(L, top+1);

    /* Call the function; push result/error and ok/error boolean */
    luaH_object_push(L, ref);
    lua_pushboolean(L, !luaH_dofunction(L, argc, 1));

    /* Serialize the result, and send it back */
    ipc_send_lua(from, IPC_TYPE_lua_js_call, L, -2, -1);
    lua_settop(L, top);
}

void
ipc_recv_lua_js_gc(ipc_endpoint_t *UNUSED(ipc), const guint8 *msg, guint length)
{
    lua_State *L = globalconf.L;
    /* Unref the function reference we got */
    gint n = lua_deserialize_range(L, msg, length);
    g_assert_cmpint(n, ==, 1);
    luaH_object_unref(L, lua_touserdata(L, -1));
    lua_pop(L, 1);
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

static gpointer
web_extension_connect_thread(const gchar *socket_path)
{
    int sock, web_socket;
    struct sockaddr_un local, remote;
    local.sun_family = AF_UNIX;
    strcpy(local.sun_path, socket_path);
    int len = strlen(local.sun_path) + sizeof(local.sun_family);

    if ((sock = socket(AF_UNIX, SOCK_STREAM, 0)) == -1)
        fatal("Error calling socket(): %s", strerror(errno));

    /* Remove any pre-existing socket, before opening */
    unlink(local.sun_path);

    if (bind(sock, (struct sockaddr *)&local, len) == -1)
        fatal("Error calling bind(): %s", strerror(errno));

    if (listen(sock, 5) == -1)
        fatal("Error calling listen(): %s", strerror(errno));

    while (TRUE) {
        debug("Waiting for a connection...");

        socklen_t size = sizeof(remote);
        if ((web_socket = accept(sock, (struct sockaddr *)&remote, &size)) == -1)
            fatal("Error calling accept(): %s", strerror(errno));

        ipc_endpoint_t *ipc = ipc_endpoint_new("UI");
        ipc_endpoint_connect_to_socket(ipc, web_socket);
    }

    return NULL;
}

static void
initialize_web_extensions_cb(WebKitWebContext *context, gpointer socket_path)
{
#if DEVELOPMENT_PATHS
    gchar *extension_dir = g_get_current_dir();
#else
    const gchar *extension_dir = LUAKIT_INSTALL_PATH;
#endif

    char *extension_file = g_build_filename(extension_dir,  "luakit.so", NULL);
    if (access(extension_file, R_OK | X_OK)) {
#if DEVELOPMENT_PATHS
#  define DEVPATHS "\nLuakit was built with DEVELOPMENT_PATHS=1; are you running luakit correctly?"
#else
#  define DEVPATHS ""
#endif
        fatal("Cannot access luakit extension '%s': %s" DEVPATHS, extension_file, strerror(errno));
#undef DEVPATHS
    }
    g_free(extension_file);

    /* There's a potential race condition here; the accept thread might not run
     * until after the web extension process has already started (and failed to
     * connect). TODO: add a busy wait */

    GVariant *payload = g_variant_new_string(socket_path);
    webkit_web_context_set_web_extensions_initialization_user_data(context, payload);
    webkit_web_context_set_web_extensions_directory(context, extension_dir);
#if DEVELOPMENT_PATHS
    g_free(extension_dir);
#endif
}

static gchar *
build_socket_path(void)
{
    gchar *socket_name = g_strdup_printf("socket.%d", getpid());
    gchar *socket_path = g_build_filename(globalconf.cache_dir, socket_name, NULL);
    g_free(socket_name);
    return socket_path;
}

static void
remove_socket_file(void)
{
    gchar *socket_path = build_socket_path();
    g_unlink(socket_path);
    g_free(socket_path);
}

void
ipc_init(void)
{
    gchar *socket_path = build_socket_path();
    /* Start web extension connection accept thread */
    g_thread_new("accept_thread", (GThreadFunc) web_extension_connect_thread, socket_path);
    g_signal_connect(web_context_get(), "initialize-web-extensions",
            G_CALLBACK (initialize_web_extensions_cb), socket_path);
    /* Remove socket file at exit */
    atexit(remove_socket_file);
}

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
