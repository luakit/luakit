#ifndef LUAKIT_COMMON_LUAUTIL_H
#define LUAKIT_COMMON_LUAUTIL_H

#include <lua.h>
#include <glib.h>

void luaH_add_paths(lua_State *L, const gchar *config_dir);

#endif /* end of include guard: LUAKIT_COMMON_LUAUTIL_H */
