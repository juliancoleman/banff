-- The qs clock face (Clock/HorizontalFace.qml, DigitTicker.qml, Period.qml): "hh:mm" with a dimmed
-- leading hour zero and digits that roll in fixed-width strips, plus an optional AM/PM whose A/P
-- rolls too. Sizes come from a presentation's size set (theme.sizes).

local theme = require("./theme")

local ASCENT = 1.025 -- IBM Plex Sans ascender, in em
local LINE = 1.3 -- ascender + descender, in em

-- Hour (1–12, or 0–23 when `use24`) and minute from a 24-hour hour and minute.
local function parts(hour24: number, minute: number, use24: boolean): (number, number)
    if use24 then
        return hour24, minute
    end
    local hour = hour24 % 12
    return if hour == 0 then 12 else hour, minute
end

-- The four digits of "hh:mm".
local function digits(hour: number, minute: number): { number }
    return { hour // 10, hour % 10, minute // 10, minute % 10 }
end

-- Cell widths for size set `z`: digit, colon, the A/P cell and the trailing M.
local function metrics(ctx, z)
    local style = { font = theme.font, size = z.digit, weight = "medium" }
    local digit = 0
    for value = 0, 9 do
        digit = math.max(digit, (ctx.format.measure(tostring(value), style)))
    end
    local colon = ctx.format.measure(":", style)
    local periodStyle = { font = theme.font, size = z.period, weight = "medium" }
    local letter = math.max((ctx.format.measure("A", periodStyle)), (ctx.format.measure("P", periodStyle)))
    local m = ctx.format.measure("M", periodStyle)
    return { digit = math.ceil(digit), colon = math.ceil(colon), letter = math.ceil(letter), m = math.ceil(m) + 1 }
end

local function label(text: string, size: number, color: string)
    return ui.text({ text = text, font = theme.font, size = size, weight = "medium", color = color })
end

-- One rolling cell: a clipped column of `symbols` offset to `index` (0-based).
local function strip(key: string, index: number, symbols: { string }, width: number, height: number, size: number,
    color: string)
    local column = { key = "strip", w = width, gap = 0, align = "topLeading", dy = -index * height,
        animate = theme.roll, appear = { animate = "none" } }
    for _, symbol in symbols do
        column[#column + 1] = ui.box({ key = symbol, w = width, h = height, label(symbol, size, color) })
    end
    return ui.stack({
        key = key,
        w = width,
        h = height,
        ui.path({ key = "clip", d = "M0 0 H1 V1 H0 Z", viewBox = { 0, 0, 1, 1 }, w = width, h = height, mask = true }),
        ui.column(column),
    })
end

local DIGITS = { "0", "1", "2", "3", "4", "5", "6", "7", "8", "9" }
local PERIODS = { "A", "P" }

-- The AM/PM: a rolling A/P and a fixed M in pencil, sharing the digits' baseline.
local function period(value: string, m, z)
    local height = math.ceil(z.period * LINE)
    local digitBaseline = (z.digitBox - z.digit * LINE) / 2 + z.digit * ASCENT
    local top = digitBaseline - z.period * ASCENT - (height - z.period * LINE) / 2
    local color = theme.colors.textSecondary
    return ui.stack({
        key = "period",
        w = m.letter + m.m,
        h = z.digitBox,
        ui.row({
            key = "letters",
            gap = 0,
            align = "topLeading",
            dy = top,
            strip("ap", if value == "P" then 1 else 0, PERIODS, m.letter, height, z.period, color),
            ui.box({ key = "m", w = m.m, h = height, label("M", z.period, color) }),
        }),
    })
end

-- The time row. `m` comes from `metrics(ctx, z)`; `meridiem` is "A", "P" or nil.
local function render(hour: number, minute: number, m, z, meridiem: string?)
    local d = digits(hour, minute)
    local text, dim = theme.colors.text, theme.colors.textSecondary
    local row = {
        key = "time",
        gap = 0,
        h = z.digitBox,
        strip("h1", d[1], DIGITS, m.digit, z.digitBox, z.digit, if d[1] == 0 then dim else text),
        strip("h2", d[2], DIGITS, m.digit, z.digitBox, z.digit, text),
        ui.box({ key = "colon", w = m.colon, h = z.digitBox, label(":", z.digit, text) }),
        strip("m1", d[3], DIGITS, m.digit, z.digitBox, z.digit, text),
        strip("m2", d[4], DIGITS, m.digit, z.digitBox, z.digit, text),
    }
    if meridiem then
        row[#row + 1] = ui.box({ key = "periodGap", w = theme.periodGap, h = 1 })
        row[#row + 1] = period(meridiem, m, z)
    end
    return ui.row(row)
end

local function width(m, meridiem: string?): number
    local base = 4 * m.digit + m.colon
    return if meridiem then base + theme.periodGap + m.letter + m.m else base
end

return {
    parts = parts,
    digits = digits,
    metrics = metrics,
    render = render,
    width = width,
}
