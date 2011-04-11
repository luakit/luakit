/*
 * download.c - Wrapper for the WebKitDownload class
 *
 * Copyright © 2011 Fabian Streitel <karottenreibe@gmail.com>
 * Copyright © 2011 Mason Larobina <mason.larobina@gmail.com>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program; if not, write to the Free Software Foundation, Inc.,
 * 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
 *
 */

#include "common/luaobject.h"
#include "clib/download.h"
#include "luah.h"
#include "globalconf.h"

#include <webkit/webkitdownload.h>
#include <webkit/webkitnetworkrequest.h>
#include <glib/gstdio.h>

typedef struct {
    LUA_OBJECT_HEADER
    WebKitDownload* webkit_download;
    gpointer ref;
    gchar *uri;
    gchar *destination;
    gchar *error;
} download_t;

static lua_class_t download_class;
LUA_OBJECT_FUNCS(download_class, download_t, download)

#define luaH_checkdownload(L, idx) luaH_checkudata(L, idx, &(download_class))

/* allow garbage collection of the download object */
static void
luaH_download_unref(lua_State *L, download_t *download)
{
    if (download->ref) {
        luaH_object_unref(L, download->ref);
        download->ref = NULL;
    }

    /* delete the annoying backup file generated while downloading */
    gchar *backup = g_strdup_printf("%s~", download->destination);
    g_unlink(backup);
    g_free(backup);
}

static gboolean
download_is_started(download_t *download)
{
    WebKitDownloadStatus status = webkit_download_get_status(
            download->webkit_download);
    return status == WEBKIT_DOWNLOAD_STATUS_STARTED;
}

static gint
luaH_download_gc(lua_State *L)
{
    download_t *download = luaH_checkdownload(L, 1);
    g_object_unref(G_OBJECT(download->webkit_download));

    if (download->destination)
        g_free(download->destination);
    if (download->uri)
        g_free(download->uri);
    if (download->error)
        g_free(download->error);

    return luaH_object_gc(L);
}

static gboolean
error_cb(WebKitDownload *d, gint error_code, gint error_detail, gchar *reason,
        download_t *download)
{
    (void) d;
    (void) error_detail;
    (void) error_code;

    /* save error message */
    if (download->error)
        g_free(download->error);
    download->error = g_strdup(reason);

    /* emit error signal if able */
    if (download->ref) {
        lua_State *L = globalconf.L;
        luaH_object_push(L, download->ref);
        lua_pushstring(L, reason);
        luaH_object_emit_signal(L, -2, "error", 1, 0);
        lua_pop(L, 1);
        /* unref download object */
        luaH_download_unref(L, download);
    }
    return FALSE;
}

static gint
luaH_download_new(lua_State *L)
{
    luaH_class_new(L, &download_class);
    download_t *download = luaH_checkdownload(L, -1);

    /* create download object from constructor properties */
    WebKitNetworkRequest *request = webkit_network_request_new(
            download->uri);
    download->webkit_download = webkit_download_new(request);
    g_object_ref(G_OBJECT(download->webkit_download));

    /* raise error signal on error */
    g_signal_connect(G_OBJECT(download->webkit_download), "error",
            G_CALLBACK(error_cb), download);

    /* return download object */
    return 1;
}

gint
luaH_download_push(lua_State *L, WebKitDownload *d)
{
    download_class.allocator(L);
    download_t *download = luaH_checkdownload(L, -1);

    /* steal webkit download */
    download->uri = g_strdup(webkit_download_get_uri(d));
    download->webkit_download = d;
    g_object_ref(G_OBJECT(download->webkit_download));

    /* raise error signal on error */
    g_signal_connect(G_OBJECT(download->webkit_download), "error",
            G_CALLBACK(error_cb), download);

    /* return download object */
    return 1;
}

