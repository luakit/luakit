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

module "lousy.widget.dmenu"

local data = setmetatable({}, { __mode = "k" })

function update(dmenu)
    assert(data[dmenu] and type(dmenu.widget) == "widget", "invalid dmenu widget")

    -- Get private dmenu widget data
    local d = data[dmenu]

    -- Get theme table
    local theme = get_theme()
    local fg, bg = theme.dmenu_fg, theme.dmenu_bg
    local sfg, sbg = theme.dmenu_selected_fg, theme.dmenu_selected_bg

    -- Hide widget while re-drawing
    dmenu.widget:hide()

    -- Build & populate rows
    for i = 1, math.max(d.max_rows, #d.rows) do
        -- Get row
        local row = (i <= d.max_rows) and d.all_rows[i + d.offset - 1]
        -- Get row widget table
        local rw = d.rows[i]

        -- Make new row
        if row and not rw then
            -- Row widget table
            rw = {
                ebox = capi.widget{type = "eventbox"},
                hbox = capi.widget{type = "hbox"},
                cols = {},
            }
            rw.ebox:set_child(rw.hbox)
            d.rows[i] = rw
            -- Add to main vbox
            dmenu.widget:pack_start(rw.ebox, false, false, 0)

        -- Remove row
        elseif not row and rw then
            -- Destroy row cells
            for i = 1, #rw.cols do
                local cell = table.remove(rw.cols)
                rw.hbox:remove(cell)
                cell:destroy()
            end
            rw.ebox:remove(rw.hbox)
            rw.hbox:destroy()
            dmenu.widget:remove(rw.ebox)
            rw.ebox:destroy()
            d.rows[i] = nil
        end

        -- Populate columns
        if row and rw then
            -- Match up row data with row widget (for callbacks)
            rw.data = row

            -- Set selected var
            row.selected = row.selectable ~= false and row.index == d.cursor

            -- Set row bg
            local bg = (row.selected and (row.selected_bg or sbg)) or row.bg or bg
            if rw.ebox.bg ~= bg then rw.ebox.bg = bg end

            for c = 1, math.max(#row, #rw.cols) do
                -- Get column text
                local text = row[c]
                -- Get row cell widget
                local cell = rw.cols[c]

                -- Make new row column widget
                if text and not cell then
                    cell = capi.widget{type = "label"}
                    rw.hbox:pack_start(cell, true, true, 0)
                    rw.cols[c] = cell
                    cell.font = theme.dmenu_font
                    cell:set_width(1)

                -- Remove row column widget
                elseif not text and cell then
                    rw.hbox:remove(cell)
                    rw.cols[c] = nil
                    cell:destroy()
                end

                -- Set cell props
                if text and cell then
                    cell.text = type(text) == "function" and text(row) or text
                    local fg = (row.selected and (row.selected_fg or sfg)) or row.fg or fg
                    if cell.fg ~= fg then cell.fg = fg end
                end
            end
        end
    end
    -- Show widget
    dmenu.widget:show()
end

function build(dmenu, rows)
    assert(data[dmenu] and type(dmenu.widget) == "widget", "invalid dmenu widget")

    -- Get private dmenu widget data
    local d = data[dmenu]

    -- Clone row tables
    local all_rows = {}
    for i, row in ipairs(rows) do
        assert(type(row) == "table", "invalid row in rows table")
        assert(#row >= 1, "empty row")
        all_rows[i] = util.table.clone(row)
        all_rows[i].index = i
    end

    d.all_rows = all_rows

    -- Initial positions
    d.cursor = 1
    d.offset = 1

    update(dmenu)
end

function move_cursor(dmenu, p)
    assert(data[dmenu] and type(dmenu.widget) == "widget", "invalid dmenu widget")
    assert(p, "invalid position")

    -- Get private dmenu widget data
    local d = data[dmenu]
    local c = d.cursor

    -- If the cursor was never set then nothing is selectable
    if not c then return end

    -- Adjust cursor position
    if p < 0 then
        d.cursor = math.max(c + p, 1)
    elseif p > 0 then
        d.cursor = math.min(c + p, #d.all_rows)
    end

    -- Adjust offset to make selected row visible
    if d.cursor < d.offset then
        d.offset = d.cursor
    elseif d.cursor > (d.offset + d.max_rows - 1) then
        d.offset = math.max(d.cursor - d.max_rows + 1, 1)
    end

    update(dmenu)
end

function get_current(dmenu)
    assert(data[dmenu] and type(dmenu.widget) == "widget", "invalid dmenu widget")

    -- Get private dmenu widget data
    local d = data[dmenu]

    return d.all_rows[d.cursor or 1]
end

function del_current(dmenu)
    assert(data[dmenu] and type(dmenu.widget) == "widget", "invalid dmenu widget")

    -- Get private dmenu widget data
    local d = data[dmenu]

    -- Unable to delete this index, return
    if d.cursor < 1 then return end

    table.remove(d.all_rows, d.cursor)

    -- Update table indexes
    for i, row in ipairs(d.all_rows) do row.index = i end

    -- Check cursor
    d.cursor = math.min(d.cursor, #d.all_rows)
    d.offset = math.max(d.offset - 1, 1)

    update(dmenu)
end

function new(args)
    args = args or {}

    local dmenu = {
        widget = capi.widget{type = "vbox"},
        -- Add widget methods
        build  = build,
        update = update,
        get_current = get_current,
        del_current = del_current,
        move_cursor = move_cursor,
        hide   = function(dmenu) dmenu.widget:hide() end,
        show   = function(dmenu) dmenu.widget:show() end,
    }

    -- Save private widget data
    data[dmenu] = {
        rows = {},
        max_rows = args.max_rows or 10,
    }

    -- Setup class signals
    signal.setup(dmenu)

    return dmenu
end

setmetatable(_M, { __call = function(_, ...) return new(...) end })
