/*
 * common/property.c - GObject property set/get lua functions
 *
 * Copyright © 2011 Mason Larobina <mason.larobina@gmail.com>
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

#include "common/property.h"
#include "clib/soup/soup.h"

#include <webkit/webkit.h>

static gint
luaH_gobject_get(lua_State *L, property_t *p, GObject *object)
{
    SoupURI *u;
    property_tmp_t tmp;

#define TG_CASE(type, dest, pfunc)                    \
      case type:                                      \
        g_object_get(object, p->name, &(dest), NULL); \
        pfunc(L, dest);                               \
        return 1;

    switch(p->type) {
      TG_CASE(BOOL,   tmp.b, lua_pushboolean)
      TG_CASE(INT,    tmp.i, lua_pushnumber)
      TG_CASE(FLOAT,  tmp.f, lua_pushnumber)
      TG_CASE(DOUBLE, tmp.d, lua_pushnumber)

      case CHAR:
        g_object_get(object, p->name, &tmp.c, NULL);
        lua_pushstring(L, tmp.c);
        g_free(tmp.c);
        return 1;

      case URI:
        g_object_get(object, p->name, &u, NULL);
        tmp.c = u ? soup_uri_to_string(u, 0) : NULL;
        lua_pushstring(L, tmp.c);
        if (u) soup_uri_free(u);
        g_free(tmp.c);
        return 1;

      default:
        break;
    }
    /* unhandled property type */
    g_assert_not_reached();
}

static gboolean
luaH_gobject_set(lua_State *L, property_t *p, gint vidx, GObject *object)
{
    SoupURI *u;
    property_tmp_t tmp;
    size_t len;

#define TS_CASE(type, cast, dest, cfunc)           \
      case type:                                   \
        dest = (cast)cfunc(L, vidx);               \
        g_object_set(object, p->name, dest, NULL); \
        break;

    switch(p->type) {
      TS_CASE(BOOL,   gboolean, tmp.b, luaH_checkboolean);
      TS_CASE(INT,    gint,     tmp.i, luaL_checknumber);
      TS_CASE(FLOAT,  gfloat,   tmp.f, luaL_checknumber);
      TS_CASE(DOUBLE, gdouble,  tmp.d, luaL_checknumber);

      case CHAR:
        tmp.c = (gchar*) luaL_checkstring(L, vidx);
        g_object_set(object, p->name, tmp.c, NULL);
        break;

      case URI:
        tmp.c = (gchar*) luaL_checklstring(L, vidx, &len);
        /* use http protocol if none specified */
        if (!len || g_strrstr(tmp.c, "://"))
            tmp.c = g_strdup(tmp.c);
        else
            tmp.c = g_strdup_printf("http://%s", tmp.c);
        u = soup_uri_new(tmp.c);
        gboolean valid = !u || SOUP_URI_VALID_FOR_HTTP(u);
        if (valid) {
            g_object_set(object, p->name, u, NULL);
            g_free(tmp.c);
        }
        soup_uri_free(u);
        if (!valid) {
            lua_pushfstring(L, "invalid uri: %s", tmp.c);
            g_free(tmp.c);
            lua_error(L);
        }
        break;

      default:
        /* unhandled property type */
        g_assert_not_reached();
    }
    return TRUE;
}

gint
luaH_gobject_index(lua_State *L, property_t *props, luakit_token_t tok,
        GObject *object)
{
    for (property_t *p = props; p->tok; p++)
        if (p->tok == tok)
            return luaH_gobject_get(L, p, object);
    return 0;
}

gboolean
luaH_gobject_newindex(lua_State *L, property_t *props, luakit_token_t tok,
        gint vidx, GObject *object)
{
    for (property_t *p = props; p->tok; p++) {
        if (p->tok != tok)
            continue;
        if (p->writable)
            return luaH_gobject_set(L, p, vidx, object);
        else
            warn("read-only property: %s", p->name);
        break;
    }
    return FALSE;
}
