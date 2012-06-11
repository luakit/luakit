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

#include "clib/sqlite3.h"
#include "common/luaobject.h"
#include "common/luaclass.h"
#include "globalconf.h"

#include <sqlite3.h>


/** Internal data structure for all Lua \c sqlite3 object instances. */
typedef struct {
    /** Common \ref lua_object_t header. \see LUA_OBJECT_HEADER */
    LUA_OBJECT_HEADER
    /** \privatesection */
    /** File path used to open the SQLite3 database connection handle. */
    char *filename;
    /** Internal SQLite3 connection handle object.
        \see http://www.sqlite.org/c3ref/sqlite3.html */
    sqlite3 *db;
    /** Internal count of rows returned from the last SQL query. */
    guint rows;
} sqlite3_t;

static lua_class_t sqlite3_class;
LUA_OBJECT_FUNCS(sqlite3_class, sqlite3_t, sqlite3)

#define luaH_checksqlite3(L, idx) luaH_checkudata(L, idx, &sqlite3_class)

static inline void
luaH_sqlite3_checkopen(lua_State *L, sqlite3_t *sqlite)
{
    if (!sqlite->db) {
        lua_pushliteral(L, "sqlite3: database handle closed");
        lua_error(L);
    }
}

static gint
luaH_sqlite3_close(lua_State *L)
{
    sqlite3_t *sqlite = luaH_checksqlite3(L, 1);

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

static gint
luaH_sqlite3_gc(lua_State *L)
{
    luaH_sqlite3_close(L);
    return luaH_object_gc(L);
}

static gint
luaH_sqlite3_set_filename(lua_State *L, sqlite3_t *sqlite)
{
    const gchar *filename = luaL_checkstring(L, -1);

    /* open database */
    if (sqlite3_open(filename, &sqlite->db)) {
        lua_pushfstring(L, "sqlite3: failed to open \"%s\" (%s)",
                filename, sqlite3_errmsg(sqlite->db));
        sqlite3_close(sqlite->db);
        lua_error(L);
    }

    sqlite->filename = g_strdup(filename);
    return 0;
}

static gint
luaH_sqlite3_get_filename(lua_State *L, sqlite3_t *sqlite)
{
    lua_pushstring(L, sqlite->filename);
    return 1;
}

static gint
luaH_sqlite3_changes(lua_State *L)
{
    sqlite3_t *sqlite = luaH_checksqlite3(L, 1);
    luaH_sqlite3_checkopen(L, sqlite);
    lua_pushnumber(L, sqlite3_changes(sqlite->db));
    return 1;
}

static gint
luaH_sqlite3_exec(lua_State *L)
{
    sqlite3_t *sqlite = luaH_checksqlite3(L, 1);
    luaH_sqlite3_checkopen(L, sqlite);

    /* reset row count for callback function */
    sqlite->rows = 0;

    /* get SQL query */
    const gchar *sql = luaL_checkstring(L, 2);

    /* check type before we prepare statement */
    if (!lua_isnoneornil(L, 3))
        luaH_checktable(L, 3);

    gint ret = 0, ncol = 0;

    /* compile SQL statement */
    const gchar *tail;
    sqlite3_stmt *stmt;
    if (sqlite3_prepare_v2(sqlite->db, sql, -1, &stmt, &tail)) {
        lua_pushfstring(L, "sqlite3: statement compilation failed (%s)",
                sqlite3_errmsg(sqlite->db));
        sqlite3_finalize(stmt);
        lua_error(L);
    } else if (!stmt) {
        lua_pushfstring(L, "sqlite3: no SQL found in string: \"%s\"", sql);
        lua_error(L);
    }

    /* is there values to bind to this statement? */
    if (!lua_isnoneornil(L, 3)) {
        /* iterate through table and bind values to the compiled statement */
        lua_pushnil(L);
        while (lua_next(L, 3)) {
            gint idx = 0;
            if (lua_isnumber(L, -2))
                idx = lua_tonumber(L, -2);
            else if (lua_isstring(L, -2))
                idx = sqlite3_bind_parameter_index(stmt, lua_tostring(L, -2));

            /* invalid index */
            if (idx <= 0) {
                lua_pop(L, 1);
                continue;
            }

            /* bind values */
            ret = 0;
            switch (lua_type(L, -1)) {
            case LUA_TNUMBER:
                ret = sqlite3_bind_double(stmt, idx, lua_tonumber(L, -1));
                break;
            case LUA_TBOOLEAN:
                ret = sqlite3_bind_int(stmt, idx, lua_toboolean(L, -1)?1:0);
                break;
            case LUA_TSTRING:
                ret = sqlite3_bind_text(stmt, idx, lua_tostring(L, -1), -1,
                        SQLITE_TRANSIENT);
                break;
            default:
                break;
            }

            if (!(ret == SQLITE_OK || ret == SQLITE_RANGE)) {
                lua_pushfstring(L, "sqlite3: sqlite3_bind_* failed (%s)",
                        sqlite3_errmsg(sqlite->db));
                sqlite3_finalize(stmt);
                lua_error(L);
            }

            /* pop value */
            lua_pop(L, 1);
        }
    }

    ret = sqlite3_step(stmt);

    if (ret == SQLITE_DONE || ret == SQLITE_ROW) {
        if ((ncol = sqlite3_column_count(stmt)))
            lua_newtable(L);
        else
            lua_pushnil(L); /* statement doesn't return rows */
    }

check_next_step:
    switch (ret) {
    case SQLITE_DONE:
        goto exec_done;

    case SQLITE_ROW:
        lua_newtable(L);
        for (gint i = 0; i < ncol; i++) {
            /* push column name */
            lua_pushstring(L, sqlite3_column_name(stmt, i));

            /* push column value */
            switch (sqlite3_column_type(stmt, i)) {
            case SQLITE_INTEGER:
            case SQLITE_FLOAT:
                lua_pushnumber(L, sqlite3_column_double(stmt, i));
                lua_rawset(L, -3);
                break;

            case SQLITE_BLOB:
            case SQLITE_TEXT:
                lua_pushstring(L, sqlite3_column_blob(stmt, i));
                lua_rawset(L, -3);
                break;

            case SQLITE_NULL:
            default:
                lua_pop(L, 1);
                break;
            }
        }
        lua_rawseti(L, -2, ++(sqlite->rows));
        break;

    /* there was an error */
    default:
        lua_pushfstring(L, "sqlite3: exec error (%s)",
                sqlite3_errmsg(sqlite->db));
        sqlite3_finalize(stmt);
        lua_error(L);
    }

    ret = sqlite3_step(stmt);
    goto check_next_step;

exec_done:
    sqlite3_finalize(stmt);
    if (tail && *tail) /* this is the leftovers from sqlite3_prepare_v2 */
        lua_pushstring(L, tail);
    else
        lua_pushnil(L);
    return 2;
}

static gint
luaH_sqlite3_new(lua_State *L)
{
    luaH_class_new(L, &sqlite3_class);
    sqlite3_t *sqlite = luaH_checksqlite3(L, -1);
    if (!sqlite->db) {
        lua_pushliteral(L, "sqlite3: database not opened, forgot filename?");
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
}

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
