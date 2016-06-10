#ifdef WITH_WEBKIT2

#include "clib/web_module.h"
#include "common/tokenize.h"
#include "common/luauniq.h"
#include "common/luaserialize.h"
#include "extension/msg.h"
#include "msg.h"

#define REG_KEY "luakit.uniq.registry.web_module"

LUA_OBJECT_FUNCS(web_module_class, web_module_t, web_module);

#define luaH_check_web_module(L, idx) luaH_checkudata(L, idx, &(web_module_class))

static int
luaH_web_module_new(lua_State *L)
{
    const char *name = luaL_checkstring(L, -1);

    if (luaH_uniq_get(L, REG_KEY, -1))
        return 1;

    lua_newtable(L);
    luaH_class_new(L, &web_module_class);
    lua_remove(L, -2);
    web_module_t *web_module = luaH_check_web_module(L, -1);
    web_module->name = g_strdup(name);

    luaH_uniq_add(L, REG_KEY, -2, -1);

    msg_header_t header = {
        .type = MSG_TYPE_lua_require_module,
        .length = strlen(name)+1
    };
    msg_send(&header, name);

    return 1;
}

static gint
luaH_web_module_gc(lua_State *L)
{
    web_module_t *web_module = luaH_check_web_module(L, -1);
    g_free(web_module->name);
    return luaH_object_gc(L);
}

static gint
web_module_send(lua_State *L)
{
    web_module_t *web_module = luaH_check_web_module(L, 1);
    luaL_checkstring(L, 2);
    lua_pushstring(L, web_module->name);
    msg_send_lua(MSG_TYPE_lua_msg, L, 2, lua_gettop(L));
    return 0;
}

void
web_module_recv(lua_State *L, const gchar *arg, guint arglen)
{
    int n = lua_deserialize_range(L, (guint8*)arg, arglen);

    const char *signame = lua_tostring(L, -n);
    luaH_uniq_get(L, REG_KEY, -1);
    lua_remove(L, -n-1);
    lua_insert(L, -n);
    lua_remove(L, -1);
    luaH_object_emit_signal(L, -n+1, signame, n-2, 0);
    lua_pop(L, 1);
}

void
web_module_restart(lua_State *L)
{
    static gboolean crashed;
    if (!crashed) {
        crashed = TRUE;
        return;
    }

    lua_pushstring(L, REG_KEY);
    lua_rawget(L, LUA_REGISTRYINDEX);
    lua_pushnil(L);
    while (lua_next(L, -2)) {
        const gchar *name = lua_tostring(L, -2);
        msg_header_t header = {
            .type = MSG_TYPE_lua_require_module,
            .length = strlen(name)+1
        };
        msg_send(&header, name);
        lua_pop(L, 1);
    }
}

void
web_module_class_setup(lua_State *L)
{
    static const struct luaL_reg web_module_methods[] =
    {
        LUA_CLASS_METHODS(web_module)
        { "__call", luaH_web_module_new },
        { NULL, NULL }
    };

    static const struct luaL_reg web_module_meta[] =
    {
        LUA_OBJECT_META(web_module)
        { "emit_signal", web_module_send },
        { "__gc", luaH_web_module_gc },
        { NULL, NULL }
    };

    luaH_class_setup(L, &web_module_class, "web_module",
            (lua_class_allocator_t) web_module_new,
            NULL, NULL,
            web_module_methods, web_module_meta);

    luaH_uniq_setup(L, REG_KEY);
}

#endif

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
