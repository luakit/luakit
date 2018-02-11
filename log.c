/*
 * log.c - logging functions
 *
 * Copyright © 2016 Aidan Holm <aidanholm@gmail.com>
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

#include "globalconf.h"
#include "common/log.h"
#include "common/luaserialize.h"
#include "common/luaclass.h"
#include "common/ipc.h"
#include "clib/msg.h"

#include <glib/gprintf.h>
#include <stdlib.h>
#include <unistd.h>

static GHashTable *group_levels;
static GAsyncQueue *queued_emissions;
static gboolean block_log = FALSE;

void
log_set_verbosity(const char *group, log_level_t lvl)
{
    group_levels = group_levels ?: g_hash_table_new_full(g_str_hash, g_str_equal, g_free, NULL);
    g_hash_table_insert(group_levels, g_strdup(group), GINT_TO_POINTER(lvl+1));
}

/* Will modify the group name passed to it, unless that name is "all" */
log_level_t
log_get_verbosity(char *group)
{
    if (!group_levels)
        return LOG_LEVEL_info;

    gint len = strlen(group);
    log_level_t lvl;

    while (TRUE) {
        lvl = GPOINTER_TO_UINT(g_hash_table_lookup(group_levels, (gpointer)group));
        if (lvl > 0)
            break;
        char *slash = strrchr(group, '/');
        if (slash)
            *slash = '\0';
        else {
            lvl = GPOINTER_TO_UINT(g_hash_table_lookup(group_levels, (gpointer)"all"));
            break;
        }
    }

    for (gint i = 0; i < len; ++i)
        if (group[i] == '\0') group[i] = '/';

    return lvl-1;
}

static char *
log_group_from_fct(const char *fct)
{
    /* Strip off installation prefixes */
    static GPtrArray *paths;
    if (!paths) {
        paths = g_ptr_array_new_with_free_func(g_free);
        g_ptr_array_add(paths, "./");
        g_ptr_array_add(paths, g_build_path("/", LUAKIT_INSTALL_PATH, "lib/", NULL));
        g_ptr_array_add(paths, g_build_path("/", LUAKIT_CONFIG_PATH, "/luakit/", NULL));
        g_ptr_array_add(paths, g_build_path("/", globalconf.config_dir, "/", NULL));
    }
    for (unsigned i = 0; i < paths->len; i++)
        if (g_str_has_prefix(fct, paths->pdata[i])) {
            fct += strlen(paths->pdata[i]);
            break;
        }

    int len = strlen(fct);
    gboolean core = !strcmp(&fct[len-2], ".c") || !strcmp(&fct[len-2], ".h"),
             lua = !strcmp(&fct[len-4], ".lua") || !strncmp(fct, "[string \"", 9);
    if (core == lua)
        warn("not sure how to handle this one: '%s'", fct);

    if (core) /* Strip .c or .lua off the end */
        return g_strdup_printf("core/%.*s", len-2, fct);
    else
        return g_strdup_printf("lua/%.*s", len-4, fct);
}

int
log_level_from_string(log_level_t *out, const char *str)
{
#define X(name) if (!strcmp(#name, str)) { \
    *out = LOG_LEVEL_##name; \
    return 0; \
}
LOG_LEVELS
#undef X
    return 1;
}

const char*
log_string_from_level(log_level_t lvl)
{
    switch (lvl) {
#define X(name) case LOG_LEVEL_##name: return #name;
LOG_LEVELS
#undef X
    }
    g_assert_not_reached();
}

static void
emit_log_signal(double time, log_level_t lvl, const gchar *group, const gchar *msg)
{
    lua_class_t *msg_class = msg_lib_get_msg_class();
    lua_pushnumber(common.L, time);
    lua_pushstring(common.L, log_string_from_level(lvl));
    lua_pushstring(common.L, group);
    lua_pushstring(common.L, msg);
    block_log = TRUE;
    luaH_class_emit_signal(common.L, msg_class, "log", 4, 0);
    block_log = FALSE;
}

typedef struct _queued_log_t {
    log_level_t lvl;
    double time;
    char *group;
    char *msg;
} queued_log_t;

static int consumer_added = FALSE;

static gboolean
log_emit_pending_signals(void *UNUSED(usedata))
{
    queued_log_t *entry;
    while ((entry = g_async_queue_try_pop(queued_emissions)))
    {
        emit_log_signal(entry->time, entry->lvl, entry->group, entry->msg);
        g_free(entry->group);
        g_free(entry->msg);
        g_slice_free(queued_log_t, entry);
    }
    g_atomic_int_set(&consumer_added, FALSE);
    return FALSE;
}

static void
queue_log_signal(double time, log_level_t lvl, const gchar *group, const gchar *msg)
{
    queued_log_t *entry = g_slice_new0(queued_log_t);
    entry->time = time;
    entry->lvl = lvl;
    entry->group = g_strdup(group);
    entry->msg = g_strdup(msg);
    g_async_queue_push(queued_emissions, entry);

    /* Add idle function to consume everything in the queue */
    if (g_atomic_int_compare_and_exchange(&consumer_added, FALSE, TRUE))
        g_idle_add(log_emit_pending_signals, NULL);
}

void
_log(log_level_t lvl, const gchar *fct, const gchar *fmt, ...)
{
    va_list ap;
    va_start(ap, fmt);
    va_log(lvl, fct, fmt, ap);
    va_end(ap);
}

