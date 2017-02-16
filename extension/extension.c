#include <stdlib.h>
#include <unistd.h>
#include <glib.h>

#include "common/util.h"
#include "common/luautil.h"
#include "common/luauniq.h"
#include "extension/msg.h"
#include "common/luaobject.h"
#include "extension/extension.h"

#include "extension/clib/luakit.h"
#include "extension/clib/ui_process.h"
#include "extension/clib/dom_document.h"
#include "extension/clib/dom_element.h"
#include "extension/clib/page.h"
#include "extension/clib/extension.h"
#include "common/clib/msg.h"
#include "common/clib/soup.h"

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
    luaH_object_setup(WL);
    luaH_uniq_setup(WL, NULL);
    luaH_add_paths(WL, NULL);
    luakit_lib_setup(WL);
    soup_lib_setup(WL);
    ui_process_class_setup(WL);
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
    const gchar **v = g_variant_get_strv(payload, NULL);
    const gchar *socket_path = v[0];
    globalconf.execpath = (gchar *)v[1];
    g_free(v);

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
