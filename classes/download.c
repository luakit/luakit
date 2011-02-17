/*
 * download.c - Wrapper for the WebKitDownload class
 *
 * Copyright © 2009 Julien Danjou <julien@danjou.info>
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

#include <stdbool.h>
#include <webkit/webkitdownload.h>
#include <webkit/webkitnetworkrequest.h>
#include <glib/gstdio.h>

#include "globalconf.h"
#include "luah.h"
#include "classes/download.h"
#include "common/luaobject.h"

typedef struct
{
    LUA_OBJECT_HEADER
    WebKitDownload* webkit_download;
    gpointer ref;
    char *uri;
    char *destination;
    bool error;
} download_t;

static lua_class_t download_class;
LUA_OBJECT_FUNCS(download_class, download_t, download)

static void
luaH_download_unref(lua_State *L, download_t *download)
{
    // unref the object
    luaH_object_unref(L, download->ref);
    download->ref = NULL;
    // delete the annoying backup file generated while downloading
    int len = strlen(download->destination);
    char backup[len + 2];
    snprintf(backup, len + 2, "%s~", download->destination);
    g_unlink(backup);
}

static bool
download_is_started(download_t *download)
{
    WebKitDownloadStatus status = webkit_download_get_status(download->webkit_download);
    return status == WEBKIT_DOWNLOAD_STATUS_STARTED;
}

static int
luaH_download_gc(lua_State *L)
{
    download_t *download = luaH_checkudata(L, 1, &download_class);
    g_object_unref(G_OBJECT(download->webkit_download));
    g_free(download->destination);
    g_free(download->uri);
    return 0;
}

static int
luaH_download_new(lua_State *L)
{
    luaH_class_new(L, &download_class);
    download_t *download = luaH_checkudata(L, -1, &download_class);
    lua_pushvalue(L, -1);
    download->ref = luaH_object_ref(L, -1); // prevent Lua garbage collection of download while running
    download->error = false;
    WebKitNetworkRequest *request = webkit_network_request_new(download->uri);
    download->webkit_download = webkit_download_new(request);
    g_object_ref(G_OBJECT(download->webkit_download));
    return 1;
}

gint
luaH_download_push(lua_State *L, WebKitDownload* d)
{
    download_class.allocator(L);
    download_t *download = luaH_checkudata(L, -1, &download_class);
    lua_pushvalue(L, -1);
    download->ref = luaH_object_ref(L, -1); // prevent Lua garbage collection of download while running
    download->error = false;
    download->uri = g_strdup(webkit_download_get_uri(d));
    download->webkit_download = d;
    g_object_ref(G_OBJECT(download->webkit_download));
    return 1;
}

static int
luaH_download_set_destination(lua_State *L, download_t *download)
{
    if (download_is_started(download)) {
        luaH_warn(L, "cannot change destination while download is running");
    } else {
        const char *destination = luaL_checkstring(L, -1);
        download->destination = g_strdup(destination);
        const char *destination_uri = g_filename_to_uri(destination, NULL, NULL);
        webkit_download_set_destination_uri(download->webkit_download, destination_uri);
        luaH_object_emit_signal(L, -3, "property::destination_uri", 0, 0);
    }
    return 0;
}

LUA_OBJECT_EXPORT_PROPERTY(download, download_t, destination, lua_pushstring)

static int
luaH_download_get_progress(lua_State *L, download_t *download)
{
    gdouble progress = webkit_download_get_progress(download->webkit_download);
    if (progress == 1) {
        luaH_download_unref(L, download); // allow Lua garbage collection of download
    }
    lua_pushnumber(L, progress);
    return 1;
}

static int
luaH_download_get_mime_type(lua_State *L, download_t *download)
{
    GError *error;
    const char *destination = webkit_download_get_destination_uri(download->webkit_download);
    GFile *file = g_file_new_for_uri(destination);
    GFileInfo *file_info = g_file_query_info(file,
            "standard::*", 0, NULL, &error);
    const char *content_type = g_file_info_get_content_type(file_info);
    const char *mime_type = g_content_type_get_mime_type(content_type);
    if (mime_type == NULL) {
        lua_pushnil(L);
    } else {
        lua_pushstring(L, mime_type);
    }
    return 1;
}

static int
luaH_download_get_status(lua_State *L, download_t *download)
{
    WebKitDownloadStatus status = webkit_download_get_status(download->webkit_download);
    if (download->error) {
        status = WEBKIT_DOWNLOAD_STATUS_ERROR;
    }
    switch (status) {
        case WEBKIT_DOWNLOAD_STATUS_FINISHED:
            luaH_download_unref(L, download); // allow Lua garbage collection of download
            lua_pushstring(L, "finished");
            break;
        case WEBKIT_DOWNLOAD_STATUS_CREATED:
            lua_pushstring(L, "created");
            break;
        case WEBKIT_DOWNLOAD_STATUS_STARTED:
            lua_pushstring(L, "started");
            break;
        case WEBKIT_DOWNLOAD_STATUS_CANCELLED:
            luaH_download_unref(L, download); // allow Lua garbage collection of download
            lua_pushstring(L, "cancelled");
            break;
        case WEBKIT_DOWNLOAD_STATUS_ERROR:
            luaH_download_unref(L, download); // allow Lua garbage collection of download
            lua_pushstring(L, "error");
            break;
        default:
            luaH_warn(L, "unknown download status");
            return 0;
    }
    return 1;
}

static int
luaH_download_get_total_size(lua_State *L, download_t *download)
{
    gdouble total_size = webkit_download_get_total_size(download->webkit_download);
    lua_pushnumber(L, total_size);
    return 1;
}

static int
luaH_download_get_current_size(lua_State *L, download_t *download)
{
    gdouble current_size = webkit_download_get_current_size(download->webkit_download);
    lua_pushnumber(L, current_size);
    return 1;
}

static int
luaH_download_get_elapsed_time(lua_State *L, download_t *download)
{
    gdouble elapsed_time = webkit_download_get_elapsed_time(download->webkit_download);
    lua_pushnumber(L, elapsed_time);
    return 1;
}

static int
luaH_download_get_suggested_filename(lua_State *L, download_t *download)
{
    const char *suggested_filename = webkit_download_get_suggested_filename(download->webkit_download);
    lua_pushstring(L, suggested_filename);
    return 1;
}

static int
luaH_download_set_uri(lua_State *L, download_t *download)
{
    char *uri = (char*) luaL_checkstring(L, -1);
    /* use http protocol if none specified */
    if (g_strrstr(uri, "://"))
        uri = g_strdup(uri);
    else
        uri = g_strdup_printf("http://%s", uri);
    download->uri = uri;
    return 0;
}

