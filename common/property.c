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

GHashTable*
hash_properties(property_t *properties_table)
{
    GHashTable *properties = g_hash_table_new(g_str_hash, g_str_equal);
    for (property_t *p = properties_table; p->name; p++) {
        /* pre-compile "property::name" signals for each property */
        if (!p->signame)
            p->signame = g_strdup_printf("property::%s", p->name);
        g_hash_table_insert(properties, (gpointer) p->name, (gpointer) p);
    }
    return properties;
}

inline static GObject*
get_scope_object(gpointer obj, property_t *p)
{
    switch (p->scope) {
      case SETTINGS:
        return G_OBJECT(webkit_web_view_get_settings(WEBKIT_WEB_VIEW(obj)));
      case WEBKITVIEW:
        return G_OBJECT(obj);
      case SESSION:
        return G_OBJECT(soupconf.session);
      case COOKIEJAR:
        return G_OBJECT(soupconf.cookiejar);
      default:
        break;
    }
    warn("programmer error: unknown settings scope for property: %s", p->name);
    return NULL;
}

/* sets a gobject property from lua */
gint
luaH_get_property(lua_State *L, GHashTable *properties, gpointer obj, gint nidx)
{
    SoupURI *u;
    GObject *so;
    property_t *p;
    property_tmp_value_t tmp;

    /* get property struct */
    const gchar *name = luaL_checkstring(L, nidx);
    if ((p = g_hash_table_lookup(properties, name))) {
        /* get scope object */
        so = get_scope_object(obj, p);

        switch(p->type) {
          case BOOL:
            g_object_get(so, p->name, &tmp.b, NULL);
            lua_pushboolean(L, tmp.b);
            return 1;

          case INT:
            g_object_get(so, p->name, &tmp.i, NULL);
            lua_pushnumber(L, tmp.i);
            return 1;

          case FLOAT:
            g_object_get(so, p->name, &tmp.f, NULL);
            lua_pushnumber(L, tmp.f);
            return 1;

          case DOUBLE:
            g_object_get(so, p->name, &tmp.d, NULL);
            lua_pushnumber(L, tmp.d);
            return 1;

          case CHAR:
            g_object_get(so, p->name, &tmp.c, NULL);
            lua_pushstring(L, tmp.c);
            g_free(tmp.c);
            return 1;

          case URI:
            g_object_get(so, p->name, &u, NULL);
            tmp.c = u ? soup_uri_to_string(u, 0) : NULL;
            lua_pushstring(L, tmp.c);
            if (u) soup_uri_free(u);
            g_free(tmp.c);
            return 1;

          default:
            warn("unknown property type for: %s", p->name);
            break;
        }
    }
    warn("unknown property: %s", name);
    return 0;
}

/* gets a gobject property from lua */
gint
luaH_set_property(lua_State *L, GHashTable *properties, gpointer obj, gint nidx, gint vidx)
{
    size_t len;
    GObject *so;
    SoupURI *u;
    property_t *p;
    property_tmp_value_t tmp;

    /* get property struct */
    const gchar *name = luaL_checkstring(L, nidx);
    if ((p = g_hash_table_lookup(properties, name))) {
        if (!p->writable) {
            warn("attempt to set read-only property: %s", p->name);
            return 0;
        }

        so = get_scope_object(obj, p);
        switch(p->type) {
          case BOOL:
            tmp.b = luaH_checkboolean(L, vidx);
            g_object_set(so, p->name, tmp.b, NULL);
            return 0;

          case INT:
            tmp.i = (gint) luaL_checknumber(L, vidx);
            g_object_set(so, p->name, tmp.i, NULL);
            return 0;

          case FLOAT:
            tmp.f = (gfloat) luaL_checknumber(L, vidx);
            g_object_set(so, p->name, tmp.f, NULL);
            return 0;

          case DOUBLE:
            tmp.d = (gdouble) luaL_checknumber(L, vidx);
            g_object_set(so, p->name, tmp.d, NULL);
            return 0;

          case CHAR:
            tmp.c = (gchar*) luaL_checkstring(L, vidx);
            g_object_set(so, p->name, tmp.c, NULL);
            return 0;

          case URI:
            tmp.c = (gchar*) luaL_checklstring(L, vidx, &len);
            /* use http protocol if none specified */
            if (!len || g_strrstr(tmp.c, "://"))
                tmp.c = g_strdup(tmp.c);
            else
                tmp.c = g_strdup_printf("http://%s", tmp.c);
            u = soup_uri_new(tmp.c);
            if (!u || SOUP_URI_VALID_FOR_HTTP(u))
                g_object_set(so, p->name, u, NULL);
            else
                luaL_error(L, "cannot parse uri: %s", tmp.c);
            if (u) soup_uri_free(u);
            g_free(tmp.c);
            return 0;

          default:
            warn("unknown property type for: %s", p->name);
            break;
        }
    }
    warn("unknown property: %s", name);
    return 0;
}
