------------------------------------------------------------------------------
-- Add {A,C,S,}-Return binds to follow selected link (or link in selection) --
-- © 2010 Chris van Dijk (quigybo) <quigybo@hotmail.com>                    --
-- © 2010 Mason Larobina (mason-l) <mason.larobina@gmail.com>               --
-- © 2010 Paweł Zuzelski (pawelz)  <pawelz@pld-linux.org>                   --
-- © 2009 israellevin                                                       --
------------------------------------------------------------------------------

-- Return selected uri or first uri in selection
local return_selected = [=[
(function(document) {
    var selection = window.getSelection(),
        container = document.createElement('div'),
        range, elements, i = 0;

    if (selection.toString() !== "") {
        range = selection.getRangeAt(0);
        // Check for links contained within the selection
        container.appendChild(range.cloneContents());

        var elements = container.getElementsByTagName('a'),
            len = elements.length, i = 0, href;

        for (; i < len;)
            if ((href = elements[i++].href))
                return href;

        // Check for links which contain the selection
        container = range.startContainer;
        while (container !== document) {
            if ((href = container.href))
                return href;
            container = container.parentNode;
        }
    }
    // Check for active links
    var element = document.activeElement;
    return element.src || element.href;
})(document);
]=]

-- Add binding to normal mode to follow selected link
local key = lousy.bind.key
add_binds("normal", {
    -- Follow selected link
    key({}, "Return", function (w)
        local uri = w.view:eval_js(return_selected)
        if not uri then return false end
        assert(type(uri) == "string")
        w:navigate(uri)
    end),

    -- Follow selected link in new tab
    key({"Control"}, "Return", function (w)
        local uri = w.view:eval_js(return_selected)
        if not uri then return false end
        assert(type(uri) == "string")
        w:new_tab(uri, false)
    end),

    -- Follow selected link in new window
    key({"Shift"}, "Return", function (w)
        local uri = w.view:eval_js(return_selected)
        if not uri then return false end
        assert(type(uri) == "string")
        window.new({uri})
    end),

    -- Download selected uri
    key({"Mod1"}, "Return", function (w)
        local uri = w.view:eval_js(return_selected)
        if not uri then return false end
        assert(type(uri) == "string")
        w:download(uri)
    end),
})
-- vim: et:sw=4:ts=8:sts=4:tw=80
