-- Geometry, motion and non-palette colour tokens from ~/code/qs (Common/Theme.qml, PLAN.md §4).
-- Palette roles (surface, accent, ...) live in themes/banff.toml; use role names for those.

return table.freeze({
    font = "IBM Plex Sans",

    -- Geometry (points)
    circle = 48,
    pill = 40,
    islandGap = 8,
    padX = 7,
    padY = 10,
    statusGap = 8,

    -- Colours without a palette role
    track = "#14181B",
    statusTrack = "#F2F0EA33",
    statusDim = "#F2F0EA4D",
    greenBlack = "#4C6455",
    blueBlack = "#3D566E",

    -- Motion: 220 ms workspace/clock transitions with light overshoot, 140 ms hover
    burst = table.freeze({ response = 0.22, bounce = 0.25 }),
    hover = table.freeze({ response = 0.14, bounce = 0.2 }),
    standard = table.freeze({ response = 0.2, bounce = 0 }),
    collapseDelay = 0.9,
})
