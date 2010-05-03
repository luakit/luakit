/*
 * luafuncs.c - Lua functions
 *
 * Copyright (C) 2010 Mason Larobina <mason.larobina@gmail.com>
 * Copyright (C) 2008-2009 Julien Danjou <julien@danjou.info>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 */

#include "luakit.h"
#include "util.h"
#include "config.h"
#include "luafuncs.h"

/* Dump the Lua stack. Useful for debugging. */
static void
luaH_dumpstack(lua_State *L) {
    g_fprintf(stderr, "-------- Lua stack dump ---------\n");
    for(int i = lua_gettop(L); i; i--) {
        int t = lua_type(L, i);
        switch (t) {
          case LUA_TSTRING:
            g_fprintf(stderr, "%d: string: `%s'\n", i, lua_tostring(L, i));
            break;
          case LUA_TBOOLEAN:
            g_fprintf(stderr, "%d: bool:   %s\n", i, lua_toboolean(L, i) ? "true" : "false");
            break;
          case LUA_TNUMBER:
            g_fprintf(stderr, "%d: number: %g\n", i, lua_tonumber(L, i));
            break;
          case LUA_TNIL:
            g_fprintf(stderr, "%d: nil\n", i);
            break;
          default:
            g_fprintf(stderr, "%d: %s\t#%d\t%p\n", i, lua_typename(L, t),
                (int) lua_objlen(L, i),
                lua_topointer(L, i));
            break;
        }
    }
    g_fprintf(stderr, "------- Lua stack dump end ------\n");
}

static int
luaH_dofunction_error(lua_State *L) {
    if(lualib_dofunction_on_error)
        return lualib_dofunction_on_error(L);
    return 0;
}

/** Execute an Lua function on top of the stack.
 * `nargs` is the number of arguments for the Lua function.
 * `nret` is the number of returned values from the Lua function.
 * Returns TRUE on no error, FALSE otherwise. */
static gboolean
luaH_dofunction(lua_State *L, int nargs, int nret) {
    /* Move function before arguments */
    lua_insert(L, - nargs - 1);
    /* Push error handling function */
    lua_pushcfunction(L, luaH_dofunction_error);
    /* Move error handling function before args and function */
    lua_insert(L, - nargs - 2);
    int error_func_pos = lua_gettop(L) - nargs - 1;
    if(lua_pcall(L, nargs, nret, - nargs - 2)) {
        warn("%s", lua_tostring(L, -1));
        /* Remove error function and error string */
        lua_pop(L, 2);
        return FALSE;
    }
    /* Remove error function */
    lua_remove(L, error_func_pos);
    return TRUE;
}

/* UTF-8 aware string length computing.
 * Returns the number of elements pushed on the stack. */
static int
luaH_utf8_strlen(lua_State *L) {
    const char *cmd  = luaL_checkstring(L, 1);
    lua_pushnumber(L, (ssize_t) g_utf8_strlen(NONULL(cmd), -1));
    return 1;
}

/* Overload standard Lua next function to use __next key on metatable.
 * Returns the number of elements pushed on stack. */
static int
luaHe_next(lua_State *L) {
    if(luaL_getmetafield(L, 1, "__next")) {
        lua_insert(L, 1);
        lua_call(L, lua_gettop(L) - 1, LUA_MULTRET);
        return lua_gettop(L);
    }
    luaL_checktype(L, 1, LUA_TTABLE);
    lua_settop(L, 2);
    if(lua_next(L, 1))
        return 2;
    lua_pushnil(L);
    return 1;
}

/* Overload lua_next() function by using __next metatable field to get
 * next elements. `idx` is the index number of elements in stack.
 * Returns 1 if more elements to come, 0 otherwise. */
int
luaH_next(lua_State *L, int idx) {
    if(luaL_getmetafield(L, idx, "__next")) {
        /* if idx is relative, reduce it since we got __next */
        if(idx < 0) idx--;
        /* copy table and then move key */
        lua_pushvalue(L, idx);
        lua_pushvalue(L, -3);
        lua_remove(L, -4);
        lua_pcall(L, 2, 2, 0);
        /* next returned nil, it's the end */
        if(lua_isnil(L, -1)) {
            /* remove nil */
            lua_pop(L, 2);
            return 0;
        }
        return 1;
    }
    else if(lua_istable(L, idx))
        return lua_next(L, idx);
    /* remove the key */
    lua_pop(L, 1);
    return 0;
}

