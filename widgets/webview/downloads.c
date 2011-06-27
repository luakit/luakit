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

static gboolean
mime_type_decision_cb(WebKitWebView *v, WebKitWebFrame* UNUSED(f),
        WebKitNetworkRequest *r, gchar *mime, WebKitWebPolicyDecision *pd,
        widget_t *w)
{
    lua_State *L = globalconf.L;
    const gchar *uri = webkit_network_request_get_uri(r);

    luaH_object_push(L, w->ref);
    lua_pushstring(L, uri);
    lua_pushstring(L, mime);
    gint ret = luaH_object_emit_signal(L, -3, "mime-type-decision", 2, 1);

    if (ret && !lua_toboolean(L, -1))
        /* User responded with false, ignore request */
        webkit_web_policy_decision_ignore(pd);
    else if (!webkit_web_view_can_show_mime_type(v, mime))
        webkit_web_policy_decision_download(pd);
    else
        webkit_web_policy_decision_use(pd);

    lua_pop(L, ret + 1);
    return TRUE;
}

static gboolean
download_request_cb(WebKitWebView* UNUSED(v), WebKitDownload *dl, widget_t *w)
{
    lua_State *L = globalconf.L;
    luaH_object_push(L, w->ref);
    luaH_download_push(L, dl);
    gint ret = luaH_object_emit_signal(L, 1, "download-request", 1, 1);
    gboolean handled = (ret && lua_toboolean(L, 2));
    lua_pop(L, 1 + ret);
    return handled;
}

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
