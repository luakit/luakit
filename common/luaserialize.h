#ifndef LUAKIT_COMMON_LUASERIALIZE_H
#define LUAKIT_COMMON_LUASERIALIZE_H

#include <lua.h>
#include <glib.h>

void lua_serialize_range(lua_State *L, GByteArray *out, gint start, gint end);
int lua_deserialize_range(lua_State *L, const guint8 *in, guint length);

#endif
