-- Compact weather from the qs notch (Weather/WeatherCircle.qml): a Lucide glyph and whole degrees
-- without a unit, from OmniWM's weather feed. Shared by the weather component (which draws it) and
-- the island root (which reserves its width).

local theme = require("./theme")
local glyphs = require("./glyphs")

local TEXT = { font = theme.font, size = theme.digitSize, weight = "medium" }

local function temperature(w): string
    return if w.status == "stale" then "–" else tostring(math.round(w.temp))
end

-- Width of the compact view in points, or nil when the feed is off or not loaded yet.
local function width(ctx): number?
    local w = ctx.data.weather
    if w == nil or w.access ~= "ok" then
        return nil
    end
    local textWidth = math.ceil((ctx.format.measure(temperature(w), TEXT)))
    return 2 * theme.weatherInset + theme.weatherIcon + theme.weatherIconGap + textWidth
end

local function icon(name: string)
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

local function render(ctx, height: number)
    local w = ctx.data.weather
    local total = width(ctx)
    if w == nil or w.access ~= "ok" or total == nil then
        return ui.box({ w = 0, h = 0 })
    end
    local inset = theme.weatherInset
    return ui.row({
        key = "weather",
        w = total,
        h = height,
        gap = 0,
        help = w.condition,
        ui.box({ w = inset, h = 1 }),
        icon(glyphs.weatherGlyph(w.code, w.day)),
        ui.box({ w = theme.weatherIconGap, h = 1 }),
        ui.text({ key = "temp", text = temperature(w), font = theme.font, size = theme.digitSize, weight = "medium",
            color = theme.colors.text }),
        ui.box({ w = inset, h = 1 }),
    })
end

return { width = width, render = render }
