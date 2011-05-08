-------------------------------------------------------
-- Follow styles to customize hints for luakit       --
-- © 2010 Fabian Streitel <karottenreibe@gmail.com>  --
-- © 2010 Mason Larobina  <mason.larobina@gmail.com> --
-------------------------------------------------------

local table, string = table, string
local tostring = tostring

--- Contains different styles for following.
-- A style is a function that returns a hash with the following entries:
--
-- <ul>
-- <li> <code>make_labels</code>
-- <li> <code>parse_inupt</code>
-- </ul>
--
-- See below for documentation of these functions
module("follow.styles")

--- Generates the labels for the hints.
--
-- @param size How many labels to generate
-- @return An array of strings with the given size.
--
-- @class function
-- @name make_labels

--- Parses the user's input into a match string and an ID.
--
-- @param text The input of the user.
-- @return A string that is used to filter the hints by their text content.
-- @return An string that is used to filter the hints by their IDs.
--
-- @class function
-- @name parse_input

-- Calculates the minimum number of characters needed in a hint given a
-- charset of a certain length.
--
-- @param size The number of hints that need to be generated
-- @param charset The length of the charset
local function calculate_hint_length(size, charset)
    local digits = 1
    while true do
        local max = charset ^ digits
        if max >= size then
            break
        else
            digits = digits + 1
        end
    end
    return digits
end

--- Style that uses numbers for the hint labels and matches other text against the pages elements.
--
-- @param sort Whether to sort the hint labels
--  <br> Not sorting can help reading labels on high link density sites.
-- @param reverse Whether to reverse the hint labels.
--  <br> This sometimes equates to less key presses.
function filtered_number_hints(sort, reverse)
    return {
        make_labels = function (size)
            local digits = calculate_hint_length(size, 10)
            local start = 10 ^ (digits - 1)
            if start == 1 then start = 0 end
            local labels = {}
            for i = start, size+start-1, 1 do
                if reverse then
                    table.insert(labels, string.reverse(i))
                else
                    table.insert(labels, tostring(i))
                end
            end
            if reverse and sort then table.sort(labels) end
            return labels
        end,

        parse_input = function (text)
            return string.match(text, "^(.-)(%d*)$")
        end,
    }
end

--- Style that uses characters from a charset for the hint labels.
--
-- @param charset The characters to use for the labels.
function char_hints(charset)
    return {
        make_labels = function (size)
            -- calculate the number of digits to use
            local digits = calculate_hint_length(size, #charset)
            -- use this to track what label to generate next
            local state = {}
            for i = 1, digits, 1 do
                table.insert(state, 1)
            end
            -- make all labels
            local labels = {}
            for i = 1, size, 1 do
                -- assemble each label according to state
                local label = ""
                for i = 1, digits, 1 do
                    label = string.sub(charset, state[i], state[i]) .. label
                end
                table.insert(labels, label)
                -- increase the state
                local inc
                inc = function (digit)
                    local s = state[digit]
                    if not s then return end
                    s = s + 1
                    if s > #charset then
                        s = 1
                        inc(digit + 1)
                    end
                    state[digit] = s
                end
                inc(1)
            end
            return labels
        end,

        parse_input = function (text)
            return "", text
        end,
    }
end

