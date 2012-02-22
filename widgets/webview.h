/*
 * widgets/webview.h - webkit webview widget header
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

#ifndef LUAKIT_WIDGETS_WEBVIEW_H
#define LUAKIT_WIDGETS_WEBVIEW_H

#include <lua.h>
#include <webkit/webkit.h>
#include "widgets/common.h"
#include "clib/inspector.h"

typedef struct {
    /** The parent widget_t struct */
    widget_t *widget;
    /** The webview widget */
    WebKitWebView *view;
    /** The GtkScrolledWindow for the webview widget */
    GtkScrolledWindow *win;
    /** Current webview uri */
    gchar *uri;
    /** Currently hovered uri */
    gchar *hover;
    /** Scrollbar hide signal id */
    gulong hide_id;
    /** The webinspector */
    inspector_t *inspector;
} webview_data_t;

widget_t* luaH_checkwebview(lua_State *L, gint udx);

#define luaH_checkwvdata(L, udx) ((webview_data_t*)(luaH_checkwebview(L, udx)->data))

#endif

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
