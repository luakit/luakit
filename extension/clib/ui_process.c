#include <assert.h>

#include "extension/clib/ui_process.h"
#include "luah.h"
#include "common/tokenize.h"
#include "extension/msg.h"

LUA_OBJECT_FUNCS(ui_process_class, ui_process_t, ui_process);

#define luaH_check_ui_process(L, idx) luaH_checkudata(L, idx, &(ui_process_class))

GArray *module_refs;
gchar *name;

void
ui_process_set_module(lua_State *L, const gchar *module_name)
{
    assert(!name != !module_name);

    name = module_name ? g_strdup(module_name) : NULL;

    /* Pre-initialize an instance for this module, and push a ref */
    if (name) {
        lua_newtable(L);
        luaH_class_new(L, &ui_process_class);

        ui_process_t *ui_process = luaH_check_ui_process(L, -1);
        ui_process->name = name;

        /* Append the reference to the module reference array */
        int ref = luaL_ref(L, LUA_REGISTRYINDEX);
        g_array_append_val(module_refs, ref);
        ui_process->module = module_refs->len - 1;
    }
}

static int
luaH_ui_process_new(lua_State *L)
{
    if (!name) {
        luaL_error(L, "Can only instantiate ui_process objects during module load");
        return 0;
    }

    int ref = g_array_index(module_refs, int, module_refs->len - 1);
    lua_rawgeti(L, LUA_REGISTRYINDEX, ref);

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

    GByteArray *buf = g_byte_array_new();

    g_byte_array_append(buf, (guint8*)&ui_process->module, sizeof(ui_process->module));
    lua_serialize_range(L, buf, 2, lua_gettop(L));

    msg_header_t header = {
        .type = MSG_TYPE_lua_msg,
        .length = buf->len
    };

    msg_send(&header, buf->data);
    g_byte_array_unref(buf);

    return 0;
}

void
ui_process_recv(lua_State *L, const guint module, const gchar *arg, guint arglen)
{
    int ref = g_array_index(module_refs, int, module);
    lua_rawgeti(L, LUA_REGISTRYINDEX, ref);
    luaH_check_ui_process(L, -1);

    int n = lua_deserialize_range(L, arg, arglen);
    const char *signame = lua_tostring(L, -n);
    lua_remove(L, -n);
    luaH_object_emit_signal(L, -n, signame, n-1, 0);
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

    module_refs = g_array_new(FALSE, FALSE, sizeof(int));
}

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
