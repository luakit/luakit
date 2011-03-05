------------------------------------------------------------------------------
-- Add {A,C,S,}-Return binds to follow selected link (or link in selection) --
-- (C) 2010 Chris van Dijk (quigybo) <quigybo@hotmail.com>                  --
-- (C) 2010 Mason Larobina (mason-l) <mason.larobina@gmail.com>             --
-- (C) 2010 Paweł Zuzelski (pawelz)  <pawelz@pld-linux.org>                 --
-- (C) 2009 israellevin                                                     --
------------------------------------------------------------------------------

-- Return selected uri or first uri in selection
local return_selected = [=[
(function() {
    var selection = window.getSelection();
    var container = document.createElement('div');
    var range;
    var elements;
    var idx;
    if ('' + selection) {
        range = selection.getRangeAt(0);
        // Check for links contained within the selection
        container.appendChild(range.cloneContents());
        elements = container.getElementsByTagName('a');
        for (idx in elements) {
            if (elements[idx].href) {
                return elements[idx].href;
            }
        }
        // Check for links which contain the selection
        container = range.startContainer;
        while (container != document) {
            if (container.href) {
                return container.href;
            }
            container = container.parentNode;
        }
    }
    // Check for active links
    var element = document.activeElement;
    var uri = element.src || element.href;
    if (uri && !uri.match(/javascript:/)) {
        return uri;
    }
})();
]=]

-- Add binding to normal mode to follow selected link
local key = lousy.bind.key
add_binds("normal", {
    -- Follow selected link
    key({}, "Return", function (w)
        local uri = w:eval_js(return_selected)
        if uri == "" then return false end
        w:navigate(uri)
    end),

    -- Follow selected link in new tab
    key({"Control"}, "Return", function (w)
        local uri = w:eval_js(return_selected)
        if uri == "" then return false end
        w:new_tab(uri, false)
    end),

    -- Follow selected link in new window
    key({"Shift"}, "Return", function (w)
        local uri = w:eval_js(return_selected)
        if uri == "" then return false end
        window.new({uri})
    end),

    -- Download selected uri
    key({"Mod1"}, "Return", function (w)
        local uri = w:eval_js(return_selected)
        if uri == "" then return false end
        w:download(uri)
    end),
})
-- vim: et:sw=4:ts=8:sts=4:tw=80
