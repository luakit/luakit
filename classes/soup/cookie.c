/*
 * classes/soup/cookie.c - cookie class
 *
 * Copyright (C) 2011 Mason Larobina <mason.larobina@gmail.com>
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

#include <libsoup/soup-date.h>
#include "classes/soup/soup.h"
#include "common/util.h"

inline static SoupCookie*
get_cookie(cookie_t *c)
{
    if (!c->cookie)
        c->cookie = soup_cookie_new("", "", "", "", -1);
    return c->cookie;
}

#define simple_get_str(prop)                                             \
    static gint                                                          \
    luaH_cookie_get_##prop(lua_State *L, cookie_t *c)                    \
    {                                                                    \
        lua_pushstring(L, get_cookie(c)->prop);                          \
        return 1;                                                        \
    }

#define simple_set_str(prop)                                             \
    static gint                                                          \
    luaH_cookie_set_##prop(lua_State *L, cookie_t *c)                    \
    {                                                                    \
        soup_cookie_set_##prop(get_cookie(c), luaL_checkstring(L, -1));  \
        return 0;                                                        \
    }

simple_get_str(name)
simple_set_str(name)
simple_get_str(value)
simple_set_str(value)
simple_get_str(domain)
simple_set_str(domain)
simple_get_str(path)
simple_set_str(path)

#undef simple_get_str
#undef simple_set_str

#define simple_get_bool(prop)                                            \
    static gint                                                          \
    luaH_cookie_get_##prop(lua_State *L, cookie_t *c)                    \
    {                                                                    \
        lua_pushboolean(L, get_cookie(c)->prop);                         \
        return 1;                                                        \
    }

#define simple_set_bool(prop)                                            \
    static gint                                                          \
    luaH_cookie_set_##prop(lua_State *L, cookie_t *c)                    \
    {                                                                    \
        soup_cookie_set_##prop(get_cookie(c), luaH_checkboolean(L, -1)); \
        return 0;                                                        \
    }

simple_get_bool(secure)
simple_set_bool(secure)
simple_get_bool(http_only)
simple_set_bool(http_only)

#undef simple_get_bool
#undef simple_set_bool

static gint
luaH_cookie_get_expires(lua_State *L, cookie_t *c)
{
    SoupCookie *cookie = get_cookie(c);
    if (!cookie->expires)
        return 0;
    lua_pushnumber(L, soup_date_to_time_t(cookie->expires));
    return 1;
}

static gint
luaH_cookie_set_expires(lua_State *L, cookie_t *c)
{
    SoupDate *date = soup_date_new_from_time_t((time_t) luaL_checklong(L, 3));
    soup_cookie_set_expires(get_cookie(c), date);
    soup_date_free(date);
    return 0;
}

gint
luaH_cookie_push(lua_State *L, SoupCookie *cookie)
{
    cookie_class.allocator(L);
    cookie_t *c = luaH_checkudata(L, -1, &cookie_class);
    c->cookie = soup_cookie_copy(cookie);
    return 1;
}

static inline cookie_t *
cookie_new(lua_State *L) {
    cookie_t *c = lua_newuserdata(L, sizeof(cookie_t));
    p_clear(c, 1);
    luaH_settype(L, &(cookie_class));
    lua_newtable(L);
    lua_newtable(L);
    lua_setmetatable(L, -2);
    lua_setfenv(L, -2);
    lua_pushvalue(L, -1);
    return c;
}

static gint
luaH_cookie_new(lua_State *L)
{
    luaH_class_new(L, &cookie_class);
    return 1;
}

static gint
luaH_cookie_gc(lua_State *L)
{
    cookie_t *c = luaH_checkudata(L, 1, &cookie_class);
    if (c->cookie)
        soup_cookie_free(c->cookie);
    return 0;
}

void
cookie_class_setup(lua_State *L)
{
    static const struct luaL_reg cookie_methods[] =
    {
        { "__call", luaH_cookie_new },
        { NULL, NULL },
    };

    static const struct luaL_reg cookie_meta[] =
    {
        { "__tostring", luaH_object_tostring },
        { "__gc", luaH_cookie_gc },
        { "__index", luaH_class_index },
        { "__newindex", luaH_class_newindex },
        { NULL, NULL },
    };

    luaH_class_setup(L, &cookie_class, "cookie",
        (lua_class_allocator_t) cookie_new,
        luaH_class_index_miss_property, luaH_class_newindex_miss_property,
        cookie_methods, cookie_meta);

#define cookie_property(token, name)                     \
    luaH_class_add_property(&cookie_class, L_TK_##token, \
        (lua_class_propfunc_t) luaH_cookie_set_##name,   \
        (lua_class_propfunc_t) luaH_cookie_get_##name,   \
        (lua_class_propfunc_t) luaH_cookie_set_##name)   \

    cookie_property(NAME, name);
    cookie_property(VALUE, value);
    cookie_property(DOMAIN, domain);
    cookie_property(PATH, path);
    cookie_property(EXPIRES, expires);
    cookie_property(SECURE, secure);
    cookie_property(HTTP_ONLY, http_only);

#undef cookie_property

}

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
