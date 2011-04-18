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
#include <time.h>

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

#define luaH_checksqlite3(L, idx) luaH_checkudata(L, idx, &sqlite3_class);

/** Close the \c sqlite3 database.
 * \see http://sqlite.org/c3ref/close.html
 *
 * \param L The Lua VM state.
 *
 * \luastack
 * \lvalue A \c sqlite3 object.
 */
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

/** Collects \c sqlite3 object and closes/frees private \ref sqlite3_t
 * members.
 *
 * \param L The Lua VM state.
 *
 * \luastack
 * \lvalue A \c sqlite3 object.
 */
static gint
luaH_sqlite3_gc(lua_State *L)
{
    luaH_sqlite3_close(L);
    return luaH_object_gc(L);
}

/** Sets the \ref sqlite3_t::filename field. Setting this field triggers the
 * connection of the internal SQLite3 database handle to the given file path.
 *
 * \param L      The Lua VM state.
 * \param sqlite A \c sqlite3 objects private \ref sqlite3_t struct.
 *
 * \luastack
 * \lreturn An error if database connection fails.
 */
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

/** Pushes the \ref sqlite3_t::filename field on to the Lua stack.
 *
 * \param L      The Lua VM state.
 * \param sqlite A \c sqlite3 objects private \ref sqlite3_t struct.
 *
 * \luastack
 * \lvalue A \c sqlite3 object.
 * \return The file path used for the SQLite3 database connection handle or
 *         nil if connection closed.
 */
static gint
luaH_sqlite3_get_filename(lua_State *L, sqlite3_t *sqlite)
{
    if (sqlite->filename) {
        lua_pushstring(L, sqlite->filename);
        return 1;
    }
    return 0;
}

/** Checks if SQLite3 database connection handle is still open.
 *
 * \param L      The Lua VM state.
 * \param sqlite A \c sqlite3 objects private \ref sqlite3_t struct.
 *
 * \luastack
 * \lvalue A \c sqlite3 object.
 * \return Boolean result of expression (\ref sqlite3_t::db != NULL)
 */
static gint
luaH_sqlite3_get_open(lua_State *L, sqlite3_t *sqlite)
{
    lua_pushboolean(L, (sqlite->db != NULL));
    return 1;
}


/** Pushes on to the Lua stack the number of database rows that were changed,
 * inserted or deleted by the most recently completed SQL statement on the
 * \c sqlite3 objects database connection handle. Only changes that are
 * directly specified by the \c INSERT, \c UPDATE, or \c DELETE statements
 * are counted. Auxiliary changes caused by triggers or foreign key actions
 * are not counted.
 * \see http://www.sqlite.org/c3ref/changes.html
 *
 * \param L The Lua VM state.
 *
 * \luastack
 * \lvalue A \c sqlite3 object.
 */
static gint
luaH_sqlite3_changes(lua_State *L)
{
    sqlite3_t *sqlite = luaH_checksqlite3(L, 1);
    if (sqlite->db) {
        lua_pushnumber(L, sqlite3_changes(sqlite->db));
        return 1;
    }
    return 0;
}

/** A \c sqlite3_exec callback function which is invoked for each result
 * row coming out of the evaluated SQL. All column data is inserted into table
 * fields (indexed by their relevant column names) and the resulting table is
 * appended to the end of the main results table created in the
 * \ref luaH_sqlite3_exec function.
 * \see http://www.sqlite.org/c3ref/exec.html
 *
 * \param data    Pointer to a \c sqlite3_t struct.
 * \param argc    Number of columns in the result.
 * \param argv    An array of pointers to strings obtained as if from
 *                \c sqlite3_column_text(), one for each column.
 * \param colname An array of pointers to strings where each entry represents
 *                the name of corresponding result column as obtained from
 *                \c sqlite3_column_name().
 *
 * \luastack
 * A table at the top of the Lua stack for all result row tables.
 */
static int
exec_callback (gpointer data, gint argc, gchar **argv, gchar **colname)
{
    lua_State *L = globalconf.L;
    /* create row table */
    lua_createtable(L, 0, argc);

    for (gint i = 0; i < argc; i++) {
        /* ignore null elements */
        if (!argv[i])
            continue;
        /* push colname */
        lua_pushstring(L, colname[i]);
        /* push row column value */
        lua_pushstring(L, argv[i]);
        /* insert into row table */
        lua_rawset(L, -3);
    }

    /* increment row count and insert row into main results table */
    lua_rawseti(L, -2, ++(((sqlite3_t*)data)->rows));
    return 0;
}

/** Execute a SQLite3 SQL query.
 * \see http://sqlite.org/lang.html for the complete SQLite3 SQL syntax.
 *
 * \param L The Lua VM state.
 *
 * \luastack
 * \lparam  A \c sqlite3 object.
 * \lvalue  String of one or more valid SQL expressions.
 * \lvalue  Database busy timeout in ms (default 1000ms).
 * \lreturn Table of rows returned from the SQL query.
 * \lreturn Number of rows in return table.
 */
static gint
luaH_sqlite3_exec(lua_State *L)
{
    gchar *error;
    gint timeout = 1000;
    struct timespec ts1, ts2;
    sqlite3_t *sqlite = luaH_checksqlite3(L, 1);

    /* reset row count for callback function */
    sqlite->rows = 0;

    /* check database open */
    if (!sqlite->db) {
        lua_pushliteral(L, "sqlite3: database closed");
        lua_error(L);
    }

    /* get SQL query */
    const gchar *sql = luaL_checkstring(L, 2);
    debug("%s", sql);

    /* get database busy timeout */
    if (lua_gettop(L) > 2)
        timeout = luaL_checknumber(L, 3);

    /* set query timeout */
    sqlite3_busy_timeout(sqlite->db, timeout);

    /* create table for return result rows */
    lua_newtable(L);

    /* record time taken to exec query & build return table */
    clock_gettime(CLOCK_REALTIME, &ts1);

    if (sqlite3_exec(sqlite->db, sql, exec_callback, sqlite, &error)) {
        lua_pushfstring(L, "sqlite3: failed to execute query: %s", error);
        sqlite3_free(error);
        lua_error(L);
    }

    /* get end time reference point */
    clock_gettime(CLOCK_REALTIME, &ts2);
    gdouble td = (ts2.tv_sec + (ts2.tv_nsec/1e9))
               - (ts1.tv_sec + (ts1.tv_nsec/1e9));

    debug("Query OK, %d rows returned (%f sec)", sqlite->rows, td);

    /* push sql query & query time to "execute" signal */
    lua_pushvalue(L, 2);
    lua_pushnumber(L, td);
    luaH_object_emit_signal(L, 1, "execute", 2, 0);

    /* push number of rows in result as second return arg */
    lua_pushnumber(L, sqlite->rows);

    return 2;
}

/** Create a new \c sqlite3 instance.
 *
 * \param L The Lua VM state.
 *
 * \luastack
 * \lparam  A table with a filename value.
 * \lreturn A new \c sqlite3 database object.
 */
static gint
luaH_sqlite3_new(lua_State *L)
{
    luaH_class_new(L, &sqlite3_class);
    sqlite3_t *sqlite = luaH_checksqlite3(L, -1);

    /* error if database not opened */
    if (!sqlite->db) {
        lua_pushliteral(L, "sqlite3: database not opened, missing filename?");
        lua_error(L);
    }

    return 1;
}

/** Setup the \c sqlite3 Lua class.
 *
 * \param L The Lua VM state.
 */
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
