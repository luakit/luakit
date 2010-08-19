table.insert( mode_binds['normal'], bind.buf("^za",                     function (w) w:formfiller("add") end) )
table.insert( mode_binds['normal'], bind.buf("^zn",                     function (w) w:formfiller("new") end) )
table.insert( mode_binds['normal'], bind.buf("^ze",                     function (w) w:formfiller("edit") end) )
table.insert( mode_binds['normal'], bind.buf("^zl",                     function (w) w:formfiller("load") end) )

window_helpers["formfiller"] = function(w, action)
        local editor = (os.getenv("EDITOR") or "vim") .. " "
        local modeline = "> vim:ft=formfiller"
        local filename = ""
        local formsDir = luakit.data_dir .. "/forms/"
        luakit.spawn(string.format("mkdir -p %q", formsDir))
        if action == "once" then
            filename = os.tmpname()
        else
            local uri, match = string.gsub(string.gsub(w.sbar.l.uri.text, "%w+://", ""), "(.-)/.*", "%1")
            filename = formsDir .. uri
        end 
        if action == "add" then
            modeline = ""
        end
        if action == "new" or action == "once" or action == "add" then
            local dumpFunction=[[(function dump() {
                var rv='';
                var allFrames = new Array(window);
                for(f=0;f<window.frames.length;f=f+1) {
                    allFrames.push(window.frames[f]);
                }
                for(j=0;j<allFrames.length;j=j+1) {
                    try {
                        var xp_res=allFrames[j].document.evaluate('//input', allFrames[j].document.documentElement, null, XPathResult.ANY_TYPE,null);
                        var input;
                        while(input=xp_res.iterateNext()) {
                            if(input.name != "") {
                                var type=(input.type?input.type:text);
                                if(type == 'text' || type == 'password' || type == 'search') {
                                    rv += input.name + '(' + type + '):' + input.value + '\n';
                                }
                                else if(type == 'checkbox' || type == 'radio') {
                                    rv += input.name + '{' + input.value + '}(' + type + '):' + (input.checked?'ON':'OFF') + '\n';
                                }
                            }
                        }
                        xp_res=allFrames[j].document.evaluate('//textarea', allFrames[j].document.documentElement, null, XPathResult.ANY_TYPE,null);
                        var input;
                        while(input=xp_res.iterateNext()) {
                            if(input.name != "") {
                                rv += input.name + '(textarea):' + input.value + '\n';
                            }
                        }
                    }
                    catch(err) { }
                }
                return rv;
            })()]]
            math.randomseed(os.time())
            local fd
            if action == "add" then
                fd = io.open(filename, "a+")
            else
                fd = io.open(filename, "w+")
            end
            fd:write(string.format("%s\n!profile=NAME_THIS_PROFILE_%d\n%s", modeline, math.random(1,9999), w:get_current():eval_js(dumpFunction, "dump")))
            fd:flush()
            luakit.spawn("xterm -e " .. editor .. filename)
            fd:close()
        elseif action == "load" then
            local insertFunction=[[function insert(fname, ftype, fvalue, fchecked) {
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
                            allFrames[j].document.getElementsByName(fname)[0].checked = fchecked
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
            };]]
            if (luakit.spawn_sync(string.format("sh -c '[ -e %s ] || exit 1'", filename))) == 1 then
                return nil
            end
            local fd = io.open(filename, "r")
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
            local fname, fchecked, ftype, fvalue
            local js = insertFunction
            local pattern1 = "(.+)%((.+)%):% *(.*)"
            local pattern2 = "%1{0}(%2):%3"
            local pattern3 = "([^{]+){(.+)}%((.+)%):% *(.*)"
            for line in fd:lines() do
                if not string.match(line, "^!profile=.*") then
                    if ftype == "textarea" then
                        if string.match(string.gsub(line, pattern1, pattern2), pattern3) then
                            js = string.format("%s insert('%s', '%s', '%s', '%s');", js, fname, ftype, fvalue, fchecked)
                            ftype = nil
                        else
                            fvalue = string.format("%s\\n%s", fvalue, line)
                        end
                    end
                    if ftype ~= "textarea" then
                        fname, fchecked, ftype, fvalue = string.match(string.gsub(line, pattern1, pattern2), pattern3)
                        if fname ~= nil and ftype ~= "textarea" then
                            js = string.format("%s insert('%s', '%s', '%s', '%s');", js, fname, ftype, fvalue, fchecked)
                        end
                    end
                else
                    break
                end
            end
            if ftype == "textarea" then
                js = string.format("%s insert('%s', '%s', '%s', '%s');", js, fname, ftype, fvalue, fchecked)
            end
            w:get_current():eval_js(js, "f")
            fd:close()
        elseif action == "edit" then
            luakit.spawn(string.format("xterm -e %s %s", editor, filename))
        end
    end
