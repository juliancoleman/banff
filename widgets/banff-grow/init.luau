-- SPIKE ONLY (SPIKE.md checks 3–4). Delete after the spike.
-- A clock pill that grows inward from the screen edge on hover, plus a marker drawn
-- 80 pt outside its slot, to show whether bar-slot content is clipped.

local theme = require("../lib/banff/theme")

interval = 60

function render(ctx)
    local style = ctx.data.bar.style
    local vertical = style == nil or style.vertical
    local open = ctx.state.open == true
    local cross = if open then 160 else theme.pill
    local along = theme.pill

    local label = { gap = 2, center = true, ui.text({ text = ctx.data.clock, weight = "medium", color = "foreground" }) }
    if open then
        label[#label + 1] = ui.text({ text = ctx.data.date, size = 11, color = "secondaryForeground" })
    end

    return ui.stack({
        key = "grow-slot",
        ui.stack({
            key = "grow-pill",
            w = if vertical then cross else along * 2,
            h = if vertical then along else cross,
            radius = theme.pill / 2,
            fill = "elevatedSurface",
            border = "border",
            borderWidth = 1,
            animate = theme.hover,
            hoverDelay = 0.05,
            hoverGrace = 0.12,
            onHover = function(next, event)
                next.state.open = event.phase == "began"
            end,
            ui.column(label),
        }),
        ui.box({
            key = "overflow-marker",
            w = 12,
            h = 12,
            radius = 6,
            fill = "accent",
            dx = if vertical then -80 else 0,
            dy = if vertical then 0 else 80,
        }),
    })
end
