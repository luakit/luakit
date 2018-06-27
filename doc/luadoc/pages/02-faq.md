@name Frequently Asked Questions
# Frequently Asked Questions

## General

### How do I set luakit as my default browser?

On systems that use `xdg-settings`, you can run the following command to set
luakit as your default browser:

    xdg-settings set default-web-browser luakit.desktop

## Downloads

### How do I change the default download location?

In your `rc.lua` after `require "downloads"` add (or modify) the following:

    downloads.default_dir = os.getenv("HOME") .. "/downloads"

### How do I make all downloads save to my default download location without asking?

In your `rc.lua` after `require "downloads"` add (or modify) the following:

    downloads.add_signal("download-location", function (uri, file)
        if not file or file == "" then
            file = (string.match(uri, "/([^/]+)$")
                or string.match(uri, "^%w+://(.+)")
                or string.gsub(uri, "/", "_")
                or "untitled")
        end
        return downloads.default_dir .. "/" .. file
    end)

## Keybindings

### What's the syntax for defining a keybinding?

The syntax for specifying a keybinding is fairly straightforward:

  * Regular keys are represented by themselves.
  * Modifiers are represented as `<ModifierName-key>`, e.g., `<Control-c>`.
  * Modifier names are case-insensitive, e.g., `<CONTROL-c>` and `<Control-c>`
    are the same.

The available modifiers are:

  * `Control`. It is also possible to spell it as `Ctrl`, or `C`, so `<C-c>` is
    a valid binding.
  * `Mod1`, the `Alt` or `Meta` key.
  * `Mod4`, the Windows key.

It is also possible to use the keys for system commands (`Insert`, `Home`,
`Pause`, etc.) in keybindings. Just indicate the key name between angle
brackets. For example, the syntax for the `Insert` key is `<Insert>`.

If you don't know the name for a given key, you can use the
[xev](https://linux.die.net/man/1/xev) utility to find it out and use the
syntax described above to define the keybinding.

The mouse buttons can be used in bindings, too. If you want to define a binding
for a particular mouse button, indicate it as a "named key", just like with
system keys; the buttons are named using the following convention: `Mouse{n}`,
with `n` being the button number. For example, to bind the buttons 8 and 9 to
the previous/next tab commands, use the following code:

    modes.remap_binds("normal", {
        {"<Mouse8>", "gt", true},
        {"<Mouse9>", "gT", true},
    })

Modifier keys can also be used in bindings using mouse buttons, so things like,
e.g., `<C-mod1-Mouse1>` will work.

Once again, if you don't know the number of a particular mouse button, the xev
utility will help you find it.

## Behaviour

### How do I stop some links opening in new windows?

Add your own @ref{"new-window-decision"} webview signal handler which always opens
links in new tabs.

In your `rc.lua` after `require "webview"` add (or modify) the following:

    webview.add_signal("init", function (view)
        view:add_signal("new-window-decision", function (v, uri, reason)
            local w = window.ancestor(v)
            w:new_tab(uri)
            return true
        end)
    end)

### How do I copy text with Control-C?

Add this snippet of code to your `rc.lua`.
Note that `Ctrl-C` is already bound to "Stop loading the current tab";
adding this snippet will automatically remove that binding.

    modes.add_binds("normal", {
        { "<Control-c>", "Copy selected text.", function ()
            luakit.selection.clipboard = luakit.selection.primary
        end},
    })

### How do I open certain schemes in other applications?

To open particular schemes in other applications, use the
`navigation-request` webview signal. The generic boilerplate for
attaching to this signal is shown here:

    webview.add_signal("init", function (view)
        view:add_signal("navigation-request", function (v, uri)
            --- Check URI and open program here
        end)
    end)

Replace the inner comment with code that checks the URI and, if it
matches the right scheme, opens your external program. If it matches, it
is important to return `false` from the signal handler: this prevents
luakit from navigating to the link while your program opens.

Here are some examples:

#### Opening `mailto:` links using GMail

    if string.match(string.lower(uri), "^mailto:") then
        local mailto = "https://mail.google.com/mail/?extsrc=mailto&url=%s"
        local w = window.ancestor(v)
        w:new_tab(string.format(mailto, uri))
        return false
    end

#### Opening `mailto:` links using Mutt in `urxvt`

    if string.match(string.lower(uri), "^mailto:") then
        luakit.spawn(string.format("%s %q", "urxvt -title mutt -e mutt", uri))
        return false
    end

#### Opening `magnet:` links with Deluge

    if string.match(string.lower(uri), "^magnet:") then
        luakit.spawn(string.format("%s %q", "deluge-gtk", uri))
        return false
    end

#### Opening `magnet:` links with rTorrent

    if string.match(string.lower(uri), "^magnet:") then
        luakit.spawn(string.format("%s %q", "mktor", uri))
        return false
    end

## Styling

A number of page styling tweaks can be made by adding additional page initialization functions. These are placed in the `rc.lua` file. They must be after `require "webview"`, but before the block where the window or tab creation call is made. This happens near the end of the file, right after the comment `End user script loading`. This means that you *cannot* just add these functions to the end of the file, if you do so they will not be executed.

### I'm using a dark theme; how do I stop the white flash during the loading of a page?

This is not currently possible, as with WebKit 2 there is no way to give a webview widget a transparent background.

### How do I change the default zoom level?

The best way to change the default zoom level is to add a rule to `domain_props`:

    globals.domain_props.all = {
        ...
        zoom_level = 1.5, -- a 50% zoom
        ...
    }

### How do I set a custom `about:blank` page?

The easiest way to do this is to customize the @ref{newtab_chrome} module's options.

You can also do this by watching the `"navigation-request"` webview signal
for navigation to specific addresses (in this case `"about:blank"`):

    webview.add_signal("init", function (view)
        view:add_signal("navigation-request", function (_, uri)
            if uri == "about:blank" then
                local html = "<html><body bgcolor='#000000'></body></html>"
                view:load_string(html, "about:blank")
                return true
            end
        end)
    end)

<!-- vim: et:sw=4:ts=8:sts=4:tw=79 -->
