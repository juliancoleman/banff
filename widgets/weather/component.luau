-- The housing's weather. As an island component named "weather", it gives the Island settings
-- (Settings > Styles & Widgets > Island > Weather) OmniWM's location editor and an Enabled switch.

local theme = require("../lib/banff/theme")
local weather = require("../lib/banff/weather")

return {
    views = {
        compact = function(ctx)
            return weather.render(ctx, (ctx.view and ctx.view.h) or theme.height)
        end,
    },
}
