/*
 * tabs.c - root notebook widget wrapper
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
#include "tab.h"
#include "tabs.h"

/* Returns the tab class instance at the given index in the root notebook */
tab_t *
tabs_atindex(gint i) {
    luaH_checktabindex(i);
    /* get scroll widget */
    gpointer w = gtk_notebook_get_nth_page(GTK_NOTEBOOK(luakit.nbook), i);
    /* reverse lookup class instance ref */
    return g_hash_table_lookup(luakit.tabs, w);
}

static gint
luaH_tabs_count(lua_State *L) {
    lua_pushnumber(L, gtk_notebook_get_n_pages(GTK_NOTEBOOK(luakit.nbook)));
    return 1;
}

static gint
luaH_tabs_index(lua_State *L) {
    // I'm not sure what this function does yet.
    debug("I'm called by whatever you are doing now!");
    luaH_dumpstack(L);
    return 0;
}

static gint
luaH_tabs_module_index(lua_State *L) {
    gint i = luaL_checknumber(L, 2) - 1;
    tab_t *t = tabs_atindex(i);
    return luaH_object_push(L, t->ref);
}

static gint
luaH_tabs_current(lua_State *L) {
    gint i = gtk_notebook_get_current_page(GTK_NOTEBOOK(luakit.nbook));
    tab_t *t = tabs_atindex(i);
    return luaH_object_push(L, t->ref);
}

static gint
luaH_tabs_append(lua_State *L) {
    tab_t *t = luaH_checkudata(L, 1, &tab_class);
    if (t->anchored)
        luaL_error(L, "tab already in anchored");

    /* create lua reference for the object on demand */
    if (!t->ref) {
        /* duplicate userdata object */
        lua_pushvalue(L, -1);
        t->ref = luaH_object_ref_class(L, -1, &tab_class);
    }

    /* append widget to notebook */
    gtk_notebook_append_page(GTK_NOTEBOOK(luakit.nbook), t->scroll, NULL);
    t->anchored = TRUE;

    /* save reverse lookup from tab's scroll widget to tab instance */
    g_hash_table_insert(luakit.tabs, (gpointer) t->scroll, t);
    return 0;
}

static gint
luaH_tabs_insert(lua_State *L) {
    gint i = luaL_checknumber(L, 1);
    if (i != -1)
        luaH_checktabindex(--i);

    tab_t *t = luaH_checkudata(L, 2, &tab_class);
    if (t->anchored)
        luaL_error(L, "tab already anchored");

    gint ret = gtk_notebook_insert_page(GTK_NOTEBOOK(luakit.nbook),
            t->scroll, NULL, i);
    t->anchored = TRUE;

    /* return index of new page or -1 for error */
    lua_pushnumber(L, ret);
    return 1;
}

static gint
luaH_tabs_indexof(lua_State *L) {
    tab_t *t = luaH_checkudata(L, 1, &tab_class);
    if (!t->anchored)
        luaL_error(L, "tab not anchored");

    gint i = gtk_notebook_page_num(GTK_NOTEBOOK(luakit.nbook), t->scroll);
    lua_pushnumber(L, ++i);
    return 1;
}

static gint
luaH_tabs_remove(lua_State *L) {
    tab_t *t = luaH_checkudata(L, 1, &tab_class);
    if (!t->anchored)
        luaL_error(L, "tab not anchored");

    gint i = gtk_notebook_page_num(GTK_NOTEBOOK(luakit.nbook), t->scroll);
    gtk_notebook_remove_page(GTK_NOTEBOOK(luakit.nbook), i);

    t->anchored = FALSE;
    // TODO should I dereference the lua object reference stored in the tab
    // struct here?
    return 0;
}

const struct luaL_reg luakit_tabs_methods[] = {
    { "__index", luaH_tabs_module_index },
    { "append", luaH_tabs_append },
    { "count", luaH_tabs_count },
    { "current", luaH_tabs_current },
    { "indexof", luaH_tabs_indexof },
    { "insert", luaH_tabs_insert },
    { "remove", luaH_tabs_remove },
    { NULL, NULL }
};

const struct luaL_reg luakit_tabs_meta[] = {
    { "__index", luaH_tabs_index },
    { NULL, NULL }
};

// vim: ft=c:et:sw=4:ts=8:sts=4:enc=utf-8:tw=80