static gint
luaH_download_set_destination(lua_State *L, download_t *download)
{
    if (download_is_started(download)) {
        luaH_warn(L, "cannot change destination while download is running");
        return 0;
    }

    const gchar *destination = luaL_checkstring(L, -1);
    gchar *uri = g_filename_to_uri(destination, NULL, NULL);
    if (uri) {
        download->destination = g_strdup(destination);
        webkit_download_set_destination_uri(download->webkit_download, uri);
        g_free(uri);
        luaH_object_emit_signal(L, -3, "property::destination", 0, 0);

    /* g_filename_to_uri failed on destination path */
    } else {
        lua_pushfstring(L, "invalid destination: '%s'", destination);
        lua_error(L);
    }
    return 0;
}

LUA_OBJECT_EXPORT_PROPERTY(download, download_t, destination, lua_pushstring)

static gint
luaH_download_get_progress(lua_State *L, download_t *download)
{
    gdouble progress = webkit_download_get_progress(download->webkit_download);
    if (progress == 1)
        luaH_download_unref(L, download);
    lua_pushnumber(L, progress);
    return 1;
}

static gint
luaH_download_get_mime_type(lua_State *L, download_t *download)
{
    GError *error;
    const gchar *destination = webkit_download_get_destination_uri(
            download->webkit_download);
    GFile *file = g_file_new_for_uri(destination);
    GFileInfo *info = g_file_query_info(file, "standard::*", 0, NULL, &error);

    if (error) {
        if (download->error)
            g_free(download->error);
        download->error = g_strdup(error->message);
        luaH_warn(L, "%s", download->error);
        return 0;
    }

    const gchar *content_type = g_file_info_get_content_type(info);
    const gchar *mime_type = g_content_type_get_mime_type(content_type);

    g_object_unref(file);
    if (mime_type) {
        lua_pushstring(L, mime_type);
        return 1;
    }
    return 0;
}

static gint
luaH_download_get_status(lua_State *L, download_t *download)
{
    WebKitDownloadStatus status = webkit_download_get_status(
            download->webkit_download);

    switch (status) {
      case WEBKIT_DOWNLOAD_STATUS_FINISHED:
        luaH_download_unref(L, download);
        lua_pushstring(L, "finished");
        break;
      case WEBKIT_DOWNLOAD_STATUS_CREATED:
        lua_pushstring(L, "created");
        break;
      case WEBKIT_DOWNLOAD_STATUS_STARTED:
        lua_pushstring(L, "started");
        break;
      case WEBKIT_DOWNLOAD_STATUS_CANCELLED:
        luaH_download_unref(L, download);
        lua_pushstring(L, "cancelled");
        break;
      case WEBKIT_DOWNLOAD_STATUS_ERROR:
        luaH_download_unref(L, download);
        lua_pushstring(L, "error");
        break;
      default:
        luaH_warn(L, "unknown download status");
        return 0;
    }

    return 1;
}

LUA_OBJECT_EXPORT_PROPERTY(download, download_t, error, lua_pushstring)

static gint
luaH_download_get_total_size(lua_State *L, download_t *download)
{
    gdouble total_size = webkit_download_get_total_size(
            download->webkit_download);
    lua_pushnumber(L, total_size);
    return 1;
}

static gint
luaH_download_get_current_size(lua_State *L, download_t *download)
{
    gdouble current_size = webkit_download_get_current_size(
            download->webkit_download);
    lua_pushnumber(L, current_size);
    return 1;
}

static gint
luaH_download_get_elapsed_time(lua_State *L, download_t *download)
{
    gdouble elapsed_time = webkit_download_get_elapsed_time(
            download->webkit_download);
    lua_pushnumber(L, elapsed_time);
    return 1;
}

static gint
luaH_download_get_suggested_filename(lua_State *L, download_t *download)
{
    const gchar *suggested_filename = webkit_download_get_suggested_filename(
            download->webkit_download);
    lua_pushstring(L, suggested_filename);
    return 1;
}

static gint
luaH_download_set_uri(lua_State *L, download_t *download)
{
    gchar *uri = (gchar*) luaL_checkstring(L, -1);
    /* use http protocol if none specified */
    if (g_strrstr(uri, "://"))
        uri = g_strdup(uri);
    else
        uri = g_strdup_printf("http://%s", uri);
    download->uri = uri;
    return 0;
}

LUA_OBJECT_EXPORT_PROPERTY(download, download_t, uri, lua_pushstring)

