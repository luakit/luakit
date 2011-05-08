-------------------------------------------------------
-- Follow styles to customize hints for luakit       --
-- © 2010 Fabian Streitel <karottenreibe@gmail.com>  --
-- © 2010 Mason Larobina  <mason.larobina@gmail.com> --
-------------------------------------------------------

--- Contains different styles for following.
-- A style is a function that returns a hash with the following entries:
-- <ul>
-- <li> <code>make_labels</code>
-- <li> <code>parse_inupt</code>
-- </ul>
--
module("follow.styles")

--- Generates the labels for the hints.
--
-- @param size How many labels to generate
-- @return An array of strings with the given size.
--
-- @class function
-- @name make_labels

--- Parses the user's input into a match string and an ID.
-- Can be overriden to have a different matching procedure, e.g. when
-- <code>make_labels</code> has been overridden.
--
-- <br><br><h3>Example</h3>
--
-- To only perform the following on the follow labels and not on the text
-- content of the elements, you could use
--
-- <pre>follow.parse_input = function (text)
--  <br>  return "", text
--  <br>end
-- </pre>
--
-- @param text The input of the user.
-- @return A string that is used to filter the hints by their text content.
-- @return An string that is used to filter the hints by their IDs.
--
-- @class function
-- @name parse_input

--- Style that uses numbers for the hint labels and matches other text against the pages elements.
-- @param sort Whether to sort the hint labels
--  <br> Not sorting can help reading labels on high link density sites.
-- @param reverse Whether to reverse the hint labels.
--  <br> This sometimes equates to less key presses.
function number_hints(sort, reverse)
    return {
        make_labels = function (size)
            local digits = 1
            while true do
                local max = 10 ^ digits - 10 ^ (digits - 1)
                if max == 9 then max = 10 end
                if max >= size then
                    break
                else
                    digits = digits + 1
                end
            end
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
        end
    }
end

