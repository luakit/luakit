------------------------------------------------------------
-- Follow modes for the link following lib                --
-- © 2010-2011 Fabian Streitel <karottenreibe@gmail.com>  --
-- © 2010-2011 Mason Larobina  <mason.larobina@gmail.com> --
------------------------------------------------------------

local ipairs = ipairs
local unpack = unpack

module "follow.modes"

--- Selectors for the different modes.
-- body selects frames (this is special magic to avoid cross-domain problems)
selectors = {
    followable  = 'a, area, textarea, select, input:not([type=hidden]), button',
    focusable   = 'a, area, textarea, select, input:not([type=hidden]), button, body, applet, object',
    uri         = 'a, area, body',
    desc        = '*[title], img[alt], applet[alt], area[alt], input[alt]',
    image       = 'img, input[type=image]',
}

--- Evaluators for the different modes
evaluators = {
    -- Click the element & return form/root active signals
    follow = [=[
        function (element) {
            var tag = element.tagName.toLowerCase();
            if (tag === "input" || tag === "textarea") {
                var type = element.type.toLowerCase();
                if (type === "radio" || type === "checkbox") {
                    element.checked = !element.checked;
                } else if (type === "submit" || type === "reset" || type  === "button") {
                    follow.click(element);
                } else {
                    element.focus();
                }
            } else {
                follow.click(element);
            }
            if (follow.isEditable(element)) {
                return "form-active";
            } else {
                return "root-active";
            }
        }]=],
    -- Return the uri.
    uri = [=[
        function (element) {
            return element.src || element.href || element.location;
        }]=],
    -- Return image location.
    src = [=[
        function (element) {
            return element.src;
        }]=],
    -- Return title or alt tag text.
    desc = [=[
        function (element) {
            return element.title || element.alt || "";
        }]=],
    -- Focus the element.
    focus = [=[
        function (element) {
            element.focus();
            if (follow.isEditable(element)) {
                return "form-active";
            } else {
                return "root-active";
            }
        }]=],
}

-- Build default modes
for _, t in ipairs({
  -- Follow mode,  Selector name,  Evaluator name
    {"follow",     "followable",   "follow"      },
    {"uri",        "uri",          "uri"         },
    {"desc",       "desc",         "desc"        },
    {"focus",      "focusable",    "focus"       },
    {"image",      "image",        "src"         },
}) do
    local mode, selector, evaluator = unpack(t)
    _M[mode] = {
        selector = selectors[selector],
        evaluator = evaluators[evaluator]
    }
end
