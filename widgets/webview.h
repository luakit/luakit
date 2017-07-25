/*
 * widgets/webview.h - interfaces to webview functionality
 *
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

#ifndef LUAKIT_WIDGETS_WEBVIEW_H
#define LUAKIT_WIDGETS_WEBVIEW_H

#include <glib.h>
#include "clib/widget.h"
#include "common/ipc.h"

widget_t* luaH_checkwebview(lua_State *L, gint udx);
widget_t* webview_get_by_id(guint64 view_id);
void webview_connect_to_endpoint(widget_t *w, ipc_endpoint_t *ipc);
void webview_set_web_process_id(widget_t *w, pid_t pid);
ipc_endpoint_t * webview_get_endpoint(widget_t *w);

#endif

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
