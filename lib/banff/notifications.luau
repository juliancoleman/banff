-- The qs notification circle and panel (Notifications/NotificationCenter.qml, NotificationRow.qml),
-- fed by OmniWM's read-only copy of Notification Center (ctx.data.notifications, Full Disk Access).
-- In the row, the circle sits between weather and the time: a disc (19 pt docked, 26 pt as a pill)
-- with a bell and a count pill. Its panel opens under the time row; rows dismiss through Notification
-- Center (Accessibility). Focus/Do Not Disturb stays native: OmniWM exposes no Focus state.

local theme = require("./theme")

local WIDTH = 298 -- panel width
local LIST_MAX = 330
local HEADER = 27
local HEADER_GAP = 2
local NOTE = 16
local INSET = 10
local KNOB = 30
local KNOB_INSET = 7
local TEXT_X = KNOB_INSET + KNOB + 9
local TEXT_WIDTH = WIDTH - TEXT_X - 34
local BODY_LINES = 3
local MAX_ROWS = 50 -- rows drawn; the rest are counted in a footer
local MORE = 24 -- footer height

local BELL = "M10.268 21a2 2 0 0 0 3.464 0 M3.262 15.326A1 1 0 0 0 4 17h16a1 1 0 0 0 0.74 -1.673"
    .. "C19.41 13.956 18 12.499 18 8A6 6 0 0 0 6 8c0 4.499 -1.411 5.956 -2.738 7.326z"
local CLOSE = "M18 6 L6 18 M6 6 L18 18"

local function glyph(key: string, d: string, size: number, color: string)
    return ui.path({ key = key, w = size, h = size, viewBox = { 0, 0, 24, 24 }, d = d, border = color,
        borderWidth = 2 * size / 24 })
end

local function textWidth(ctx, text: string, size: number, weight: string): number
    return math.ceil((ctx.format.measure(text, { font = theme.font, size = size, weight = weight })))
end

type Model = {
    loaded: boolean,
    items: { any },
    count: number,
    names: { [string]: string },
    canDismiss: boolean,
    clearing: boolean,
    action: any,
    dismissAll: any,
}

