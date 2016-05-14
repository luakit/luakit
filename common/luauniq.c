#include "common/luauniq.h"
#include "common/lualib.h"

#define LUAKIT_UNIQ_REGISTRY_KEY "luakit.uniq.registry"

/* Setup the unique object system at startup. */
void
luaH_uniq_setup(lua_State *L)
{
    /* Push identification string */
    lua_pushliteral(L, LUAKIT_UNIQ_REGISTRY_KEY);
    /* Create an empty table */
    lua_newtable(L);
    /* Set metatable specifying weak-values mode */
    lua_newtable(L);
    lua_pushstring(L, "__mode");
    lua_pushstring(L, "v");
    lua_rawset(L, -3);
    lua_setmetatable(L, -2);
    /* Register table inside registry */
    lua_rawset(L, LUA_REGISTRYINDEX);
}

/* Adds a key -> Lua value mapping.
 * The key must not already be mapped to a value.
 * The stack is left unmodified,
 * `oud` is the Lua value index on the stack. */
int
luaH_uniq_add(lua_State *L, const gpointer key, int oud)
{
    /* Push the registry */
    lua_pushliteral(L, LUAKIT_UNIQ_REGISTRY_KEY);
    lua_rawget(L, LUA_REGISTRYINDEX);

    /* Assert that the value is not already there */
    lua_pushlightuserdata(L, key);
    lua_rawget(L, -2);
    g_assert(lua_isnil(L, -1));
    lua_pop(L, 1);

    /* Add the Lua value */
    lua_pushlightuserdata(L, key);
    lua_pushvalue(L, oud < 0 ? oud - 2 : oud);
    lua_rawset(L, -3);

    /* Remove the registry */
    lua_pop(L, 1);
    return 0;
}

/* Given a key, pushes its associated Lua value onto the stack,
 * or pushes nil if no such key/value pair exists; this can happen
 * if all Lua references have been released, for example. */
int
luaH_uniq_get(lua_State *L, const gpointer key)
{
    /* Push the registry */
    lua_pushliteral(L, LUAKIT_UNIQ_REGISTRY_KEY);
    lua_rawget(L, LUA_REGISTRYINDEX);

    /* Get the Lua value */
    lua_pushlightuserdata(L, key);
    lua_rawget(L, -2);

    /* Remove the registry */
    lua_remove(L, -2);

    if (lua_isnil(L, -1)) {
        lua_pop(L, 1);
        return 0;
    }

    return 1;
}

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
