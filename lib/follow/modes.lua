------------------------------------------------------------
-- Link hinting modes for the follow lib                  --
-- © 2010-2011 Fabian Streitel <karottenreibe@gmail.com>  --
-- © 2010-2011 Mason Larobina  <mason.larobina@gmail.com> --
------------------------------------------------------------

local ipairs, unpack = ipairs, unpack

module "follow.modes"

-- Click the element.
normal = {
    selector  = 'a, area, textarea, select, input:not([type=hidden]), button',
    evaluator = [=[function (element) {
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
    }]=]
}

-- Focus the element.
focus = {
    selector  = 'a, area, textarea, select, input:not([type=hidden]), button, body, applet, object',
    evaluator = [=[function (element) {
        element.focus();
        if (follow.isEditable(element)) {
            return "form-active";
        } else {
            return "root-active";
        }
    }]=]
}

-- Return the URI.
uri = {
    selector  = 'a, area, body',
    evaluator = [=[function (element) {
        return element.src || element.href || element.location;
    }]=]
}

-- Return the title or alt tag text.
desc = {
    selector  = '*[title], img[alt], applet[alt], area[alt], input[alt]',
    evaluator = [=[function (element) {
        return element.title || element.alt || "";
    }]=]
}

-- Return the image location.
image = {
    selector  = 'img, input[type=image]',
    evaluator = [=[function (element) {
        return element.src;
    }]=]
}
