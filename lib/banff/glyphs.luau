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
    -- Status circle temporary states (Status/StatusGlyph.qml).
    status = {
        speaker = "M11 4.702a0.705 0.705 0 0 0 -1.203 -0.498L6.413 7.587A1.4 1.4 0 0 1 5.416 8H3"
            .. "a1 1 0 0 0 -1 1v6a1 1 0 0 0 1 1h2.416a1.4 1.4 0 0 1 0.997 0.413l3.383 3.384"
            .. "A0.705 0.705 0 0 0 11 19.298z",
        nearWave = "M16 9a5 5 0 0 1 0 6",
        farWave = "M19.364 18.364a9 9 0 0 0 0 -12.728",
        mute = "M16.5 14.5 L21.5 9.5 M16.5 9.5 L21.5 14.5",
        mic = "M9 5a3 3 0 0 1 6 0v7a3 3 0 0 1 -6 0z M12 19v3 M19 10v2a7 7 0 0 1 -14 0v-2",
        micOff = "M12 19v3 M15 9.34V5a3 3 0 0 0 -5.68 -1.33 M16.95 16.95A7 7 0 0 1 5 12v-2 "
            .. "M18.89 13.23A7 7 0 0 0 19 12v-2 M2 2 L22 22 M9 9v3a3 3 0 0 0 5.12 2.12",
        sun = "M8 12a4 4 0 1 0 8 0a4 4 0 1 0 -8 0 M12 2v2 M12 20v2 M4.93 4.93l1.41 1.41 "
            .. "M17.66 17.66l1.41 1.41 M2 12h2 M20 12h2 M6.34 17.66l-1.41 1.41 M19.07 4.93l-1.41 1.41",
        zap = "M15.914 4a1.5 1.5 0 0 0 -2.474 -1.561l-9 9A1.5 1.5 0 0 0 5.5 14h4.002a0.5 0.5 0 0 1 0.471 0.666"
            .. "L8.086 20a1.5 1.5 0 0 0 2.475 1.56l9 -9A1.5 1.5 0 0 0 18.5 10h-3.997a0.5 0.5 0 0 1 -0.472 -0.667z",
        bluetooth = "M7 7 L17 17 L12 22 V2 L17 7 L7 17",
        play = "M5 5a2 2 0 0 1 3.008 -1.728l11.997 6.998a2 2 0 0 1 0.003 3.458l-12 7A2 2 0 0 1 5 19z",
        pause = "M15 3h3a1 1 0 0 1 1 1v16a1 1 0 0 1 -1 1h-3a1 1 0 0 1 -1 -1V4a1 1 0 0 1 1 -1z "
            .. "M6 3h3a1 1 0 0 1 1 1v16a1 1 0 0 1 -1 1H6a1 1 0 0 1 -1 -1V4a1 1 0 0 1 1 -1z",
        close = "M18 6 L6 18 M6 6 L18 18",
        -- Control center
        chevronLeft = "M15 18 L9 12 L15 6",
        chevronRight = "M9 18 L15 12 L9 6",
        check = "M20 6 L9 17 L4 12",
        lock = "M5 11h14a2 2 0 0 1 2 2v7a2 2 0 0 1 -2 2H5a2 2 0 0 1 -2 -2v-7a2 2 0 0 1 2 -2z M7 11V7a5 5 0 0 1 10 0v4",
        powerOff = "M12 2v10 M18.4 6.6a9 9 0 1 1 -12.77 0.04",
        restart = "M21 12a9 9 0 1 1 -9 -9c2.52 0 4.93 1 6.74 2.74L21 8 M21 3v5h-5",
        sleep = "M18 5h4 M20 3v4 M20.985 12.486a9 9 0 1 1 -9.473 -9.472c0.405 -0.022 0.617 0.46 0.402 0.803"
            .. "a6 6 0 0 0 8.268 8.268c0.344 -0.215 0.825 -0.004 0.803 0.401",
        cpu = "M12 20v2 M12 2v2 M17 20v2 M17 2v2 M2 12h2 M2 17h2 M2 7h2 M20 12h2 M20 17h2 M20 7h2 M7 20v2 M7 2v2 "
            .. "M6 4h12a2 2 0 0 1 2 2v12a2 2 0 0 1 -2 2H6a2 2 0 0 1 -2 -2V6a2 2 0 0 1 2 -2z "
            .. "M9 8h6a1 1 0 0 1 1 1v6a1 1 0 0 1 -1 1H9a1 1 0 0 1 -1 -1V9a1 1 0 0 1 1 -1z",
        memory = "M6 19v-3 M10 19v-3 M14 19v-3 M18 19v-3 M8 11V9 M16 11V9 M12 11V9 M2 15h20 "
            .. "M2 7a2 2 0 0 1 2 -2h16a2 2 0 0 1 2 2v1.1a2 2 0 0 0 0 3.837V17a2 2 0 0 1 -2 2H4"
            .. "a2 2 0 0 1 -2 -2v-5.1a2 2 0 0 0 0 -3.837z",
        disk = "M22 12 L2 12 M5.45 5.11 L2 12v6a2 2 0 0 0 2 2h16a2 2 0 0 0 2 -2v-6l-3.45 -6.89"
            .. "A2 2 0 0 0 16.76 4H7.24a2 2 0 0 0 -1.79 1.11z",
    },
    -- Bluetooth device kinds (StatusGlyph.qml `devices`), keyed by OmniWM's BluetoothDevice.kind.
    devices = {
        headphones = "M3 14 h3 a2 2 0 0 1 2 2 v3 a2 2 0 0 1 -2 2 H5 a2 2 0 0 1 -2 -2 v-7 a9 9 0 0 1 18 0 v7 "
            .. "a2 2 0 0 1 -2 2 h-1 a2 2 0 0 1 -2 -2 v-3 a2 2 0 0 1 2 -2 h3",
        keyboard = "M4 4 h16 a2 2 0 0 1 2 2 v12 a2 2 0 0 1 -2 2 h-16 a2 2 0 0 1 -2 -2 v-12 a2 2 0 0 1 2 -2 z "
            .. "M7 16 h10",
        mouse = "M12 2 a7 7 0 0 1 7 7 v6 a7 7 0 0 1 -7 7 a7 7 0 0 1 -7 -7 v-6 a7 7 0 0 1 7 -7 z M12 6 v4",
        gamepad = "M6 11 L10 11 M8 9 L8 13 M17.32 5 H6.68 a4 4 0 0 0 -3.978 3.59 "
            .. "c-0.006 0.052 -0.01 0.101 -0.017 0.152 C2.604 9.416 2 14.456 2 16 a3 3 0 0 0 3 3 "
            .. "c1 0 1.5 -0.5 2 -1 l1.414 -1.414 A2 2 0 0 1 9.828 16 h4.344 a2 2 0 0 1 1.414 0.586 L17 18 "
            .. "c0.5 0.5 1 1 2 1 a3 3 0 0 0 3 -3 "
            .. "c0 -1.545 -0.604 -6.584 -0.685 -7.258 -0.007 -0.05 -0.011 -0.1 -0.017 -0.151 A4 4 0 0 0 17.32 5 z",
        computer = "M18 5 a2 2 0 0 1 2 2 v8.526 a2 2 0 0 0 0.212 0.897 l1.068 2.127 a1 1 0 0 1 -0.9 1.45 H3.62 "
            .. "a1 1 0 0 1 -0.9 -1.45 l1.068 -2.127 A2 2 0 0 0 4 15.526 V7 a2 2 0 0 1 2 -2 z M20.054 15.987 H3.946",
        phone = "M7 2 h10 a2 2 0 0 1 2 2 v16 a2 2 0 0 1 -2 2 h-10 a2 2 0 0 1 -2 -2 v-16 a2 2 0 0 1 2 -2 z",
    },
}
