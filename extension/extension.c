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
#include "extension/ipc.h"
#include "common/luaobject.h"
#include "extension/extension.h"

#include "extension/clib/luakit.h"
#include "extension/clib/dom_document.h"
#include "extension/clib/dom_element.h"
#include "extension/clib/page.h"
#include "extension/clib/soup.h"
#include "extension/clib/msg.h"
#include "common/clib/ipc.h"
#include "common/clib/timer.h"
#include "common/clib/regex.h"
#include "common/clib/utf8.h"

#include "extension/scroll.h"
#include "extension/luajs.h"
#include "extension/script_world.h"

static void
web_lua_init(const char *package_path, const char *package_cpath)
{
    debug("Lua initializing...");

    lua_State *L = common.L;

    /* Set panic fuction */
    lua_atpanic(L, luaH_panic);

    luaL_openlibs(L);
    luaH_fixups(L);
    luaH_object_setup(L);
    luaH_uniq_setup(L, NULL, "v");

    lua_getglobal(L, "package");
    lua_pushstring(L, package_path);
    lua_setfield(L, -2, "path");
    lua_pushstring(L, package_cpath);
    lua_setfield(L, -2, "cpath");
    lua_pop(L, 1);

    luakit_lib_setup(L);
    soup_lib_setup(L);
    ipc_channel_class_setup(L);
    timer_class_setup(L);
    regex_class_setup(L);
    utf8_lib_setup(L);
    dom_document_class_setup(L);
    dom_element_class_setup(L);
    page_class_setup(L);
    msg_lib_setup(L);

    debug("Lua initialized");
}

G_MODULE_EXPORT void
webkit_web_extension_initialize_with_user_data(WebKitWebExtension *ext, GVariant *payload)
{
    gchar *socket_path, *package_path, *package_cpath;
    g_variant_get(payload, "(sss)", &socket_path, &package_path, &package_cpath);

    common.L = luaL_newstate();
    common.L = common.L;
    extension.ext = ext;
    extension.ipc = ipc_endpoint_new(g_strdup_printf("Web[%d]", getpid()));

    if (web_extension_connect(socket_path)) {
        debug("connecting to UI thread failed");
        exit(EXIT_FAILURE);
    }

    web_lua_init(package_path, package_cpath);
    web_scroll_init();
    web_luajs_init();
    web_script_world_init();

    debug("PID %d", getpid());
    debug("ready for messages");

    ipc_header_t header = { .type = IPC_TYPE_extension_init, .length = 0 };
    ipc_send(extension.ipc, &header, NULL);
}

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
