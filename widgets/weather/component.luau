-- The housing's weather. As an island component named "weather", it gives the Island settings
-- (Settings > Styles & Widgets > Island > Weather) OmniWM's location editor and an Enabled switch.
-- The root passes its presentation ("notch" or "pill") in the view's props.

local theme = require("../lib/banff/theme")
local weather = require("../lib/banff/weather")

return {
    views = {
        compact = function(ctx)
            local view = ctx.view
            local props = view and view.props
            local z = theme.sizes[(props and props.size) or "notch"] or theme.sizes.notch
            return weather.render(ctx, (view and view.h) or z.height, z)
        end,
    },
}
