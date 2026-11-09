-- Tokens from the live qs shell (~/dotfiles/qs qml/shell/Common/Theme.qml, pens/dark) and
-- ~/.config/qs/config.json (clock.duration 250, clock.springOvershoot 0.6). Values are for the
-- docked "notch" presentation at the top edge. Palette roles live in themes/banff.toml; the colours
-- here have no role.

return {
    font = "IBM Plex Sans",

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
    },

    -- Housing (points)
    height = 27, -- resting thickness: time box 20 + outer pad 3 + inner pad 4
    pad = 6, -- housing end padding
    gap = 10, -- between weather, clock and status (padX + 3)
    shadowRadius = 12,
    shadowOffset = { x = 0, y = 4 },
    panelPad = 12, -- gutter around an open panel

    -- Clock
    digitSize = 13,
    digitBox = 20,
    dateSize = 10,
    dateRow = 18, -- extra housing height while hovering

    -- Weather (compact)
    weatherInset = 4,
    weatherIcon = 14,
    weatherIconGap = 5,

    -- Status circle
    status = 27,
    statusRoom = 4,
    statusStroke = 1.9,
    statusGlyph = 12,

    -- Motion: 250 ms with a light OutBack overshoot (0.6)
    spring = { response = 0.25, bounce = 0.15 },
    roll = { response = 0.25, bounce = 0.2 },
    fade = { duration = 0.25, curve = "easeInOut" },
}
