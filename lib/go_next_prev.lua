----------------------------------------------------------------
-- Follow "next" or "prev" links on a page                    --
-- © 2009 Aldrik Dunbar  (n30n)                               --
-- © 2010 Mason Larobina (mason-l) <mason.larobina@gmail.com> --
-- © 2011 Roman Leonov <rliaonau@gmail.com>                   --
----------------------------------------------------------------

local defaults = {
    next = [[(\bnext\b|^>$|^(>>|»)$|^(>|»)|(>|»)$|\bmore\b)]],
    prev = [[(\b(prev|previous)\b|^<$|^(<<|«)$|^(<|«)|(<|«)$)]],
}

local cut_www = function(d) return string.gsub(string.lower(d), '^www%.', '') end

local go_table = setmetatable({}, {
    __index = function(tab, key)
        return rawget(tab, cut_www(key))
        or setmetatable({}, {
            __newindex = function(...) tab[key] = rawset(...) end,
            __index = function(_, k) return rawget(tab, k) or defaults[k] end,
        })
    end,
    __newindex = function(tab, key, val) rawset(tab, cut_www(key), val) end,
})

for k, v in pairs(globals.go_next_prev or {}) do go_table[k] = v end

local go_next_or_prev_js = [=[
(function() {
    var el = document.querySelector("[rel='{where}']");
    if (el) { // Wow a developer that knows what he's doing!
        location = el.href;
    }
    else { // Search from the bottom of the page up for a next/previous link.
        var els = document.getElementsByTagName("a");
        var i = els.length;
        while ((el = els[--i])) {
            if (el.text.search(/{pattern}/i) > -1) {
                location = el.href;
                break;
            }
        }
    }
})();
]=]

local do_js = function (w, direction)
    w:eval_js(string.gsub( go_next_or_prev_js, "{(%w+)}", {
        pattern = go_table[lousy.uri.parse(w.view.uri).host][direction],
        where = direction,
    }))
end

-- Add `[[` & `]]` bindings to the normal mode.
add_binds("normal", {
    lousy.bind.buf("^%]%]$", function(w) do_js(w, 'next') end),
    lousy.bind.buf("^%[%[$", function(w) do_js(w, 'prev') end),
})

-- vim: et:sw=4:ts=8:sts=4:tw=80
