-- Banff island root: the qs "notch" housing at the top of the main display.
-- At rest: weather · 12-hour clock · status ring in one black housing flush with the top edge,
-- square on top and rounded below. On a display with a camera notch the housing wraps the notch,
-- with weather and clock to its left and status to its right. Hover reveals the date.

local theme = require("../lib/banff/theme")
local glyphs = require("../lib/banff/glyphs")
local clock = require("../lib/banff/clock")
local status = require("../lib/banff/status")

interval = 1

local TEXT = { font = theme.font, size = theme.digitSize, weight = "medium" }

local function time(ctx): (number?, number?)
    local seconds = ctx.data.seconds
    local hour = tonumber(ctx.format.date(seconds, "HH") or "")
    local minute = tonumber(ctx.format.date(seconds, "mm") or "")
    if hour == nil or minute == nil then
        return nil, nil
    end
    return clock.parts(hour, minute, false)
end

local function dateText(ctx): string
    local seconds = ctx.data.seconds
    local fields = {}
    for _, template in { "EEE", "MMM", "d", "yyyy" } do
        fields[#fields + 1] = ctx.format.date(seconds, template) or ""
    end
    return table.concat(fields, " ")
end

local function weatherIcon(name: string)
    local size = theme.weatherIcon
    local k = size / 24
    local children = {
        key = "icon",
        w = size,
        h = size,
        ui.path({
            key = "glyph",
            w = size,
            h = size,
            viewBox = { 0, 0, 24, 24 },
            d = glyphs.weather[name],
            border = theme.colors.text,
            borderWidth = 2 * k,
        }),
    }
    for index, dot in glyphs.weatherDots[name] or {} do
        local d = 2.4 * k
        children[#children + 1] = ui.box({
            key = "dot" .. index,
            w = d,
            h = d,
            radius = d / 2,
            align = "topLeading",
            dx = dot[1] * k - d / 2,
            dy = dot[2] * k - d / 2,
            fill = theme.colors.text,
        })
    end
    return ui.stack(children)
end

-- Compact weather (Weather/WeatherCircle.qml): glyph and whole degrees without a unit.
-- Returns nil when the feed is off or not loaded.
local function weather(ctx, height: number)
    local w = ctx.data.weather
    if w == nil or w.access ~= "ok" then
        return nil, 0
    end
    local temp = if w.status == "stale" then "–" else tostring(math.round(w.temp))
    local textWidth = math.ceil((ctx.format.measure(temp, TEXT)))
    local inset = theme.weatherInset
    local width = 2 * inset + theme.weatherIcon + theme.weatherIconGap + textWidth
    return ui.row({
        key = "weather",
        w = width,
        h = height,
        gap = 0,
        help = w.condition,
        ui.box({ w = inset, h = 1 }),
        weatherIcon(glyphs.weatherGlyph(w.code, w.day)),
        ui.box({ w = theme.weatherIconGap, h = 1 }),
        ui.text({ key = "temp", text = temp, font = theme.font, size = theme.digitSize, weight = "medium",
            color = theme.colors.text }),
        ui.box({ w = inset, h = 1 }),
    }), width
end

function render(ctx)
    local island = ctx.data.island
    if island == nil then
        return ui.box({ w = 0, h = 0 })
    end
    local state = ctx.state
    state.metrics = state.metrics or clock.metrics(ctx)
    local m = state.metrics
    local hovered = state.hovered == true

    local notch = island.notch
    local height = math.max(theme.height, if notch then notch.h else 0)
    local weatherItem, weatherWidth = weather(ctx, height)
    local clockWidth = clock.width(m)
    local leftWidth = (if weatherItem then weatherWidth + theme.gap else 0) + clockWidth
    local rightWidth = theme.status

    -- Housing origin and width in envelope coordinates; group origins relative to the housing.
    local x, width, leftX, rightX
    if notch then
        -- Wrap the notch: weather and clock end left of it, status starts right of it.
        x = notch.x - theme.gap - leftWidth - theme.pad
        width = theme.pad + leftWidth + theme.gap + notch.w + theme.gap + rightWidth + theme.pad
        leftX = theme.pad
        rightX = notch.x + notch.w + theme.gap - x
    else
        width = theme.pad + leftWidth + theme.gap + rightWidth + theme.pad
        x = (island.size.w - width) / 2
        leftX = theme.pad
        rightX = leftX + leftWidth + theme.gap
    end
    local housingHeight = height + (if hovered then theme.dateRow else 0)
    local radius = theme.height / 2

    local left = { key = "left", h = height, gap = 0, align = "topLeading", dx = leftX, dy = 0, animate = theme.spring }
    if weatherItem then
        left[#left + 1] = weatherItem
        left[#left + 1] = ui.box({ key = "weatherGap", w = theme.gap, h = 1 })
    end
    local hour, minute = time(ctx)
    if hour ~= nil and minute ~= nil then
        left[#left + 1] = clock.render(hour, minute, m)
    else
        left[#left + 1] = ui.text({ key = "time", text = ctx.data.clock, font = theme.font, size = theme.digitSize,
            weight = "medium", color = theme.colors.text })
    end

    local housing = {
        key = "housing",
        w = width,
        h = housingHeight,
        align = "topLeading",
        dx = x,
        dy = 0,
        animate = theme.spring,
        hoverGrace = 0.12,
        onHover = function(next, event)
            next.state.hovered = event.phase == "began"
        end,
        ui.box({
            key = "body",
            w = width,
            h = housingHeight,
            radius = radius,
            fill = theme.colors.surface,
            shadow = theme.colors.shadow,
            shadowRadius = theme.shadowRadius,
            shadowOffset = theme.shadowOffset,
            animate = theme.spring,
        }),
        -- Squares the top corners against the screen edge.
        ui.box({ key = "top", w = width, h = radius, align = "top", fill = theme.colors.surface, animate = theme.spring }),
        ui.row(left),
        ui.box({
            key = "statusSlot",
            w = rightWidth,
            h = height,
            align = "topLeading",
            dx = rightX,
            dy = 0,
            animate = theme.spring,
            status.render(ctx.data, state),
        }),
    }
    if hovered then
        -- A housing-wide row with growing spacers on both sides centres the date (the pattern the
        -- official styles use). A plain box lays its child out from the leading edge.
        housing[#housing + 1] = ui.row({
            key = "date",
            w = width,
            h = theme.dateRow,
            gap = 0,
            align = "topLeading",
            dx = 0,
            dy = height - 1,
            appear = { opacity = 0, dy = -4, animate = theme.spring },
            exit = { opacity = 0, animate = theme.fade },
            ui.box({ grow = 1, h = 1 }),
            ui.text({
                text = dateText(ctx),
                font = theme.font,
                size = theme.dateSize,
                weight = "medium",
                color = theme.colors.textSecondary,
            }),
            ui.box({ grow = 1, h = 1 }),
        })
    end

    return ui.stack({ key = "envelope", w = island.size.w, h = island.size.h, ui.stack(housing) })
end
