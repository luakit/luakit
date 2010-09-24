------------------------------------------------------------------
-- Luakit formfiller                                            --
-- (C) 2010 Pawel Tomak    (grodzik) <pawel.tomak@gmail.com>    --
-- (C) 2010 Mason Larobina (mason-l) <mason.larobina@gmail.com> --
------------------------------------------------------------------

-- Setup formfiller binds
local buf = lousy.bind.buf
for _, b in ipairs({
    buf("^za", function (w) w:formfiller("add")  end),
    buf("^zn", function (w) w:formfiller("new")  end),
    buf("^ze", function (w) w:formfiller("edit") end),
    buf("^zl", function (w) w:formfiller("load") end),
}) do table.insert(binds.mode_binds.normal, b) end

-- Load formfiller settings
local ff = globals.formfiller or {}
local term       = ff.term     or globals.term   or "xterm"
local editor     = ff.editor   or globals.editor or (os.getenv("EDITOR") or "vim")
local modeline   = ff.modeline or "> vim:ft=formfiller"
local formsdir   = ff.formsdir or luakit.data_dir .. "/forms/"
local editor_cmd = string.format("%s -e %s", term, editor)

-- Javascript functions
local dump_function = [=[
    (function dump() {
        var rv='';
        var allFrames = new Array(window);
        for(f=0;f<window.frames.length;f=f+1) {
            allFrames.push(window.frames[f]);
        }
        for(j=0;j<allFrames.length;j=j+1) {
            try {
                for(f=0;f<allFrames[j].document.forms.length;f=f+1) {
                    var fn = allFrames[j].document.forms[f].name;
                    var fi = allFrames[j].document.forms[f].id;
                    var fm = allFrames[j].document.forms[f].method;
                    var fa = allFrames[j].document.forms[f].action;
                    var form = '!form[' + fn + '|' + fi + '|' + fm + '|' + fa + ']:autosubmit=0\n';
                    var fb = '';
                    var xp_res=allFrames[j].document.evaluate('.//input', allFrames[j].document.forms[f], null, XPathResult.ANY_TYPE,null);
                    var input;
                    while(input=xp_res.iterateNext()) {
                        if(input.name != "") {
                            var type=(input.type?input.type:text);
                            if(type == 'text' || type == 'password' || type == 'search') {
                                fb += input.name + '(' + type + '):' + input.value + '\n';
                            }
                            else if(type == 'checkbox' || type == 'radio') {
                                fb += input.name + '{' + input.value + '}(' + type + '):' + (input.checked?'ON':'OFF') + '\n';
                            }
                        }
                    }
                    xp_res=allFrames[j].document.evaluate('.//textarea', allFrames[j].document.forms[f], null, XPathResult.ANY_TYPE,null);
                    var input;
                    while(input=xp_res.iterateNext()) {
                        if(input.name != "") {
                            fb += input.name + '(textarea):' + input.value + '\n';
                        }
                    }
                    if(fb.length) {
                        rv += form + fb;
                    }
                }
            }
            catch(err) { }
        }
        return rv;
    })()]=]

local insert_function = [=[
    function insert(fname, ftype, fvalue, fchecked) {
        var allFrames = new Array(window);
        for(f=0;f<window.frames.length;f=f+1) {
            allFrames.push(window.frames[f]);
        }
        for(j=0;j<allFrames.length;j=j+1) {
            try {
                if(ftype == 'text' || ftype == 'password' || ftype == 'search' || ftype == 'textarea') {
                    allFrames[j].document.getElementsByName(fname)[0].value = fvalue;
                }
                else if(ftype == 'checkbox') {
                    allFrames[j].document.getElementsByName(fname)[0].checked = fchecked;
                }
                else if(ftype == 'radio') {
                    var radios = allFrames[j].document.getElementsByName(fname);
                    for(r=0;r<radios.length;r+=1) {
                        if(radios[r].value == fvalue) {
                            radios[r].checked = fchecked;
                        }
                    }
                }
            }
            catch(err) { }
        }
    };]=]

