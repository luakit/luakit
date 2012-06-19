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
} sqlite3_t;

typedef struct {
    sqlite3_t *sqlite;
    sqlite3_stmt *stmt;
    gpointer parent_ref;
} sqlite3_stmt_t;

#define luaH_checksqlite3(L, idx) luaH_checkudata(L, idx, &sqlite3_class)
#define luaH_checkstmtud(L, idx)  luaH_checkudata(L, idx, &sqlite3_stmt_class)

static lua_class_t sqlite3_class, sqlite3_stmt_class;

LUA_OBJECT_FUNCS(sqlite3_class, sqlite3_t, sqlite3)

static inline void
luaH_sqlite3_checkopen(lua_State *L, sqlite3_t *sqlite)
{
    if (!sqlite->db) {
        lua_pushliteral(L, "sqlite3: database handle closed");
        lua_error(L);
    }
}

static gint
luaH_sqlite3_stmt_gc(lua_State *L)
{
    sqlite3_stmt_t *stmt = luaH_checkstmtud(L, 1);
    /* release hold over parent sqlite3 object */
    luaH_object_unref(L, stmt->parent_ref);
    sqlite3_finalize(stmt->stmt);
    return 0;
}

/* create userdata object for executing prepared/compiled SQL statements */
sqlite3_stmt_t*
sqlite3_stmt_new(lua_State *L)
{
    sqlite3_stmt_t *p = lua_newuserdata(L, sizeof(sqlite3_stmt_t));
    p_clear(p, 1);
    luaH_settype(L, &sqlite3_stmt_class);
    lua_newtable(L);
    lua_newtable(L);
    lua_setmetatable(L, -2);
    lua_setfenv(L, -2);
    return p;
}

