/*
 * web_context.h - WebKit web context setup and handling
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

#ifndef LUAKIT_WEB_CONTEXT_H
#define LUAKIT_WEB_CONTEXT_H

#include <webkit2/webkit2.h>

void web_context_init(void);
void web_context_init_finish(void);
WebKitWebContext *web_context_get(void);
WebKitWebContext *web_context_get_private(void);
guint web_context_process_limit_get(void);
gboolean web_context_process_limit_set(guint limit);

#endif

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
