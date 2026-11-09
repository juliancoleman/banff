-- Lucide path data used by the qs shell (~/dotfiles/qs qml/shell/Status/StatusGlyph.qml), 24-unit grid.
-- OmniShell strokes paths with butt caps, so zero-length dots ("h0.01") are drawn as circles instead.

local cloudTop = "M4 14.899A7 7 0 1 1 15.71 8h1.79a4.5 4.5 0 0 1 2.5 8.242"

local weather = {
    ["clear-day"] = "M8 12a4 4 0 1 0 8 0a4 4 0 1 0 -8 0 M12 2v2 M12 20v2 M4.93 4.93l1.41 1.41 "
        .. "M17.66 17.66l1.41 1.41 M2 12h2 M20 12h2 M6.34 17.66l-1.41 1.41 M19.07 4.93l-1.41 1.41",
    ["clear-night"] = "M12 3a6 6 0 0 0 9 9a9 9 0 1 1 -9 -9z",
    ["partly-day"] = "M12 2v2 M4.93 4.93l1.41 1.41 M20 12h2 M19.07 4.93l-1.41 1.41 M15.947 12.65a4 4 0 0 0 -5.925 -4.128 "
        .. "M13 22H7a5 5 0 1 1 4.9 -6H13a3 3 0 0 1 0 6z",
    ["partly-night"] = "M13 16a3 3 0 0 1 0 6H7a5 5 0 1 1 4.9 -6z M18.376 14.512a6 6 0 0 0 3.461 -4.127"
        .. "c0.148 -0.625 -0.659 -0.97 -1.248 -0.714a4 4 0 0 1 -5.259 -5.26c0.255 -0.589 -0.09 -1.395 -0.716 -1.248"
        .. "a6 6 0 0 0 -4.594 5.36",
    cloud = "M17.5 19H9a7 7 0 1 1 6.71 -9h1.79a4.5 4.5 0 1 1 0 9z",
    rain = cloudTop .. " M16 14v6 M8 14v6 M12 16v6",
    snow = cloudTop,
    hail = cloudTop .. " M16 14v2 M8 14v2 M12 16v2",
    thunder = "M6 16.326A7 7 0 1 1 15.71 8h1.79a4.5 4.5 0 0 1 0.5 8.973 M13 12l-3 5h4l-3 5",
    fog = cloudTop .. " M16 17H7 M17 21H9",
}

-- Dots that complete a weather glyph: { x, y } centres on the 24-unit grid.
local weatherDots = {
    snow = { { 8, 15 }, { 8, 19 }, { 12, 17 }, { 12, 21 }, { 16, 15 }, { 16, 19 } },
    hail = { { 16, 20 }, { 8, 20 }, { 12, 22 } },
}

-- WMO weather code (Open-Meteo, as OmniWM's weather feed reports) to glyph name.
-- Mirrors WeatherService.glyphForCode, with night variants when it is dark.
local function weatherGlyph(code: number, day: boolean): string
    if code <= 1 then
        return if day then "clear-day" else "clear-night"
    elseif code == 2 then
        return if day then "partly-day" else "partly-night"
    elseif code == 3 then
        return "cloud"
    elseif code == 45 or code == 48 then
        return "fog"
    elseif code == 56 or code == 57 or code == 66 or code == 67 then
        return "hail"
    elseif (code >= 71 and code <= 77) or code == 85 or code == 86 then
        return "snow"
    elseif code >= 95 then
        return "thunder"
    end
    return "rain"
end

return {
    weather = weather,
    weatherDots = weatherDots,
    weatherGlyph = weatherGlyph,
    wifiArcs = {
        "M8.5 16.429a5 5 0 0 1 7 0",
        "M5 12.859a10 10 0 0 1 14 0",
        "M2 8.82a15 15 0 0 1 20 0",
    },
    wifiDot = { 12, 20 },
    slash = "M2 2 L22 22",
}
