/*
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

#ifndef LUAKIT_EXTENSION_CLIB_PAGE_H
#define LUAKIT_EXTENSION_CLIB_PAGE_H

#include <webkit2/webkit-web-extension.h>

#include "common/util.h"
#include "common/luaclass.h"
#include "common/luaobject.h"

#include <gtk/gtk.h>

typedef struct _page_t {
    LUA_OBJECT_HEADER
    WebKitWebPage *page;
    /* Lua object ref */
    gpointer ref;
} page_t;

void page_class_setup(lua_State *);
gint luaH_page_from_web_page(lua_State *L, WebKitWebPage *web_page);

#endif

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
