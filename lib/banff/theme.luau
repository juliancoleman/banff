-- Tokens from the live qs shell (~/dotfiles/qs qml/shell/Common/Theme.qml, pens/dark) and
-- ~/.config/qs/config.json (clock.duration 250, clock.springOvershoot 0.6). Resting sizes for the
-- notch and pill presentations are in `sizes`. Palette roles live in themes/banff.toml; the
-- colours here have no role.

return {
    font = "IBM Plex Sans",
    -- Resting row text (time, AM/PM, temperature, battery percentage, date, notification count):
    -- one step lighter than qs's Medium/DemiBold, at the user's request.
    faceWeight = "regular",
    faceStrong = "medium",

    colors = {
        surface = "#000000",
        text = "#F2F0EA", -- paper
        textSecondary = "#AEB5B9", -- pencil
        statusTrack = "#F2F0EB33", -- paper at 0.2
        statusDim = "#F2F0EB4D", -- paper at 0.3
        charging = "#7E9C88", -- green-black light
        dangerMark = "#7A2536", -- Qt.lighter(bordeaux #4C1722, 1.6)
        shadow = "#00000073", -- black at 0.45
        rule = "#D1DBE024", -- rgba(0.82, 0.86, 0.88, 0.14)
        lift = "#FFFFFF0D", -- hover: white at 0.05
        press = "#FFFFFF1A", -- press: white at 0.10
        today = "#8AA5C0", -- blue-black light
        todayInk = "#111922", -- text on `today`
        track = "#14181B", -- notification circle face
        stroke = "#D1DBE03D", -- rgba(0.82, 0.86, 0.88, 0.24): outlined knobs
        danger = "#4C1722", -- bordeaux: armed power actions
    },

    shadowRadius = 12,
    shadowOffset = { x = 0, y = 4 },
    panelPad = 12, -- gutter around an open panel
    floatMargin = 8, -- pill mode: gap from the screen's top edge
    cardRadius = 12, -- pill mode: corners of an open panel card
    periodGap = 4, -- between the minutes and AM/PM
    dateSize = 10,
    dateRow = 18, -- extra housing height while hovering

    -- Resting sizes for each presentation (qs ClockWidget/HorizontalFace/StatusIndicator/
    -- WeatherCircle/NotificationCenter with notchAmount 1 or 0). Notch: one housing flush with the
    -- top edge, 27 pt thick (time box 20 + outer pad 3 + inner pad 4). Pill: separate capsules 34 pt
    -- tall (time box 20 + padX 7 twice), 8 pt apart and 8 pt below the top edge.
    sizes = {
        notch = {
            name = "notch",
            height = 27,
            digit = 13,
            period = 13,
            digitBox = 20,
            pad = 6, -- housing end padding
            gap = 10, -- between weather, clock and status (padX + 3)
            weatherInset = 4,
            weatherIcon = 14,
            weatherIconGap = 5,
            badge = 27,
            badgeFace = 19,
            bell = 14,
            status = 27,
            statusRoom = 4,
            statusStroke = 1.9,
            statusGlyph = 12,
            batteryLabel = 13, -- beside the ring
        },
        pill = {
            name = "pill",
            height = 34,
            digit = 15,
            period = 10,
            digitBox = 20,
            pad = 10, -- clock capsule end padding
            gap = 8, -- between capsules (statusGap)
            weatherInset = 10,
            weatherIcon = 17,
            weatherIconGap = 5,
            badge = 34,
            badgeFace = 26,
            bell = 17,
            status = 34,
            statusRoom = 3,
            statusStroke = 1.4,
            statusGlyph = 15,
            batteryLabel = 9, -- inside the ring, on its bottom edge
        },
    },

    -- Motion: 250 ms with a light OutBack overshoot (0.6)
    spring = { response = 0.25, bounce = 0.15 },
    roll = { response = 0.25, bounce = 0.2 },
    fade = { duration = 0.25, curve = "easeInOut" },
}
