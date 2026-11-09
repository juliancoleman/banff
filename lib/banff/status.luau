-- The qs status circle (Status/StatusIndicator.qml, StatusArc.qml, StatusGlyph.qml): a battery ring
-- that fills from 12 o'clock down both sides around a centre glyph. At rest the glyph is Wi-Fi;
-- temporary states borrow it, highest priority first, and lower-priority events are dropped rather
-- than queued:
--   4 Bluetooth device connected (1.6 s)    3 power connected (1.6 s, cleared on unplug)
--   2 volume / microphone / brightness change (1.5 s; the ring shows that level meanwhile)
--   1 media play, pause or track change (1.6 s)
-- At 20 % or less, the battery percentage sits to the right of the ring.

local theme = require("./theme")
local glyphs = require("./glyphs")

local PRIORITY = { bluetooth = 4, power = 3, control = 2, media = 1 }
local DWELL = { bluetooth = 1.6, power = 1.6, control = 1.5, media = 1.6 }
local SETTLE = 3 -- startup settle before power and Bluetooth events count
local POWER_DEBOUNCE = 0.6
local LABEL_GAP = 3
local LABEL_STYLE = { font = theme.font, size = 13, weight = "medium" }

-- SVG path for a ring of `size` points filled to `value` (0–1) symmetrically from the top.
-- Returns nil for an empty ring.
local function ringPath(size: number, stroke: number, value: number): string?
    local r = size / 2 - stroke / 2
    local c = size / 2
    if value >= 0.999 then
        return string.format("M%.2f %.2f A%.2f %.2f 0 1 1 %.2f %.2f A%.2f %.2f 0 1 1 %.2f %.2f",
            c, c - r, r, r, c, c + r, r, r, c, c - r)
    end
    if value <= 0.005 then
        return nil
    end
    local reach = value * math.pi
    local dx = r * math.sin(reach)
    local y = c - r * math.cos(reach)
    return string.format("M%.2f %.2f A%.2f %.2f 0 %d 1 %.2f %.2f",
        c - dx, y, r, r, if reach > math.pi / 2 then 1 else 0, c + dx, y)
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

local function connectedCount(bluetooth): number
    local count = 0
    for _, device in (bluetooth and bluetooth.devices) or {} do
        if device.connected then
            count += 1
        end
    end
    return count
end

local function mediaKey(media): string?
    if media == nil then
        return nil
    end
    return table.concat({ media.bundle or "", media.title or "", media.artist or "" }, "\0")
end

