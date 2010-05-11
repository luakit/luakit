/*
 * tabs.c - notebook widget api
 *
 * Copyright (C) 2010 Mason Larobina <mason.larobina@gmail.com>
 * Copyright (C) 2007-2009 Julien Danjou <julien@danjou.info>
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

#include "luakit.h"
#include "util.h"
#include "lualib.h"
#include "luaobject.h"
#include "luafuncs.h"
#include "view.h"

#include "tabs.h"

static gint
luaH_tabs_count(lua_State *L) {
    lua_pushnumber(L, gtk_notebook_get_n_pages(GTK_NOTEBOOK(luakit.nbook)));
    return 1;
}

static gint
luaH_tabs_index(lua_State *L) {
    // I'm not sure what this function does yet.
    luaH_dumpstack(L);
    return 0;
}

static gint
luaH_tabs_module_index(lua_State *L) {
    gint i = luaL_checknumber(L, 2) - 1;
    luaH_checktabindex(i);
    /* get scroll widget */
    gpointer w = gtk_notebook_get_nth_page(GTK_NOTEBOOK(luakit.nbook), i);
    /* reverse lookup class instance ref */
    gpointer ref = g_hash_table_lookup(luakit.tabs, w);
    return luaH_object_push(L, ref);
}

const struct luaL_reg luakit_tabs_methods[] = {
    { "count", luaH_tabs_count },
    { "__index", luaH_tabs_module_index },
    { NULL, NULL }
};

const struct luaL_reg luakit_tabs_meta[] = {
    { "__index", luaH_tabs_index },
    { NULL, NULL }
};

// vim: ft=c:et:sw=4:ts=8:sts=4:enc=utf-8:tw=80