/* Generic pairs function.
 * Returns the number of elements pushed on stack. */
static int
luaH_generic_pairs(lua_State *L) {
    lua_pushvalue(L, lua_upvalueindex(1));  /* return generator, */
    lua_pushvalue(L, 1);  /* state, */
    lua_pushnil(L);  /* and initial value */
    return 3;
}

/* Overload standard pairs function to use __pairs field of metatables.
 * Returns the number of elements pushed on stack. */
static int
luaHe_pairs(lua_State *L) {
    if(luaL_getmetafield(L, 1, "__pairs")) {
        lua_insert(L, 1);
        lua_call(L, lua_gettop(L) - 1, LUA_MULTRET);
        return lua_gettop(L);
    }
    luaL_checktype(L, 1, LUA_TTABLE);
    return luaH_generic_pairs(L);
}

static int
luaH_ipairs_aux(lua_State *L) {
    int i = luaL_checkint(L, 2) + 1;
    luaL_checktype(L, 1, LUA_TTABLE);
    lua_pushinteger(L, i);
    lua_rawgeti(L, 1, i);
    return (lua_isnil(L, -1)) ? 0 : 2;
}

/* Overload standard ipairs function to use __ipairs field of metatables.
 * Returns the number of elements pushed on stack. */
static int
luaHe_ipairs(lua_State *L) {
    if(luaL_getmetafield(L, 1, "__ipairs")) {
        lua_insert(L, 1);
        lua_call(L, lua_gettop(L) - 1, LUA_MULTRET);
        return lua_gettop(L);
    }

    luaL_checktype(L, 1, LUA_TTABLE);
    lua_pushvalue(L, lua_upvalueindex(1));
    lua_pushvalue(L, 1);
    lua_pushinteger(L, 0);  /* and initial value */
    return 3;
}

/* Fix up and add handy standard lib functions */
static void
luaH_fixups(lua_State *L) {
    /* export string.wlen */
    lua_getglobal(L, "string");
    lua_pushcfunction(L, &luaH_utf8_strlen);
    lua_setfield(L, -2, "wlen");
    lua_pop(L, 1);
    /* replace next */
    lua_pushliteral(L, "next");
    lua_pushcfunction(L, luaHe_next);
    lua_settable(L, LUA_GLOBALSINDEX);
    /* replace pairs */
    lua_pushliteral(L, "pairs");
    lua_pushcfunction(L, luaHe_next);
    lua_pushcclosure(L, luaHe_pairs, 1); /* pairs get next as upvalue */
    lua_settable(L, LUA_GLOBALSINDEX);
    /* replace ipairs */
    lua_pushliteral(L, "ipairs");
    lua_pushcfunction(L, luaH_ipairs_aux);
    lua_pushcclosure(L, luaHe_ipairs, 1);
    lua_settable(L, LUA_GLOBALSINDEX);
}

static int
luaH_panic(lua_State *L) {
    warn("unprotected error in call to Lua API (%s)", lua_tostring(L, -1));
    return 0;
}

static int
luaH_quit(lua_State *L) {
    (void) L;
    debug("lua calling quit function");
    destroy();
    return 0;
}

void
luaH_openlib(lua_State *L, const char *name,
    const struct luaL_reg methods[], const struct luaL_reg meta[]) {

    luaL_newmetatable(L, name);                                        /* 1 */
    lua_pushvalue(L, -1);           /* dup metatable                      2 */
    lua_setfield(L, -2, "__index"); /* metatable.__index = metatable      1 */

    luaL_register(L, NULL, meta);                                      /* 1 */
    luaL_register(L, name, methods);                                   /* 2 */
    lua_pushvalue(L, -1);           /* dup self as metatable              3 */
    lua_setmetatable(L, -2);        /* set self as metatable              2 */
    lua_pop(L, 2);
}

