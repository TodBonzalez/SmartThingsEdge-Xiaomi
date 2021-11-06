local zcl_clusters = require "st.zigbee.zcl.clusters"
local capabilities = require "st.capabilities"

local WindowCovering = zcl_clusters.WindowCovering
local windowShade_defaults = require "st.zigbee.defaults.windowShade_defaults"

local json = require "dkjson"
local log  = require "log"

local can_handle = function(opts, driver, device)
    return device:supports_server_cluster(WindowCovering.ID)
end

local function added_handler(self, device)
    device:emit_event(capabilities.windowShade.supportedWindowShadeCommands({ value = { "open", "close", "pause"} }))
    device:refresh()
end

function current_lift_percentage_handler(ZigbeeDriver, ZigbeeDevice, value, zb_rx)
    value.value = 100 - value.value
    windowShade_defaults.default_current_lift_percentage_handler(ZigbeeDriver, ZigbeeDevice, value, zb_rx)
end

function window_shade_level_cmd(ZigbeeDriver, ZigbeeDevice, command)
    local level = 100 - command.args.shadeLevel
    ZigbeeDevice:send_to_component(command.component, WindowCovering.server.commands.GoToLiftPercentage(ZigbeeDevice, level))
end


-- local function do_configure(self, device)
--     device:send(device_management.build_bind_request(device, WindowCovering.ID, self.environment_info.hub_zigbee_eui))
--     device:send(WindowCovering.attributes.CurrentPositionLiftPercentage:configure_reporting(device, 5, 21600, 1))
--     super:do_configure
-- end


local blinds_handler = {
    NAME = "Blinds",
    supported_capabilities = {
        capabilities.windowShade,
        capabilities.windowShadeLevel,
        capabilities.windowShadePreset,
        capabilities.battery,
        capabilities.refresh,
    },
    lifecycle_handlers = {
        added = added_handler,
    },
    capability_handlers = {
        [capabilities.windowShadeLevel.ID] = {
            [capabilities.windowShadeLevel.commands.setShadeLevel.NAME] = window_shade_level_cmd
        }
    },
    zigbee_handlers = {
        attr = {
            [WindowCovering.ID] = {
                [WindowCovering.attributes.CurrentPositionLiftPercentage.ID] = current_lift_percentage_handler
            }
        }
    },
    can_handle = can_handle
}

return blinds_handler
