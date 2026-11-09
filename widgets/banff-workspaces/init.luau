-- Workspace indicator (qs PLAN.md §6). Four workspaces named "1"–"4", display-only.
-- Collapsed: every layer sits on one centre and the numbered active pill is topmost.
-- On a real workspace change the layers burst into dots plus a longer active pill,
-- then collapse after theme.collapseDelay. An active workspace outside "1"–"4" shows "?".

local theme = require("../lib/banff/theme")

local NAMES = { "1", "2", "3", "4" }
local SIZE = 32 -- collapsed pill, both axes
local DOT = 10 -- expanded inactive dot
local PILL = 28 -- expanded active pill length
local GAP = 8

-- The workspace shown on this bar's display: this display's workspace that is visible,
-- falling back to the focused one.
local function activeName(data)
    local visible = {}
    for _, workspace in data.workspaces do
        if workspace.visible then
            visible[workspace.id] = true
        end
    end
    local focused = nil
    for _, workspace in data.bar.workspaces do
        if visible[workspace.id] then
            return workspace.name
        end
        if workspace.focused then
            focused = workspace.name
        end
    end
    return focused
end

-- Expands on a change after the first observed value; a new change while expanded resets the
-- collapse timer instead of replaying the burst.
local function observe(state, active)
    if state.active == active then
        return
    end
    local initial = not state.seen
    state.seen = true
    state.active = active
    if initial then
        return
    end
    state.expanded = true
    if state.timer then
        state.timer:cancel()
    end
    local timer, err = omniwm.after(theme.collapseDelay, function()
        state.timer = nil
        state.expanded = false
    end)
    state.timer = timer
    if not timer then
        omniwm.log("banff-workspaces: collapse timer rejected:", err)
        state.expanded = false
    end
end

local function shape(entry, expanded, vertical)
    local along = if expanded then entry.length else SIZE
    local cross = if expanded then DOT else SIZE
    local offset = if expanded then entry.offset else 0
    local props = {
        key = entry.key,
        w = if vertical then cross else along,
        h = if vertical then along else cross,
        dx = if vertical then 0 else offset,
        dy = if vertical then offset else 0,
        radius = cross / 2,
        fill = if entry.active then "accent" else "secondaryForeground",
        animate = theme.burst,
    }
    if entry.key == "unknown" then
        props.appear = { opacity = 0, scale = 0.5 }
        props.exit = { opacity = 0, scale = 0.5 }
    end
    if entry.active then
        props[1] = ui.text({
            text = entry.label,
            size = 15,
            weight = "medium",
            color = "accentForeground",
            opacity = if expanded then 0 else 1,
            animate = theme.standard,
        })
    end
    return ui.stack(props)
end

function render(ctx)
    local data = ctx.data
    local style = data.bar.style
    local vertical = style == nil or style.vertical
    local active = activeName(data)
    observe(ctx.state, active)
    local expanded = ctx.state.expanded == true

    local entries = {}
    for _, name in NAMES do
        entries[#entries + 1] = { key = "ws" .. name, label = name, active = name == active }
    end
    if table.find(NAMES, active) == nil then
        entries[#entries + 1] = { key = "unknown", label = "?", active = true }
    end

    local total = -GAP
    for _, entry in entries do
        entry.length = if entry.active then PILL else DOT
        total += entry.length + GAP
    end
    local cursor = -total / 2
    for _, entry in entries do
        entry.offset = cursor + entry.length / 2
        cursor += entry.length + GAP
    end
    local span = math.max(total, SIZE)

    local props = { key = "workspaces", w = if vertical then SIZE else span, h = if vertical then span else SIZE }
    -- Inactive layers first so the active layer is drawn on top.
    for _, entry in entries do
        if not entry.active then
            props[#props + 1] = shape(entry, expanded, vertical)
        end
    end
    for _, entry in entries do
        if entry.active then
            props[#props + 1] = shape(entry, expanded, vertical)
        end
    end
    return ui.stack(props)
end
