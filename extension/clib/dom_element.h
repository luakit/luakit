#ifndef LUAKIT_CLIB_DOM_ELEMENT_H
#define LUAKIT_CLIB_DOM_ELEMENT_H

#include <webkit2/webkit-web-extension.h>

#include "common/util.h"
#include "common/luaclass.h"
#include "common/luaobject.h"

#include <gtk/gtk.h>

typedef struct _dom_element_t {
    LUA_OBJECT_HEADER
    WebKitDOMHTMLElement *element;
} dom_element_t;

lua_class_t dom_element_class;

void dom_element_class_setup(lua_State *);
gint luaH_dom_element_from_node(lua_State *L, WebKitDOMElement* node);

#endif

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
