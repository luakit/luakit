#ifndef LUAKIT_COMMON_LUAUTIL_H
#define LUAKIT_COMMON_LUAUTIL_H

#include <lua.h>
#include <glib.h>
#include <glib-object.h>

#include "common/luaobject.h"

typedef struct _luaH_gobject_destroy_cb_t {
    gpointer ref;
    lua_State *L;
} luaH_gobject_destroy_cb_t;

static inline void
luaH_gobject_destroy_cb(luaH_gobject_destroy_cb_t *data)
{
    luaH_object_unref(data->L, data->ref);
    g_slice_free(luaH_gobject_destroy_cb_t, data);
}

static inline void
luaH_bind_gobject_ref(lua_State *L, gpointer gobject, int idx)
{
    /* This is pretty inefficient, since a new slice is created for each bound
     * object, and half of each slice just points to the Lua state. */
    luaH_gobject_destroy_cb_t *data = g_slice_new(luaH_gobject_destroy_cb_t);

    data->L = L;
    lua_pushvalue(L, idx);
    data->ref = luaH_object_ref(L, -1);

    g_object_set_data_full(G_OBJECT(gobject), "dummy-destroy-notify", data,
            (GDestroyNotify)luaH_gobject_destroy_cb);
}

gint luaH_dofunction_on_error(lua_State *L);
void luaH_add_paths(lua_State *L, const gchar *config_dir);

#endif /* end of include guard: LUAKIT_COMMON_LUAUTIL_H */
