#include <webkit2/webkit-web-extension.h>
#include <stdlib.h>
#include <glib.h>
#include <lauxlib.h>
#include <lualib.h>

#include "common/util.h"
#include "common/luautil.h"
#include "extension/msg.h"
#include "common/luaobject.h"
#include "extension/clib/ui_process.h"
#include "extension/clib/dom_document.h"
#include "extension/clib/dom_element.h"

lua_State *WL;
WebKitWebExtension *extension;

void
web_lua_init(void)
{
    printf("luakit web process: Lua initializing...\n");

    WL = luaL_newstate();

    /* Set panic fuction */
    lua_atpanic(WL, luaH_panic);

    /* Set error handling function */
    lualib_dofunction_on_error = luaH_dofunction_on_error;

    luaL_openlibs(WL);
    luaH_object_setup(WL);
    luaH_add_paths(WL, NULL);
    ui_process_class_setup(WL);
    dom_document_class_setup(WL);
    dom_element_class_setup(WL);

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

    extension = ext;

    web_lua_init();

    printf("luakit web process: ready for messages\n");
}

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
