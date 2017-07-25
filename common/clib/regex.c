/*
 * common/clib/regex.c - Small wrapper around GRegex
 *
 * Copyright © 2017 Aidan Holm
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

#include "common/clib/regex.h"
#include "common/luaobject.h"
#include "luah.h"

#include <glib.h>

typedef struct {
    LUA_OBJECT_HEADER
    GRegex *reg;
    gchar *pattern;
    GRegexCompileFlags compile_options;
    GRegexMatchFlags match_options;
} lregex_t;

static lua_class_t regex_class;
LUA_OBJECT_FUNCS(regex_class, lregex_t, regex)

#define REGEX_STOPPED -1

#define luaH_checkregex(L, idx) luaH_checkudata(L, idx, &(regex_class))

static gint
luaH_regex_gc(lua_State *L)
{
    lregex_t *regex = luaH_checkregex(L, 1);
    if (regex->reg)
        g_regex_unref(regex->reg);
    g_free(regex->pattern);
    return luaH_object_gc(L);
}

static void
luaH_regenerate_regex(lua_State *L, lregex_t *regex)
{
    g_assert(regex->pattern);

    if (regex->reg)
        g_regex_unref(regex->reg);

    GError *error = NULL;
    regex->reg = g_regex_new(regex->pattern,
            G_REGEX_DOTALL|G_REGEX_OPTIMIZE|G_REGEX_JAVASCRIPT_COMPAT, 0, &error);
    if (error) {
        lua_pushstring(L, error->message);
        g_error_free(error);
        luaL_error(L, lua_tostring(L, -1));
    }
}

static int
luaH_regex_new(lua_State *L)
{
    luaH_class_new(L, &regex_class);
    lregex_t *regex = lua_touserdata(L, -1);

    if (!regex->pattern)
        return luaL_error(L, "pattern not set");

    return 1;
}

static int
luaH_regex_match(lua_State *L)
{
    lregex_t *regex = luaH_checkregex(L, 1);
    const gchar *haystack = luaL_checkstring(L, 2);

    g_assert(regex->reg);
    gboolean matched = g_regex_match(regex->reg, haystack, 0, NULL);
    lua_pushboolean(L, matched);
    return 1;
}

static int
luaH_regex_get_pattern(lua_State *L, lregex_t *regex)
{
    lua_pushstring(L, regex->pattern);
    return 1;
}

static int
luaH_regex_set_pattern(lua_State *L, lregex_t *regex)
{
    gchar *new_pattern = g_strdup(luaL_checkstring(L, -1));
    g_free(regex->pattern);
    regex->pattern = new_pattern;
    luaH_regenerate_regex(L, regex);
    return 0;
}

void
regex_class_setup(lua_State *L)
{
    static const struct luaL_Reg regex_methods[] =
    {
        LUA_CLASS_METHODS(regex)
        { "__call", luaH_regex_new },
        { NULL, NULL }
    };

    static const struct luaL_Reg regex_meta[] =
    {
        LUA_OBJECT_META(regex)
        LUA_CLASS_META
        { "match", luaH_regex_match },
        { "__gc", luaH_regex_gc },
        { NULL, NULL },
    };

    luaH_class_setup(L, &regex_class, "regex",
            (lua_class_allocator_t) regex_new,
            NULL, NULL,
            regex_methods, regex_meta);

    luaH_class_add_property(&regex_class, L_TK_PATTERN,
            (lua_class_propfunc_t) luaH_regex_set_pattern,
            (lua_class_propfunc_t) luaH_regex_get_pattern,
            (lua_class_propfunc_t) luaH_regex_set_pattern);
}

#undef luaH_checkregex

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
