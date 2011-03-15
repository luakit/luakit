local buf = lousy.bind.buf
local key = lousy.bind.key
add_binds("normal",
          {
           key({}, "a", function (w)
                            luakit.spawn("touch /tmp/luakit_iat_test",
                            function(exit_type, exit_num)
                                if exit_num == 0 then
                                    w:warning("OK")
                                else
                                    w:warning("Not OK")
                                end
                            end)
                        end),
          })

