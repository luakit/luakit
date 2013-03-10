/*
 * clib/filechooser.h - WebKitFileChooserRequest lua wrapper
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

#ifndef LUAKIT_CLIB_FILECHOOSER_H
#define LUAKIT_CLIB_FILECHOOSER_H

#include <lua.h>
#include <webkit/webkitfilechooserrequest.h>

/** Internal data structure for webkit's filechooser request. */
typedef struct {
    /** Common \ref lua_object_t header. \see LUA_OBJECT_HEADER */
    LUA_OBJECT_HEADER
    WebKitFileChooserRequest* webkit_request;
    gboolean completed, //True if the request was either canceled or fulfilled
             multiple_files,
             handled; //Indicated whether the request is handled by lua code or not
    const gchar * const * mime_types;
    const gchar * const * selected_files;
    gpointer ref;
} filechooser_t;

void filechooser_class_setup(lua_State*);
filechooser_t * luaH_filechooser_push(lua_State*, WebKitFileChooserRequest*);

#endif

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
