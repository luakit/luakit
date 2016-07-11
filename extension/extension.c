#include <stdlib.h>
#include <glib.h>

#include "common/util.h"
#include "common/luautil.h"
#include "common/luauniq.h"
#include "extension/msg.h"
#include "common/luaobject.h"
#include "extension/extension.h"

#include "extension/clib/ui_process.h"
#include "extension/clib/dom_document.h"
#include "extension/clib/dom_element.h"
#include "extension/clib/page.h"
#include "extension/clib/extension.h"
#include "common/clib/msg.h"

#include "extension/scroll.h"
#include "extension/luajs.h"
#include "extension/script_world.h"

void
web_lua_init(void)
{
    printf("luakit web process: Lua initializing...\n");

    lua_State *WL = extension.WL = luaL_newstate();

    /* Set panic fuction */
    lua_atpanic(WL, luaH_panic);

    /* Set error handling function */
    lualib_dofunction_on_error = luaH_dofunction_on_error;

    luaL_openlibs(WL);
    luaH_object_setup(WL);
    luaH_uniq_setup(WL, NULL);
    luaH_add_paths(WL, NULL);
    ui_process_class_setup(WL);
    dom_document_class_setup(WL);
    dom_element_class_setup(WL);
    page_class_setup(WL);
    extension_class_setup(WL, extension.ext);
    msg_lib_setup(WL);

    printf("luakit web process: Lua initialized\n");
}

G_MODULE_EXPORT void
webkit_web_extension_initialize_with_user_data(WebKitWebExtension *ext, GVariant *payload)
{
    const gchar *socket_path = g_variant_get_string(payload, NULL);

    if (web_extension_connect(socket_path)) {
        printf("luakit web process: connecting to UI thread failed\n");
        exit(EXIT_FAILURE);
    }

    extension.ext = ext;

    web_lua_init();
    web_scroll_init();
    web_luajs_init();
    web_script_world_init();

    printf("luakit web process: ready for messages\n");
}

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
