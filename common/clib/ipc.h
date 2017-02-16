#ifndef LUAKIT_COMMON_CLIB_IPC_H
#define LUAKIT_COMMON_CLIB_IPC_H

#include <lua.h>
#include <glib.h>

#include "common/util.h"
#include "common/luaclass.h"
#include "common/luaobject.h"

typedef struct _ipc_channel_t {
    LUA_OBJECT_HEADER
    char *name;
} ipc_channel_t;

lua_class_t ipc_channel_class;

LUA_OBJECT_FUNCS(ipc_channel_class, ipc_channel_t, ipc_channel);

#define luaH_check_ipc_channel(L, idx) luaH_checkudata(L, idx, &(ipc_channel_class))

gint luaH_ipc_channel_new(lua_State *L);
gint ipc_channel_send(lua_State *L);
void ipc_channel_recv(lua_State *L, const gchar *arg, guint arglen);
void ipc_channel_set_module(lua_State *L, const gchar *module_name);
void ipc_channel_class_setup(lua_State *);

#endif

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
