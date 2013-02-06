/*
 * clib/filechooser.c - WebKitFileChooserRequest lua wrapper
 *
 * Copyright © 2011 Fabian Streitel <karottenreibe@gmail.com>
 * Copyright © 2011 Mason Larobina <mason.larobina@gmail.com>
 * Copyright © 2013 binlain <lainex@gmx.de>
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
#include "clib/filechooser.h"
#include "luah.h"
#include "globalconf.h"
#include "stdlib.h"

#include <webkit/webkitfilechooserrequest.h>
#include <glib/gstdio.h>

/** Internal data structure for webkit's filechooser request. */
typedef struct {
    /** Common \ref lua_object_t header. \see LUA_OBJECT_HEADER */
    LUA_OBJECT_HEADER
    WebKitFileChooserRequest* webkit_request;
    gboolean completed, //True if the request was either canceled or fulfilled
             multiple_files; 
    const gchar * const * mime_types;
    const gchar * const * selected_files;
    gpointer ref;
} filechooser_t;

static lua_class_t filechooser_class;
LUA_OBJECT_FUNCS(filechooser_class, filechooser_t, filechooser)

#define luaH_checkfilechooser(L, idx) luaH_checkudata(L, idx, &(filechooser_class))

static gint
luaH_filechooser_gc(lua_State *L)
{
    filechooser_t *filechooser = luaH_checkfilechooser(L, 1);
    g_object_unref(G_OBJECT(filechooser->webkit_request));
    return luaH_object_gc(L);
}

static gint
luaH_filechooser_select_file(lua_State *L)
{
    const gchar **files;
    filechooser_t *filechooser = luaH_checkfilechooser(L, 1);
    WebKitFileChooserRequest *request = filechooser->webkit_request;

    if(!lua_isstring(L, 2)){
        luaL_typerror(L, 2, "string");
        return 0;
    }

    if(filechooser->completed){
        luaL_error(L, "File chooser request is completed");
        return 0;
    }

    files = malloc(2);

    files[0] = lua_tostring(L, 2);
    files[1] = NULL;

    webkit_file_chooser_request_select_files(request, files);
    free(files);

    filechooser->completed = TRUE;

    return 0;
}


static gint
luaH_filechooser_select_files(lua_State *L)
{
    const gchar **files;
    filechooser_t *filechooser = luaH_checkfilechooser(L, 1);
    WebKitFileChooserRequest *request = filechooser->webkit_request;

    if(!lua_istable(L, 2)){
        luaL_typerror(L, 2, "table");
        return 0;
    }

    if(filechooser->completed){
        luaL_error(L, "File chooser request is completed");
        return 0;
    }
    
    if(!filechooser->multiple_files){
        luaL_error(L, "File chooser request does not accept multiple files, use select_file(string) instead");
        return 0;
    }

    gint len = lua_objlen(L, 2); //Length of the table
    files = malloc(len+1);

    //Iterate the table
    for (gint n = 0; n < len; ++n) {
        lua_rawgeti(L, 2, n+1);
        files[n] = lua_tostring(L, -1); 
        lua_pop(L, 1);
    } 
    files[len] = NULL;

    webkit_file_chooser_request_select_files(request, files);
    free(files);

    filechooser->completed = TRUE;

    return 0;
}

static gint
luaH_filechooser_get_mime_types(lua_State *L, filechooser_t *filechooser)
{
    luaH_push_char_array(L, filechooser->mime_types);
    return 1;
}

static gint
luaH_filechooser_get_selected_files(lua_State *L, filechooser_t *filechooser)
{
    luaH_push_char_array(L, filechooser->selected_files);
    return 1;
}

static gint
luaH_filechooser_get_multiple(lua_State *L, filechooser_t *filechooser)
{
    lua_pushboolean(L, filechooser->multiple_files);
    return 1;
}


gint
luaH_filechooser_push(lua_State *L, WebKitFileChooserRequest *f)
{
    filechooser_class.allocator(L);
    filechooser_t *filechooser = luaH_checkfilechooser(L, -1);
    filechooser->webkit_request = f;
    filechooser->completed = FALSE;
    filechooser->mime_types = webkit_file_chooser_request_get_mime_types(filechooser->webkit_request);
    filechooser->selected_files = webkit_file_chooser_request_get_selected_files(filechooser->webkit_request);
    filechooser->multiple_files = webkit_file_chooser_request_get_select_multiple(filechooser->webkit_request);
    g_object_ref(G_OBJECT(f));
    return 1;
}

void filechooser_class_setup(lua_State *L)
{
    static const struct luaL_reg filechooser_methods[] =
    {
        LUA_CLASS_METHODS(filechooser)
        { NULL, NULL }
    };

    static const struct luaL_reg filechooser_meta[] =
    {
        LUA_OBJECT_META(filechooser)
        LUA_CLASS_META
        { "select_file", luaH_filechooser_select_file },
        { "select_files", luaH_filechooser_select_files },
        { "__gc", luaH_filechooser_gc },
        { NULL, NULL },
    };

    luaH_class_setup(L, &filechooser_class, "filechooser_request",
             (lua_class_allocator_t) filechooser_new,
             NULL, NULL,
             filechooser_methods, filechooser_meta);

    luaH_class_add_property(&filechooser_class, L_TK_MIME_TYPES,
            NULL,
            (lua_class_propfunc_t) luaH_filechooser_get_mime_types,
            NULL);

    luaH_class_add_property(&filechooser_class, L_TK_SELECTED_FILES,
            NULL,
            (lua_class_propfunc_t) luaH_filechooser_get_selected_files,
            NULL);
    
    luaH_class_add_property(&filechooser_class, L_TK_MULTIPLE,
            NULL,
            (lua_class_propfunc_t) luaH_filechooser_get_multiple,
            NULL);

}

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
