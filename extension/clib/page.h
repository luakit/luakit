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

lua_class_t page_class;

void page_class_setup(lua_State *);
gint luaH_page_from_web_page(lua_State *L, WebKitWebPage *web_page);

#endif

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
