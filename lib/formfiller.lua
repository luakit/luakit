------------------------------------------------------------------
-- Luakit formfiller                                            --
-- (C) 2010 Pawel Tomak    (grodzik) <pawel.tomak@gmail.com>    --
-- (C) 2010 Mason Larobina (mason-l) <mason.larobina@gmail.com> --
------------------------------------------------------------------

-- Load formfiller settings
local ff = globals.formfiller or {}
local term       = ff.term     or globals.term   or "xterm"
local editor     = ff.editor   or globals.editor or (os.getenv("EDITOR") or "vim")
local modeline   = ff.modeline or "> vim:ft=formfiller"
local formsdir   = ff.formsdir or luakit.data_dir .. "/forms/"
local editor_cmd = string.format("%s -e %s", term, editor)

-- Add formfiller mode
new_mode("formfiller", {
    leave = function (w)
        w.menu:hide()
    end,
})

-- Setup formfiller binds
local buf = lousy.bind.buf
add_binds("normal", {
    buf("^za", function (w) w:formfiller("add")  end),
    buf("^zn", function (w) w:formfiller("new")  end),
    buf("^ze", function (w) w:formfiller("edit") end),
    buf("^zl", function (w) w:formfiller("load") end),
})

-- Javascript functions
local dump_function = [=[
    (function dump() {
        var rv='';
        var allFrames = new Array(window);
        for(f=0;f<window.frames.length;f=f+1) {
            allFrames.push(window.frames[f]);
        }
        try {
            for(j=0;j<allFrames.length;j=j+1) {
                var xp;
                try {
                    xp = allFrames[j].document.evaluate("//form", allFrames[j].document, null, XPathResult.ANY_TYPE,null);
                }
                catch(err) { }
                var form;
                while(form=xp.iterateNext()) {
                    var formstr = '!form[' + form.name + '|' + form.id + '|' + form.method + '|' + form.action + ']:autosubmit=0\n';
                    var xp_res=allFrames[j].document.evaluate('.//input', form, null, XPathResult.ANY_TYPE,null);
                    var input;
                    while(input=xp_res.iterateNext()) {
                        if(input.name != "") {
                            var type=(input.type?input.type:text);
                            if(type == 'text' || type == 'password' || type == 'search') {
                                formstr += input.name + '(' + type + '):' + input.value + '\n';
                            }
                            else if(type == 'checkbox' || type == 'radio') {
                                formstr += input.name + '{' + input.value + '}(' + type + '):' + (input.checked?'ON':'OFF') + '\n';
                            }
                        }
                    }
                    xp_res=allFrames[j].document.evaluate('.//textarea', form, null, XPathResult.ANY_TYPE,null);
                    var input;
                    while(input=xp_res.iterateNext()) {
                        if(input.name != "") {
                            formstr += input.name + '(textarea):' + input.value + '\n';
                        }
                    }
                    if(formstr.length) {
                        rv += formstr;
                    }
                }
            }
        }
        catch(err) { }

        return rv;
    })()]=]

local insert_function = [=[
    function insert(fname, ftype, fvalue, fchecked, foName, foId, foMethod, foAction) {
        var allFrames = new Array(window);
        for(f=0;f<window.frames.length;f=f+1) {
            allFrames.push(window.frames[f]);
        }
        var form_string = "@method='"+foMethod+"'";
        try {
            for(j=0;j<allFrames.length;j=j+1) {
                var xp;
                try {
                    xp = allFrames[j].document.evaluate("//form["+form_string+"]", allFrames[j].document, null, XPathResult.ANY_TYPE,null);
                }
                catch(err) { }
                var form;
                while(form=xp.iterateNext()) {
                    var re = new RegExp(foAction);
                    if(form.action.search(re) != -1 && form.id == foId && foName == form.name) {
                        var xp_inp;
                        try {
                            xp_inp = allFrames[j].document.evaluate(".//input[@name='"+fname+"']|.//textarea[@name='"+fname+"']", form, null, XPathResult.ANY_TYPE, null);
                        }
                        catch(err) { }
                        var input;
                        while(input=xp_inp.iterateNext()) {
                            if(input.type == "text" || input.type == "password" || input.type == "search" || input.type == "textarea") {
                                input.value = fvalue;
                            }
                            else if(input.type == "checkbox") {
                                input.checked = fchecked;
                            }
                            else if(input.type == "radiobox") {
                                if(input.value == fvalue) {
                                    input.checked = fchecked;
                                }
                            }
                        }
                    }
                }
            }
        }
        catch(err) { }
    };]=]

local submit_function = [=[
    function submitForm(foName, foId, foMethod, foAction) {
        var allFrames = new Array(window);
        for(f=0;f<window.frames.length;f=f+1) {
            allFrames.push(window.frames[f]);
        }
        var form_string = "@method='"+foMethod+"'";
        try {
            for(j=0;j<allFrames.length;j=j+1) {
                var xp;
                try {
                    xp = allFrames[j].document.evaluate("//form["+form_string+"]", allFrames[j].document, null, XPathResult.ANY_TYPE,null);
                }
                catch(err) { }
                var form;
                while(form=xp.iterateNext()) {
                    var re = new RegExp(foAction);
                    if(form.action.search(re) != -1 && form.id == foId && foName == form.name) {
                        try {
                            var xp_res=allFrames[j].document.evaluate(".//input[@type='submit']", form, null, XPathResult.ANY_TYPE,null);
                        } catch (err) { }
                        var input;
                        try {
                            while(input=xp_res.iterateNext()) {
                                input.type='text';
                            }
                        } catch (err) { }
                        try {
                            form.submit();
                        } catch (err) { }
                        return;
                    }
                }
            }
        }
        catch(err) { }
    };]=]

