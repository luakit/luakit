/*
 * extension/log.c - logging interface for web extension
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
#include "extension/extension.h"
#include "common/log.h"
#include "common/msg.h"

#include <glib/gprintf.h>
#include <stdlib.h>
#include <unistd.h>

GArray *msg_queue;

typedef struct _queued_log_t {
    log_level_t lvl;
    gint line;
    gchar *fct, *msg;
} queued_log_t;

void
_log(log_level_t lvl, gint line, const gchar *fct, const gchar *fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    va_log(lvl, line, fct, fmt, ap);
    va_end(ap);
}

static void
va_log_string(log_level_t lvl, gint line, const gchar *fct, gchar *msg) {
    lua_State *L = extension.WL;

    lua_pushinteger(L, lvl);
    lua_pushinteger(L, line);
    lua_pushstring(L, fct);
    lua_pushstring(L, msg);
    msg_send_lua(MSG_TYPE_log, L, -4, -1);
    lua_pop(L, 4);

    g_free(msg);
}

void
va_log(log_level_t lvl, gint line, const gchar *fct, const gchar *fmt, va_list ap) {
    lua_State *L = extension.WL;
    gchar *msg = g_strdup_vprintf(fmt, ap);

    if (!extension.ui_channel || !L) {
        if (!msg_queue)
            msg_queue = g_array_sized_new(FALSE, FALSE, sizeof(queued_log_t), 1);
        queued_log_t item = {
            .lvl = lvl,
            .line = line,
            .fct = g_strdup(fct),
            .msg = msg
        };
        g_array_append_val(msg_queue, item);
        return;
    } else if (msg_queue) {
        for (unsigned i = 0; i < msg_queue->len; ++i) {
            queued_log_t item = g_array_index(msg_queue, queued_log_t, i);
            va_log_string(item.lvl, item.line, item.fct, item.msg);
            g_free(item.fct);
        }
        g_array_free(msg_queue, TRUE);
        msg_queue = NULL;
    }

    va_log_string(lvl, line, fct, msg);
}

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
