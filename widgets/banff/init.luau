-- Banff island root: the qs "notch" housing at the top of the main display.
-- At rest: weather · notifications · 12-hour clock · status ring in one black housing flush with the
-- top edge, square on top and rounded below. On a display with a camera notch the housing wraps the
-- notch, with weather, notifications and clock to its left and status to its right. Hover reveals
-- the date. Weather is the "weather" island component, so its location is edited in OmniWM's Island
-- settings. One panel opens inside the housing at a time: the month calendar (press on the housing),
-- notifications (the notification circle), the control center (the status circle) or the forecast
-- (the weather). A new notification peeks under the row.

local calendar = require("../lib/banff/calendar")
local clock = require("../lib/banff/clock")
local control = require("../lib/banff/control")
local forecast = require("../lib/banff/forecast")
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

-- Banff's root options (widgets/banff/settings.toml), defaulting missing values.
type Options = { pill: boolean, shadow: boolean, use24: boolean, meridiem: boolean, always: boolean }

local function options(ctx): Options
    local settings = ctx.data.settings or {}
    local use24 = settings.use24Hour == true
    return {
        pill = settings.presentation == "pill",
        shadow = settings.shadow ~= false,
        use24 = use24,
        meridiem = settings.meridiem == true and not use24,
        always = settings.batteryPercentage == "always",
    }
end

-- Displayed hour and minute, and "A"/"P" when the AM/PM shows.
local function time(ctx, o: Options): (number?, number?, string?)
    local seconds = ctx.data.seconds
    local hour = tonumber(ctx.format.date(seconds, "HH") or "")
    local minute = tonumber(ctx.format.date(seconds, "mm") or "")
    if hour == nil or minute == nil then
        return nil, nil, nil
    end
    local shownHour, shownMinute = clock.parts(hour, minute, o.use24)
    return shownHour, shownMinute, if o.meridiem then (if hour < 12 then "A" else "P") else nil
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

-- The status circle toggles the control center, which opens on its home page.
local function toggleControl(ctx)
    local state = ctx.state
    if state.panel == "control" then
        state.panel = nil
        return
    end
    state.panel = "control"
    state.peek = nil
    state.controlPage, state.controlDirection, state.armed = nil, 0, nil
end

-- The weather slot toggles the forecast, when the feed has one.
local function toggleWeather(ctx)
    local state = ctx.state
    if state.panel == "weather" then
        state.panel = nil
        return
    end
    local w = ctx.data.weather
    if w ~= nil and w.access == "ok" then
        state.panel = "weather"
        state.peek = nil
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

-- Pieces shared by both presentations ------------------------------------------------------------

local KEYS = { "left", "right", "escape" }

local function onKey(next, event)
    if event.key == "left" then
        shiftMonth(next, -1)
    elseif event.key == "right" then
        shiftMonth(next, 1)
    elseif event.key == "escape" then
        if next.state.panel ~= "control" or not control.back(next.state) then
            closePanels(next.state)
        end
    end
end

local function onOutsidePress(next, event)
    if not event.claimed then
        closePanels(next.state)
    end
end

local function surface(key: string, w: number, h: number, radius: number, o: Options)
    return ui.box({
        key = key,
        w = w,
        h = h,
        radius = radius,
        fill = theme.colors.surface,
        shadow = if o.shadow then theme.colors.shadow else nil,
        shadowRadius = if o.shadow then theme.shadowRadius else nil,
        shadowOffset = if o.shadow then theme.shadowOffset else nil,
        animate = theme.spring,
    })
end

local function closeMark(z)
    local size = z.statusGlyph
    return ui.stack({ key = "close", w = size + 4, h = size + 4,
        ui.path({ key = "x", w = size, h = size, viewBox = { 0, 0, 24, 24 }, d = "M18 6 L6 18 M6 6 L18 18",
            border = theme.colors.text, borderWidth = 2 * size / 24 }) })
end

-- The weather slot: the component's compact view, or an X while the forecast is open.
local function weatherSlot(z, w: number, h: number, open: boolean)
    local content = if open
        then closeMark(z)
        else ui.component({ key = WEATHER, id = WEATHER, view = "compact", w = w, h = h, props = { size = z.name } })
    return ui.stack({ key = "weatherSlot", w = w, h = h, cursor = "pointer",
        help = if open then "Close weather" else nil, onClick = toggleWeather, content })
end

local function statusSlot(ctx, z, o: Options, w: number, h: number, open: boolean)
    return ui.box({
        key = "statusSlot",
        w = w,
        h = h,
        cursor = "pointer",
        help = if open then "Close control center" else "Control center",
        onClick = toggleControl,
        status.render(ctx, ctx.state.status, z, o.always, open),
    })
end

