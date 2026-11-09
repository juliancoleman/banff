-- The qs control center (Control/ControlCenter.qml and its tiles and pages), docked under the time
-- row and opened from the status circle. 298 pt wide: a header (battery, power), then Wi-Fi and
-- Bluetooth tiles, volume / microphone / brightness sliders, and memory / CPU / disk meters, with
-- rules between groups. Pages slide in from the right: Bluetooth devices, audio output, power.
--
-- OmniWM limits what it can do: Wi-Fi and Bluetooth have no power switches or join/pair commands
-- (only `wifi settings` / `bluetooth settings`), there is no input-device switching and no fan data,
-- so those tiles open System Settings and the fan tile is gone.

local theme = require("./theme")
local glyphs = require("./glyphs")
local status = require("./status")

local WIDTH = 298
local HEADER = 27 -- the housing's resting thickness, like the notification panel
local HEADER_GAP = 2
local GAP = 6
local ROW = 44
local KNOB = 30
local KNOB_INSET = 7
local TEXT_X = KNOB_INSET + KNOB + 9
local USAGE = KNOB + 11 + 20
local LIST_ROW = 40
local LIST_MAX = 240
local LANE_X = TEXT_X + 3
local READOUT = 26
local CHEVRON = 12

local paths = glyphs.status

local function glyph(key: string, d: string, size: number, color: string)
    return ui.path({ key = key, w = size, h = size, viewBox = { 0, 0, 24, 24 }, d = d, border = color,
        borderWidth = 2 * size / 24 })
end

local function text(key: string, value: string, size: number, weight: string, color: string, maxWidth: number?)
    return ui.text({ key = key, text = value, font = theme.font, size = size, weight = weight, color = color,
        maxWidth = maxWidth })
end

local function rule(key: string)
    return ui.box({ key = key, w = WIDTH, h = 1, fill = theme.colors.rule })
end

