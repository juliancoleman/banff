-- The qs status circle (Status/StatusIndicator.qml, StatusArc.qml, StatusGlyph.qml): a battery ring
-- that fills from 12 o'clock down both sides around a centre glyph. At rest the glyph is Wi-Fi;
-- temporary states borrow it, highest priority first, and lower-priority events are dropped rather
-- than queued:
--   4 Bluetooth device connected (1.6 s)    3 power connected (1.6 s, cleared on unplug)
--   2 volume / microphone / brightness change (1.5 s; the ring shows that level meanwhile)
--   1 media play, pause or track change (1.6 s)
-- The battery percentage shows at 20 % or less, or always (Banff's "Battery percentage" setting):
-- beside the ring when docked, inside its bottom edge as a pill.

local theme = require("./theme")
local glyphs = require("./glyphs")

local PRIORITY = { bluetooth = 4, power = 3, control = 2, media = 1 }
local DWELL = { bluetooth = 1.6, power = 1.6, control = 1.5, media = 1.6 }
local SETTLE = 3 -- startup settle before power and Bluetooth events count
local POWER_DEBOUNCE = 0.6
local LABEL_GAP = 3

local RING_SEGMENTS = 8

-- SVG path for a ring of `size` points filled to `value` (0–1) symmetrically from the top. Always
-- the same commands (a move and RING_SEGMENTS cubic curves), so a changing value morphs smoothly;
-- SVG arcs become different numbers of curves and morphed into odd shapes. An empty ring collapses
-- to a point at the top.
local function ringPath(size: number, stroke: number, value: number): string
    local r = size / 2 - stroke / 2
    local c = size / 2
    local reach = math.clamp(value, 0, 1) * math.pi
    local step = 2 * reach / RING_SEGMENTS
    local handle = 4 / 3 * math.tan(step / 4) * r
    local function point(angle: number): (number, number)
        return c + r * math.sin(angle), c - r * math.cos(angle)
    end
    local x, y = point(-reach)
    local parts = { string.format("M%.3f %.3f", x, y) }
    for index = 1, RING_SEGMENTS do
        local from = -reach + (index - 1) * step
        local to = from + step
        local x0, y0 = point(from)
        local x1, y1 = point(to)
        parts[#parts + 1] = string.format("C%.3f %.3f %.3f %.3f %.3f %.3f",
            x0 + handle * math.cos(from), y0 + handle * math.sin(from),
            x1 - handle * math.cos(to), y1 - handle * math.sin(to), x1, y1)
    end
    return table.concat(parts, " ")
end

-- Lit Wi-Fi arcs (0–3) from RSSI in dBm, using qs's 25/50/75 % band thresholds and its 4-point
-- hysteresis around the previous level.
local function wifiLevel(rssi: number?, previous: number?): number
    if rssi == nil then
        return 0
    end
    local quality = math.clamp(2 * (rssi + 100) / 100, 0, 1)
    local level = if quality >= 0.75 then 3 elseif quality >= 0.5 then 2 elseif quality >= 0.25 then 1 else 0
    if previous ~= nil and level ~= previous then
        local edge = if level > previous then previous * 0.25 + 0.25 else previous * 0.25
        if math.abs(quality - edge) < 0.04 then
            return previous
        end
    end
    return level
end

-- qs counts UPower's Charging and PendingCharge as charging. macOS reports a battery held below its
-- charge limit on AC as not charging, so "on AC and not fully charged" stands in for PendingCharge.
local function ringColor(battery: number, charging: boolean, power): string
    local pending = power ~= nil and power.source == "ac" and not power.charged
    if charging or pending then
        return theme.colors.charging
    elseif battery <= 20 then
        return theme.colors.dangerMark
    end
    return theme.colors.text
end

-- Timers ------------------------------------------------------------------------------------------

local function arm(s, field: string, seconds: number, done: () -> ())
    if s[field] then
        s[field]:cancel()
    end
    s[field] = omniwm.after(seconds, function()
        s[field] = nil
        done()
    end)
end

local function cancel(s, field: string)
    if s[field] then
        s[field]:cancel()
        s[field] = nil
    end
end

-- The slot --------------------------------------------------------------------------------------

local function offer(s, kind: string, icon: string)
    local priority = PRIORITY[kind]
    if s.slot and s.slot.priority > priority then
        return
    end
    s.slot = { kind = kind, priority = priority, icon = icon }
    arm(s, "slotTimer", DWELL[kind], function()
        if s.slot and s.slot.kind == kind then
            s.slot = nil
        end
    end)
end

local function clearSlot(s, kind: string)
    if s.slot and s.slot.kind == kind then
        s.slot = nil
        cancel(s, "slotTimer")
    end
end

-- A control owns the ring for its whole dwell, even while a higher-priority glyph holds the slot.
local function showControl(s, kind: string, icon: string)
    s.control = kind
    arm(s, "controlTimer", DWELL.control, function()
        s.control = nil
    end)
    offer(s, "control", icon)
end

local function volumeIcon(volume: number?, muted: boolean?): string
    return if muted or (volume or 0) <= 0.5 then "volume-muted" else "volume"
end

local function microphoneIcon(mic): string
    return if mic.muted or (mic.volume or 0) <= 0.5 then "microphone-muted" else "microphone"
end

local function connectedDevices(bluetooth): { [string]: boolean }
    local connected = {}
    for _, device in (bluetooth and bluetooth.devices) or {} do
        if device.connected then
            connected[device.id] = true
        end
    end
    return connected
end

local function mediaKey(media): string?
    if media == nil then
        return nil
    end
    return table.concat({ media.bundle or "", media.title or "", media.artist or "" }, "\0")
end

-- Whether a reading changed between two renders. A reading that is missing on either side (a feed
-- still loading) is not a change.
local function changed(before, after): boolean
    return before ~= nil and after ~= nil and before ~= after
end

-- Compares this render's data with the last and raises temporary states. Nothing is raised during
-- the first SETTLE seconds, while feeds load (qs BatterySource and BluetoothSource settle the same
-- way); readings keep updating meanwhile, so the first change after it counts.
local function observe(data, s)
    -- OmniWM lists Bluetooth devices only after macOS grants it Bluetooth access, and reading the
    -- feed does not ask. Ask once, from a timer callback, since render must not issue commands.
    if data.bluetooth and data.bluetooth.access == "notDetermined" and not s.askedBluetooth then
        s.askedBluetooth = true
        omniwm.after(0.01, function()
            omniwm.run("bluetooth authorize")
        end)
    end
    local mic = data.microphone or {}
    local media = data.media
    local current = {
        volume = data.volume,
        muted = data.muted,
        micVolume = mic.volume,
        micMuted = mic.muted,
        brightness = data.brightness and data.brightness.available and data.brightness.value or nil,
        mediaKey = mediaKey(media),
        playing = if media then media.playing else nil,
        devices = connectedDevices(data.bluetooth),
        ac = if data.power then data.power.source == "ac" else nil,
    }
    local previous = s.previous
    s.previous = current
    if previous == nil then
        arm(s, "settleTimer", SETTLE, function()
            s.settled = true
        end)
        return
    end
    if not s.settled then
        return
    end

    if changed(previous.volume, current.volume) or changed(previous.muted, current.muted) then
        showControl(s, "volume", volumeIcon(current.volume, current.muted))
    end
    if changed(previous.micVolume, current.micVolume) or changed(previous.micMuted, current.micMuted) then
        showControl(s, "microphone", microphoneIcon(mic))
    end
    if changed(previous.brightness, current.brightness) then
        showControl(s, "brightness", "brightness")
    end
    if current.mediaKey ~= nil and (current.mediaKey ~= previous.mediaKey or changed(previous.playing, current.playing)) then
        offer(s, "media", if current.playing then "play" else "pause")
    end
    for id in current.devices do
        if not previous.devices[id] then
            offer(s, "bluetooth", "bluetooth")
            break
        end
    end
    if changed(previous.ac, current.ac) then
        if current.ac then
            arm(s, "powerTimer", POWER_DEBOUNCE, function()
                if s.previous and s.previous.ac then
                    offer(s, "power", "zap")
                end
            end)
        else
            cancel(s, "powerTimer")
            clearSlot(s, "power")
        end
    end
end

-- Glyphs ----------------------------------------------------------------------------------------

local function stroke(key: string, d: string, color: string, size: number)
    return ui.path({ key = key, w = size, h = size, viewBox = { 0, 0, 24, 24 }, d = d, border = color,
        borderWidth = 2 * size / 24, animate = theme.fade })
end

local function wifiGlyph(wifi, level: number, size: number)
    local k = size / 24
    local off = wifi == nil or not wifi.power
    local connected = wifi ~= nil and wifi.connected
    local children = {}
    for index, d in glyphs.wifiArcs do
        local lit = connected and not off and index <= level
        children[#children + 1] = stroke("arc" .. index, d, if lit then theme.colors.text else theme.colors.statusDim,
            size)
    end
    local dot = 2.4 * k
    children[#children + 1] = ui.box({
        key = "dot",
        w = dot,
        h = dot,
        radius = dot / 2,
        align = "topLeading",
        dx = glyphs.wifiDot[1] * k - dot / 2,
        dy = glyphs.wifiDot[2] * k - dot / 2,
        fill = if connected and not off then theme.colors.text else theme.colors.statusDim,
    })
    if off then
        children[#children + 1] = stroke("slash", glyphs.slash, theme.colors.text, size)
    end
    return children
end

-- The resting glyph, after qs NetworkSource (`wired ? "ethernet" : wifi ? "wifi" : "ethernet-off"`).
-- OmniWM reports Wi-Fi but no wired link, so a wired connection is inferred: Wi-Fi is not
-- connected, yet traffic moved in the last 30 s (`networkHistory`). With Wi-Fi connected the
-- glyph stays Wi-Fi even if a cable is also plugged in, since Banff cannot tell. Returns nil while
-- the traffic history has no samples yet (it restarts whenever no widget has been reading it).
local function networkIcon(data): string?
    local wifi = data.wifi
    if wifi and wifi.connected then
        return "wifi"
    end
    local history = data.networkHistory
    if history == nil or (#history.down == 0 and #history.up == 0) then
        return nil
    end
    for _, series in { history.down, history.up } do
        for _, sample in series do
            if sample > 0 then
                return "ethernet"
            end
        end
    end
    return "ethernet-off"
end

-- The parts of a glyph, by icon name, at `size` points.
local function glyphParts(icon: string, data, wifiBars: number, size: number)
    local paths = glyphs.status
    local ink = theme.colors.text
    local function line(key: string, d: string, color: string)
        return stroke(key, d, color, size)
    end
    if icon == "volume" or icon == "volume-muted" then
        local level = (data.volume or 0) / 100
        local parts = { line("speaker", paths.speaker, ink) }
        if icon == "volume-muted" then
            parts[#parts + 1] = line("mute", paths.mute, ink)
        else
            parts[#parts + 1] = line("near", paths.nearWave, if level > 0.005 then ink else theme.colors.statusDim)
            parts[#parts + 1] = line("far", paths.farWave, if level >= 0.5 then ink else theme.colors.statusDim)
        end
        return parts
    elseif icon == "microphone" then
        return { line("mic", paths.mic, ink) }
    elseif icon == "microphone-muted" then
        return { line("mic", paths.micOff, ink) }
    elseif icon == "brightness" then
        return { line("sun", paths.sun, ink) }
    elseif icon == "zap" or icon == "bluetooth" or icon == "play" or icon == "pause" or icon == "close" then
        return { line(icon, paths[icon], ink) }
    elseif icon == "ethernet" then
        return { line("ethernet", paths.ethernet, ink) }
    elseif icon == "ethernet-off" then
        return { line("ethernet", paths.ethernet, theme.colors.statusDim), line("slash", glyphs.slash, ink) }
    end
    return wifiGlyph(data.wifi, wifiBars, size)
end

-- Rendering -------------------------------------------------------------------------------------

-- The battery percentage, when shown: at 20 % or less, or always with `always`; hidden while a
-- control level or the close X holds the ring (qs StatusIndicator.labelShown).
local function batteryLabel(data, s, always: boolean, closeAction: boolean?): string?
    local battery = data.battery
    if closeAction or s.control ~= nil or battery == nil or (battery > 20 and not always) then
        return nil
    end
    return tostring(math.round(battery))
end

local function labelStyle(z)
    return { font = theme.font, size = z.batteryLabel, weight = if z.name == "pill" then "semibold" else "medium" }
end

-- Width of the status slot at size set `z`: the circle, plus the battery label beside it when docked.
local function width(ctx, s, z, always: boolean, closeAction: boolean?): number
    local label = batteryLabel(ctx.data, s, always, closeAction)
    if label == nil or z.name == "pill" then
        return z.status
    end
    return z.status + LABEL_GAP + math.ceil((ctx.format.measure(label, labelStyle(z))))
end

local function controlLevel(data, control: string): number
    if control == "volume" then
        return if data.muted then 0 else (data.volume or 0) / 100
    elseif control == "microphone" then
        local mic = data.microphone or {}
        return if mic.muted then 0 else (mic.volume or 0) / 100
    end
    return ((data.brightness and data.brightness.value) or 0) / 100
end

-- The status slot at size set `z`. `s` is this display's status state (`ctx.state.status`). With
-- `closeAction` (the control center is open) the glyph is an X, as in qs.
local function render(ctx, s, z, always: boolean, closeAction: boolean?)
    local data = ctx.data
    local wifi = data.wifi
    local bars = wifiLevel(wifi and wifi.rssi, s.wifiLevel)
    s.wifiLevel = bars

    local ring = z.status - 2 * z.statusRoom
    local lineWidth = z.statusStroke
    local value, color
    if s.control then
        value, color = controlLevel(data, s.control), theme.colors.text
    elseif data.battery then
        value, color = data.battery / 100, ringColor(data.battery, data.charging, data.power)
    end
    local circle = {
        key = "circle",
        w = z.status,
        h = z.status,
        align = "leading",
        ui.path({
            key = "track",
            w = ring,
            h = ring,
            viewBox = { 0, 0, ring, ring },
            d = ringPath(ring, lineWidth, 1),
            border = theme.colors.statusTrack,
            borderWidth = lineWidth,
        }),
    }
    -- Always present, so an empty ring is hidden rather than removed. Not animated: OmniWM morphs a
    -- path's `d` with Core Animation, and on the Mac that drew the ring as a square mid-change even
    -- with identical commands on both sides. Values snap instead.
    circle[#circle + 1] = ui.path({
        key = "fill",
        w = ring,
        h = ring,
        viewBox = { 0, 0, ring, ring },
        d = ringPath(ring, lineWidth, value or 0),
        border = color or theme.colors.text,
        borderWidth = lineWidth,
        opacity = if value and value > 0.005 then 1 else 0,
    })

    -- The network glyph is worked out every render, even while another glyph shows, so its feeds stay
    -- demanded and closing the control center does not flash a stale or empty reading; until the
    -- first reading the last known glyph stays.
    s.network = networkIcon(data) or s.network or "ethernet-off"
    -- Keyed by icon so a change swaps glyphs: the old one fades and shrinks, the new one grows in.
    local icon = if closeAction then "close" elseif s.slot then s.slot.icon else s.network
    local glyph = {
        key = "glyph:" .. icon,
        w = z.statusGlyph,
        h = z.statusGlyph,
        appear = { opacity = 0, scale = 0.6, animate = theme.spring },
        exit = { opacity = 0, scale = 0.6, animate = { duration = 0.15, curve = "easeOut" } },
    }
    for _, part in glyphParts(icon, data, bars, z.statusGlyph) do
        glyph[#glyph + 1] = part
    end
    circle[#circle + 1] = ui.stack(glyph)

    local label = batteryLabel(data, s, always, closeAction)
    local fade = { appear = { opacity = 0, animate = theme.fade }, exit = { opacity = 0, animate = theme.fade } }
    if label and z.name == "pill" then
        -- Inside the ring, its baseline on the ring's outer bottom edge (qs ringLabelSize, DemiBold).
        circle[#circle + 1] = ui.row({
            key = "battery",
            w = z.status,
            gap = 0,
            align = "topLeading",
            dy = z.status - z.statusRoom - z.batteryLabel * 1.025,
            appear = fade.appear,
            exit = fade.exit,
            ui.box({ grow = 1, h = 1 }),
            ui.text({ text = label, font = theme.font, size = z.batteryLabel, weight = "semibold",
                color = theme.colors.text }),
            ui.box({ grow = 1, h = 1 }),
        })
    end

    local slot = { key = "status", w = width(ctx, s, z, always, closeAction), h = z.status, gap = LABEL_GAP,
        ui.stack(circle) }
    if label and z.name ~= "pill" then
        slot[#slot + 1] = ui.text({ key = "battery", text = label, font = theme.font, size = z.batteryLabel,
            weight = "medium", color = theme.colors.text, appear = fade.appear, exit = fade.exit })
    end
    return ui.row(slot)
end

return {
    ringPath = ringPath,
    wifiLevel = wifiLevel,
    ringColor = ringColor,
    observe = observe,
    width = width,
    render = render,
}
