#ifndef LUAKIT_CLIB_DOM_DOCUMENT_H
#define LUAKIT_CLIB_DOM_DOCUMENT_H

#include <webkit2/webkit-web-extension.h>

#include "common/util.h"
#include "common/luaclass.h"
#include "common/luaobject.h"

#include <gtk/gtk.h>

typedef struct _dom_document_t {
    LUA_OBJECT_HEADER
    WebKitDOMDocument *document;
} dom_document_t;

lua_class_t dom_document_class;

void dom_document_class_setup(lua_State *);
gint luaH_dom_document_from_web_page(lua_State *L, WebKitWebPage *web_page);

#endif

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
