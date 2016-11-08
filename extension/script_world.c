#include <webkit2/webkit-web-extension.h>
#include "extension/extension.h"

void
web_script_world_init(void)
{
    extension.script_world = webkit_script_world_new();
}

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