-- Compares this render's data with the last and raises temporary states. The first call records a
-- baseline; power and Bluetooth also wait out a startup settle (qs BatterySource, BluetoothSource).
local function observe(data, s)
    local mic = data.microphone or {}
    local media = data.media
    local current = {
        volume = data.volume,
        muted = data.muted,
        micVolume = mic.volume,
        micMuted = mic.muted,
        brightness = data.brightness and data.brightness.available and data.brightness.value or nil,
        mediaKey = mediaKey(media),
        playing = media ~= nil and media.playing,
        bluetooth = connectedCount(data.bluetooth),
        ac = data.power ~= nil and data.power.source == "ac",
    }
    local previous = s.previous
    s.previous = current
    if previous == nil then
        arm(s, "settleTimer", SETTLE, function()
            s.settled = true
        end)
        return
    end

    if current.volume ~= previous.volume or current.muted ~= previous.muted then
        showControl(s, "volume", volumeIcon(current.volume, current.muted))
    end
    if current.micVolume ~= previous.micVolume or current.micMuted ~= previous.micMuted then
        showControl(s, "microphone", microphoneIcon(mic))
    end
    if current.brightness ~= nil and previous.brightness ~= nil and current.brightness ~= previous.brightness then
        showControl(s, "brightness", "brightness")
    end
    if current.mediaKey ~= nil and (current.mediaKey ~= previous.mediaKey or current.playing ~= previous.playing) then
        offer(s, "media", if current.playing then "play" else "pause")
    end
    if s.settled and current.bluetooth > previous.bluetooth then
        offer(s, "bluetooth", "bluetooth")
    end
    if current.ac ~= previous.ac then
        if current.ac then
            arm(s, "powerTimer", POWER_DEBOUNCE, function()
                if s.settled and s.previous and s.previous.ac then
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

local function stroke(key: string, d: string, color: string)
    local size = theme.statusGlyph
    return ui.path({ key = key, w = size, h = size, viewBox = { 0, 0, 24, 24 }, d = d, border = color,
        borderWidth = 2 * size / 24, animate = theme.fade })
end

local function wifiGlyph(wifi, level: number)
    local size = theme.statusGlyph
    local k = size / 24
    local off = wifi == nil or not wifi.power
    local connected = wifi ~= nil and wifi.connected
    local children = {}
    for index, d in glyphs.wifiArcs do
        local lit = connected and not off and index <= level
        children[#children + 1] = stroke("arc" .. index, d, if lit then theme.colors.text else theme.colors.statusDim)
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
        children[#children + 1] = stroke("slash", glyphs.slash, theme.colors.text)
    end
    return children
end

-- The parts of a glyph, by icon name.
local function glyphParts(icon: string, data, wifiBars: number)
    local paths = glyphs.status
    local ink = theme.colors.text
    if icon == "volume" or icon == "volume-muted" then
        local level = (data.volume or 0) / 100
        local parts = { stroke("speaker", paths.speaker, ink) }
        if icon == "volume-muted" then
            parts[#parts + 1] = stroke("mute", paths.mute, ink)
        else
            parts[#parts + 1] = stroke("near", paths.nearWave, if level > 0.005 then ink else theme.colors.statusDim)
            parts[#parts + 1] = stroke("far", paths.farWave, if level >= 0.5 then ink else theme.colors.statusDim)
        end
        return parts
    elseif icon == "microphone" then
        return { stroke("mic", paths.mic, ink) }
    elseif icon == "microphone-muted" then
        return { stroke("mic", paths.micOff, ink) }
    elseif icon == "brightness" then
        return { stroke("sun", paths.sun, ink) }
    elseif icon == "zap" or icon == "bluetooth" or icon == "play" or icon == "pause" then
        return { stroke(icon, paths[icon], ink) }
    end
    return wifiGlyph(data.wifi, wifiBars)
end

-- Rendering -------------------------------------------------------------------------------------

local function batteryLabel(data, s): string?
    local battery = data.battery
    if s.control ~= nil or battery == nil or battery > 20 then
        return nil
    end
    return tostring(math.round(battery))
end

-- Width of the status slot: the circle, plus the low-battery label beside it.
local function width(ctx, s): number
    local label = batteryLabel(ctx.data, s)
    if label == nil then
        return theme.status
    end
    return theme.status + LABEL_GAP + math.ceil((ctx.format.measure(label, LABEL_STYLE)))
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

-- The status slot. `s` is this display's status state (`ctx.state.status`).
local function render(ctx, s)
    local data = ctx.data
    local wifi = data.wifi
    local bars = wifiLevel(wifi and wifi.rssi, s.wifiLevel)
    s.wifiLevel = bars

    local ring = theme.status - 2 * theme.statusRoom
    local lineWidth = theme.statusStroke
    local value, color
    if s.control then
        value, color = controlLevel(data, s.control), theme.colors.text
    elseif data.battery then
        value, color = data.battery / 100, ringColor(data.battery, data.charging, data.power)
    end
    local circle = {
        key = "circle",
        w = theme.status,
        h = theme.status,
        align = "leading",
        ui.path({
            key = "track",
            w = ring,
            h = ring,
            viewBox = { 0, 0, ring, ring },
            d = ringPath(ring, lineWidth, 1) :: string,
            border = theme.colors.statusTrack,
            borderWidth = lineWidth,
        }),
    }
    local fill = if value then ringPath(ring, lineWidth, value) else nil
    if fill then
        circle[#circle + 1] = ui.path({
            key = "fill",
            w = ring,
            h = ring,
            viewBox = { 0, 0, ring, ring },
            d = fill,
            border = color,
            borderWidth = lineWidth,
            animate = theme.fade,
        })
    end

    -- Keyed by icon so a change swaps glyphs: the old one fades and shrinks, the new one grows in.
    local icon = if s.slot then s.slot.icon else "wifi"
    local glyph = {
        key = "glyph:" .. icon,
        w = theme.statusGlyph,
        h = theme.statusGlyph,
        appear = { opacity = 0, scale = 0.6, animate = theme.spring },
        exit = { opacity = 0, scale = 0.6, animate = { duration = 0.15, curve = "easeOut" } },
    }
    for _, part in glyphParts(icon, data, bars) do
        glyph[#glyph + 1] = part
    end
    circle[#circle + 1] = ui.stack(glyph)

    local slot = { key = "status", w = width(ctx, s), h = theme.status, gap = LABEL_GAP, ui.stack(circle) }
    local label = batteryLabel(data, s)
    if label then
        slot[#slot + 1] = ui.text({ key = "battery", text = label, font = theme.font, size = 13, weight = "medium",
            color = theme.colors.text, appear = { opacity = 0, animate = theme.fade },
            exit = { opacity = 0, animate = theme.fade } })
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
