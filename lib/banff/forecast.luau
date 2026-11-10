-- The qs weather panel (Weather/WeatherPanel.qml, WeatherBody.qml, HourlyTrace.qml), docked under the
-- time row and opened from the weather slot. 290 pt wide: the place, the current temperature with
-- condition and today's range, a 24-hour temperature trace with rain bars and sunrise/sunset, and the
-- coming days as range bars on a shared axis.
--
-- From OmniWM's weather feed (Open-Meteo): no NWS alerts, wind warnings or air quality, and 7 days
-- rather than qs's 10. Sunrise and sunset come for today only; tomorrow's are today's plus a day.

local theme = require("./theme")
local glyphs = require("./glyphs")
local weatherView = require("./weather")

local WIDTH = 290
local PLACE = 27 -- the housing's resting thickness, like the other panels
local GAP = 8
local HERO = 52
local CAPTION = 6 + 13 + 4 + 1

-- Hourly trace (HourlyTrace.qml)
local INSET = 12
local PLOT_TOP = 16
local PLOT_HEIGHT = 56
local RAIN_HEIGHT = 14
local FLOOR = PLOT_TOP + PLOT_HEIGHT
local TRACE = FLOOR + 4 + 14
local SUN_ROW = 6 + 14

-- Days
local DAY_ROW = 26
local SPAN_X = 124
local SPAN_WIDTH = WIDTH - SPAN_X - 44

local function text(value: string, size: number, weight: string, color: string)
    return ui.text({ text = value, font = theme.font, size = size, weight = weight, color = color })
end

