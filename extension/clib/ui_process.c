#include <assert.h>

#include "extension/clib/ui_process.h"
#include "extension/clib/page.h"
#include "luah.h"
#include "common/tokenize.h"
#include "common/luaserialize.h"
#include "extension/msg.h"
#include "extension/extension.h"

#define REG_KEY "luakit.registry.ui_process"

LUA_OBJECT_FUNCS(ui_process_class, ui_process_t, ui_process);

#define luaH_check_ui_process(L, idx) luaH_checkudata(L, idx, &(ui_process_class))

static gchar *name;

void
ui_process_set_module(lua_State *L, const gchar *module_name)
{
    assert(!name != !module_name);

    name = module_name ? g_strdup(module_name) : NULL;

    /* Pre-initialize an instance for this module, and push a ref */
    if (name) {
        lua_pushstring(L, REG_KEY);
        lua_rawget(L, LUA_REGISTRYINDEX);

        lua_pushstring(L, name);
        lua_rawget(L, -2);
        gboolean already_loaded = !lua_isnil(L, -1);
        lua_pop(L, 1);
        if (already_loaded)
            return;

        lua_pushstring(L, name);

        lua_newtable(L);
        luaH_class_new(L, &ui_process_class);
        lua_remove(L, -2);
        ui_process_t *ui_process = luaH_check_ui_process(L, -1);
        ui_process->name = name;

        lua_rawset(L, -3);
        lua_pop(L, 1);
    }
}

static int
luaH_ui_process_new(lua_State *L)
{
    if (!name) {
        luaL_error(L, "Can only instantiate ui_process objects during module load");
        return 0;
    }

    lua_pushstring(L, REG_KEY);
    lua_rawget(L, LUA_REGISTRYINDEX);
    lua_pushstring(L, name);
    lua_rawget(L, -2);
    lua_remove(L, -2);
    return 1;
}

static gint
luaH_ui_process_gc(lua_State *L)
{
    ui_process_t *ui_process = luaH_check_ui_process(L, -1);
    g_free(ui_process->name);
    return luaH_object_gc(L);
}

static gint
ui_process_send(lua_State *L)
{
    ui_process_t *ui_process = luaH_check_ui_process(L, 1);
    luaL_checkstring(L, 2);
    lua_pushstring(L, ui_process->name);
    msg_send_lua(extension.ipc, MSG_TYPE_lua_msg, L, 2, lua_gettop(L));
    return 0;
}

void
ui_process_recv(lua_State *L, const gchar *arg, guint arglen)
{
    int n = lua_deserialize_range(L, (guint8*)arg, arglen);

    /* Remove signal name, module_name and page_id from the stack */
    const char *signame = lua_tostring(L, -n);
    lua_remove(L, -n);
    const char *module_name = lua_tostring(L, -2);
    guint64 page_id = lua_tointeger(L, -1);
    lua_pop(L, 2);
    n -= 3;

    /* Prepend the page object, or nil */
    if (page_id) {
        WebKitWebPage *web_page = webkit_web_extension_get_page(extension.ext, page_id);
        luaH_page_from_web_page(L, web_page);
    } else
        lua_pushnil(L);
    lua_insert(L, -n-1);
    n++;

    /* Push the right module object onto the stack */
    lua_pushstring(L, REG_KEY);
    lua_rawget(L, LUA_REGISTRYINDEX);
    lua_pushstring(L, module_name);
    lua_rawget(L, -2);
    lua_remove(L, -2);

    /* Move the module before arguments, and emit signal */
    lua_insert(L, -n-1);
    luaH_object_emit_signal(L, -n-1, signame, n, 0);
    lua_pop(L, 1);
}

void
ui_process_class_setup(lua_State *L)
{
    static const struct luaL_reg ui_process_methods[] =
    {
        LUA_CLASS_METHODS(ui_process)
        { "__call", luaH_ui_process_new },
        { NULL, NULL }
    };

    static const struct luaL_reg ui_process_meta[] =
    {
        LUA_OBJECT_META(ui_process)
        { "emit_signal", ui_process_send },
        { "__gc", luaH_ui_process_gc },
        { NULL, NULL }
    };

    luaH_class_setup(L, &ui_process_class, "ui_process",
            (lua_class_allocator_t) ui_process_new,
            NULL, NULL,
            ui_process_methods, ui_process_meta);

    lua_pushstring(L, REG_KEY);
    lua_newtable(L);
    lua_rawset(L, LUA_REGISTRYINDEX);
}

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
