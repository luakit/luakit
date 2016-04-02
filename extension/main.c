#include <webkit2/webkit-web-extension.h>

G_MODULE_EXPORT void
webkit_web_extension_initialize(WebKitWebExtension *extension)
{
	puts("luakit.so loaded");
}