/* Setup the object system at startup. */
void
luaH_object_setup(lua_State *L) {
    /* Push identification string */
    lua_pushliteral(L, LUAKIT_OBJECT_REGISTRY_KEY);
    /* Create an empty table */
    lua_newtable(L);
    /* Create an empty metatable */
    lua_newtable(L);
    /* Set this empty table as the registry metatable.
     * It's used to store the number of reference on stored objects. */
    lua_setmetatable(L, -2);
    /* Register table inside registry */
    lua_rawset(L, LUA_REGISTRYINDEX);
}

void
luaH_init(xdgHandle *xdg) {
    lua_State *L;

    static const struct luaL_reg luakit_lib[] = {
        { "quit", luaH_quit },
        { NULL, NULL }
    };

    /* Lua VM init */
    L = luakit.L = luaL_newstate();

    /* Set panic fuction */
    lua_atpanic(L, luaH_panic);

    luaL_openlibs(L);

    luaH_fixups(L);

    luaH_object_setup(L);

    /* Export luakit lib */
    luaH_openlib(L, "luakit", luakit_lib, luakit_lib);

    /* add Lua search paths */
    lua_getglobal(L, "package");
    if(LUA_TTABLE != lua_type(L, 1)) {
        warn("package is not a table");
        return;
    }
    lua_getfield(L, 1, "path");
    if(LUA_TSTRING != lua_type(L, 2)) {
        warn("package.path is not a string");
        lua_pop(L, 1);
        return;
    }

    /* add XDG_CONFIG_DIR as an include path */
    const char * const *xdgconfigdirs = xdgSearchableConfigDirectories(xdg);
    for(; *xdgconfigdirs; xdgconfigdirs++)
    {
        size_t len = l_strlen(*xdgconfigdirs);
        lua_pushliteral(L, ";");
        lua_pushlstring(L, *xdgconfigdirs, len);
        lua_pushliteral(L, "/luakit/?.lua");
        lua_concat(L, 3);

        lua_pushliteral(L, ";");
        lua_pushlstring(L, *xdgconfigdirs, len);
        lua_pushliteral(L, "/luakit/?/init.lua");
        lua_concat(L, 3);

        lua_concat(L, 3); /* concatenate with package.path */
    }

    /* add Lua lib path (/usr/share/luakit/lib by default) */
    lua_pushliteral(L, ";" LUAKIT_LUA_LIB_PATH "/?.lua");
    lua_pushliteral(L, ";" LUAKIT_LUA_LIB_PATH "/?/init.lua");
    lua_concat(L, 3); /* concatenate with package.path */
    lua_setfield(L, 1, "path"); /* package.path = "concatenated string" */
}

gboolean
luaH_loadrc(const gchar *confpath, gboolean run) {
    lua_State *L = luakit.L;

    if(!luaL_loadfile(L, confpath)) {
        if(run) {
            if(lua_pcall(L, 0, LUA_MULTRET, 0)) {
                g_fprintf(stderr, "%s\n", lua_tostring(L, -1));
            } else
                return TRUE;
        } else
            lua_pop(L, 1);
        return TRUE;
    } else
        g_fprintf(stderr, "%s\n", lua_tostring(L, -1));
    return FALSE;
}

/* Load a configuration file.
 *
 * param xdg An xdg handle to use to get XDG basedir.
 * param confpatharg The configuration file to load.
 * param run Run the configuration file.
 */
gboolean
luaH_parserc(xdgHandle* xdg, const gchar *confpatharg, gboolean run) {
    Luakit *l = &luakit;
    gchar *confpath = NULL;
    gboolean ret = FALSE;

    /* try to load, return if it's ok */
    if(confpatharg) {
        debug("Attempting to load rc file: %s", confpatharg);
        if(luaH_loadrc(confpatharg, run))
            ret = TRUE;
        goto bailout;
    }
    confpath = xdgConfigFind("luakit/rc.lua", xdg);
    gchar *tmp = confpath;

    /* confpath is "string1\0string2\0string3\0\0" */
    while(*tmp) {
        debug("Loading rc file: %s", tmp);
        if(luaH_loadrc(tmp, run)) {
            l->confpath = g_strdup(tmp);
            ret = TRUE;
            goto bailout;
        } else if(!run)
            goto bailout;
        tmp += l_strlen(tmp) + 1;
    }

bailout:

    if (confpath) free(confpath);
    return ret;
}
// vim: ft=c:et:sw=4:ts=8:sts=4:enc=utf-8:tw=80