-- Visible notifications (newest first, without ones already sent for dismissal) and what the panel
-- may do with them.
local function model(data): Model
    local feed = data.notifications
    local result: Model = { loaded = false, items = {}, count = 0, names = {}, canDismiss = false, clearing = false,
        action = nil, dismissAll = nil }
    if feed == nil or (feed.state ~= "ready" and feed.state ~= "incomplete" and feed.state ~= "empty") then
        return result
    end
    result.loaded = true
    local dispatched = {}
    for _, id in feed.dispatched or {} do
        dispatched[id] = true
    end
    for _, item in feed.items or {} do
        if not dispatched[item.id] then
            result.items[#result.items + 1] = item
        end
    end
    for _, app in feed.apps or {} do
        if app.name then
            result.names[app.bundle] = app.name
        end
    end
    result.count = #result.items
    result.canDismiss = feed.membershipComplete == true
    result.clearing = feed.dismissAll ~= nil and feed.dismissAll.active == true
    result.action = feed.action
    result.dismissAll = feed.dismissAll
    return result
end

-- The circle at size set `z`: bell (or the newest app's icon for a moment after an arrival) and a
-- count pill; an X while the panel is open.
local function badge(ctx, m: Model, open: boolean, media: boolean, onClick, z)
    local faceSize = z.badgeFace
    local face = { key = "face", w = faceSize, h = faceSize, radius = faceSize / 2, fill = theme.colors.track }
    if open then
        face[1] = glyph("close", CLOSE, z.statusGlyph, theme.colors.text)
    elseif media and m.items[1] then
        face[1] = ui.icon({ key = "media", app = m.items[1].bundle, w = faceSize, h = faceSize, radius = faceSize / 2,
            placeholder = "bell", appear = { opacity = 0, animate = theme.fade }, exit = { opacity = 0, animate = theme.fade } })
    else
        face[1] = glyph("bell", BELL, z.bell, theme.colors.text)
    end
    local children = {
        key = "badge",
        w = z.badge,
        h = z.badge,
        cursor = "pointer",
        help = if m.count == 1 then "1 notification" else m.count .. " notifications",
        onClick = onClick,
        appear = { opacity = 0, scale = 0.6, animate = theme.spring },
        exit = { opacity = 0, scale = 0.6, animate = theme.fade },
        ui.stack(face),
    }
    if not open then
        local text = if m.count > 99 then "99+" else tostring(m.count)
        children[#children + 1] = ui.stack({
            key = "pill",
            h = 13,
            w = math.max(13, textWidth(ctx, text, 9, "semibold") + 6),
            radius = 6.5,
            align = "topTrailing",
            dx = -1,
            dy = 1,
            fill = theme.colors.today,
            appear = { opacity = 0, animate = theme.fade },
            exit = { opacity = 0, animate = theme.fade },
            ui.text({ text = text, font = theme.font, size = 9, weight = "semibold", color = theme.colors.todayInk }),
        })
    end
    return ui.stack(children)
end

local function bodyText(item): string
    local parts = {}
    if item.subtitle and item.subtitle ~= "" then
        parts[#parts + 1] = item.subtitle
    end
    if item.body and item.body ~= "" then
        parts[#parts + 1] = item.body
    end
    return table.concat(parts, "\n")
end

local function bodyStyle(lines: number)
    return { font = theme.font, size = 11, weight = "regular", maxWidth = TEXT_WIDTH, lines = lines }
end

-- Row layout facts: body lines shown, whether it is cut, and the row height. Text measurement is the
-- expensive part of a render, and a notification's text never changes, so layouts are cached in
-- `ctx.state` by id and expansion. The cache is dropped when it outgrows the retained list.
local function rowLayout(ctx, item, expanded: boolean)
    local cache = ctx.state.noteLayouts
    if cache == nil or cache.size > 600 then
        cache = { size = 0, entries = {} }
        ctx.state.noteLayouts = cache
    end
    local key = if expanded then item.id .. ":expanded" else item.id
    local cached = cache.entries[key]
    if cached then
        return cached
    end
    local body = bodyText(item)
    local lines = if expanded then 100 else BODY_LINES
    local bodyHeight, truncated = 0, false
    if body ~= "" then
        local _, shown = ctx.format.measure(body, bodyStyle(lines))
        local _, full = ctx.format.measure(body, bodyStyle(100))
        bodyHeight = shown
        truncated = full > shown + 1
    end
    local height = 13 + 2 + 16 -- app name, gap, summary
    if body ~= "" then
        height += 2 + bodyHeight
    end
    if truncated or expanded then
        height += 2 + 13
    end
    local layout = {
        body = body,
        lines = lines,
        truncated = truncated,
        height = math.max(height + 2 * INSET, KNOB + 2 * KNOB_INSET),
    }
    cache.entries[key] = layout
    cache.size += 1
    return layout
end

-- One notification. `bare` drops the hover box and rule (the arrival peek).
local function row(ctx, m: Model, item, index: number, bare: boolean)
    local expandedSet = ctx.state.expandedNotes or {}
    local expanded = expandedSet[item.id] == true
    local layout = rowLayout(ctx, item, expanded)
    local name = m.names[item.bundle] or item.bundle
    local column = {
        key = "text",
        w = TEXT_WIDTH,
        gap = 2,
        center = false,
        align = "topLeading",
        dx = TEXT_X,
        dy = INSET,
        ui.text({ key = "app", text = name, font = theme.font, size = 10, weight = "medium",
            color = theme.colors.textSecondary, maxWidth = TEXT_WIDTH }),
        ui.text({ key = "summary", text = if item.title ~= "" then item.title else name, font = theme.font, size = 12,
            weight = "medium", color = theme.colors.text, maxWidth = TEXT_WIDTH }),
    }
    if layout.body ~= "" then
        column[#column + 1] = ui.text({ key = "body", text = layout.body, font = theme.font, size = 11,
            weight = "regular", color = theme.colors.textSecondary, maxWidth = TEXT_WIDTH, lines = layout.lines })
    end
    if layout.truncated or expanded then
        column[#column + 1] = ui.stack({
            key = "more",
            cursor = "pointer",
            onClick = function(next)
                local set = next.state.expandedNotes or {}
                set[item.id] = if set[item.id] then nil else true
                next.state.expandedNotes = set
            end,
            ui.text({ text = if expanded then "Show less" else "Show more", font = theme.font, size = 10,
                weight = "medium", color = theme.colors.today }),
        })
    end

    local children = {
        key = "n:" .. item.id,
        w = WIDTH,
        h = layout.height,
        radius = 6,
        animate = theme.spring,
        appear = { opacity = 0, animate = theme.fade },
        exit = { opacity = 0, animate = theme.fade },
    }
    if item.actionsSupported then
        -- Clicking acts on the notification like qs's default action: dismiss it and open its app.
        local canDismiss = m.canDismiss
        children.cursor = "pointer"
        children.onClick = function(next)
            if canDismiss then
                omniwm.run("notifications dismiss " .. item.bundle .. " " .. item.id)
            end
            omniwm.run("notifications open " .. item.bundle)
            if bare then
                next.state.peek = nil
            end
        end
        if not bare then
            children.hover = theme.colors.lift
            children.pressFill = theme.colors.press
        end
    end
    if index > 1 and not bare then
        children[#children + 1] = ui.box({ key = "rule", w = WIDTH, h = 1, align = "top", fill = theme.colors.rule })
    end
    children[#children + 1] = ui.icon({ key = "icon", app = item.bundle, w = KNOB, h = KNOB, radius = KNOB / 2,
        placeholder = "bell", align = "topLeading", dx = KNOB_INSET, dy = KNOB_INSET })
    children[#children + 1] = ui.column(column)
    if item.actionsSupported and m.canDismiss then
        children[#children + 1] = ui.stack({
            key = "dismiss",
            w = 22,
            h = 22,
            radius = 11,
            align = "topTrailing",
            dx = -6,
            dy = 6,
            opacity = 0.55,
            hoverOpacity = 1,
            hover = theme.colors.lift,
            pressFill = theme.colors.press,
            cursor = "pointer",
            help = "Dismiss",
            onClick = "notifications dismiss " .. item.bundle .. " " .. item.id,
            glyph("x", CLOSE, 12, theme.colors.text),
        })
    end
    return ui.stack(children), layout.height
end

-- Outcomes of a dismiss (`action.state`) or of Clear all (`dismissAll.outcome`) worth a note.
-- "unavailable" means OmniWM could not reach Notification Center's own controls: it dismisses by
-- opening Notification Center from the menu bar clock through Accessibility.
local MESSAGES = {
    denied = "Allow OmniWM in Accessibility settings to dismiss notifications.",
    dispatchedPanelOpen = "Close Notification Center to finish.",
    failedPanelOpen = "Close Notification Center, then try again.",
    failed = "Notification Center did not dismiss it.",
    timeout = "Notification Center did not respond.",
    unavailable = "OmniWM could not reach Notification Center to dismiss.",
    ambiguous = "Notification Center's list did not match; try again.",
    notFound = "Notification Center no longer has that notification.",
}

local function message(m: Model): string?
    local batch = m.dismissAll
    if batch and (batch.state == "failed" or batch.state == "partial") then
        if batch.state == "partial" then
            return batch.failed .. " of " .. batch.total .. " notifications stayed in Notification Center."
        end
        return MESSAGES[batch.outcome or "failed"] or MESSAGES.failed
    end
    return if m.action then MESSAGES[m.action.state] else nil
end

-- The rows the panel draws: the newest MAX_ROWS (Notification Center may retain up to 256), their
-- total height, and how many are left out.
local function listRows(ctx, m: Model): ({ any }, number, number)
    local rows, total = {}, 0
    local expandedSet = ctx.state.expandedNotes or {}
    for index, item in m.items do
        if index > MAX_ROWS then
            break
        end
        rows[index] = item
        total += rowLayout(ctx, item, expandedSet[item.id] == true).height
    end
    local hidden = m.count - #rows
    if hidden > 0 then
        total += MORE
    end
    return rows, total, hidden
end

local function clearButton(ctx, m: Model)
    local label = if m.clearing then "Clearing…" else "Clear all"
    local enabled = m.canDismiss and not m.clearing
    local props = {
        key = "clear",
        w = textWidth(ctx, label, 11, "medium") + 16,
        h = 26,
        radius = 6,
        opacity = if enabled then 1 else 0.45,
        ui.text({ text = label, font = theme.font, size = 11, weight = "medium", color = theme.colors.text }),
    }
    if enabled then
        props.hover = theme.colors.lift
        props.pressFill = theme.colors.press
        props.cursor = "pointer"
        props.onClick = "notifications dismiss-all"
    end
    return ui.stack(props)
end

-- The open panel and its height. Presses on its gutter are absorbed so they do not reach the housing.
local function panel(ctx, m: Model)
    local note = message(m)
    local rows, total, hidden = listRows(ctx, m)
    local listShown = math.min(LIST_MAX, total)
    local height = HEADER + HEADER_GAP + (if note then NOTE else 0) + listShown
    local list = {
        key = "list",
        w = WIDTH,
        h = listShown,
        scroll = total > LIST_MAX,
        gap = 0,
        center = false,
        align = "topLeading",
        dy = HEADER + HEADER_GAP + (if note then NOTE else 0),
    }
    for index, item in rows do
        list[#list + 1] = (row(ctx, m, item, index, false))
    end
    if hidden > 0 then
        list[#list + 1] = ui.row({
            key = "more",
            w = WIDTH,
            h = MORE,
            gap = 0,
            ui.box({ grow = 1, h = 1 }),
            ui.text({ text = hidden .. " more in Notification Center", font = theme.font, size = 10, weight = "medium",
                color = theme.colors.textSecondary }),
            ui.box({ grow = 1, h = 1 }),
        })
    end

    local children = {
        key = "notes",
        w = WIDTH,
        h = height,
        onClick = function() end,
        ui.row({
            key = "header",
            w = WIDTH - 8,
            h = HEADER,
            gap = 6,
            align = "topLeading",
            dx = 4,
            ui.text({ text = "Notifications", font = theme.font, size = 13, weight = "medium", color = theme.colors.text }),
            ui.text({ text = tostring(m.count), font = theme.font, size = 11, weight = "regular",
                color = theme.colors.textSecondary }),
            ui.box({ grow = 1, h = 1 }),
            clearButton(ctx, m),
        }),
    }
    if note then
        children[#children + 1] = ui.text({ key = "note", text = note, font = theme.font, size = 10, weight = "medium",
            color = theme.colors.textSecondary, maxWidth = WIDTH - 8, align = "topLeading", dx = 4,
            dy = HEADER + HEADER_GAP })
    end
    children[#children + 1] = ui.column(list)
    return ui.stack(children), height
end

-- The arrival peek: the newest row on its own, and its height.
local function peek(ctx, m: Model, item)
    return row(ctx, m, item, 1, true)
end

-- Orders notifications by when Banff first saw them, newest first, and returns the ids that are new
-- since the last render (newest first). Notification Center sorts by the notification's own date,
-- which a sender can set in the past; ordering by arrival puts a late-dated notification on top
-- instead of burying it. The first loaded snapshot keeps Notification Center's order and reports
-- nothing new.
local function track(state, m: Model): { string }
    local fresh = {}
    if not m.loaded then
        return fresh
    end
    local seen = state.noteOrder
    local first = seen == nil
    if first then
        seen = { next = 0, order = {} }
        state.noteOrder = seen
    end
    -- Oldest first, so later arrivals get higher numbers.
    for index = #m.items, 1, -1 do
        local id = m.items[index].id
        if seen.order[id] == nil then
            seen.next += 1
            seen.order[id] = seen.next
            if not first then
                table.insert(fresh, 1, id)
            end
        end
    end
    local current = {}
    for _, item in m.items do
        current[item.id] = seen.order[item.id]
    end
    seen.order = current
    table.sort(m.items, function(a, b)
        return current[a.id] > current[b.id]
    end)
    return fresh
end

return {
    WIDTH = WIDTH,
    model = model,
    badge = badge,
    panel = panel,
    peek = peek,
    rowLayout = rowLayout,
    track = track,
}