-- Places `element` in a row of width `w` at (x, y), aligned within it. Positioning a text element
-- by its own offset misplaced it on the Mac, while rows place their children reliably.
local function place(key: string, element, x: number, y: number, w: number, alignment: string)
    local row = { key = key, w = w, gap = 0, align = "topLeading", dx = x, dy = y }
    if alignment ~= "leading" then
        row[#row + 1] = ui.box({ grow = 1, h = 1 })
    end
    row[#row + 1] = element
    if alignment == "center" then
        row[#row + 1] = ui.box({ grow = 1, h = 1 })
    end
    return ui.row(row)
end

local function degrees(value: number?): string
    return if value then math.round(value) .. "°" else "–"
end

local function caption(key: string, label: string)
    return ui.column({
        key = key,
        w = WIDTH,
        gap = 4,
        center = false,
        ui.box({ w = 1, h = 2 }),
        text(label, 10, "regular", theme.colors.textSecondary),
        ui.box({ key = "rule", w = WIDTH, h = 1, fill = theme.colors.rule }),
    })
end

local function timeLabel(ctx, seconds: number, minutes: boolean): string
    local settings = ctx.data.settings
    local use24 = settings ~= nil and settings.use24Hour == true
    local template = if use24 then (if minutes then "HHmm" else "HH") else (if minutes then "hmma" else "ha")
    return ctx.format.date(seconds, template) or ""
end

-- Grid step and bounds for a set of temperatures (5° steps up to a 15° span, else 10°).
local function bounds(values: { number }, spanLimit: number): (number, number, number)
    local low, high = math.huge, -math.huge
    for _, value in values do
        low = math.min(low, value)
        high = math.max(high, value)
    end
    local step = if high - low <= spanLimit then 5 else 10
    local lo = math.floor(low / step) * step
    local hi = math.ceil(high / step) * step
    if hi == lo then
        hi = lo + step
    end
    return lo, hi, step
end

-- Hero ------------------------------------------------------------------------------------------

local function hero(w)
    local today = w.days and w.days[1]
    local high = w.high or (today and today.high)
    local low = w.low or (today and today.low)
    return ui.row({
        key = "hero",
        w = WIDTH,
        h = HERO,
        gap = 14,
        text(degrees(w.temp), 40, "light", theme.colors.text),
        ui.column({
            key = "sky",
            gap = 3,
            center = false,
            ui.row({ key = "condition", gap = 6,
                weatherView.icon(glyphs.weatherGlyph(w.code, w.day), theme.colors.text, 14),
                text(w.condition or "", 12, "regular", theme.colors.text) }),
            text("High " .. degrees(high) .. " · Low " .. degrees(low), 12, "regular", theme.colors.textSecondary),
        }),
    })
end

-- 24-hour trace ---------------------------------------------------------------------------------

local function sunTimes(w, first: number, last: number)
    local times = {}
    for _, entry in { { "sunrise", w.sunrise }, { "sunset", w.sunset } } do
        local kind, time = entry[1], entry[2]
        if time then
            for _, candidate in { time, time + 86400 } do
                if candidate > first and candidate < last then
                    times[#times + 1] = { kind = kind, time = candidate }
                end
            end
        end
    end
    table.sort(times, function(a, b)
        return a.time < b.time
    end)
    return times
end

local function trace(ctx, w)
    local hours = {}
    for index, hour in w.hours do
        if index > 24 then
            break
        end
        hours[index] = hour
    end
    local count = #hours
    local plotWidth = WIDTH - 2 * INSET
    local step = plotWidth / math.max(1, count - 1)
    local temps = {}
    for index, hour in hours do
        temps[index] = if index == 1 then w.temp else hour.temp
    end
    local lo, hi, gridStep = bounds(temps, 15)
    local function x(index: number): number
        return INSET + (index - 1) * step
    end
    local function y(value: number): number
        return PLOT_TOP + (hi - value) / (hi - lo) * PLOT_HEIGHT
    end

    local first, last = hours[1].time, hours[count].time
    local suns = sunTimes(w, first, last)
    local height = TRACE + (if #suns > 0 then SUN_ROW else 0)
    local children = { key = "trace", w = WIDTH, h = height }

    for value = lo, hi, gridStep do
        children[#children + 1] = ui.box({ key = "grid" .. value, w = plotWidth, h = 1, align = "topLeading",
            dx = INSET, dy = y(value), fill = theme.colors.rule })
    end
    for _, sun in suns do
        local sx = INSET + (sun.time - first) / (last - first) * plotWidth
        children[#children + 1] = ui.box({ key = "sun" .. sun.time, w = 1, h = PLOT_HEIGHT, align = "topLeading",
            dx = sx, dy = PLOT_TOP, fill = theme.colors.rule })
    end
    for index, hour in hours do
        local chance = hour.rain or 0
        if chance >= 10 then
            local barWidth = math.max(2, step * 0.5)
            local barHeight = chance / 100 * RAIN_HEIGHT
            children[#children + 1] = ui.box({ key = "rain" .. index, w = barWidth, h = barHeight,
                align = "topLeading", dx = x(index) - barWidth / 2, dy = FLOOR - barHeight,
                fill = theme.colors.statusTrack })
        end
    end
    local points = {}
    for index, value in temps do
        points[#points + 1] = string.format("%s%.2f %.2f", if index == 1 then "M" else "L", x(index), y(value))
    end
    children[#children + 1] = ui.path({ key = "line", w = WIDTH, h = height, viewBox = { 0, 0, WIDTH, height },
        align = "topLeading", d = table.concat(points, " "), border = theme.colors.text, borderWidth = 2 })
    children[#children + 1] = ui.box({ key = "now", w = 2, h = 8, align = "topLeading", dx = x(1) - 1,
        dy = FLOOR - 4, fill = theme.colors.today })

    local every = if plotWidth / count * 3 >= 40 then 3 else 4
    for index = 1, count, every do
        children[#children + 1] = place("value" .. index, text(degrees(temps[index]), 11, "medium", theme.colors.text),
            x(index) - 20, y(temps[index]) - 15, 40, "center")
        local label = if index == 1 then "Now" else timeLabel(ctx, hours[index].time, false)
        children[#children + 1] = place("time" .. index, text(label, 10, "regular", theme.colors.textSecondary),
            x(index) - 24, FLOOR + 4, 48, "center")
    end

    if #suns > 0 then
        local row = { key = "suns", gap = 12, align = "topLeading", dx = INSET, dy = TRACE + 6 }
        for index, sun in suns do
            row[#row + 1] = ui.row({ key = "s" .. index, gap = 4,
                ui.path({ key = "glyph", w = 12, h = 12, viewBox = { 0, 0, 24, 24 }, d = glyphs.weather[sun.kind],
                    border = theme.colors.textSecondary, borderWidth = 1 }),
                text((if sun.kind == "sunrise" then "Sunrise " else "Sunset ") .. timeLabel(ctx, sun.time, true), 10,
                    "regular", theme.colors.textSecondary) })
        end
        children[#children + 1] = ui.row(row)
    end
    return ui.stack(children), height
end

-- Days ------------------------------------------------------------------------------------------

local function days(ctx, w)
    local values = {}
    for _, day in w.days do
        values[#values + 1] = day.low
        values[#values + 1] = day.high
    end
    local lo, hi, step = bounds(values, 20)
    local function x(value: number): number
        return SPAN_X + (value - lo) / (hi - lo) * SPAN_WIDTH
    end

    local axis = { key = "axis", w = WIDTH, h = 12 }
    for value = lo, hi, step do
        axis[#axis + 1] = place("a" .. value, text(value .. "°", 8, "regular", theme.colors.textSecondary),
            x(value) - 15, 0, 30, "center")
    end

    local rows = { key = "days", w = WIDTH, gap = 0, center = false, ui.stack(axis) }
    for index, day in w.days do
        local chance = day.rain or 0
        local name = if index == 1 then "Today" else day.label
        local row = {
            key = "d" .. index,
            w = WIDTH,
            h = DAY_ROW,
            place("name", text(name, 12, "medium", theme.colors.text), 0, 6, 44, "leading"),
            ui.stack({ key = "icon", w = 14, h = 14, align = "topLeading", dx = 48,
                dy = 6 - (if chance >= 20 then 4 else 0),
                weatherView.icon(glyphs.weatherGlyph(day.code, true), theme.colors.text, 14) }),
            place("low", text(degrees(day.low), 12, "regular", theme.colors.textSecondary), 76, 6, 34, "trailing"),
            ui.box({ key = "range", w = math.max(2, x(day.high) - x(day.low)), h = 2, align = "topLeading",
                dx = x(day.low), dy = DAY_ROW / 2 - 1, fill = theme.colors.text }),
            ui.box({ key = "lowTick", w = 1, h = 8, align = "topLeading", dx = x(day.low), dy = DAY_ROW / 2 - 4,
                fill = theme.colors.text }),
            ui.box({ key = "highTick", w = 1, h = 8, align = "topLeading", dx = x(day.high) - 1,
                dy = DAY_ROW / 2 - 4, fill = theme.colors.text }),
            place("high", text(degrees(day.high), 12, "regular", theme.colors.text), WIDTH - 34, 6, 34, "trailing"),
        }
        if chance >= 20 then
            row[#row + 1] = place("chance", text(math.round(chance) .. "%", 8, "medium", theme.colors.today), 55 - 15,
                15, 30, "center")
        end
        if index == 1 and w.temp then
            row[#row + 1] = ui.box({ key = "nowTick", w = 2, h = 12, align = "topLeading",
                dx = math.clamp(x(w.temp), SPAN_X, SPAN_X + SPAN_WIDTH) - 1, dy = DAY_ROW / 2 - 6,
                fill = theme.colors.today })
        end
        rows[#rows + 1] = ui.stack(row)
    end
    return ui.column(rows), 12 + #w.days * DAY_ROW
end

-- Panel -----------------------------------------------------------------------------------------

-- The open panel and its height, or nil when the feed has nothing to show. Presses on its gutter
-- are absorbed so they do not reach the housing.
local function panel(ctx)
    local w = ctx.data.weather
    if w == nil or w.access ~= "ok" then
        return nil, 0
    end
    local parts = { { hero(w), HERO } }
    if #w.hours > 1 then
        parts[#parts + 1] = { caption("hoursCaption", "Next 24 hours"), CAPTION }
        parts[#parts + 1] = { trace(ctx, w) }
    end
    if #w.days > 0 then
        parts[#parts + 1] = { caption("daysCaption", #w.days .. "-day forecast"), CAPTION }
        parts[#parts + 1] = { days(ctx, w) }
    end
    local body = { key = "body", w = WIDTH, gap = GAP, center = false, align = "topLeading", dy = PLACE }
    local bodyHeight = -GAP
    for _, part in parts do
        body[#body + 1] = part[1]
        bodyHeight += part[2] + GAP
    end
    body.h = bodyHeight
    local height = PLACE + bodyHeight
    return ui.stack({
        key = "weatherPanel",
        w = WIDTH,
        h = height,
        onClick = function() end,
        place("place", text(w.place or "Weather", 12, "regular", theme.colors.textSecondary), 0, 7, WIDTH, "leading"),
        ui.column(body),
    }), height
end

return { WIDTH = WIDTH, panel = panel }
