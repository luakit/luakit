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
#include <webkit/webkitfilechooserrequest.h>

static gboolean
run_file_chooser_request_cb(WebKitWebView* UNUSED(v), WebKitFileChooserRequest *request, widget_t *w)
{
    lua_State *L = globalconf.L;
    luaH_object_push(L, w->ref);
    filechooser_t *request_object = luaH_filechooser_push(L, request);
    //Set this to true for now so stuff running synchronous doesn't run into
    //any problems
    request_object->handled = TRUE; 
    gint ret = luaH_object_emit_signal(L, 1, "run-file-chooser", 1, 1);
    gboolean handled = (ret && lua_toboolean(L, 2));
    if(request_object->completed){
        //If this request was already fulfilled synchronouly we don't need to
        //bother with the rest  
        request_object->handled = FALSE; //false so the request object does not get unreferenced when the lua garbage collector kicks in
        lua_pop(L, 1 + ret);
        if(!handled){
            //The lua code selected files but didn't return true to handle the
            //request, this is discouraged so throw an error
            luaL_error(L, "select_files was called but the request wasn't explicitely handled (i.e. run_file_chooser didn't return true)");
        }
        return TRUE;
    }
    request_object->handled = handled;  
    if(handled){
        //If we are handling this request with lua code, we are doing so
        //asyncronically, which means we need to reference it now
        g_object_ref(G_OBJECT(request));
    }
    lua_pop(L, 1 + ret);
    return handled;
}

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
