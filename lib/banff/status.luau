-- The qs status circle at rest (Status/StatusIndicator.qml, StatusArc.qml): a battery ring that fills
-- from 12 o'clock down both sides, around the Wi-Fi glyph.

local theme = require("./theme")
local glyphs = require("./glyphs")

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

local function ringColor(battery: number, charging: boolean): string
    if charging then
        return theme.colors.charging
    elseif battery <= 20 then
        return theme.colors.dangerMark
    end
    return theme.colors.text
end

local function wifiGlyph(wifi, level: number)
    local size = theme.statusGlyph
    local k = size / 24
    local off = wifi == nil or not wifi.power
    local connected = wifi ~= nil and wifi.connected
    local children = { key = "wifi", w = size, h = size }
    for index, d in glyphs.wifiArcs do
        local lit = connected and not off and index <= level
        children[#children + 1] = ui.path({
            key = "arc" .. index,
            w = size,
            h = size,
            viewBox = { 0, 0, 24, 24 },
            d = d,
            border = if lit then theme.colors.text else theme.colors.statusDim,
            borderWidth = 2 * k,
            animate = theme.fade,
        })
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
        children[#children + 1] = ui.path({
            key = "slash",
            w = size,
            h = size,
            viewBox = { 0, 0, 24, 24 },
            d = glyphs.slash,
            border = theme.colors.text,
            borderWidth = 2 * k,
        })
    end
    return ui.stack(children)
end

-- The status circle element. `state` keeps the Wi-Fi level for hysteresis.
local function render(data, state)
    local wifi = data.wifi
    local level = wifiLevel(wifi and wifi.rssi, state.wifiLevel)
    state.wifiLevel = level

    local ring = theme.status - 2 * theme.statusRoom
    local stroke = theme.statusStroke
    local children = {
        key = "status",
        w = theme.status,
        h = theme.status,
        ui.path({
            key = "track",
            w = ring,
            h = ring,
            viewBox = { 0, 0, ring, ring },
            d = ringPath(ring, stroke, 1) :: string,
            border = theme.colors.statusTrack,
            borderWidth = stroke,
        }),
    }
    local battery = data.battery
    local fill = if battery then ringPath(ring, stroke, battery / 100) else nil
    if fill then
        children[#children + 1] = ui.path({
            key = "fill",
            w = ring,
            h = ring,
            viewBox = { 0, 0, ring, ring },
            d = fill,
            border = ringColor(battery :: number, data.charging),
            borderWidth = stroke,
            animate = theme.fade,
        })
    end
    children[#children + 1] = wifiGlyph(wifi, level)
    return ui.stack(children)
end

return {
    ringPath = ringPath,
    wifiLevel = wifiLevel,
    ringColor = ringColor,
    render = render,
}
