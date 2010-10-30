-------------------------------------------------------------
-- @author Mason Larobina &lt;mason.larobina@gmail.com&gt; --
-- @copyright 2010 Mason Larobina                          --
-------------------------------------------------------------

-- Grab environment we need
local capi = { widget = widget }
local setmetatable = setmetatable
local math = require "math"
local signal = require "lousy.signal"
local print = print
local type = type
local assert = assert
local ipairs = ipairs
local table = table
local util = require "lousy.util"
local get_theme = require("lousy.theme").get

module "lousy.widget.menu"

local data = setmetatable({}, { __mode = "k" })

function update(menu)
    assert(data[menu] and type(menu.widget) == "widget", "invalid menu widget")

    -- Get private menu widget data
    local d = data[menu]

    -- Get theme table
    local theme = get_theme()
    local fg, bg, font = theme.menu_fg, theme.menu_bg, theme.menu_font
    local sfg, sbg = theme.menu_selected_fg, theme.menu_selected_bg

    -- Hide widget while re-drawing
    menu.widget:hide()

    -- Build & populate rows
    for i = 1, math.max(d.max_rows, #(d.table)) do
        -- Get row
        local index = i + d.offset - 1
        local row = (i <= d.max_rows) and d.rows[index]
        -- Get row widget table
        local rw = d.table[i]

        -- Make new row
        if row and not rw then
            -- Row widget struct
            rw = {
                ebox = capi.widget{type = "eventbox"},
                hbox = capi.widget{type = "hbox"},
                cols = {},
            }
            rw.ebox:set_child(rw.hbox)
            d.table[i] = rw
            -- Add to main vbox
            menu.widget:pack_start(rw.ebox, false, false, 0)

        -- Remove row
        elseif not row and rw then
            -- Destroy row columns (label widgets)
            for _, l in ipairs(rw.cols) do
                rw.hbox:remove(l)
                l:destroy()
            end
            rw.ebox:remove(rw.hbox)
            rw.hbox:destroy()
            menu.widget:remove(rw.ebox)
            rw.ebox:destroy()
            d.table[i] = nil
        end

        -- Populate columns
        if row and rw then
            -- Match up row data with row widget (for callbacks)
            rw.data = row

            -- Try to find last off-screen title row and replace with current
            if i == 1 and not row.title and d.offset > 1 then
                local j = d.offset - 1
                while j > 0 do
                    local r = d.rows[j]
                    -- Only check rows with same number of columns
                    if r.ncols ~= row.ncols then break end
                    -- Check if title row
                    if r.title then
                        row, index = r, j
                        break
                    end
                    j = j - 1
                end
            end

            -- Is this the selected row?
            selected = not row.title and index == d.cursor

            -- Set row bg
            local rbg
            if row.title then
                rbg = (row.bg or theme.menu_title_bg) or bg
            else
                rbg = (selected and (row.selected_bg or sbg)) or row.bg or bg
            end
            if rw.ebox.bg ~= rbg then rw.ebox.bg = rbg end

            for c = 1, math.max(row.ncols, #(rw.cols)) do
                -- Get column text
                local text = row[c]
                text = (type(text) == "function" and text(row)) or text
                -- Get table cell
                local cell = rw.cols[c]

                -- Make new row column widget
                if text and not cell then
                    cell = capi.widget{type = "label"}
                    rw.hbox:pack_start(cell, true, true, 0)
                    rw.cols[c] = cell
                    cell.font = font
                    cell:set_width(1)

                -- Remove row column widget
                elseif not text and cell then
                    rw.hbox:remove(cell)
                    rw.cols[c] = nil
                    cell:destroy()
                end

                -- Set cell props
                if text and cell and row.title then
                    cell.text = text
                    local fg = row.fg or (c == 1 and theme.menu_primary_title_fg or theme.menu_secondary_title_fg) or fg
                    if cell.fg ~= fg then cell.fg = fg end
                elseif text and cell then
                    cell.text = text
                    local fg = (selected and (row.selected_fg or sfg)) or row.fg or fg
                    if cell.fg ~= fg then cell.fg = fg end
                end
            end
        end
    end
    -- Show widget
    menu.widget:show()
end

function build(menu, rows)
    assert(data[menu] and type(menu.widget) == "widget", "invalid menu widget")

    -- Get private menu widget data
    local d = data[menu]

    -- Check rows
    for i, row in ipairs(rows) do
        assert(type(row) == "table", "invalid row in rows table")
        assert(#row >= 1, "empty row")
        row.ncols = #row
    end

    d.rows = rows
    d.nrows = #rows

    -- Initial positions
    d.cursor = 0
    d.offset = 1

    update(menu)
end

local function calc_offset(menu)
    local d = data[menu]
    if d.cursor < 1 then
        return
    elseif d.cursor <= d.offset then
        d.offset = math.max(d.cursor - 1, 1)
    elseif d.cursor > (d.offset + d.max_rows - 1) then
        d.offset = math.max(d.cursor - d.max_rows + 1, 1)
    end
end

function move_up(menu)
    assert(data[menu] and type(menu.widget) == "widget", "invalid menu widget")

    -- Get private menu widget data
    local d = data[menu]

    -- Move cursor
    if not d.cursor or d.cursor < 1 then
        d.cursor = d.nrows
    else
        d.cursor = d.cursor - 1
    end

    -- Get next non-title row (you can't select titles)
    while d.cursor > 0 and d.cursor <= d.nrows and d.rows[d.cursor].title do
        d.cursor = d.cursor - 1
    end

    calc_offset(menu)
    update(menu)

    -- Emit changed signals
    menu:emit_signal("changed", menu:get())
end

function move_down(menu)
    assert(data[menu] and type(menu.widget) == "widget", "invalid menu widget")

    -- Get private menu widget data
    local d = data[menu]

    -- Move cursor
    if d.cursor == d.nrows then
        d.cursor = 0
    else
        d.cursor = (d.cursor or 0) + 1
    end

    -- Get next non-title row (you can't select titles)
    while d.cursor > 0 and d.cursor <= d.nrows and d.rows[d.cursor].title do
        d.cursor = d.cursor + 1
    end

    calc_offset(menu)
    update(menu)

    -- Emit changed signals
    menu:emit_signal("changed", menu:get())
end

function get(menu, index)
    assert(data[menu] and type(menu.widget) == "widget", "invalid menu widget")

    -- Get private menu widget data
    local d = data[menu]

    -- Return row at given index or current cursor position.
    return d.rows[index or d.cursor]
end

function del(menu, index)
    assert(data[menu] and type(menu.widget) == "widget", "invalid menu widget")

    -- Get private menu widget data
    local d = data[menu]

    -- Unable to delete this index, return
    if d.cursor < 1 then return end

    table.remove(d.rows, d.cursor)

    -- Update rows count
    d.nrows = #(d.rows)

    -- Check cursor
    d.cursor = math.min(d.cursor, d.nrows)
    d.offset = math.min(d.offset, math.max(d.nrows - d.max_rows + 1, 1))

    update(menu)

    -- Emit changed signals
    menu:emit_signal("changed", menu:get())
end

function new(args)
    args = args or {}

    local menu = {
        widget    = capi.widget{type = "vbox"},
        -- Add widget methods
        build     = build,
        update    = update,
        get       = get,
        del       = del,
        move_up   = move_up,
        move_down = move_down,
        hide      = function(menu) menu.widget:hide() end,
        show      = function(menu) menu.widget:show() end,
    }

    -- Save private widget data
    data[menu] = {
        -- Hold the rows & columns of label widgets which construct the
        -- menu list widget.
        table = {},
        max_rows = args.max_rows or 10,
        nrows = 0,
        rows = {},
    }

    -- Setup class signals
    signal.setup(menu)

    return menu
end

setmetatable(_M, { __call = function(_, ...) return new(...) end })
