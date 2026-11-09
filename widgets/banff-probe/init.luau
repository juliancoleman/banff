-- SPIKE ONLY (SPIKE.md checks 2, 5–8). Delete after the spike.
-- Bar slot: a 48 pt circle. Click: popout listing display, workspace, notification and
-- weather facts; its button writes the same facts as JSON to the unified log.

local theme = require("../lib/banff/theme")

local function snapshot(data)
    local bar = data.bar
    local style = bar.style
    local barWorkspaces = {}
    for _, workspace in bar.workspaces do
        barWorkspaces[#barWorkspaces + 1] =
            { id = workspace.id, name = workspace.name, focused = workspace.focused, apps = #workspace.windows }
    end
    local workspaces = {}
    for _, workspace in data.workspaces do
        workspaces[#workspaces + 1] = {
            id = workspace.id,
            name = workspace.name,
            focused = workspace.focused,
            visible = workspace.visible,
            windows = workspace.windows,
        }
    end
    local notifications = data.notifications
    local weather = data.weather
    local weatherFacts = nil
    if weather and weather.access == "ok" then
        weatherFacts = {
            access = weather.access,
            place = weather.place,
            status = weather.status,
            unit = weather.unit,
            hours = #weather.hours,
            days = #weather.days,
            firstHourRain = weather.hours[1] and weather.hours[1].rain,
        }
    elseif weather then
        weatherFacts = { access = weather.access }
    end
    return {
        bar = {
            monitor = bar.monitor,
            monitorId = bar.monitorId,
            island = bar.island,
            position = style and style.position,
            height = style and style.height,
            vertical = style and style.vertical,
            fullWidth = style and style.fullWidth,
            transparent = style and style.transparent,
            hidesMenuBar = style and style.hidesMenuBar,
        },
        barWorkspaces = barWorkspaces,
        workspaces = workspaces,
        displays = data.system and data.system.displays,
        notifications = notifications and {
            state = notifications.state,
            items = #notifications.items,
            complete = notifications.complete,
            error = notifications.error,
        },
        weather = weatherFacts,
        appearance = data.appearance,
    }
end

local function encode(value)
    local text, err = json.encode(value)
    return text or ("<json error: " .. tostring(err) .. ">")
end

local function row(label, value)
    return ui.row({
        gap = 8,
        ui.text({ text = label, size = 12, weight = "semibold", color = "secondaryForeground" }),
        ui.text({ text = value, style = "mono", size = 11, color = "foreground", maxWidth = 440, lines = 6 }),
    })
end

function render(ctx)
    return ui.stack({
        key = "probe",
        w = theme.circle,
        h = theme.circle,
        radius = theme.circle / 2,
        fill = "elevatedSurface",
        border = "border",
        borderWidth = 1,
        help = "Banff probe",
        onClick = ui.popout,
        ui.symbol({ name = "stethoscope", size = 18, color = "accent" }),
    })
end

function popout(ctx)
    local facts = snapshot(ctx.data)
    return ui.column({
        w = 560,
        pad = 16,
        gap = 10,
        center = false,
        radius = 12,
        fill = "surface",
        border = "border",
        borderWidth = 1,
        ui.text({ text = "Banff probe", weight = "bold", color = "foreground" }),
        row("bar", encode(facts.bar)),
        row("bar.workspaces", encode(facts.barWorkspaces)),
        row("workspaces", encode(facts.workspaces)),
        row("displays", encode(facts.displays)),
        row("notifications", encode(facts.notifications)),
        row("weather", encode(facts.weather)),
        row("appearance", tostring(facts.appearance)),
        ui.stack({
            key = "log",
            pad = 8,
            radius = 8,
            fill = "elevatedSurface",
            hover = "foreground/0.08",
            onClick = function(next)
                omniwm.log("banff-probe " .. encode(snapshot(next.data)))
            end,
            ui.text({ text = "Write to log", size = 12, weight = "semibold", color = "accent" }),
        }),
    })
end
