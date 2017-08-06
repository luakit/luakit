@name Frequently Asked Questions
# Frequently Asked Questions

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

## Behaviour

### How do I stop some links opening in new windows?

Add your own @ref{new-window-decision} webview signal handler which always opens
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
