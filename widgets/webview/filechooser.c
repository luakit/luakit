/*
 * widgets/webview/downloads.c - webkit file chooser request functions
 *
 * Copyright © 2010-2011 Mason Larobina <mason.larobina@gmail.com>
 * Copyright © 2013 binlain <lainex@gmx.de>
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

#include "clib/filechooser.h"

static gboolean
run_file_chooser_request_cb(WebKitWebView* UNUSED(v), WebKitFileChooserRequest *request, widget_t *w)
{
    lua_State *L = globalconf.L;
    luaH_object_push(L, w->ref);
    luaH_filechooser_push(L, request);
    gint ret = luaH_object_emit_signal(L, 1, "run-file-chooser", 1, 1);
    gboolean handled = (ret && lua_toboolean(L, 2));
    lua_pop(L, 1 + ret);
    return handled;
}

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
