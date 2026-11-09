-- Banff island root: the qs "notch" housing at the top of the main display.
-- At rest: weather · notifications · 12-hour clock · status ring in one black housing flush with the
-- top edge, square on top and rounded below. On a display with a camera notch the housing wraps the
-- notch, with weather, notifications and clock to its left and status to its right. Hover reveals
-- the date. Weather is the "weather" island component, so its location is edited in OmniWM's Island
-- settings. One panel opens inside the housing at a time: the month calendar (press on the housing)
-- or notifications (press on the notification circle). A new notification peeks under the row.

local calendar = require("../lib/banff/calendar")
local clock = require("../lib/banff/clock")
local notifications = require("../lib/banff/notifications")
local status = require("../lib/banff/status")
local theme = require("../lib/banff/theme")
local weather = require("../lib/banff/weather")

interval = 1

local WEATHER = "weather" -- component instance id in shell.toml
local MEDIA_DWELL = 2.5 -- seconds the circle shows the newest app after an arrival
local PEEK_DWELL = 5 -- seconds an arrival peeks, restarted while hovered

-- Whether the weather instance is enabled. Without component data (not documented for every
-- root context) it counts as enabled, so a missing feed shows the placeholder instead of nothing.
local function weatherEnabled(ctx): boolean
    local components = ctx.data.components
    if components == nil then
        return true
    end
    for _, component in components do
        if component.id == WEATHER then
            return component.enabled ~= false
        end
    end
    return false
end

local function time(ctx): (number?, number?)
    local seconds = ctx.data.seconds
    local hour = tonumber(ctx.format.date(seconds, "HH") or "")
    local minute = tonumber(ctx.format.date(seconds, "mm") or "")
    if hour == nil or minute == nil then
        return nil, nil
    end
    local settings = ctx.data.settings
    return clock.parts(hour, minute, settings ~= nil and settings.use24Hour == true)
end

