-- The qs notch clock (Clock/HorizontalFace.qml, DigitTicker.qml): 12-hour "hh:mm" without a
-- meridiem, a dimmed leading hour zero, and digits that roll in fixed-width strips.

local theme = require("./theme")

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

-- Width of one digit cell and of the colon, in points.
local function metrics(ctx)
    local style = { font = theme.font, size = theme.digitSize, weight = "medium" }
    local digit = 0
    for value = 0, 9 do
        digit = math.max(digit, (ctx.format.measure(tostring(value), style)))
    end
    local colon = ctx.format.measure(":", style)
    return { digit = math.ceil(digit), colon = math.ceil(colon) }
end

local function label(text: string, color: string)
    return ui.text({ text = text, font = theme.font, size = theme.digitSize, weight = "medium", color = color })
end

-- One rolling digit: a clipped column of 0–9 offset to `value`.
local function strip(key: string, value: number, width: number, color: string)
    local height = theme.digitBox
    local column = { key = "strip", w = width, gap = 0, align = "topLeading", dy = -value * height,
        animate = theme.roll, appear = { animate = "none" } }
    for digit = 0, 9 do
        column[#column + 1] = ui.box({ key = tostring(digit), w = width, h = height, label(tostring(digit), color) })
    end
    return ui.stack({
        key = key,
        w = width,
        h = height,
        ui.path({ key = "clip", d = "M0 0 H1 V1 H0 Z", viewBox = { 0, 0, 1, 1 }, w = width, h = height, mask = true }),
        ui.column(column),
    })
end

-- The "hh:mm" row. `m` comes from `metrics`.
local function render(hour: number, minute: number, m)
    local d = digits(hour, minute)
    local text, dim = theme.colors.text, theme.colors.textSecondary
    return ui.row({
        key = "time",
        gap = 0,
        h = theme.digitBox,
        strip("h1", d[1], m.digit, if d[1] == 0 then dim else text),
        strip("h2", d[2], m.digit, text),
        ui.box({ key = "colon", w = m.colon, h = theme.digitBox, label(":", text) }),
        strip("m1", d[3], m.digit, text),
        strip("m2", d[4], m.digit, text),
    })
end

local function width(m): number
    return 4 * m.digit + m.colon
end

return {
    parts = parts,
    digits = digits,
    metrics = metrics,
    render = render,
    width = width,
}
