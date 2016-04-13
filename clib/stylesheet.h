#ifndef LUAKIT_CLIB_STYLESHEET_H
#define LUAKIT_CLIB_STYLESHEET_H

#if WITH_WEBKIT2

#include "common/luaobject.h"

#include <lua.h>
#include <glib.h>
#include <webkit2/webkit2.h>

typedef struct {
    LUA_OBJECT_HEADER
    WebKitUserStyleSheet *stylesheet;
    gchar *source;
} lstylesheet_t;

void stylesheet_class_setup(lua_State *);
gpointer luaH_checkstylesheet(lua_State *L, gint idx);

#endif

#endif

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
