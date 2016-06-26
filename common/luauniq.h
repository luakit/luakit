#ifndef LUAKIT_COMMON_LUAUNIQ_H
#define LUAKIT_COMMON_LUAUNIQ_H

#include <glib.h>
#include <lua.h>

/* Registry system for unique Lua objects.
 * In contrast to the luaobject system, useful when a unique Lua instance is
 * owned by a C object, this system should be used when the C instance lifetime
 * depends on the Lua instance lifetime.
 */

void luaH_uniq_setup(lua_State *L, const gchar *reg);
int luaH_uniq_add(lua_State *L, const gchar *reg, int k, int oud);
int luaH_uniq_add_ptr(lua_State *L, const gchar *reg, gpointer key, int oud);
int luaH_uniq_get(lua_State *L, const gchar *reg, int k);
int luaH_uniq_get_ptr(lua_State *L, const gchar *reg, gpointer key);
void luaH_uniq_del(lua_State *L, const gchar *reg, int k);

#endif /* end of include guard: LUAKIT_COMMON_LUAUNIQ_H */
