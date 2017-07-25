/*
 * widgets/webview/downloads.c - webkit webview download functions
 *
 * Copyright © 2010-2011 Mason Larobina <mason.larobina@gmail.com>
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

#include "clib/download.h"
#include "clib/luakit.h"

gboolean
download_start_cb(WebKitWebContext* UNUSED(c), WebKitDownload *dl, gpointer UNUSED(user_data))
{
    WebKitWebView *dl_view = webkit_download_get_web_view(dl);
    widget_t *w = dl_view ? GOBJECT_TO_LUAKIT_WIDGET(dl_view) : NULL;

    lua_State *L = common.L;
    gint top = lua_gettop(L);
    luaH_download_push(L, dl);
    if (w)
        luaH_object_push(L, w->ref);
    else
        lua_pushnil(L);

    lua_class_t *luakit_class = luakit_lib_get_luakit_class();
    gint ret = luaH_class_emit_signal(L, luakit_class, "download-start", 2, 1);
    gboolean handled = (ret && lua_toboolean(L, 2));
    lua_settop(L, top);
    return handled;
}

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