-- A 30 pt knob (Status/Knob.qml): filled blue-black when on, outlined otherwise, with an optional
-- level ring. `parts` are its glyph strokes, drawn at 16 pt (13 pt inside a ring).
local function knob(key: string, on: boolean, level: number?, parts: (number, string) -> { any })
    local children = {
        key = key,
        w = KNOB,
        h = KNOB,
        radius = KNOB / 2,
        fill = if on then theme.colors.today else nil,
        border = if on or level then nil else theme.colors.stroke,
        borderWidth = 1,
    }
    if level then
        local ring = KNOB - 4
        children[#children + 1] = ui.path({ key = "track", w = ring, h = ring, viewBox = { 0, 0, ring, ring },
            d = status.ringPath(ring, 2, 1), border = theme.colors.statusTrack, borderWidth = 2 })
        children[#children + 1] = ui.path({ key = "level", w = ring, h = ring, viewBox = { 0, 0, ring, ring },
            d = status.ringPath(ring, 2, level), border = theme.colors.text, borderWidth = 2,
            opacity = if level > 0.005 then 1 else 0 })
    end
    local ink = if on then theme.colors.todayInk else theme.colors.text
    local glyphStack = { key = "glyph", w = 16, h = 16 }
    for _, part in parts(if level then 13 else 16, ink) do
        glyphStack[#glyphStack + 1] = part
    end
    children[#children + 1] = ui.stack(glyphStack)
    return ui.stack(children)
end

local function single(name: string, d: string)
    return function(size: number, ink: string)
        return { glyph(name, d, size, ink) }
    end
end

local function chevron(key: string)
    return ui.stack({ key = key, w = CHEVRON, h = CHEVRON, align = "trailing", dx = -8,
        glyph("chevron", paths.chevronRight, CHEVRON, theme.colors.textSecondary) })
end

-- A tile row (Control/ToggleTile.qml): knob, title and subtitle, optional chevron. The whole row
-- runs `onClick`.
local function tile(key: string, width: number, knobElement, title: string, subtitle: string?, onClick, opens: boolean)
    local column = { key = "text", gap = 1, center = false, align = "leading", dx = TEXT_X,
        text("title", title, 12, "medium", theme.colors.text, width - TEXT_X - (if opens then 24 else 8)) }
    if subtitle and subtitle ~= "" then
        column[#column + 1] = text("subtitle", subtitle, 11, "regular", theme.colors.textSecondary,
            width - TEXT_X - (if opens then 24 else 8))
    end
    local children = {
        key = key,
        w = width,
        h = ROW,
        radius = 6,
        hover = theme.colors.lift,
        pressFill = theme.colors.press,
        cursor = "pointer",
        onClick = onClick,
        ui.stack({ key = "knobSlot", w = KNOB, h = KNOB, align = "leading", dx = KNOB_INSET, knobElement }),
        ui.column(column),
    }
    if opens then
        children[#children + 1] = chevron("chevron")
    end
    return ui.stack(children)
end

-- Glyph parts -----------------------------------------------------------------------------------

local function wifiParts(wifi)
    return function(size: number, ink: string)
        local k = size / 24
        local bars = status.wifiLevel(wifi and wifi.rssi, nil)
        local connected = wifi ~= nil and wifi.power and wifi.connected
        local parts = {}
        for index, d in glyphs.wifiArcs do
            parts[#parts + 1] = glyph("arc" .. index, d, size,
                if connected and index <= bars then ink else theme.colors.statusDim)
        end
        local dot = 2.4 * k
        parts[#parts + 1] = ui.box({ key = "dot", w = dot, h = dot, radius = dot / 2, align = "topLeading",
            dx = 12 * k - dot / 2, dy = 20 * k - dot / 2, fill = if connected then ink else theme.colors.statusDim })
        if wifi == nil or not wifi.power then
            parts[#parts + 1] = glyph("slash", glyphs.slash, size, ink)
        end
        return parts
    end
end

local function volumeParts(level: number, muted: boolean)
    return function(size: number, ink: string)
        local parts = { glyph("speaker", paths.speaker, size, ink) }
        if muted or level <= 0.005 then
            parts[#parts + 1] = glyph("mute", paths.mute, size, ink)
        else
            parts[#parts + 1] = glyph("near", paths.nearWave, size, ink)
            parts[#parts + 1] = glyph("far", paths.farWave, size, if level >= 0.5 then ink else theme.colors.statusDim)
        end
        return parts
    end
end

-- Tiles -----------------------------------------------------------------------------------------

local function wifiTile(data, width: number)
    local wifi = data.wifi
    local subtitle = if wifi == nil or not wifi.power then "Off"
        elseif wifi.connected then (wifi.ssid or "Connected")
        else "Not connected"
    return tile("wifi", width, knob("knob", wifi ~= nil and wifi.power, nil, wifiParts(wifi)), "Wi-Fi", subtitle,
        "wifi settings", true)
end

local function bluetoothSummary(bluetooth): (boolean, string)
    if bluetooth == nil or bluetooth.access ~= "granted" then
        return false, "Allow access"
    elseif not bluetooth.power then
        return false, "Off"
    end
    local connected = {}
    for _, device in bluetooth.devices do
        if device.connected then
            connected[#connected + 1] = device.name
        end
    end
    if #connected == 1 then
        return true, connected[1]
    elseif #connected > 1 then
        return true, #connected .. " devices"
    end
    return true, "On"
end

local function bluetoothTile(data, width: number, onOpen)
    local on, subtitle = bluetoothSummary(data.bluetooth)
    return tile("bluetooth", width, knob("knob", on, nil, single("bluetooth", paths.bluetooth)), "Bluetooth", subtitle,
        onOpen, true)
end

-- A slider row (Control/SliderTile.qml): knob (mute where supported), a 2 pt track with quarter
-- ticks, the value in pencil, and an optional chevron. Dragging uses a native slider laid over the
-- track at 2 % opacity, so the visible track can keep qs's look.
local function slider(key: string, title: string, value: number, muted: boolean, knobParts, onKnob, onSet, onOpen)
    local shown = if muted then 0 else math.clamp(value, 0, 1)
    local right = WIDTH - 8 - CHEVRON - 6
    local readoutX = right - READOUT
    local laneWidth = readoutX - 10 - LANE_X
    local lane = {
        key = "lane",
        w = laneWidth,
        h = 20,
        align = "leading",
        dx = LANE_X,
        ui.box({ key = "track", w = laneWidth, h = 2, radius = 1, fill = theme.colors.statusTrack }),
        ui.box({ key = "fill", w = math.max(2, laneWidth * shown), h = 2, radius = 1, align = "leading",
            fill = theme.colors.text, animate = theme.fade }),
    }
    for index = 1, 3 do
        lane[#lane + 1] = ui.box({ key = "tick" .. index, w = 1, h = 3, align = "leading",
            dx = laneWidth * index / 4, dy = 4, fill = theme.colors.statusTrack })
    end
    lane[#lane + 1] = ui.slider({ key = "input", w = laneWidth, h = 20, value = shown, opacity = 0.02,
        help = title, onChange = onSet })

    local knobSlot = { key = "knobSlot", w = KNOB, h = KNOB, align = "leading", dx = KNOB_INSET,
        knob("knob", false, nil, knobParts) }
    if onKnob then
        knobSlot.cursor = "pointer"
        knobSlot.onClick = onKnob
        knobSlot.help = if muted then "Unmute" else "Mute"
    end
    local children = {
        key = key,
        w = WIDTH,
        h = ROW,
        ui.stack(knobSlot),
        ui.stack(lane),
        ui.stack({ key = "readout", w = READOUT, h = ROW, align = "leading", dx = readoutX,
            ui.text({ text = tostring(math.round(shown * 100)), font = theme.font, size = 11, weight = "regular",
                color = theme.colors.textSecondary }) }),
    }
    if onOpen then
        children[#children + 1] = ui.stack({ key = "open", w = READOUT + 4 + CHEVRON + 8, h = ROW, align = "trailing",
            cursor = "pointer", onClick = onOpen, chevron("chevron") })
    end
    return ui.stack(children)
end

local function setter(command: string)
    return function(_, event)
        if event.value ~= nil then
            omniwm.run(command .. " " .. math.round(math.clamp(event.value, 0, 1) * 100))
        end
    end
end

local function volumeSlider(data, onOpen)
    local level = (data.volume or 0) / 100
    return slider("volume", "Volume", level, data.muted == true, volumeParts(level, data.muted == true), "volume mute",
        setter("volume set"), onOpen)
end

local function sliders(data, onOpenOutput)
    local rows = {}
    if data.volume ~= nil then
        rows[#rows + 1] = volumeSlider(data, onOpenOutput)
    end
    local mic = data.microphone
    if mic and mic.volume ~= nil then
        local muted = mic.muted == true
        rows[#rows + 1] = slider("microphone", "Microphone", mic.volume / 100, muted,
            single("mic", if muted or mic.volume <= 0.5 then paths.micOff else paths.mic),
            if mic.muted ~= nil then "microphone mute" else nil, setter("microphone set"), nil)
    end
    local brightness = data.brightness
    if brightness and brightness.available then
        rows[#rows + 1] = slider("brightness", "Brightness", brightness.value / 100, false, single("sun", paths.sun),
            nil, setter("brightness set"), nil)
    end
    return rows
end

-- Memory, CPU and disk (Control/UsageTile.qml): ringed knobs with the percentage beneath.
local function usage(data)
    local cells = {
        { key = "memory", d = paths.memory, value = data.memory },
        { key = "cpu", d = paths.cpu, value = data.cpu },
        { key = "disk", d = paths.disk, value = data.disk },
    }
    local row = { key = "usage", w = WIDTH, h = USAGE, gap = 0 }
    for _, cell in cells do
        local value = cell.value or 0
        row[#row + 1] = ui.column({
            key = cell.key,
            w = WIDTH / 3,
            gap = 3,
            knob("knob", false, math.clamp(value / 100, 0, 1), single(cell.key, cell.d)),
            text("value", math.round(value) .. "%", 11, "regular", theme.colors.textSecondary),
        })
    end
    return ui.row(row)
end

-- Rows ------------------------------------------------------------------------------------------

-- A list row (Control/ListRow.qml): 16 pt glyph (or a ringed one), title, subtitle, trailing check.
local function listRow(key: string, parts, level: number?, title: string, subtitle: string?, current: boolean, onClick)
    local ink = if current then theme.colors.today else theme.colors.text
    local glyphSlot = { key = "glyph", w = 24, h = 24, align = "leading", dx = 10 - 4 }
    if level then
        glyphSlot[#glyphSlot + 1] = ui.path({ key = "track", w = 24, h = 24, viewBox = { 0, 0, 24, 24 },
            d = status.ringPath(24, 2, 1), border = theme.colors.statusTrack, borderWidth = 2 })
        glyphSlot[#glyphSlot + 1] = ui.path({ key = "level", w = 24, h = 24, viewBox = { 0, 0, 24, 24 },
            d = status.ringPath(24, 2, level), border = theme.colors.text, borderWidth = 2 })
    end
    for _, part in parts(if level then 11 else 16, ink) do
        glyphSlot[#glyphSlot + 1] = part
    end
    local column = { key = "text", gap = 1, center = false, align = "leading", dx = 40,
        text("title", title, 12, if current then "medium" else "regular", theme.colors.text, WIDTH - 40 - 34) }
    if subtitle and subtitle ~= "" then
        column[#column + 1] = text("subtitle", subtitle, 10, "regular", theme.colors.textSecondary, WIDTH - 40 - 34)
    end
    local children = {
        key = key,
        w = WIDTH,
        h = LIST_ROW,
        radius = 6,
        hover = theme.colors.lift,
        pressFill = theme.colors.press,
        cursor = "pointer",
        onClick = onClick,
        ui.stack(glyphSlot),
        ui.column(column),
    }
    if current then
        children[#children + 1] = ui.stack({ key = "check", w = 14, h = 14, align = "trailing", dx = -10,
            glyph("check", paths.check, 14, theme.colors.today) })
    end
    return ui.stack(children)
end

local function list(key: string, rows: { any }, empty: string)
    if #rows == 0 then
        return ui.row({ key = key, w = WIDTH, h = 28, gap = 0, ui.box({ w = 4, h = 1 }),
            text("empty", empty, 11, "regular", theme.colors.textSecondary) }), 28
    end
    local total = #rows * LIST_ROW
    local column = { key = key, w = WIDTH, h = math.min(LIST_MAX, total), scroll = total > LIST_MAX, gap = 0,
        center = false }
    for _, row in rows do
        column[#column + 1] = row
    end
    return ui.column(column), math.min(LIST_MAX, total)
end

-- Pages -----------------------------------------------------------------------------------------

local function back(title: string, onBack)
    return ui.stack({
        key = "back",
        h = 28,
        radius = 6,
        hover = theme.colors.lift,
        pressFill = theme.colors.press,
        cursor = "pointer",
        onClick = onBack,
        ui.row({ gap = 4, ui.box({ w = 2, h = 1 }), glyph("chevron", paths.chevronLeft, 14, theme.colors.text),
            text("title", title, 13, "medium", theme.colors.text), ui.box({ w = 4, h = 1 }) }),
    })
end

local function headerButton(key: string, d: string, help: string, onClick)
    return ui.stack({ key = key, w = 24, h = 24, radius = 6, hover = theme.colors.lift, pressFill = theme.colors.press,
        cursor = "pointer", help = help, onClick = onClick, glyph("glyph", d, 16, theme.colors.text) })
end

-- Pushes a page; nil returns home. Remembers the direction for the slide.
local function toPage(page: string?)
    return function(next)
        next.state.controlDirection = if page then 1 else -1
        next.state.controlPage = page
        next.state.armed = nil
    end
end

local function stack(rows: { any }): (any, number)
    local column = { key = "body", w = WIDTH, gap = GAP, center = false }
    local height = -GAP
    for _, row in rows do
        column[#column + 1] = row[1]
        height += row[2] + GAP
    end
    return ui.column(column), math.max(0, height)
end

local function home(ctx)
    local data = ctx.data
    local half = (WIDTH - 1 - 2 * GAP) / 2
    local rows = {
        { ui.row({ key = "links", w = WIDTH, h = ROW, gap = GAP, wifiTile(data, half),
            ui.box({ key = "divider", w = 1, h = KNOB, fill = theme.colors.rule }),
            bluetoothTile(data, half, toPage("bluetooth")) }), ROW },
        { rule("rule1"), 1 },
    }
    local faders = sliders(data, if data.outputs and #data.outputs > 0 then toPage("output") else nil)
    if #faders > 0 then
        local column = { key = "faders", w = WIDTH, gap = GAP, center = false }
        for _, fader in faders do
            column[#column + 1] = fader
        end
        rows[#rows + 1] = { ui.column(column), #faders * ROW + (#faders - 1) * GAP }
        rows[#rows + 1] = { rule("rule2"), 1 }
    end
    rows[#rows + 1] = { usage(data), USAGE }
    return stack(rows)
end

local function bluetoothPage(ctx)
    local bluetooth = ctx.data.bluetooth
    local on, subtitle = bluetoothSummary(bluetooth)
    local devices = {}
    for _, device in (bluetooth and bluetooth.devices) or {} do
        local level = if device.battery then device.battery / 100 else nil
        local detail = if device.connected
            then (if device.battery then "Connected · " .. math.round(device.battery) .. "%" else "Connected")
            else "Paired"
        devices[#devices + 1] = listRow("d:" .. device.id, single("kind", glyphs.devices[device.kind] or paths.bluetooth),
            level, device.name, detail, device.connected, "bluetooth settings")
    end
    local listElement, listHeight = list("devices", devices, "No devices")
    return stack({
        { tile("bluetoothRow", WIDTH, knob("knob", on, nil, single("bluetooth", paths.bluetooth)), "Bluetooth", subtitle,
            if bluetooth and bluetooth.access == "notDetermined" then "bluetooth authorize" else "bluetooth settings",
            true), ROW },
        { rule("rule"), 1 },
        { listElement, listHeight },
    })
end

local function outputPage(ctx)
    local data = ctx.data
    local rows = {}
    for _, output in data.outputs or {} do
        rows[#rows + 1] = listRow("o:" .. output.id, volumeParts(1, false), nil, output.name, nil, output.default,
            "volume output " .. output.id)
    end
    local listElement, listHeight = list("outputs", rows, "No output devices")
    return stack({
        { volumeSlider(data, nil), ROW },
        { rule("rule"), 1 },
        { listElement, listHeight },
    })
end

-- Power (Control/PowerPage.qml): lock and sleep act at once; restart and shut down need a second
-- press, as in qs (macOS then asks again).
local function powerPage(ctx)
    local armed = ctx.state.armed
    local function action(key: string, title: string, confirm: string?, d: string, command: string)
        local isArmed = armed == key
        local knobElement = ui.stack({
            key = "knob",
            w = KNOB,
            h = KNOB,
            radius = KNOB / 2,
            fill = if isArmed then theme.colors.danger else nil,
            border = if isArmed then nil else theme.colors.stroke,
            borderWidth = 1,
            animate = theme.fade,
            glyph("glyph", d, 16, theme.colors.text),
        })
        return tile(key, WIDTH, knobElement, if isArmed and confirm then confirm else title, nil, function(next)
            if confirm and next.state.armed ~= key then
                next.state.armed = key
                return
            end
            next.state.armed = nil
            next.state.panel = nil
            omniwm.run(command)
        end, false)
    end
    return stack({
        { action("lock", "Lock", nil, paths.lock, "session lock"), ROW },
        { action("sleep", "Sleep", nil, paths.sleep, "session sleep"), ROW },
        { rule("rule"), 1 },
        { action("restart", "Restart", "Confirm Restart", paths.restart, "session restart"), ROW },
        { action("shutdown", "Shut Down", "Confirm Shut Down", paths.powerOff, "session shutdown"), ROW },
    })
end

local TITLES = { bluetooth = "Bluetooth", output = "Output", power = "Power" }

-- The open panel and its height. Presses on its gutter are absorbed so they do not reach the housing.
local function panel(ctx)
    local state = ctx.state
    local page = state.controlPage
    local body, bodyHeight
    if page == "bluetooth" then
        body, bodyHeight = bluetoothPage(ctx)
    elseif page == "output" then
        body, bodyHeight = outputPage(ctx)
    elseif page == "power" then
        body, bodyHeight = powerPage(ctx)
    else
        page = nil
        body, bodyHeight = home(ctx)
    end

    local header
    if page then
        header = ui.row({ key = "header:" .. page, w = WIDTH - 8, h = HEADER, gap = 0, align = "topLeading", dx = 4,
            back(TITLES[page], toPage(nil)) })
    else
        local battery = ctx.data.battery
        local row = { key = "header", w = WIDTH - 8, h = HEADER, gap = 6, align = "topLeading", dx = 4 }
        if battery then
            row[#row + 1] = text("battery", math.round(battery) .. "%", 12, "medium", theme.colors.text)
        end
        row[#row + 1] = ui.box({ grow = 1, h = 1 })
        row[#row + 1] = headerButton("power", paths.powerOff, "Power", toPage("power"))
        header = ui.row(row)
    end
    local direction = state.controlDirection or 0
    local height = HEADER + HEADER_GAP + bodyHeight
    return ui.stack({
        key = "control",
        w = WIDTH,
        h = height,
        onClick = function() end,
        header,
        ui.stack({
            key = "page:" .. (page or "home"),
            w = WIDTH,
            h = bodyHeight,
            align = "topLeading",
            dy = HEADER + HEADER_GAP,
            appear = { opacity = 0, dx = 24 * direction, animate = theme.spring },
            exit = { opacity = 0, dx = -24 * direction, animate = theme.fade },
            body,
        }),
    }), height
end

-- Escape: a page goes back home; home closes the panel. Returns whether it handled the key.
local function back_(state): boolean
    if state.controlPage then
        state.controlDirection = -1
        state.controlPage = nil
        state.armed = nil
        return true
    end
    return false
end

return {
    WIDTH = WIDTH,
    panel = panel,
    back = back_,
}
