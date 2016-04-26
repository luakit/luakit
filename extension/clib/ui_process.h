#ifndef LUAKIT_EXTENSION_CLIB_UI_PROCESS_H
#define LUAKIT_EXTENSION_CLIB_UI_PROCESS_H

#include <lua.h>
#include <glib.h>

#include "common/util.h"
#include "common/luaclass.h"
#include "common/luaobject.h"

typedef struct _ui_process_t {
    LUA_OBJECT_HEADER
    char *name;
    int module;
} ui_process_t;

lua_class_t ui_process_class;

void ui_process_recv(lua_State *L, const guint module, const gchar *arg);
void ui_process_set_module(lua_State *L, const gchar *module_name);
void ui_process_class_setup(lua_State *);

#endif

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
