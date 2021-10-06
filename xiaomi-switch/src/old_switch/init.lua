local zcl_clusters = require "st.zigbee.zcl.clusters"
local capabilities = require "st.capabilities"

local OnOff = zcl_clusters.OnOff
local log = require "log"
local utils = require "utils"

function old_button_handler(device, component_id, value)
    local CLICK_TIMER  = string.format("button_timer%d", component_id)
    local UP_COUNTER   = string.format("up_counter%d"  , component_id)
    local DOWN_COUNTER = string.format("down_counter%d", component_id)
    
    local click_timer = device:get_field(CLICK_TIMER)
    local down_counter = device:get_field(DOWN_COUNTER)
    local up_counter = device:get_field(UP_COUNTER)
  
    local held = function()
      local f_down_counter = device:get_field(DOWN_COUNTER)
      local f_up_counter = device:get_field(UP_COUNTER)
      local button = capabilities.button.button
      log.warn(">>> up_counter: " .. tostring(f_up_counter) .. ", down_counter: " .. tostring(f_down_counter))
  
      local click_type
      if f_down_counter == 1 and f_up_counter == 0 then
        click_type = button.held
      elseif f_down_counter < f_up_counter then
        click_type = button.up
        log.warn("WTF up_counter: " .. tostring(f_up_counter) .. "> down_counter: " .. tostring(f_down_counter))
      else
        click_type = utils.click_types[f_down_counter]   
      end
      
      device:emit_event_for_endpoint(component_id, click_type({state_change = true}))
      device:set_field(CLICK_TIMER, nil)
      device:set_field(DOWN_COUNTER, 0)
      device:set_field(UP_COUNTER, 0)
    end

    if click_timer then
        if not value.value then
            down_counter = down_counter + 1
            device:set_field(DOWN_COUNTER, down_counter)
        else
            up_counter = up_counter + 1
            device:set_field(UP_COUNTER, up_counter)
        end
        else
        if not value.value then
            timer = device.thread:call_with_delay(1, held)
            device:emit_event_for_endpoint(component_id, capabilities.button.button.down())

            device:set_field(CLICK_TIMER, timer)
            device:set_field(DOWN_COUNTER, 1)
            device:set_field(UP_COUNTER, 0)
        else
            --log.warn("up without down, from previous held?")
        end
    end
end

function on_off_attr_handler(driver, device, value, zb_rx)
    local ep = zb_rx.address_header.src_endpoint.value
    local first_button_ep = utils.first_button_ep(device)

    if ep < first_button_ep  then
        local attr = capabilities.switch.switch
        local component_id = ep - utils.first_switch_ep(device) + 1
        device:emit_event_for_endpoint(component_id, value.value and attr.on() or attr.off())
    else
        local click_type = zb_rx.body_length.value>8 and capabilities.button.button.pushed or capabilities.button.button.held
        
        local component_id = ep - first_button_ep + 1
        local event = click_type({state_change = true})

        log.warn(" old button " .. tostring(component_id) .. " " .. tostring(event))
        if not value.value then
            device:emit_event_for_endpoint(component_id, event)
        end
        --old_button_handler(device, component_id, value)
    end
end


local old_switch_handler = {
    NAME = "Old Switch Handler",
    zigbee_handlers = {
        attr = {
            [OnOff.ID] = {
                [OnOff.attributes.OnOff.ID] = on_off_attr_handler
            }
        },
    },
    can_handle = function(opts, driver, device)
        return utils.first_switch_ep(device) > 0 and utils.first_button_ep(device) == 4
    end
}

return old_switch_handler