void
va_log(log_level_t lvl, const gchar *fct, const gchar *fmt, va_list ap)
{
    if (block_log)
        return;

    char *group = log_group_from_fct(fct);
    log_level_t verbosity = log_get_verbosity(group);
    if (lvl > verbosity)
        goto done;

    gchar *msg = g_strdup_vprintf(fmt, ap);
    gint log_fd = STDERR_FILENO;
    double time = l_time() - globalconf.starttime;

    queue_log_signal(time, lvl, group, msg);

    /* Determine logging style */
    /* TODO: move to X-macro generated table? */

    gchar prefix_char, *style = "";
    switch (lvl) {
        case LOG_LEVEL_fatal:   prefix_char = 'F'; style = ANSI_COLOR_BG_RED; break;
        case LOG_LEVEL_error:   prefix_char = 'E'; style = ANSI_COLOR_RED; break;
        case LOG_LEVEL_warn:    prefix_char = 'W'; style = ANSI_COLOR_YELLOW; break;
        case LOG_LEVEL_info:    prefix_char = 'I'; break;
        case LOG_LEVEL_verbose: prefix_char = 'V'; break;
        case LOG_LEVEL_debug:   prefix_char = 'D'; break;
        default: g_assert_not_reached();
    }

    /* Log format: [timestamp] level [group]: msg */
#define LOG_FMT "[%#12f] %c [%s]: %s"
#define LOG_IND "                 "

    /* Indent new lines within the message */
    static GRegex *indent_lines_reg;
    if (!indent_lines_reg) {
        GError *err = NULL;
        indent_lines_reg = g_regex_new("\n", G_REGEX_OPTIMIZE, 0, &err);
        g_assert_no_error(err);
    }
    gchar *wrapped = g_regex_replace_literal(indent_lines_reg, msg, -1, 0, "\n" LOG_IND, 0, NULL);
    g_free(msg);
    msg = wrapped;

    if (!isatty(log_fd)) {
        gchar *stripped = strip_ansi_escapes(msg);
        g_free(msg);
        msg = stripped;

        g_fprintf(stderr, LOG_FMT "\n", time, prefix_char, group, msg);
    } else {
        g_fprintf(stderr, "%s" LOG_FMT ANSI_COLOR_RESET "\n",
                style, time, prefix_char, group, msg);
    }

    g_free(msg);

    if (lvl == LOG_LEVEL_fatal)
        exit(EXIT_FAILURE);
done:
    g_free(group);
}

void
ipc_recv_log(ipc_endpoint_t *UNUSED(ipc), const guint8 *lua_msg, guint length)
{
    lua_State *L = common.L;
    gint n = lua_deserialize_range(L, lua_msg, length);
    g_assert_cmpint(n, ==, 3);

    log_level_t lvl = lua_tointeger(L, -3);
    const gchar *fct = lua_tostring(L, -2);
    const gchar *msg = lua_tostring(L, -1);
    _log(lvl, fct, "%s", msg);
    lua_pop(L, 3);
}

void
log_init(void)
{
    queued_emissions = g_async_queue_new();

    const char *log_dump_file = getenv("LUAKIT_QUEUED_EMISSIONS_FILE");
    unsetenv("LUAKIT_QUEUED_EMISSIONS_FILE");

    if (!log_dump_file || !file_exists(log_dump_file))
        return;

    char *dump;
    size_t len;
    GError *error = NULL;

    if (!g_file_get_contents(log_dump_file, &dump, &len, &error)) {
        error("unable to load previous log messages: %s", error->message);
        g_error_free(error);
        return;
    }
    unlink(log_dump_file);
    char *end = dump + len;

    g_async_queue_lock(queued_emissions);
    while (dump < end) {
        queued_log_t *entry = g_slice_new0(queued_log_t);
        entry->lvl = *dump++;
        entry->time = g_ascii_strtod(dump, &dump);
        entry->group = g_strdup(dump);
        dump += strlen(dump)+1;
        entry->msg = g_strdup(dump);
        dump += strlen(dump)+1;
        g_async_queue_push_unlocked(queued_emissions, entry);
    }
    g_async_queue_unlock(queued_emissions);
}

char *
log_dump_queued_emissions(void)
{
    GString *dump = g_string_new(NULL);
    g_async_queue_lock(queued_emissions);
    queued_log_t *entry;
    while ((entry = g_async_queue_try_pop_unlocked(queued_emissions))) {
        g_string_append_c(dump, (char) entry->lvl);
        g_string_append_printf(dump, "%f", entry->time);
        g_string_append(dump, entry->group);
        g_string_append_c(dump, '\0');
        g_string_append(dump, entry->msg);
        g_string_append_c(dump, '\0');
        g_free(entry->group);
        g_free(entry->msg);
        g_slice_free(queued_log_t, entry);
    }
    g_async_queue_unlock(queued_emissions);

    char *name_used = NULL;
    int log_dump_fd = g_file_open_tmp("luakit-log-dump.XXXXXX", &name_used, NULL);
    if (log_dump_fd != -1) {
        ssize_t written = write(log_dump_fd, dump->str, dump->len);
        close(log_dump_fd);
        if (written != (ssize_t)dump->len) {
            unlink(name_used);
            g_free(name_used);
            name_used = NULL;
        }
    }
    g_string_free(dump, TRUE);

    return name_used;
}

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
