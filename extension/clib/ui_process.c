#include <assert.h>

#include "extension/clib/ui_process.h"
#include "extension/clib/page.h"
#include "luah.h"
#include "common/tokenize.h"
#include "common/luaserialize.h"
#include "extension/msg.h"
#include "extension/extension.h"
#include "common/clib/ipc.h"

LUA_OBJECT_FUNCS(ui_process_class, ui_process_t, ui_process);

#define luaH_check_ui_process(L, idx) luaH_checkudata(L, idx, &(ui_process_class))

static gchar *name;

void
ui_process_set_module(lua_State *UNUSED(L), const gchar *module_name)
{
    assert(!name != !module_name);

    g_free(name);
    name = module_name ? g_strdup(module_name) : NULL;
}

static int
luaH_ui_process_new(lua_State *L)
{
    if (!name) {
        luaL_error(L, "Can only instantiate ui_process objects during module load");
        return 0;
    }

    lua_settop(L, 0);
    lua_pushstring(L, name);
    return luaH_ipc_channel_new(L);
}

void
ui_process_class_setup(lua_State *L)
{
    static const struct luaL_reg ui_process_methods[] =
    {
        { "__call", luaH_ui_process_new },
        { NULL, NULL }
    };

    static const struct luaL_reg ui_process_meta[] =
    {
        { NULL, NULL }
    };

    luaH_class_setup(L, &ui_process_class, "ui_process",
            (lua_class_allocator_t) ui_process_new,
            NULL, NULL,
            ui_process_methods, ui_process_meta);
}

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
