#ifndef LUAKIT_CLIB_WEB_MODULE_H
#define LUAKIT_CLIB_WEB_MODULE_H

#include "common/util.h"
#include "common/luaclass.h"
#include "common/luaobject.h"
#include "common/msg.h"

typedef struct _web_module_t {
    LUA_OBJECT_HEADER
    char *name;
} web_module_t;

lua_class_t web_module_class;

void web_module_class_setup(lua_State *);
void web_module_recv(lua_State *L, const gchar *arg, guint arglen);
void web_module_load_modules_on_endpoint(msg_endpoint_t *ipc);

#endif

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
