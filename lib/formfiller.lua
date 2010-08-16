table.insert( mode_binds['normal'], bind.buf("^za",                     function (w) w:formfiller("add") end) )
table.insert( mode_binds['normal'], bind.buf("^zn",                     function (w) w:formfiller("new") end) )
table.insert( mode_binds['normal'], bind.buf("^ze",                     function (w) w:formfiller("edit") end) )
table.insert( mode_binds['normal'], bind.buf("^zl",                     function (w) w:formfiller("load") end) )

window_helpers["formfiller"] = function(w, action)
        local editor = (os.getenv("EDITOR") or "vim") .. " "
        local modeline = "> vim:ft=formfiller"
        local filename = ""
        local formsDir = luakit.data_dir .. "/forms/"
        os.execute(string.format("mkdir -p %q", formsDir))
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
                            var type=(input.type?input.type:text);
                            if(type == 'text' || type == 'password' || type == 'search') {
                                rv += input.name + '(' + type + '):' + input.value + '\\n';
                            }
                            else if(type == 'checkbox' || type == 'radio') {
                                rv += input.name + '{' + input.value + '}(' + type + '):' + (input.checked?'ON':'OFF') + '\\n';
                            }
                        }
                        xp_res=allFrames[j].document.evaluate('//textarea', allFrames[j].document.documentElement, null, XPathResult.ANY_TYPE,null);
                        var input;
                        while(input=xp_res.iterateNext()) {
                            rv += input.name + '(textarea):' + input.value + '\\n';
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
            fd:write(string.format("%s\n!profile=NAME_THIS_PROFILE_%d\n%s", modeline, math.random(), w:get_current():eval_js(dumpFunction, "dump")))
            fd:flush()
            os.execute("xterm -e " .. editor .. filename .. " &")
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
            local fd = io.open(filename, "r")
            local profile = ".*"
            fd:seek("set")
            if fd:read("*a"):find("!profile=.*") > 1 then
                fd:seek("set")
                local p = ""
                for l in fd:lines() do
                    if string.match(l, "^!profile=.*$") then
                        if p == "" then
                            p = string.format("%s", string.match(l, "^!profile=([^$]*)$"))
                        else
                            p = string.format("%s\n%s", p, string.match(l, "^!profile=([^$]*)$"))
                        end
                    end
                end

                p = string.format("echo -e -n \"%s\" | dmenu -l 3 ", p)
                profile = io.popen(p):read("*a")
            end
            fd:seek("set")
            for line in fd:lines() do
                if string.match(line, "^!profile=" .. profile .. "\ *$") then
                    break
                end
            end
            for line in fd:lines() do
                if not string.match(line, "^!profile=.*") then
                    local fname, fchecked, ftype, fvalue
                    fname, fchecked, ftype, fvalue = string.match(string.gsub(line, "(.+)%((.+)%):% -(.*)", "%1{0}(%2):%3"), "([^{]+){(.+)}%((.+)%):\ *([^ ]*)")
                    if fname ~= nil then
                        -- print(string.format("name: %s checked: %s type: %s value: %s", fname, fchecked, ftype, fvalue))
                        w:get_current():eval_js(insertFunction .. string.format("insert('%s', '%s', '%s', '%s');", fname, ftype, fvalue, fchecked), "f")
                    end
                else
                    break
                end
            end
            fd:close()
        elseif action == "edit" then
            os.execute("xterm -e " .. editor .. filename .. " &")
        end
    end
