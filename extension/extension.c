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

#include <stdlib.h>
#include <unistd.h>
#include <glib.h>

#include "common/util.h"
#include "common/luah.h"
#include "common/luautil.h"
#include "common/luauniq.h"
#include "extension/msg.h"
#include "common/luaobject.h"
#include "extension/extension.h"

#include "extension/clib/luakit.h"
#include "extension/clib/dom_document.h"
#include "extension/clib/dom_element.h"
#include "extension/clib/page.h"
#include "extension/clib/extension.h"
#include "common/clib/msg.h"
#include "common/clib/soup.h"
#include "common/clib/ipc.h"

#include "extension/scroll.h"
#include "extension/luajs.h"
#include "extension/script_world.h"

void
web_lua_init(void)
{
    debug("luakit web process: Lua initializing...");

    lua_State *WL = extension.WL;

    /* Set panic fuction */
    lua_atpanic(WL, luaH_panic);

    /* Set error handling function */
    lualib_dofunction_on_error = luaH_dofunction_on_error;

    luaL_openlibs(WL);
    luaH_fixups(WL);
    luaH_object_setup(WL);
    luaH_uniq_setup(WL, NULL);
    luaH_add_paths(WL, NULL);
    luakit_lib_setup(WL);
    soup_lib_setup(WL);
    ipc_channel_class_setup(WL);
    dom_document_class_setup(WL);
    dom_element_class_setup(WL);
    page_class_setup(WL);
    extension_class_setup(WL, extension.ext);
    msg_lib_setup(WL);

    debug("luakit web process: Lua initialized");
}

G_MODULE_EXPORT void
webkit_web_extension_initialize_with_user_data(WebKitWebExtension *ext, GVariant *payload)
{
    const gchar *socket_path = g_variant_get_string(payload, NULL);

    extension.WL = luaL_newstate();
    extension.ext = ext;
    extension.ipc = msg_endpoint_new("Web");

    if (web_extension_connect(socket_path)) {
        debug("luakit web process: connecting to UI thread failed");
        exit(EXIT_FAILURE);
    }

    web_lua_init();
    web_scroll_init();
    web_luajs_init();
    web_script_world_init();

    debug("luakit web process: PID %d", getpid());
    debug("luakit web process: ready for messages");

    msg_header_t header = { .type = MSG_TYPE_extension_init, .length = 0 };
    msg_send(extension.ipc, &header, NULL);
}

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
