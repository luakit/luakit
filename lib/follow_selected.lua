------------------------------------------------------------------
-- luakit follow selected link (or link in selection)           --
-- (C) 2009 israellevin                                         --
-- (C) 2010 Paweł Zuzelski (pawelz)  <pawelz@pld-linux.org>     --
-- (C) 2010 Mason Larobina (mason-l) <mason.larobina@gmail.com> --
------------------------------------------------------------------

local follow_selected = [=[
(function() {
    var selection = window.getSelection().getRangeAt(0);
    var container = document.createElement('div');
    var elements;
    var idx;
    if ('' + selection) {
        // Check for links contained within the selection
        container.appendChild(selection.cloneContents());
        elements = container.getElementsByTagName('a');
        for (idx in elements) {
            if (elements[idx].href) {
                document.location.href = elements[idx].href;
            }
        }
        // Check for links which contain the selection
        container = selection.startContainer;
        while (container != document) {
            if (container.href) {
                document.location.href = container.href;
            }
            container = container.parentNode;
        }
    }
})();
]=]

local follow_bind = lousy.bind.key({}, "Return", function (w)
    w:eval_js(follow_selected)
    return false
end)

-- Add binding to search & normal modes
table.insert(binds.mode_binds.search, follow_bind)
table.insert(binds.mode_binds.normal, follow_bind)