local submit_function = [=[
    function submitForm(fname, fid, fmethod, faction) {
        var allFrames = new Array(window);
        for(f=0;f<window.frames.length;f=f+1) {
            allFrames.push(window.frames[f]);
        }
        for(j=0;j<allFrames.length;j=j+1) {
            for(f=0;f<allFrames[j].document.forms.length;f=f+1) {
                var myForm = allFrames[j].document.forms[f];
                if( ( (myForm.name != "" && myForm.name == fname) || (myForm.id != "" && myForm.id == fid) || (myForm.action != "" && myForm.action == faction)) && myForm.method == fmethod) {
                    try {
                        var xp_res=allFrames[j].document.evaluate(".//input[@type='submit']", myForm, null, XPathResult.ANY_TYPE,null);
                    } catch (err) { }
                    var input;
                    try {
                        while(input=xp_res.iterateNext()) {
                                input.type='text';
                        }
                    } catch (err) { }
                    try {
                        myForm.submit();
                    } catch (err) { }
                    return;
                }
            }
        }
    };]=]

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
        luakit.spawn(string.format("%s %q", editor_cmd, filename))
        fd:close()

    elseif action == "load" then
        local fd, err = io.open(filename, "r")
        if not fd then return end
        local profile = ""
        fd:seek("set")
        for l in fd:lines() do
            if string.match(l, "^!profile=.*$") then
                if profile == "" then
                    profile = string.format("%s", string.match(l, "^!profile=([^$]*)$"))
                else
                    profile = string.format("%s\n%s", profile, string.match(l, "^!profile=([^$]*)$"))
                end
            end
        end
        if profile:find("\n") then
            local exit_status, multiline, err = luakit.spawn_sync('sh -c \'if [ "`dmenu --help 2>&1| grep lines`x" != "x" ]; then echo -n "-l 3"; else echo -n ""; fi\'')
            if exit_status ~= 0 then
                print(string.format("An error occured: %s", err))
                return nil
            end
            -- color settings
            local NB="#0f0f0f"
            local NF="#4e7093"
            local SB="#003d7c"
            local SF="#3a9bff"
            profile = string.format('sh -c \'echo -e -n "%s" | dmenu %s -nb "%s" -nf "%s" -sb "%s" -sf "%s" -p "Choose profile"\'', profile, multiline, NB, NF, SB, SF)
            exit_status, profile, err = luakit.spawn_sync(profile)
            if exit_status ~= 0 then
                print(string.format("An error occured: ", err))
                return nil
            end
        end
        fd:seek("set")
        for line in fd:lines() do
            if string.match(line, "^!profile=" .. profile .. "\ *$") then
                break
            end
        end
        local fname, fchecked, ftype, fvalue, form
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
                    form = line
                    autosubmit = string.match(form, "^!form%[.-%]:autosubmit=(%d)")
                else
                    if ftype == "textarea" then
                        if string.match(string.gsub(line, pattern1, pattern2), pattern3) then
                            js = string.format("%s\ninsert(%q, %q, %q, %q);", js, fname, ftype, fvalue, fchecked)
                            ftype = nil
                        else
                            fvalue = string.format("%s\\n%s", fvalue, line)
                        end
                    end
                    if ftype ~= "textarea" then
                        fname, fchecked, ftype, fvalue = string.match(string.gsub(line, pattern1, pattern2), pattern3)
                        if fname ~= nil and ftype ~= "textarea" then
                            js = string.format("%s\ninsert(%q, %q, %q, %q);", js, fname, ftype, fvalue, fchecked)
                        end
                    end
                end
            else
                break
            end
        end
        if ftype == "textarea" then
            js = string.format("%s\ninsert(%q, %q, %q, %q);", js, fname, ftype, fvalue, fchecked)
        end
        if autosubmit == "1" then
            js = string.format("%s\nsubmitForm(%q, %q, %q, %q);", js, string.match(form, "^!form%[([^|]-)|([^|]-)|([^|]-)|([^|]-)%]"))
        end
        view:eval_js(js, "(formfiller:load)")
        fd:close()

    elseif action == "edit" then
        luakit.spawn(string.format("%s %q", editor_cmd, filename))
    end
end

-- vim: et:sw=4:ts=8:sts=4:tw=80
