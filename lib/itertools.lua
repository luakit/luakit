local ipairs = ipairs
local pairs = pairs
local coroutine = coroutine

module("itertools")

function limit(items, start, stop)
    return coroutine.wrap(function ()
        local counter = 0
        for item in items do
            counter = counter + 1
            if counter >= start then
                if counter > stop then return end
                coroutine.yield(item)
            end
        end
    end)
end

function unique(items, key)
    return coroutine.wrap(key and function ()
        local last = nil
        for item in items do
            local k = key(item)
            if k ~= last then
                last = k
                coroutine.yield(item)
            end
        end
    end or
    function ()
        local last = nil
        for item in items do
            if item ~= last then
                last = item
                coroutine.yield(item)
            end
        end
    end)
end

function split_by(items, grouper)
    return coroutine.wrap(function ()
        local last = nil
        for item in items do
            local h = grouper(item)
            if h ~= last then
                coroutine.yield({ h, title = true })
                last = h
            end
            coroutine.yield(item)
        end
    end)
end

function map(filter, items)
    return coroutine.wrap(function ()
        for v in items do
            coroutine.yield(filter(v))
        end
    end)
end

function values(items)
    return coroutine.wrap(function ()
        for _, v in ipairs(items) do
            coroutine.yield(v)
        end
    end)
end

function kvalues(items)
    return coroutine.wrap(function ()
        for _, v in pairs(items) do
            coroutine.yield(v)
        end
    end)
end

function rvalues(items)
    return coroutine.wrap(function ()
        local count = #items
        for i = 1, count do
            coroutine.yield(items[count - i + 1])
        end
    end)
end

function reduce(callback, items, init)
    local acc = init
    for item in items do
        acc = callback(acc, item)
    end
    return acc
end
