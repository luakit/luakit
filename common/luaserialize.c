#include "common/luaserialize.h"
#include "common/lualib.h"

#include <lauxlib.h>

static void
lua_serialize_value(lua_State *L, GByteArray *out, int index)
{
    gint8 type = lua_type(L, index);
    int top = lua_gettop(L);

    switch (type) {
        case LUA_TLIGHTUSERDATA:
        case LUA_TUSERDATA:
        case LUA_TFUNCTION:
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
            int b = lua_toboolean(L, index);
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
            int b;
            TAKE(b, sizeof(b));
            lua_pushboolean(L, b);
            break;
        }
        case LUA_TSTRING: {
            size_t len;
            TAKE(len, sizeof(len));
            lua_pushstring(L, (char*)*bytes);
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
