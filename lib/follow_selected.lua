------------------------------------------------------------------
-- luakit follow selected link (or link in selection)           --
-- (C) 2009 israellevin                                         --
-- (C) 2010 Paweł Zuzelski (pawelz)  <pawelz@pld-linux.org>     --
-- (C) 2010 Mason Larobina (mason-l) <mason.larobina@gmail.com> --
------------------------------------------------------------------

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
for _, b in ipairs({
    lousy.bind.key({},          "Return", function (w)
                                              uri = w:eval_js(return_selected)
                                              if uri == "" then return end
                                              w:navigate(uri)
                                          end),
    lousy.bind.key({"Control"}, "Return", function (w)
                                              uri = w:eval_js(return_selected)
                                              if uri == "" then return end
                                              w:new_tab(uri, false)
                                          end),
    lousy.bind.key({"Shift"},   "Return", function (w)
                                              uri = w:eval_js(return_selected)
                                              if uri == "" then return end
                                              window.new({uri})
                                          end),
    lousy.bind.key({"Mod1"},    "Return", function (w)
                                              uri = w:eval_js(return_selected)
                                              if uri == "" then return end
                                              w:download(uri)
                                          end),
}) do table.insert(binds.mode_binds.normal, b) end
-- vim: et:sw=4:ts=8:sts=4:tw=80
