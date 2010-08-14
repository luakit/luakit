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

#include <webkit/webkitdownload.h>
#include <webkit/webkitnetworkrequest.h>

#include "globalconf.h"
#include "luah.h"
#include "objects/download.h"
#include "common/luaobject.h"

typedef struct
{
    LUA_OBJECT_HEADER
    WebKitDownload* webkit_download;
} download_t;

static lua_class_t download_class;
LUA_OBJECT_FUNCS(download_class, download_t, download)

/* Wraps and pushes the given download onto the Lua stack.
 * \param L The Lua VM state.
 * \param download The WebKitDownload to push onto the stack.
 */
void
luaH_pushdownload(lua_State *L, WebKitDownload* download)
{
    luaH_class_new(L, &download_class);
    download_t *lua_download = luaH_checkudata(L, -1, &download_class);
    lua_download->webkit_download = download;
}

static int
luaH_download_new(lua_State *L)
{
    const char *uri = luaL_checkstring(L, 1);
    luaH_class_new(L, &download_class);
    download_t *download = luaH_checkudata(L, -1, &download_class);
    WebKitNetworkRequest *request = webkit_network_request_new(uri);
    download->webkit_download = webkit_download_new(request);
    return 1;
}

static int
luaH_download_set_destination_uri(lua_State *L, download_t *download)
{
    const char *destination_uri = luaL_checkstring(L, -1);
    webkit_download_set_destination_uri(download->webkit_download, destination_uri);
    luaH_object_emit_signal(L, -3, "property::destination_uri", 0, 0);
    return 0;
}

static int
luaH_download_get_destination_uri(lua_State *L, download_t *download)
{
    const char *destination_uri = webkit_download_get_destination_uri(download->webkit_download);
    lua_pushstring(L, destination_uri);
    return 1;
}

static int
luaH_download_get_progress(lua_State *L, download_t *download)
{
    double progress = webkit_download_get_progress(download->webkit_download);
    lua_pushnumber(L, progress);
    return 1;
}

static int
luaH_download_get_status(lua_State *L, download_t *download)
{
    WebKitDownloadStatus status = webkit_download_get_status(download->webkit_download);
    switch (status) {
        case WEBKIT_DOWNLOAD_STATUS_FINISHED:
            lua_pushstring(L, "finished");
            break;
        case WEBKIT_DOWNLOAD_STATUS_CREATED:
            lua_pushstring(L, "created");
            break;
        case WEBKIT_DOWNLOAD_STATUS_STARTED:
            lua_pushstring(L, "started");
            break;
        case WEBKIT_DOWNLOAD_STATUS_CANCELLED:
            lua_pushstring(L, "cancelled");
            break;
        case WEBKIT_DOWNLOAD_STATUS_ERROR:
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
    double total_size = webkit_download_get_total_size(download->webkit_download);
    lua_pushnumber(L, total_size);
    return 1;
}

static int
luaH_download_get_current_size(lua_State *L, download_t *download)
{
    double current_size = webkit_download_get_current_size(download->webkit_download);
    lua_pushnumber(L, current_size);
    return 1;
}

static int
luaH_download_get_elapsed_time(lua_State *L, download_t *download)
{
    double elapsed_time = webkit_download_get_elapsed_time(download->webkit_download);
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
luaH_download_get_uri(lua_State *L, download_t *download)
{
    const char *uri = webkit_download_get_uri(download->webkit_download);
    lua_pushstring(L, uri);
    return 1;
}

static int
luaH_download_start(lua_State *L)
{
    download_t *download = luaH_checkudata(L, 1, &download_class);
    luaH_object_ref(L, 1); // TODO why? necessary?
    webkit_download_start(download->webkit_download);
    return 0;
}
static int
luaH_download_cancel(lua_State *L)
{
    download_t *download = luaH_checkudata(L, 1, &download_class);
    luaH_object_ref(L, 1); // TODO why? necessary?
    webkit_download_cancel(download->webkit_download);
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
            { NULL, NULL },
    };

    luaH_class_setup(L, &download_class, "download",
                     (lua_class_allocator_t) download_new,
                     luaH_class_index_miss_property, luaH_class_newindex_miss_property,
                     download_methods, download_meta);
    luaH_class_add_property(&download_class, L_TK_DESTINATION_URI,
                            (lua_class_propfunc_t) luaH_download_set_destination_uri,
                            (lua_class_propfunc_t) luaH_download_get_destination_uri,
                            (lua_class_propfunc_t) luaH_download_set_destination_uri);
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
    luaH_class_add_property(&download_class, L_TK_SUGGESTED_FILENAME,
                            NULL,
                            (lua_class_propfunc_t) luaH_download_get_suggested_filename,
                            NULL);
    luaH_class_add_property(&download_class, L_TK_URI,
                            NULL,
                            (lua_class_propfunc_t) luaH_download_get_uri,
                            NULL);
}

// vim: filetype=c:expandtab:shiftwidth=4:tabstop=8:softtabstop=4:encoding=utf-8:textwidth=80
