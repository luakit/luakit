require "lunit"

module("test_common", lunit.testcase, package.seeall)

function files(dir, pattern)
    assert(dir and dir ~= "", "directory parameter is missing or empty")
    if string.sub(dir, -1) == "/" then
        dir = string.sub(dir, 1, -2)
    end

    local ignore = { ["."] = true, [".."] = true, [".git"] = true, ["tokenize.h"] = true, ["tokenize.c"] = true }

    local function yieldtree(dir)
        for entry in lfs.dir(dir) do
            if not ignore[entry] then
                entry = dir.."/"..entry
                local attr = lfs.attributes(entry)
                if attr.mode == "directory" then
                    yieldtree(entry)
                elseif attr.mode == "file" and entry:match(pattern) then
                    coroutine.yield(entry, attr)
                end
            end
        end
    end

    return coroutine.wrap(function() yieldtree(dir) end)
end

function test_no_globalconf_in_common()
    local has_globalconf = {}
    for file in files("common", "%.[ch]$") do
        -- Get file contents
        local f = assert(io.open(file, "r"))
        local contents = f:read("*all")
        f:close()
        if contents:match("globalconf") then
            table.insert(has_globalconf, file)
        end
    end

    if #has_globalconf > 0 then
        local err = {}
        for _, file in ipairs(has_globalconf) do
            err[#err+1] = "  " .. file
        end
        fail("Some files in common/ access globalconf:\n" .. table.concat(err, "\n"))
    end
end
