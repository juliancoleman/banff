-- The qs calendar (Clock/MonthGrid.qml, MonthHeader.qml, MonthArrow.qml): a month title between
-- ‹ › arrows over a Sunday-first grid with only as many week rows as the month needs, planner rules
-- between weeks, adjacent-month days dimmed and today in blue-black text. Navigation slides the
-- days 18 pt in the direction of travel while fading in from 45 %.

local theme = require("./theme")

local MONTHS = { "January", "February", "March", "April", "May", "June",
    "July", "August", "September", "October", "November", "December" }
local WEEKDAYS = { "S", "M", "T", "W", "T", "F", "S" }

local CELL = 24
local GAP = 2
local WEEK_ROW = 16
local HEADER = 22
local ARROW = 28

local function leap(year: number): boolean
    return (year % 4 == 0 and year % 100 ~= 0) or year % 400 == 0
end

local function daysIn(year: number, month: number): number
    if month == 2 then
        return if leap(year) then 29 else 28
    end
    return if month == 4 or month == 6 or month == 9 or month == 11 then 30 else 31
end

-- Day of the week, 0 = Sunday (Sakamoto's method). `month` is 1–12.
local function weekday(year: number, month: number, day: number): number
    local offsets = { 0, 3, 2, 5, 0, 3, 5, 1, 4, 6, 2, 4 }
    local y = if month < 3 then year - 1 else year
    return (y + y // 4 - y // 100 + y // 400 + offsets[month] + day) % 7
end

local function shift(year: number, month: number, delta: number): (number, number)
    local index = year * 12 + (month - 1) + delta
    return index // 12, index % 12 + 1
end

type Cell = { day: number, inMonth: boolean, today: boolean }
type Today = { year: number, month: number, day: number }

-- The month's cells from the Sunday on or before the 1st, whole weeks only.
local function grid(year: number, month: number, today: Today?): ({ Cell }, number)
    local first = weekday(year, month, 1)
    local length = daysIn(year, month)
    local rows = math.ceil((first + length) / 7)
    local py, pm = shift(year, month, -1)
    local ny, nm = shift(year, month, 1)
    local previous = daysIn(py, pm)
    local cells = {}
    for index = 0, rows * 7 - 1 do
        local offset = index - first + 1
        local y, m, d
        if offset < 1 then
            y, m, d = py, pm, previous + offset
        elseif offset > length then
            y, m, d = ny, nm, offset - length
        else
            y, m, d = year, month, offset
        end
        cells[#cells + 1] = {
            day = d,
            inMonth = m == month,
            today = today ~= nil and today.year == y and today.month == m and today.day == d,
        }
    end
    return cells, rows
end

local function title(year: number, month: number): string
    return MONTHS[month] .. " " .. year
end

local WIDTH = 7 * CELL + 6 * GAP

-- Height of the header, gap and grid for a month with `rows` weeks.
local function height(rows: number): number
    return HEADER + 6 + WEEK_ROW + 6 + rows * CELL + (rows - 1) * GAP
end

local function arrow(key: string, glyph: string, onClick)
    return ui.stack({
        key = key,
        w = ARROW,
        h = HEADER,
        radius = 6,
        hover = theme.colors.lift,
        pressFill = theme.colors.press,
        cursor = "pointer",
        help = if glyph == "‹" then "Previous month" else "Next month",
        onClick = onClick,
        ui.text({ text = glyph, font = theme.font, size = 15, weight = "medium", color = theme.colors.text }),
    })
end

local function header(year: number, month: number, onShift)
    return ui.stack({
        key = "header",
        w = WIDTH,
        h = HEADER,
        ui.row({
            key = "titleRow",
            w = WIDTH,
            h = HEADER,
            gap = 0,
            arrow("previous", "‹", function(next)
                onShift(next, -1)
            end),
            ui.box({ grow = 1, h = 1 }),
            ui.text({ key = "title", text = title(year, month), font = theme.font, size = 12, weight = "medium",
                color = theme.colors.text }),
            ui.box({ grow = 1, h = 1 }),
            arrow("next", "›", function(next)
                onShift(next, 1)
            end),
        }),
        ui.box({ key = "rule", w = WIDTH, h = 1, align = "bottom", fill = theme.colors.rule }),
    })
end

-- Today differs only in text colour; there is no disc behind it.
local function cell(entry: Cell, index: number)
    return ui.stack({
        key = "c" .. index,
        w = CELL,
        h = CELL,
        ui.text({
            key = "day",
            text = tostring(entry.day),
            font = theme.font,
            size = 12,
            weight = "medium",
            color = if entry.today then theme.colors.today
                elseif entry.inMonth then theme.colors.text
                else theme.colors.statusDim,
        }),
    })
end

-- The open calendar: header, weekday letters, then the weeks. `direction` (-1, 0, 1) is the last
-- navigation step; `onShift(ctx, delta)` moves the month.
local function render(year: number, month: number, today: Today?, direction: number, onShift)
    local cells, rows = grid(year, month, today)
    local bodyHeight = rows * CELL + (rows - 1) * GAP

    local weekdays = { key = "weekdays", w = WIDTH, h = WEEK_ROW, gap = GAP }
    for index, letter in WEEKDAYS do
        weekdays[#weekdays + 1] = ui.stack({ key = "w" .. index, w = CELL, h = WEEK_ROW,
            ui.text({ text = letter, font = theme.font, size = 10, weight = "medium", color = theme.colors.textSecondary }) })
    end

    local weeks = {
        key = string.format("days-%d-%02d", year, month),
        w = WIDTH,
        h = bodyHeight,
        gap = GAP,
        align = "topLeading",
        appear = if direction ~= 0
            then { dx = direction * 18, opacity = 0.45, animate = theme.spring }
            else { animate = "none" },
        exit = { opacity = 0, animate = "none" },
    }
    for row = 0, rows - 1 do
        local line = { key = "r" .. row, w = WIDTH, h = CELL, gap = GAP }
        for column = 1, 7 do
            local index = row * 7 + column
            line[#line + 1] = cell(cells[index], index)
        end
        weeks[#weeks + 1] = ui.row(line)
    end

    -- Planner rules stay put while the days slide across them; the mask keeps the slide inside.
    local body = {
        key = "body",
        w = WIDTH,
        h = bodyHeight,
        ui.path({ key = "clip", d = "M0 0 H1 V1 H0 Z", viewBox = { 0, 0, 1, 1 }, w = WIDTH, h = bodyHeight, mask = true }),
    }
    for row = 1, rows - 1 do
        body[#body + 1] = ui.box({ key = "rule" .. row, w = WIDTH, h = 1, align = "topLeading",
            dy = row * (CELL + GAP) - GAP / 2 - 0.5, fill = theme.colors.rule })
    end
    body[#body + 1] = ui.column(weeks)

    return ui.column({
        key = "calendar",
        w = WIDTH,
        gap = 0,
        center = false,
        header(year, month, onShift),
        ui.box({ w = 1, h = 6 }),
        ui.row(weekdays),
        ui.box({ w = 1, h = 6 }),
        ui.stack(body),
    })
end

return {
    daysIn = daysIn,
    weekday = weekday,
    shift = shift,
    grid = grid,
    title = title,
    height = height,
    width = WIDTH,
    render = render,
}