local function timeElement(ctx, z, m, hour: number?, minute: number?, meridiem: string?)
    if hour ~= nil and minute ~= nil then
        return clock.render(hour, minute, m, z, meridiem)
    end
    return ui.text({ key = "time", text = ctx.data.clock, font = theme.font, size = z.digit, weight = "medium",
        color = theme.colors.text })
end

-- The hovered date, centred across `w` (a row with growing spacers on both sides; a plain box lays
-- its child out from the leading edge).
local function dateRow(ctx, w: number, dy: number)
    return ui.row({
        key = "date",
        w = w,
        h = theme.dateRow,
        gap = 0,
        align = "topLeading",
        dx = 0,
        dy = dy,
        appear = { opacity = 0, dy = -4, animate = theme.spring },
        exit = { opacity = 0, animate = theme.fade },
        ui.box({ grow = 1, h = 1 }),
        ui.text({ text = dateText(ctx), font = theme.font, size = theme.dateSize, weight = "medium",
            color = theme.colors.textSecondary }),
        ui.box({ grow = 1, h = 1 }),
    })
end

-- What hangs under the row for the open panel or a peeking notification: a stack spec (key and
-- child, positioned by `placeHang`), its width and its height. Nil when nothing hangs.
local function hangFor(ctx, panel: string?, notes, peekItem)
    local state = ctx.state
    if panel == "calendar" then
        local _, rows = calendar.grid(state.viewYear, state.viewMonth, nil)
        return { key = "calendarPanel",
            calendar.render(state.viewYear, state.viewMonth, today(ctx), state.direction or 0, shiftMonth) },
            calendar.width, calendar.height(rows)
    elseif panel == "notifications" then
        local element, height = notifications.panel(ctx, notes)
        return { key = "notificationsPanel", element }, notifications.WIDTH, height
    elseif panel == "control" then
        local element, height = control.panel(ctx)
        return { key = "controlPanel", element }, control.WIDTH, height
    elseif panel == "weather" then
        local element, height = forecast.panel(ctx)
        if element then
            return { key = "weatherPanel", element }, forecast.WIDTH, height
        end
    elseif peekItem then
        local element, height = notifications.peek(ctx, notes, peekItem)
        return {
            key = "peekPanel",
            hoverGrace = 0.12,
            onHover = function(next, event)
                next.state.peekHovered = event.phase == "began"
            end,
            element,
        }, notifications.WIDTH, height
    end
    return nil, 0, 0
end

local function placeHang(hang, w: number, h: number, dx: number, dy: number)
    hang.w = w
    hang.h = h
    hang.align = "topLeading"
    hang.dx = dx
    hang.dy = dy
    hang.animate = theme.spring
    hang.appear = { opacity = 0, animate = theme.spring }
    hang.exit = { opacity = 0, animate = { duration = 0.12, curve = "easeOut" } }
    return ui.stack(hang)
end

-- Notch: one housing flush with the top edge ------------------------------------------------------