/* return compliled SQL statement userdata object */
static gint
luaH_sqlite3_compile(lua_State *L)
{
    sqlite3_t *sqlite = luaH_checksqlite3(L, 1);
    luaH_sqlite3_checkopen(L, sqlite);

    const gchar *sql = luaL_checkstring(L, 2);

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

    /* create userdata object */
    sqlite3_stmt_t *p = sqlite3_stmt_new(L);
    p->sqlite = sqlite;
    p->stmt = stmt;
    /* store reference to parent sqlite3 object to prevent it being collected
     * while a sqlite3_stmt object is still around */
    p->parent_ref = luaH_object_ref(L, 1);

    /* sqlite3_prepare_v2 only compiles the first statement found in the sql
     * query, if there are several `tail` points to the first character of the
     * next query */
    if (tail && *tail) {
        lua_pushstring(L, tail);
        return 2;
    }

    return 1;
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
luaH_param_index(lua_State *L, sqlite3_stmt *stmt, gint idx)
{
    int type = lua_type(L, idx);
    if (type == LUA_TNUMBER)
        return lua_tointeger(L, idx);
    else if (type == LUA_TSTRING)
        return sqlite3_bind_parameter_index(stmt, lua_tostring(L, idx));
    return 0;
}

static gint
luaH_bind_value(lua_State *L, sqlite3_stmt *stmt, gint bidx, gint idx)
{
    switch (lua_type(L, idx)) {
    case LUA_TNUMBER:
        return sqlite3_bind_double(stmt, bidx, lua_tonumber(L, idx));
    case LUA_TBOOLEAN:
        return sqlite3_bind_int(stmt, bidx, lua_toboolean(L, idx) ? 1 : 0);
    case LUA_TSTRING:
        return sqlite3_bind_text(stmt, bidx, lua_tostring(L, idx), -1,
                SQLITE_TRANSIENT);
    default:
        warn("sqlite3: unable to bind Lua value (type %s)",
                lua_typename(L, lua_type(L, idx)));
        break;
    }
    return SQLITE_OK; /* ignore invalid types */
}

static gint
luaH_sqlite3_do_exec(lua_State *L, sqlite3_stmt *stmt)
{
    gint ret = sqlite3_step(stmt), rows = 0, ncol;

    /* determine if this statement returns rows */
    if (ret == SQLITE_DONE || ret == SQLITE_ROW) {
        if ((ncol = sqlite3_column_count(stmt)))
            /* user will expect table even if SQLITE_DONE */
            lua_newtable(L);
        else
            /* statement doesn't return rows */
            lua_pushnil(L);
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
        lua_rawseti(L, -2, ++rows);
        break;

    /* there was an error */
    default:
        return -1;
    }

    /* process next row (or check if done) */
    ret = sqlite3_step(stmt);
    goto check_next_step;

exec_done:
    return 1;
}

static gint
luaH_sqlite3_exec(lua_State *L)
{
    sqlite3_t *sqlite = luaH_checksqlite3(L, 1);
    luaH_sqlite3_checkopen(L, sqlite);

    /* get SQL query */
    const gchar *sql = luaL_checkstring(L, 2), *tail;

    /* check type before we prepare statement */
    if (!lua_isnoneornil(L, 3))
        luaH_checktable(L, 3);

    gint top = lua_gettop(L), ret = 0;

    /* compile SQL statement */
    sqlite3_stmt *stmt;

next_statement:

    if (sqlite3_prepare_v2(sqlite->db, sql, -1, &stmt, &tail)) {
        lua_pushfstring(L, "sqlite3: statement compilation failed (%s)",
                sqlite3_errmsg(sqlite->db));
        sqlite3_finalize(stmt);
        lua_error(L);
    } else if (!stmt)
        return 0;

    /* is there values to bind to this statement? */
    if (!lua_isnoneornil(L, 3)) {
        /* iterate through table and bind values to the compiled statement */
        lua_pushnil(L);
        gint idx;

        while (lua_next(L, 3)) {
            /* check valid parameter index */
            if ((idx = luaH_param_index(L, stmt, -2)) == 0) {
                lua_pop(L, 1);
                continue;
            }

            /* bind value at index */
            ret = luaH_bind_value(L, stmt, idx, -1);

            /* check for sqlite3_bind_* error */
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

    ret = luaH_sqlite3_do_exec(L, stmt);
    sqlite3_finalize(stmt);

    /* check for error */
    if (ret == -1) {
        lua_pushfstring(L, "sqlite3: exec error (%s)",
                sqlite3_errmsg(sqlite->db));
        lua_error(L);
    }

    /* the sqlite3_prepare_*() functions only compile the first statement
     * in the input string. If there are more `tail` points to the first
     * character of the next statement (valid or not). */
    if (tail && *tail) {
        sql = tail;
        lua_settop(L, top);
        goto next_statement;
    }

    return 1;
}

static gint
luaH_sqlite3_stmt_exec(lua_State *L)
{
    sqlite3_stmt_t *stmt = luaH_checkstmtud(L, 1);
    sqlite3_t *sqlite = stmt->sqlite;
    luaH_sqlite3_checkopen(L, sqlite);

    /* reset prepared statement back to original state */
    sqlite3_reset(stmt->stmt);

    gint ret;

    /* is there values to bind to this statement? */
    if (!lua_isnoneornil(L, 2)) {
        luaH_checktable(L, 2);

        /* clear bound values */
        sqlite3_clear_bindings(stmt->stmt);

        /* iterate through table and bind values to the compiled statement */
        lua_pushnil(L);
        gint idx;

        while (lua_next(L, 2)) {
            /* check valid parameter index */
            if ((idx = luaH_param_index(L, stmt->stmt, -2)) == 0) {
                lua_pop(L, 1);
                continue;
            }

            /* bind value at index */
            ret = luaH_bind_value(L, stmt->stmt, idx, -1);

            /* check for sqlite3_bind_* error */
            if (!(ret == SQLITE_OK || ret == SQLITE_RANGE)) {
                lua_pushfstring(L, "sqlite3: sqlite3_bind_* failed (%s)",
                        sqlite3_errmsg(sqlite->db));
                sqlite3_finalize(stmt->stmt);
                lua_error(L);
            }

            /* pop value */
            lua_pop(L, 1);
        }
    }

    ret = luaH_sqlite3_do_exec(L, stmt->stmt);

    /* check for error */
    if (ret == -1) {
        lua_pushfstring(L, "sqlite3: exec error (%s)",
                sqlite3_errmsg(sqlite->db));
        lua_error(L);
    }

    return 1;
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
        { "compile", luaH_sqlite3_compile },
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

    static const struct luaL_reg sqlite3_stmt_meta[] =
    {
        { "exec", luaH_sqlite3_stmt_exec },
        { "__gc", luaH_sqlite3_stmt_gc },
        { NULL, NULL },
    };

    luaH_class_setup(L, &sqlite3_stmt_class, "sqlite3::statement",
            NULL, NULL, NULL, NULL, sqlite3_stmt_meta);
}

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
