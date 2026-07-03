/*
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

#include "extension/extension.h"

static void
script_world_window_object_cleared_cb(WebKitScriptWorld *UNUSED(world), WebKitWebPage *web_page, WebKitFrame *frame, gpointer UNUSED(user_data))
{
    if (webkit_frame_is_main_frame(frame)) {
        g_object_set_data(G_OBJECT(web_page), "luakit-main-frame", frame);
    }
}

void
web_script_world_init(void)
{
    extension.script_world = webkit_script_world_new_with_name("luakit-world");
    WebKitScriptWorld *world = webkit_script_world_get_default();
    g_signal_connect(world, "window-object-cleared",
            G_CALLBACK(script_world_window_object_cleared_cb), NULL);
}

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
