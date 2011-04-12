/*
 * clib/sqlite3.c - luakit sqlite3 wrapper
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

#include <sqlite3.h>
#include <time.h>

#include "clib/sqlite3.h"
#include "common/luaobject.h"
#include "common/luaclass.h"

typedef struct {
    LUA_OBJECT_HEADER
    char *filename;
    sqlite3 *db;
} sqlite3_t;

struct callback_data {
    lua_State *L;
    gint rowi;
};

static lua_class_t sqlite3_class;
LUA_OBJECT_FUNCS(sqlite3_class, sqlite3_t, sqlite3)

static gint
luaH_sqlite3_close(lua_State *L)
{
    sqlite3_t *sqlite = luaH_checkudata(L, 1, &sqlite3_class);

    if (sqlite->filename) {
        g_free(sqlite->filename);
        sqlite->filename = NULL;
    }

    if (sqlite->db) {
        sqlite3_close(sqlite->db);
        sqlite->db = NULL;
    }

    return 0;
}

/* close database on garbage collection */
static gint
luaH_sqlite3_gc(lua_State *L)
{
    luaH_sqlite3_close(L);
    return luaH_object_gc(L);
}

/* set filename and auto-open database */
static gint
luaH_sqlite3_set_filename(lua_State *L, sqlite3_t *sqlite)
{
    gchar *error;
    const gchar *filename = luaL_checkstring(L, -1);

    /* open database */
    if (sqlite3_open(filename, &sqlite->db)) {
        sqlite3_close(sqlite->db);
        sqlite->db = NULL;

        /* raise lua error */
        error = g_strdup_printf("sqlite3: can't open %s", filename);
        lua_pushstring(L, error);
        g_free(error);
        lua_error(L);
    }

    /* save filename */
    sqlite->filename = g_strdup(filename);

    return 0;
}

static gint
luaH_sqlite3_get_filename(lua_State *L, sqlite3_t *sqlite)
{
    if (sqlite->filename) {
        lua_pushstring(L, sqlite->filename);
        return 1;
    }
    return 0;
}

static gint
luaH_sqlite3_get_open(lua_State *L, sqlite3_t *sqlite)
{
    lua_pushboolean(L, (sqlite->db != NULL));
    return 1;
}

static gint
luaH_sqlite3_changes(lua_State *L)
{
    sqlite3_t *sqlite = luaH_checkudata(L, 1, &sqlite3_class);
    if (sqlite->db) {
        lua_pushnumber(L, sqlite3_changes(sqlite->db));
        return 1;
    }
    return 0;
}

/* insert all sqlite3 result rows into a lua table */
static int
callback (gpointer data, gint argc, gchar **argv, gchar **colname)
{
    struct callback_data *d = data;
    lua_State *L = d->L;

    /* create row table */
    lua_createtable(L, 0, argc);

    for (gint i = 0; i < argc; i++) {
        /* push colname */
        lua_pushstring(L, colname[i]);
        /* push row column value */
        lua_pushstring(L, argv[i]);
        /* insert into row table */
        lua_rawset(L, -3);
    }

    /* insert row into main results table */
    lua_rawseti(L, -2, ++(d->rowi));

    return 0;
}

static gint
luaH_sqlite3_exec(lua_State *L)
{
    struct callback_data d = { L, 0 };
    gchar *error;
    const gchar *sql;
    gint timeout = 1000;
    gdouble td;
    struct timespec ts1, ts2;
    sqlite3_t *sqlite = luaH_checkudata(L, 1, &sqlite3_class);

    /* check database open */
    if (!sqlite->db) {
        lua_pushliteral(L, "sqlite3: database closed");
        lua_error(L);
    }

    /* get sql query */
    sql = luaL_checkstring(L, 2);
    debug("%s", sql);

    /* get database busy timeout */
    if (lua_gettop(L) > 2)
        timeout = luaL_checknumber(L, 3);

    /* set query timeout */
    sqlite3_busy_timeout(sqlite->db, timeout);

    /* create table to insert result rows into */
    lua_newtable(L);

    /* record time taken to exec query & build return table */
    clock_gettime(CLOCK_REALTIME, &ts1);

    if (sqlite3_exec(sqlite->db, sql, callback, &d, &error)) {
        lua_pushfstring(L, "sqlite3: failed to execute query: %s", error);
        sqlite3_free(error);
        lua_error(L);
    }

    /* get end time reference point */
    clock_gettime(CLOCK_REALTIME, &ts2);
    td = (ts2.tv_sec + (ts2.tv_nsec/1e9)) - (ts1.tv_sec + (ts1.tv_nsec/1e9));

    debug("Query OK, %d rows returned (%f sec)", d.rowi, td);

    /* push sql query & query time to "execute" signal */
    lua_pushvalue(L, 2);
    lua_pushnumber(L, td);
    luaH_object_emit_signal(L, 1, "execute", 2, 0);

    /* push number of rows in result as second return arg */
    lua_pushnumber(L, d.rowi);

    return 2;
}

static gint
luaH_sqlite3_new(lua_State *L)
{
    luaH_class_new(L, &sqlite3_class);
    sqlite3_t *sqlite = luaH_checkudata(L, -1, &sqlite3_class);

    /* error if database not opened */
    if (!sqlite->db) {
        lua_pushliteral(L, "sqlite3: database not opened, missing filename?");
        lua_error(L);
    }

    return 1;
}

void
sqlite3_class_setup(lua_State *L)
{
    static const struct luaL_reg sqlite3_methods[] =
    {
        LUA_CLASS_METHODS(sqlite3)
        { "__call", luaH_sqlite3_new },
        { NULL, NULL },
    };

    static const struct luaL_reg sqlite3_meta[] =
    {
        LUA_OBJECT_META(sqlite3)
        LUA_CLASS_META
        { "exec", luaH_sqlite3_exec },
        { "close", luaH_sqlite3_close },
        { "changes", luaH_sqlite3_changes },
        { "__gc", luaH_sqlite3_gc },
        { NULL, NULL },
    };

    luaH_class_setup(L, &sqlite3_class, "sqlite3",
            (lua_class_allocator_t) sqlite3_new,
            NULL, NULL,
            sqlite3_methods, sqlite3_meta);

    luaH_class_add_property(&sqlite3_class, L_TK_FILENAME,
            (lua_class_propfunc_t) luaH_sqlite3_set_filename,
            (lua_class_propfunc_t) luaH_sqlite3_get_filename,
            NULL);

    luaH_class_add_property(&sqlite3_class, L_TK_OPEN,
            NULL,
            (lua_class_propfunc_t) luaH_sqlite3_get_open,
            NULL);
}

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
