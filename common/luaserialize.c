/*
 * Copyright © 2016 Aidan Holm <aidanholm@gmail.com>
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

#include "common/luaserialize.h"
#include "common/lualib.h"

#include <lauxlib.h>

static GByteArray *bytecode_buf; /* Used only for serializing functions */
static size_t bytecode_len; /* Used only for de-serializing functions */

static int
lua_function_writer(lua_State *UNUSED(L), const void *p, size_t sz, void *UNUSED(ud))
{
    g_byte_array_append(bytecode_buf, (guint8*)p, sz);
    return 0;
}

static const char *
lua_function_reader(lua_State *UNUSED(L), const guint8** bytes, size_t *sz)
{
    if (bytecode_len == 0)
        return NULL;
    const char *ret = (const char *)*bytes;
    *bytes += bytecode_len;
    *sz = bytecode_len;
    return ret;
}

static void
lua_serialize_value(lua_State *L, GByteArray *out, int index)
{
    gint8 type = lua_type(L, index);
    int top = lua_gettop(L);

    switch (type) {
        case LUA_TUSERDATA:
        case LUA_TTHREAD:
            luaL_error(L, "cannot serialize variable of type %s", lua_typename(L, type));
            return;
        default:
            break;
    }

    g_byte_array_append(out, (guint8*)&type, sizeof(type));

    switch (type) {
        case LUA_TNIL:
            break;
        case LUA_TNUMBER: {
            lua_Number n = lua_tonumber(L, index);
            g_byte_array_append(out, (guint8*)&n, sizeof(n));
            break;
        }
        case LUA_TBOOLEAN: {
            gint8 b = lua_toboolean(L, index);
            g_byte_array_append(out, (guint8*)&b, sizeof(b));
            break;
        }
        case LUA_TSTRING: {
            size_t len;
            const char *s = lua_tolstring(L, index, &len);
            g_byte_array_append(out, (guint8*)&len, sizeof(len));
            g_byte_array_append(out, (guint8*)s, len+1);
            break;
        }
        case LUA_TTABLE: {
            /* Serialize all key-value pairs */
            index = index > 0 ? index : lua_gettop(L) + 1 + index;
            lua_pushnil(L);
            while (lua_next(L, index) != 0) {
                lua_serialize_value(L, out, -2);
                lua_serialize_value(L, out, -1);
                lua_pop(L, 1);
            }
            /* Finish with a LUA_TNONE sentinel */
            gint8 end = LUA_TNONE;
            g_byte_array_append(out, (guint8*)&end, sizeof(end));
            break;
        }
        case LUA_TLIGHTUSERDATA: {
            gpointer p = lua_touserdata(L, index);
            g_byte_array_append(out, (guint8*)&p, sizeof(p));
            break;
        }
        case LUA_TFUNCTION: {
            /* Serialize bytecode */
            bytecode_buf = bytecode_buf ?: g_byte_array_new();
            g_byte_array_set_size(bytecode_buf, 0);
            lua_pushvalue(L, index);
            lua_dump(L, lua_function_writer, NULL);
            lua_pop(L, 1);
            size_t len = bytecode_buf->len;
            g_byte_array_append(out, (guint8*)&len, sizeof(len));
            g_byte_array_append(out, bytecode_buf->data, len);
            g_byte_array_set_size(bytecode_buf, 0);
            /* Serialize upvalues */
            lua_Debug ar;
            lua_pushvalue(L, index);
            lua_getinfo(L, ">u", &ar);
            g_byte_array_append(out, (guint8*)&ar.nups, sizeof(ar.nups));
            for (int i = 1; i <= ar.nups; i++) {
                lua_getupvalue(L, -1, i);
                lua_serialize_value(L, out, -1);
                lua_pop(L, 1);
            }
            break;
        }
    }

    g_assert_cmpint(lua_gettop(L), ==, top);
}

static int
lua_deserialize_value(lua_State *L, const guint8 **bytes)
{
#define TAKE(dst, length) \
    memcpy(&(dst), *bytes, (length)); \
    *bytes += (length);

    gint8 type;
    TAKE(type, sizeof(type));

    int top = lua_gettop(L);

    switch (type) {
        case LUA_TNIL:
            lua_pushnil(L);
            break;
        case LUA_TNUMBER: {
            lua_Number n;
            TAKE(n, sizeof(n));
            lua_pushnumber(L, n);
            break;
        }
        case LUA_TBOOLEAN: {
            gint8 b;
            TAKE(b, sizeof(b));
            lua_pushboolean(L, b);
            break;
        }
        case LUA_TSTRING: {
            size_t len;
            TAKE(len, sizeof(len));
            lua_pushlstring(L, (char*)*bytes, len);
            *bytes += len+1;
            break;
        }
        case LUA_TTABLE: {
            lua_newtable(L);
            /* Deserialize key-value pairs and set them */
            while (lua_deserialize_value(L, bytes) == 1) {
                lua_deserialize_value(L, bytes);
                lua_rawset(L, -3);
            }
            break;
        }
        case LUA_TLIGHTUSERDATA: {
            gpointer p;
            TAKE(p, sizeof(p));
            lua_pushlightuserdata(L, p);
            break;
        }
        case LUA_TFUNCTION: {
            /* Deserialize bytecode */
            TAKE(bytecode_len, sizeof(bytecode_len));
            int status = lua_load(L, (lua_Reader)lua_function_reader, bytes, NULL);
            if (status != 0)
                return luaL_error(L, "deserialize error: %s", lua_tostring(L, -1));
            /* Deserialize upvalues */
            int nups;
            TAKE(nups, sizeof(nups));
            for (int i = 1; i <= nups; i++) {
                lua_deserialize_value(L, bytes);
                lua_setupvalue(L, -2, i);
            }
            break;
        }
        case LUA_TNONE:
            return 0;
    }

    g_assert_cmpint(lua_gettop(L), ==, top + 1);

    return 1;
}

void
lua_serialize_range(lua_State *L, GByteArray *out, int start, int end)
{
    start = luaH_absindex(L, start);
    end   = luaH_absindex(L, end);

    for (int i = start; i <= end; i++)
        lua_serialize_value(L, out, i);
}

int
lua_deserialize_range(lua_State *L, const guint8 *in, guint length)
{
    const guint8 *bytes = in;
    int i = 0;

    while (bytes < in + length) {
        lua_deserialize_value(L, &bytes);
        i++;
    }

    return i;
}

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