LUA_OBJECT_EXPORT_PROPERTY(download, download_t, uri, lua_pushstring)

static void
download_check_prerequesites(download_t *download)
{
    // check prerequesites for download
    GError *error = NULL;
    // check disk space
    guint64 total_size = webkit_download_get_total_size(download->webkit_download);
    const char *destination = webkit_download_get_destination_uri(download->webkit_download);
    GFile *file = g_file_new_for_uri(destination);
    GFile *folder = g_file_get_parent(file);
    GFileInfo *info = g_file_query_filesystem_info (folder,
        G_FILE_ATTRIBUTE_FILESYSTEM_FREE, NULL, &error);
    guint64 free_space = g_file_info_get_attribute_uint64 (info,
        G_FILE_ATTRIBUTE_FILESYSTEM_FREE);
    g_object_unref(folder);
    // check permissions
    // somewhat crude: we just open it for appending and see what happens
    GFileOutputStream *stream = g_file_append_to(file, G_FILE_CREATE_NONE, NULL, &error);
    g_object_unref(stream);
    g_object_unref(file);
    // check for errors
    if (free_space < total_size || error != NULL) {
        download->error = true;
    }
}

static int
luaH_download_start(lua_State *L)
{
    download_t *download = luaH_checkudata(L, 1, &download_class);
    if (download_is_started(download)) {
        luaH_warn(L, "download already running. Cannot start twice");
    } else {
        download->error = false;
        download_check_prerequesites(download);
        if (!download->error) {
            // everything OK, download
            webkit_download_start(download->webkit_download);
        }
    }
    return 0;
}

static int
luaH_download_cancel(lua_State *L)
{
    download_t *download = luaH_checkudata(L, 1, &download_class);
    webkit_download_cancel(download->webkit_download);
    luaH_download_unref(L, download); // allow Lua garbage collection of download
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
                     luaH_class_index_miss_property, luaH_class_newindex_miss_property,
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

// vim: filetype=c:expandtab:shiftwidth=4:tabstop=8:softtabstop=4:textwidth=80
