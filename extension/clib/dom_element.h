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

#ifndef LUAKIT_EXTENSION_CLIB_DOM_ELEMENT_H
#define LUAKIT_EXTENSION_CLIB_DOM_ELEMENT_H

#include "extension/extension.h"

#include "common/util.h"
#include "common/luaclass.h"
#include "common/luaobject.h"
#include "extension/clib/page.h"

#include <gtk/gtk.h>

typedef struct _dom_element_t {
    LUA_OBJECT_HEADER
    WebKitDOMElement *element;
} dom_element_t;

void dom_element_class_setup(lua_State *);
gint luaH_dom_element_from_node(lua_State *L, WebKitDOMElement* node);
JSValueRef dom_element_js_ref(page_t *page, dom_element_t *element);
dom_element_t * luaH_to_dom_element(lua_State *L, gint idx);

#endif

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
