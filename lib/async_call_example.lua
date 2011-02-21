local buf = lousy.bind.buf
local key = lousy.bind.key
add_binds("normal",
          {
           key({}, "a", function (w)
                            luakit.spawn("ls /home",
                            function(exit_type, exit_num, stdout, stderr)
                                w:warning(stdout)
                            end)
                        end),
          })