local function renderNotch(ctx, o: Options, f)
    local island, state, panel, notes = f.island, ctx.state, f.panel, f.notes
    local z = theme.sizes.notch
    local m = f.metrics(z)
    local notch = island.notch
    local height = math.max(z.height, if notch then notch.h else 0)
    local weatherWidth = if f.weather then weather.width(ctx, z) else nil
    local badgeWidth = if notes.count > 0 then z.badge else nil
    local leadWidth = (weatherWidth or 0) + (badgeWidth or 0)
    local clockWidth = clock.width(m, f.meridiem)
    local leftWidth = leadWidth + (if leadWidth > 0 then z.gap else 0) + clockWidth
    local rightWidth = status.width(ctx, state.status, z, o.always, panel == "control")

    -- The resting row in envelope coordinates: where the left group starts, where status starts,
    -- and the centre an open panel hangs from.
    local leftStart, rightStart, centre
    if notch then
        leftStart = notch.x - z.gap - leftWidth
        rightStart = notch.x + notch.w + z.gap
        centre = notch.x + notch.w / 2
    else
        local rowWidth = leftWidth + z.gap + rightWidth
        leftStart = (island.size.w - rowWidth) / 2
        rightStart = leftStart + leftWidth + z.gap
        centre = island.size.w / 2
    end

    -- The housing spans the row, and what hangs under it plus its gutter.
    local hangWidth, hangHeight = f.hangWidth, f.hangHeight
    local x = leftStart - z.pad
    local right = rightStart + rightWidth + z.pad
    local housingHeight = height
    if f.hang then
        x = math.min(x, centre - hangWidth / 2 - theme.panelPad)
        right = math.max(right, centre + hangWidth / 2 + theme.panelPad)
        housingHeight += hangHeight + theme.panelPad
    elseif f.hovered then
        housingHeight += theme.dateRow
    end
    local width = right - x
    local radius = z.height / 2

    local left = { key = "left", h = height, gap = 0, align = "topLeading", dx = leftStart - x, dy = 0,
        animate = theme.spring }
    if weatherWidth then
        left[#left + 1] = weatherSlot(z, weatherWidth, height, panel == "weather")
    end
    if badgeWidth then
        left[#left + 1] = notifications.badge(ctx, notes, panel == "notifications", state.media == true,
            toggleNotifications, z)
    end
    if leadWidth > 0 then
        left[#left + 1] = ui.box({ key = "leadGap", w = z.gap, h = 1 })
    end
    left[#left + 1] = f.time(z, m)

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
        keys = KEYS,
        onKey = onKey,
        onOutsidePress = if panel ~= nil then onOutsidePress else nil,
        surface("body", width, housingHeight, radius, o),
        -- Squares the top corners against the screen edge.
        ui.box({ key = "top", w = width, h = radius, align = "top", fill = theme.colors.surface, animate = theme.spring }),
        ui.row(left),
        ui.stack({ key = "statusPlace", w = rightWidth, h = height, align = "topLeading", dx = rightStart - x, dy = 0,
            animate = theme.spring, statusSlot(ctx, z, o, rightWidth, height, panel == "control") }),
    }
    if f.hovered then
        housing[#housing + 1] = dateRow(ctx, width, height - 1)
    end
    if f.hang then
        housing[#housing + 1] = placeHang(f.hang, hangWidth, hangHeight, centre - hangWidth / 2 - x, height)
    end
    return ui.stack(housing)
end

-- Pill: separate capsules below the top edge -------------------------------------------------------

-- qs pill presentation: weather, notifications, clock and status as capsules 8 pt apart and 8 pt
-- below the top edge (beside the notch when there is one). An open panel grows its own capsule into
-- a card: notifications and weather extend left from their capsule's right edge, the control center
-- right from its left edge, and the calendar and hovered date grow the clock capsule around its
-- centre. The capsule's content keeps its place in the card's top row, as the X that closes it. The
-- weather capsule yields while notifications show, since their card covers it.
local function renderPill(ctx, o: Options, f)
    local island, state, panel, notes = f.island, ctx.state, f.panel, f.notes
    local z = theme.sizes.pill
    local m = f.metrics(z)
    local notch = island.notch
    local envelopeWidth = island.size.w
    local h = z.height
    local top = theme.floatMargin

    -- Which capsule grows, and how.
    local owner, anchor = nil, nil
    if panel == "calendar" or (panel == nil and f.hovered) then
        owner, anchor = "clock", "centre"
    elseif panel == "notifications" or (panel == nil and f.hang ~= nil) then
        owner, anchor = "badge", "right"
    elseif panel == "weather" then
        owner, anchor = "weather", "right"
    elseif panel == "control" then
        owner, anchor = "status", "left"
    end

    local weatherWidth = if f.weather then weather.width(ctx, z) else nil
    local badgeWidth = if notes.count > 0 then z.badge else nil
    local clockWidth = clock.width(m, f.meridiem) + 2 * z.pad
    local statusWidth = status.width(ctx, state.status, z, o.always, panel == "control")
    -- The clock capsule's outer width: as qs places its neighbours from the clock's edges, they move
    -- aside while the calendar or date widens it.
    local clockOuter = clockWidth
    if owner == "clock" then
        clockOuter = math.max(clockWidth,
            if f.hang then f.hangWidth + 2 * theme.panelPad else f.dateWidth + 2 * z.pad)
    end

    local clockLeft, statusX
    if notch then
        clockLeft = notch.x - z.gap - clockOuter
        statusX = notch.x + notch.w + z.gap
    else
        -- The resting row is centred; the clock keeps its resting centre as it widens.
        local leftWidth = clockWidth + (if weatherWidth then weatherWidth + z.gap else 0)
            + (if badgeWidth then badgeWidth + z.gap else 0)
        local restLeft = (envelopeWidth - (leftWidth + z.gap + statusWidth)) / 2
        local clockCentre = restLeft + leftWidth - clockWidth / 2
        clockLeft = clockCentre - clockOuter / 2
        statusX = clockLeft + clockOuter + z.gap
    end
    local clockX = clockLeft + (clockOuter - clockWidth) / 2
    local cursor = clockLeft
    local weatherX, badgeX
    if badgeWidth then
        badgeX = cursor - z.gap - badgeWidth
        cursor = badgeX
    end
    if weatherWidth then
        weatherX = cursor - z.gap - weatherWidth
    end

    local function capsule(key: string, px: number, pw: number, content, handlers)
        local cardX, cardW, cardH, radius = px, pw, h, h / 2
        local extra = nil
        if owner == key then
            if f.hang then
                cardW = math.max(pw, f.hangWidth + 2 * theme.panelPad)
                cardH = h + f.hangHeight + theme.panelPad
                radius = theme.cardRadius
            else -- the hovered date
                cardW = math.max(pw, f.dateWidth + 2 * z.pad)
                cardH = h + theme.dateRow
            end
            cardX = if anchor == "right" then px + pw - cardW elseif anchor == "left" then px else px + (pw - cardW) / 2
            cardX = math.clamp(cardX, 0, math.max(0, envelopeWidth - cardW))
            extra = if f.hang
                then placeHang(f.hang, f.hangWidth, f.hangHeight, (cardW - f.hangWidth) / 2, h)
                else dateRow(ctx, cardW, h - 1)
        end
        local spec = handlers or {}
        spec.key = key
        spec.w = cardW
        spec.h = cardH
        spec.align = "topLeading"
        spec.dx = cardX
        spec.dy = top
        spec.animate = theme.spring
        spec.focusable = true
        spec.focusRing = false
        spec.keys = KEYS
        spec.onKey = onKey
        spec.onOutsidePress = if owner == key and panel ~= nil then onOutsidePress else nil
        spec.appear = { opacity = 0, scale = 0.8, animate = theme.spring }
        spec.exit = { opacity = 0, scale = 0.8, animate = theme.fade }
        spec[#spec + 1] = surface("body", cardW, cardH, radius, o)
        spec[#spec + 1] = ui.stack({ key = "content", w = pw, h = h, align = "topLeading", dx = px - cardX, dy = 0,
            animate = theme.spring, content })
        if extra then
            spec[#spec + 1] = extra
        end
        return ui.stack(spec)
    end

    -- Presses on a card's gutter are absorbed rather than reaching the window beneath.
    local function absorb() end
    local pieces = {}
    if weatherWidth and not (owner == "badge") then
        pieces.weather = capsule("weather", weatherX, weatherWidth,
            weatherSlot(z, weatherWidth, h, panel == "weather"), { onClick = absorb })
    end
    if badgeWidth then
        pieces.badge = capsule("badge", badgeX, badgeWidth,
            notifications.badge(ctx, notes, panel == "notifications", state.media == true, toggleNotifications, z),
            { onClick = absorb })
    end
    pieces.clock = capsule("clock", clockX, clockWidth,
        ui.row({ key = "face", w = clockWidth, h = h, gap = 0, ui.box({ w = z.pad, h = 1 }), f.time(z, m) }), {
            onClick = toggleCalendar,
            hoverGrace = 0.12,
            onHover = function(next, event)
                next.state.hovered = event.phase == "began"
            end,
        })
    pieces.status = capsule("status", statusX, statusWidth, statusSlot(ctx, z, o, statusWidth, h, panel == "control"),
        { onClick = absorb })

    -- The growing capsule draws last, over its neighbours.
    local envelope = { key = "pills", w = envelopeWidth, h = island.size.h }
    for _, key in { "weather", "badge", "clock", "status" } do
        if pieces[key] and key ~= owner then
            envelope[#envelope + 1] = pieces[key]
        end
    end
    if owner and pieces[owner] then
        envelope[#envelope + 1] = pieces[owner]
    end
    return ui.stack(envelope)
end

function render(ctx)
    local island = ctx.data.island
    if island == nil then
        return ui.box({ w = 0, h = 0 })
    end
    local state = ctx.state
    local o = options(ctx)
    state.metrics = state.metrics or {}
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

    local hang, hangWidth, hangHeight = hangFor(ctx, state.panel, notes, peekItem)
    if state.panel == "weather" and hang == nil then
        state.panel = nil -- the forecast went away
    end
    local panel = state.panel
    local hovered = state.hovered == true and panel == nil and peekItem == nil
    local hour, minute, meridiem = time(ctx, o)

    local facts = {
        island = island,
        panel = panel,
        notes = notes,
        hovered = hovered,
        weather = weatherEnabled(ctx),
        meridiem = meridiem,
        hang = hang,
        hangWidth = hangWidth,
        hangHeight = hangHeight,
        dateWidth = if hovered
            then math.ceil((ctx.format.measure(dateText(ctx), { font = theme.font, size = theme.dateSize,
                weight = "medium" })))
            else 0,
        metrics = function(z)
            state.metrics[z.name] = state.metrics[z.name] or clock.metrics(ctx, z)
            return state.metrics[z.name]
        end,
        time = function(z, m)
            return timeElement(ctx, z, m, hour, minute, meridiem)
        end,
    }
    local content = if o.pill then renderPill(ctx, o, facts) else renderNotch(ctx, o, facts)
    return ui.stack({ key = "envelope", w = island.size.w, h = island.size.h, content })
end