/* check prerequesites for download */
static gboolean
download_check_prerequesites(lua_State *L, download_t *download)
{
    /* clear last download error message */
    if (download->error) {
        g_free(download->error);
        download->error = NULL;
    }

    /* get download destination */
    const gchar *destination = webkit_download_get_destination_uri(
        download->webkit_download);

    if (!destination) {
        download->error = g_strdup("Download destination not set");
        luaH_warn(L, "%s", download->error);
        return FALSE;
    }

    /* ready to go */
    return TRUE;
}

static gint
luaH_download_start(lua_State *L)
{
    download_t *download = luaH_checkdownload(L, 1);
    if (!download_is_started(download)) {
        /* prevent lua garbage collection while downloading */
        lua_pushvalue(L, 1);
        download->ref = luaH_object_ref(L, -1);

        /* check if we can download to destination & if enough disk space */
        if (download_check_prerequesites(L, download))
            webkit_download_start(download->webkit_download);

        /* check for webkit/glib errors from download start */
        if (download->error) {
            lua_pushstring(L, download->error);
            lua_error(L);
        }

    } else
        luaH_warn(L, "download already stared");
    return 0;
}

static gint
luaH_download_cancel(lua_State *L)
{
    download_t *download = luaH_checkdownload(L, 1);
    if (download_is_started(download)) {
        webkit_download_cancel(download->webkit_download);
        luaH_download_unref(L, download);
    } else
        luaH_warn(L, "download not started");
    return 0;
}

void
download_class_setup(lua_State *L)
{
    static const struct luaL_reg download_methods[] =
    {
        LUA_CLASS_METHODS(download)
        { "__call", luaH_download_new },
        { NULL, NULL }
    };

    static const struct luaL_reg download_meta[] =
    {
        LUA_OBJECT_META(download)
        LUA_CLASS_META
        { "start", luaH_download_start },
        { "cancel", luaH_download_cancel },
        { "__gc", luaH_download_gc },
        { NULL, NULL },
    };

    luaH_class_setup(L, &download_class, "download",
             (lua_class_allocator_t) download_new,
             NULL, NULL,
             download_methods, download_meta);

    luaH_class_add_property(&download_class, L_TK_DESTINATION,
            (lua_class_propfunc_t) luaH_download_set_destination,
            (lua_class_propfunc_t) luaH_download_get_destination,
            (lua_class_propfunc_t) luaH_download_set_destination);

    luaH_class_add_property(&download_class, L_TK_PROGRESS,
            NULL,
            (lua_class_propfunc_t) luaH_download_get_progress,
            NULL);

    luaH_class_add_property(&download_class, L_TK_STATUS,
            NULL,
            (lua_class_propfunc_t) luaH_download_get_status,
            NULL);

    luaH_class_add_property(&download_class, L_TK_ERROR,
            NULL,
            (lua_class_propfunc_t) luaH_download_get_error,
            NULL);

    luaH_class_add_property(&download_class, L_TK_TOTAL_SIZE,
            NULL,
            (lua_class_propfunc_t) luaH_download_get_total_size,
            NULL);

    luaH_class_add_property(&download_class, L_TK_CURRENT_SIZE,
            NULL,
            (lua_class_propfunc_t) luaH_download_get_current_size,
            NULL);

    luaH_class_add_property(&download_class, L_TK_ELAPSED_TIME,
            NULL,
            (lua_class_propfunc_t) luaH_download_get_elapsed_time,
            NULL);

    luaH_class_add_property(&download_class, L_TK_MIME_TYPE,
            NULL,
            (lua_class_propfunc_t) luaH_download_get_mime_type,
            NULL);

    luaH_class_add_property(&download_class, L_TK_SUGGESTED_FILENAME,
            NULL,
            (lua_class_propfunc_t) luaH_download_get_suggested_filename,
            NULL);

    luaH_class_add_property(&download_class, L_TK_URI,
            (lua_class_propfunc_t) luaH_download_set_uri,
            (lua_class_propfunc_t) luaH_download_get_uri,
            (lua_class_propfunc_t) NULL);
}

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
