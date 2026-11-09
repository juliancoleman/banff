-- Compact weather from the qs notch (Weather/WeatherCircle.qml): a Lucide glyph and whole degrees
-- without a unit, from OmniWM's weather feed. Shared by the weather component (which draws it) and
-- the island root (which reserves its width). While the feed has nothing to show, an enabled
-- component draws a dimmed cloud and "–", with the reason in its tooltip.

local theme = require("./theme")
local glyphs = require("./glyphs")

local TEXT = { font = theme.font, size = theme.digitSize, weight = "medium" }

type Summary = { text: string, glyph: string, help: string, ready: boolean }

local function summary(w): Summary
    if w == nil then
        return { text = "–", glyph = "cloud", ready = false,
            help = "No weather yet. Set a location in Settings > Styles & Widgets > Island > Weather." }
    elseif w.access == "off" then
        return { text = "–", glyph = "cloud", ready = false,
            help = "Weather is off in Settings > Network & Permissions." }
    elseif w.access ~= "ok" then
        return { text = "–", glyph = "cloud", ready = false, help = "Weather is blocked by your organization." }
    end
    local place = if w.place then " · " .. w.place else ""
    if w.status == "stale" then
        return { text = "–", glyph = glyphs.weatherGlyph(w.code, w.day), ready = false,
            help = w.condition .. place .. " (out of date)" }
    end
    return { text = tostring(math.round(w.temp)), glyph = glyphs.weatherGlyph(w.code, w.day), ready = true,
        help = w.condition .. place }
end

-- Width of the compact view in points.
local function width(ctx): number
    local textWidth = math.ceil((ctx.format.measure(summary(ctx.data.weather).text, TEXT)))
    return 2 * theme.weatherInset + theme.weatherIcon + theme.weatherIconGap + textWidth
end

local function icon(name: string, color: string)
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
            border = color,
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
            fill = color,
        })
    end
    return ui.stack(children)
end

local function render(ctx, height: number)
    local s = summary(ctx.data.weather)
    local color = if s.ready then theme.colors.text else theme.colors.textSecondary
    local inset = theme.weatherInset
    return ui.row({
        key = "weather",
        w = width(ctx),
        h = height,
        gap = 0,
        help = s.help,
        ui.box({ w = inset, h = 1 }),
        icon(s.glyph, color),
        ui.box({ w = theme.weatherIconGap, h = 1 }),
        ui.text({ key = "temp", text = s.text, font = theme.font, size = theme.digitSize, weight = "medium",
            color = color }),
        ui.box({ w = inset, h = 1 }),
    })
end

return { width = width, render = render }