local function dateText(ctx): string
    local seconds = ctx.data.seconds
    local fields = {}
    for _, template in { "EEE", "MMM", "d", "yyyy" } do
        fields[#fields + 1] = ctx.format.date(seconds, template) or ""
    end
    return table.concat(fields, " ")
end

-- Today's date from the seconds feed.
local function today(ctx)
    local seconds = ctx.data.seconds
    local year = tonumber(ctx.format.date(seconds, "yyyy") or "")
    local month = tonumber(ctx.format.date(seconds, "M") or "")
    local day = tonumber(ctx.format.date(seconds, "d") or "")
    if year == nil or month == nil or day == nil then
        return nil
    end
    return { year = year, month = month, day = day }
end

-- Runs `done` after `seconds`, replacing the timer stored in `state[field]`. False if refused.
local function arm(state, field: string, seconds: number, done: () -> ()): boolean
    if state[field] then
        state[field]:cancel()
    end
    local timer = omniwm.after(seconds, function()
        state[field] = nil
        done()
    end)
    state[field] = timer
    return timer ~= nil
end

local function endPeek(state)
    if state.peekHovered then
        if arm(state, "peekTimer", PEEK_DWELL, function()
            endPeek(state)
        end) then
            return
        end
    end
    state.peek = nil
end

-- New notifications (`fresh`, newest first, from notifications.track) are arrivals: the circle
-- shows the newest one's app for a moment, and it peeks under the row unless a panel is open
-- (qs NotificationCenter.reveal/peek).
local function observeArrivals(state, fresh: { string })
    local id = fresh[1]
    if id == nil then
        return
    end
    state.media = true
    if not arm(state, "mediaTimer", MEDIA_DWELL, function()
        state.media = false
    end) then
        state.media = false
    end
    if state.panel == nil then
        state.peek = id
        if not arm(state, "peekTimer", PEEK_DWELL, function()
            endPeek(state)
        end) then
            state.peek = nil
        end
    end
end

local function closePanels(state)
    state.panel = nil
    state.peek = nil
end

-- A press on the housing toggles the calendar (qs ClockWidget.toggleCalendar), replacing an open
-- notifications panel. Opening resets to the current month.
local function toggleCalendar(ctx)
    local state = ctx.state
    if state.panel == "calendar" then
        state.panel = nil
        return
    end
    local now = today(ctx)
    if now == nil then
        return
    end
    state.panel = "calendar"
    state.peek = nil
    state.viewYear, state.viewMonth, state.direction = now.year, now.month, 0
end

-- Opening also asks OmniWM to re-read Notification Center, which can lag behind on its own.
local function toggleNotifications(ctx)
    local state = ctx.state
    if state.panel == "notifications" then
        state.panel = nil
    elseif notifications.model(ctx.data).count > 0 then
        state.panel = "notifications"
        state.peek = nil
        omniwm.run("notifications refresh")
    end
end

local function shiftMonth(ctx, delta: number)
    local state = ctx.state
    if state.panel ~= "calendar" then
        return
    end
    state.viewYear, state.viewMonth = calendar.shift(state.viewYear, state.viewMonth, delta)
    state.direction = delta
end

function render(ctx)
    local island = ctx.data.island
    if island == nil then
        return ui.box({ w = 0, h = 0 })
    end
    local state = ctx.state
    state.metrics = state.metrics or clock.metrics(ctx)
    local m = state.metrics
    state.status = state.status or {}
    status.observe(ctx.data, state.status)

    local notes = notifications.model(ctx.data)
    observeArrivals(state, notifications.track(state, notes))
    if state.panel == "notifications" and notes.count == 0 then
        state.panel = nil
    end
    local peekItem = nil
    if state.peek then
        for _, item in notes.items do
            if item.id == state.peek then
                peekItem = item
            end
        end
        if peekItem == nil then
            state.peek = nil
        end
    end
    local panel = state.panel
    local hovered = state.hovered == true and panel == nil and peekItem == nil

    local notch = island.notch
    local height = math.max(theme.height, if notch then notch.h else 0)
    local weatherWidth = if weatherEnabled(ctx) then weather.width(ctx) else nil
    local badgeWidth = if notes.count > 0 then notifications.SLOT else nil
    local leadWidth = (weatherWidth or 0) + (badgeWidth or 0)
    local clockWidth = clock.width(m)
    local leftWidth = leadWidth + (if leadWidth > 0 then theme.gap else 0) + clockWidth
    local rightWidth = status.width(ctx, state.status)

    -- The resting row in envelope coordinates: where the left group starts, where status starts,
    -- and the centre an open panel hangs from.
    local leftStart, rightStart, centre
    if notch then
        leftStart = notch.x - theme.gap - leftWidth
        rightStart = notch.x + notch.w + theme.gap
        centre = notch.x + notch.w / 2
    else
        local rowWidth = leftWidth + theme.gap + rightWidth
        leftStart = (island.size.w - rowWidth) / 2
        rightStart = leftStart + leftWidth + theme.gap
        centre = island.size.w / 2
    end

    -- What hangs under the row, if anything: its width and height (gutter included).
    local hangWidth, hangHeight = 0, 0
    local hangElement = nil -- the notifications panel or peek, built once with its height
    if panel == "calendar" then
        local _, rows = calendar.grid(state.viewYear, state.viewMonth, nil)
        hangWidth, hangHeight = calendar.width, calendar.height(rows)
    elseif panel == "notifications" then
        local element, panelHeight = notifications.panel(ctx, notes)
        hangElement = element
        hangWidth, hangHeight = notifications.WIDTH, panelHeight
    elseif peekItem then
        local element, rowHeight = notifications.peek(ctx, notes, peekItem)
        hangElement = element
        hangWidth, hangHeight = notifications.WIDTH, rowHeight
    end

    -- The housing spans the row, and what hangs under it plus its gutter.
    local x = leftStart - theme.pad
    local right = rightStart + rightWidth + theme.pad
    local housingHeight = height
    if hangWidth > 0 then
        x = math.min(x, centre - hangWidth / 2 - theme.panelPad)
        right = math.max(right, centre + hangWidth / 2 + theme.panelPad)
        housingHeight += hangHeight + theme.panelPad
    elseif hovered then
        housingHeight += theme.dateRow
    end
    local width = right - x
    local radius = theme.height / 2

    local left = { key = "left", h = height, gap = 0, align = "topLeading", dx = leftStart - x, dy = 0,
        animate = theme.spring }
    if weatherWidth then
        left[#left + 1] = ui.component({ key = WEATHER, id = WEATHER, view = "compact", w = weatherWidth, h = height })
    end
    if badgeWidth then
        left[#left + 1] = notifications.badge(ctx, notes, panel == "notifications", state.media == true,
            toggleNotifications)
    end
    if leadWidth > 0 then
        left[#left + 1] = ui.box({ key = "leadGap", w = theme.gap, h = 1 })
    end
    local hour, minute = time(ctx)
    if hour ~= nil and minute ~= nil then
        left[#left + 1] = clock.render(hour, minute, m)
    else
        left[#left + 1] = ui.text({ key = "time", text = ctx.data.clock, font = theme.font, size = theme.digitSize,
            weight = "medium", color = theme.colors.text })
    end

    -- Presses on the housing toggle the calendar; the circle, arrows and panel claim their own.
    -- While a panel is open the housing holds keyboard focus and closes on an outside press.
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
        onClick = toggleCalendar,
        focusable = true,
        focusRing = false,
        keys = { "left", "right", "escape" },
        onKey = function(next, event)
            if event.key == "left" then
                shiftMonth(next, -1)
            elseif event.key == "right" then
                shiftMonth(next, 1)
            elseif event.key == "escape" then
                closePanels(next.state)
            end
        end,
        onOutsidePress = if panel ~= nil
            then function(next, event)
                if not event.claimed then
                    closePanels(next.state)
                end
            end
            else nil,
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
            dx = rightStart - x,
            dy = 0,
            animate = theme.spring,
            status.render(ctx, state.status),
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

    local hang = nil
    if panel == "calendar" then
        hang = { key = "calendarPanel",
            calendar.render(state.viewYear, state.viewMonth, today(ctx), state.direction or 0, shiftMonth) }
    elseif panel == "notifications" then
        hang = { key = "notificationsPanel", hangElement }
    elseif peekItem then
        hang = {
            key = "peekPanel",
            hoverGrace = 0.12,
            onHover = function(next, event)
                next.state.peekHovered = event.phase == "began"
            end,
            hangElement,
        }
    end
    if hang then
        hang.w = hangWidth
        hang.h = hangHeight
        hang.align = "topLeading"
        hang.dx = centre - hangWidth / 2 - x
        hang.dy = height
        hang.animate = theme.spring
        hang.appear = { opacity = 0, animate = theme.spring }
        hang.exit = { opacity = 0, animate = { duration = 0.12, curve = "easeOut" } }
        housing[#housing + 1] = ui.stack(hang)
    end

    return ui.stack({ key = "envelope", w = island.size.w, h = island.size.h, ui.stack(housing) })
end
