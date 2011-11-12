------------------------------------------------------------
-- Follow styles to customize hints for luakit            --
-- © 2010-2011 Fabian Streitel <karottenreibe@gmail.com>  --
-- © 2010-2011 Mason Larobina  <mason.larobina@gmail.com> --
------------------------------------------------------------

local table, string = table, string
local tostring = tostring
local ipairs = ipairs
local math = require "math"

module("follow.styles")

-- Calculates the minimum number of characters needed in a hint given a
-- charset of a certain length (I.e. the base)
local function max_hint_len(size, base)
    local floor, len = math.floor, 0
    while size > 0 do size, len = floor(size / base), len + 1 end
    return len
end

--- Style that uses a given set of characters for the hint labels and
-- does not perform text matching against the page elements.
--
-- @param charset A string of characters to use for the hint labels.
function charset(charset)
    local floor, sub = math.floor, string.sub
    local insert, concat = table.insert, table.concat
    return {
        make_labels = function (size)
            local base = #charset
            local digits = max_hint_len(size, base)
            local labels, blanks = {}, {}
            for n = 1, digits do
                insert(blanks, sub(charset, 1, 1))
            end
            for n = 1, size do
                local t, d = {}
                repeat
                    d, n = (n % base) + 1, floor(n / base)
                    insert(t, 1, sub(charset, d, d))
                until n == 0
                insert(labels, concat(blanks, "", #t + 1) .. concat(t, ""))
            end
            return labels
        end,

        parse_input = function (text)
            return "", text
        end,
    }
end

--- Style that uses numbers for the hint labels and matches other text against
-- the pages elements.
function numbers_and_labels()
    local style = charset("0123456789")
    style.parse_input = function (text)
        return string.match(text, "^(.-)(%d*)$")
    end
    return style
end

--- Decorator for a style that reverses each label.
--
-- @param style The style to decorate.
function reverse(style)
    local maker = style.make_labels
    style.make_labels = function (size)
        local labels = maker(size)
        for i, l in ipairs(labels) do
            labels[i] = string.reverse(l)
        end
        return labels
    end
    return style
end

--- Decorator for a style that sorts the labels.
--
-- @param style The style to decorate.
function sort(style)
    local maker = style.make_labels
    style.make_labels = function (size)
        local labels = maker(size)
        table.sort(labels)
        return labels
    end
    return style
end

--- Decorator for a style that removes all leading occurrances of a given char from the labels.
-- If a label consists only of the character to remove, it will be truncated to just that character.
--
-- @param char The character to remove.
-- @param style The style to decorate.
function remove_leading(char, style)
    local maker = style.make_labels
    style.make_labels = function (size)
        local labels = maker(size)
        for i, l in ipairs(labels) do
            labels[i] = string.match(l, char.."*(.+)")
        end
        return labels
    end
    return style
end

--- Decorator for a style that makes the label matching case-insensitive.
-- It also converts all labels to upper-case for readability.
--
-- @param style The style to decorate.
function upper(style)
    local maker = style.make_labels
    style.make_labels = function (size)
        local labels = maker(size)
        for i, l in ipairs(labels) do
            labels[i] = string.upper(l)
        end
        return labels
    end
    local parser = style.parse_input
    style.parse_input = function (text)
        local text, id = parser(text)
        return text, string.upper(id)
    end
    return style
end

