------------------------------------------------------------------
-- Luakit go_input                                              --
-- (C) 2009 israellevin                                         --
-- (C) 2010 Paweł Zuzelski (pawelz)      <pawelz@pld-linux.org> --
------------------------------------------------------------------

local follow_selected = [=[
(function() {
        var selection = window.getSelection().getRangeAt(0);
        var container = document.createElement('div');
        var elements;
        var idx;
        if('' + selection){
            // Check for links contained within the selection
            container.appendChild(selection.cloneContents());
            elements = container.getElementsByTagName('a');
            for(idx in elements){
                if(elements[idx].href){
                    document.location.href = elements[idx].href;
                    return;
                }
            }
            // Check for links which contain the selection
            container = selection.startContainer;
            while(container != document){
                if(container.href){
                    document.location.href = container.href;
                    return;
                }
                container = container.parentNode;
            }
        }
})();
]=]

-- Add key bindings
table.insert(binds.mode_binds.search,
    lousy.bind.key({}, "Return", function (w) w:eval_js(follow_selected) end))
table.insert(binds.mode_binds.normal,
    lousy.bind.key({}, "Return", function (w) w:eval_js(follow_selected) end))