-- Misc funs
function do_load(w, profile, filename)
    local view = w:get_current()
    local filename = formsdir .. string.match(string.gsub(view.uri, "%w+://", ""), "(.-)/.*")
    local fd, err = io.open(filename, "r")
    if not fd then return end
    fd:seek("set")
    for line in fd:lines() do
        if string.match(line, "^!profile=" .. profile .. "\ *$") then
            break
        end
    end
    local fname, fchecked, ftype, fvalue
    local form = {}
    local autosubmit = 0
    local js = string.format("%s\n%s", insert_function, submit_function)
    local pattern1 = "(.+)%((.+)%):% *(.*)"
    local pattern2 = "%1{0}(%2):%3"
    local pattern3 = "([^{]+){(.+)}%((.+)%):% *(.*)"
    for line in fd:lines() do
        if not string.match(line, "^!profile=.*") then
            if string.match(line, "^!form.*") and autosubmit == "1" then
                break
            end
            if string.match(line, "^!form.*") then
                form[1], form[2], form[3], form[4] = string.match(line, "^!form%[([^|]-)|([^|]-)|([^|]-)|([^|]-)%]")
                autosubmit = string.match(line, "^!form%[.-%]:autosubmit=(%d)")
            else
                if ftype == "textarea" then
                    if string.match(string.gsub(line, pattern1, pattern2), pattern3) then
                        js = string.format("%s\ninsert(%q, %q, %q, %q, %q, %q, %q, %q);", js, fname, ftype, fvalue, fchecked, form[1] or "", form[2] or "", form[3] or "", form[4] or "")
                        ftype = nil
                    else
                        fvalue = string.format("%s\\n%s", fvalue, line)
                    end
                end
                if ftype ~= "textarea" then
                    fname, fchecked, ftype, fvalue = string.match(string.gsub(line, pattern1, pattern2), pattern3)
                    if fname ~= nil and ftype ~= "textarea" then
                        js = string.format("%s\ninsert(%q, %q, %q, %q, %q, %q, %q, %q);", js, fname, ftype, fvalue, fchecked, form[1] or "", form[2] or "", form[3] or "", form[4] or "")
                    end
                end
            end
        else
            break
        end
    end
    if ftype == "textarea" then
        js = string.format("%s\ninsert(%q, %q, %q, %q, %q, %q, %q, %q);", js, fname, ftype, fvalue, fchecked, form[1] or "", form[2] or "", form[3] or "", form[4] or "")
    end
    if autosubmit == "1" then
        js = string.format("%s\nsubmitForm(%q, %q, %q, %q);", js, form[1] or "", form[2] or "", form[3] or "", form[4] or "")
    end
    view:eval_js(js, "(formfiller:load)")
    fd:close()
    w:set_mode()
end

-- Add `w:formfiller(action)` method when a webview is active.
-- TODO: This could easily be split up into several smaller functions.
webview.methods.formfiller = function(view, w, action)
    local filename = ""
    lousy.util.mkdir(formsdir)

    if action == "once" then
        filename = os.tmpname()
    else
        filename = formsdir .. string.match(string.gsub(view.uri, "%w+://", ""), "(.-)/.*")
    end

    if action == "new" or action == "once" or action == "add" then
        math.randomseed(os.time())
        if action == "add" and os.exists(filename) then
            modeline = ""
        end
        local fd
        if action == "add" then
            fd = io.open(filename, "a+")
        else
            fd = io.open(filename, "w+")
        end
        local ret = view:eval_js(dump_function, "(formfiller:dump)")
        fd:write(string.format("%s\n!profile=NAME_THIS_PROFILE_%d\n%s", modeline, math.random(1,9999), ret))
        fd:flush()
        fd:close()
        luakit.spawn(string.format("%s %q", editor_cmd, filename))

    elseif action == "load" then
        local fd, err = io.open(filename, "r")
        if not fd then return end
        local profile = {{"Profile", title = true},}
        w:set_mode("formfiller")
        fd:seek("set")
        for l in fd:lines() do
            if string.match(l, "^!profile=.*$") then
                table.insert(profile, {string.match(l, "^!profile=(.*)$")})
            end
        end
        fd:close()
        if #profile > 2 then
            w.menu:build(profile)
        else
            do_load(w, profile[2][1])
        end
    elseif action == "edit" then
        luakit.spawn(string.format("%s %q", editor_cmd, filename))
    end
end

local key = lousy.bind.key
add_binds("formfiller", lousy.util.table.join({
    -- Exit profile menu
    key({}, "q", function (w) w:set_mode() end),

    -- Select profile
    key({}, "Return",
        function (w)
            local profile = w.menu:get()[1]
            do_load(w, profile)
            w.menu:hide()
            w:set_mode()
        end),
}, menu_binds))

-- Enable (re)storing of HTTP auth credentials
soup.add_signal("authenticate", function (uri)
    local filename = formsdir .. string.match(string.gsub(uri, "%w+://", ""), "(.-)/.*")
    local fd, err = io.open(filename, "r")
    if not fd then return end
    fd:seek("set")
    local user = nil
    local pass = nil
    for line in fd:lines() do
        if string.match(line, "^!httpuser") then
            user = string.match(line, "^!httpuser (.*)$")
        elseif string.match(line, "^!httppass") then
            pass = string.match(line, "^!httppass (.*)$")
        end
    end
    if user and pass then
        return user, pass
    end
end)

soup.add_signal("store-password", function (uri, login, password)
    local filename = formsdir .. string.match(string.gsub(uri, "%w+://", ""), "(.-)/.*")
    local fd = io.open(filename, "a+")
    fd:write(string.format("!httpuser %s\n!httppass %s\n", login, password))
    fd:flush()
    fd:close()
end)

-- vim: et:sw=4:ts=8:sts=4:tw=80
