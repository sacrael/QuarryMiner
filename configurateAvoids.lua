component = require("component")
robot = require("robot")
config = require("config")

ConfigureAvoids = {}

-- CONSTANTS
local DB_AVOID_SLOT_START = config.DB.AVOID_SLOTS.START
local DB_AVOID_SLOT_END = config.DB.AVOID_SLOTS.END

local function findFirstAvailableSlot ()
    for i = DB_AVOID_SLOT_START, DB_AVOID_SLOT_END do
        if component.database.get(i) == nil then
            return i
        end
    end
    return -1
end

local function alreadyExists (internal_slot) 
    -- check the databse between DB_AVOID_SLOT_START and DB_AVOID_SLOT_END to see if the item
    -- in internal_slot exists within
    for i = DB_AVOID_SLOT_START, DB_AVOID_SLOT_END do
        if component.inventory_controller.compareToDatabase(internal_slot, config.DB_ADDRESS, i) then
            return true
        end
    end

    return false
end

function ConfigureAvoids.beginConfiguration (block_count) 
    -- Breaks -block_count- blocks ahead of it and moves forward each time
    -- for each block it analyzes in front of it, the block is added to the database
    -- of blocks to avoid

    -- find first empty slot between the specified location for
    -- avoid items
    local slot_start = findFirstAvailableSlot ()

    if slot_start < 0 then
        error("No available slots in database between ".. DB_AVOID_SLOT_START .. " and " .. DB_AVOID_SLOT_END)
        return
    end

    -- add each item picked up into the database
    for i=1, robot.inventorySize() do 
        -- if the item isnt in the database
        if slot_start <= DB_AVOID_SLOT_END 
            and component.inventory_controller.getStackInInternalSlot(i) ~= nil
            and not alreadyExists(i) then
            -- add the component to the slot
            component.inventory_controller.storeInternal(i, config.DB_ADDRESS, slot_start)
            print("Successfully added item " .. i .. " to slot " .. slot_start)
            slot_start =  slot_start + 1

        elseif slot_start > DB_AVOID_SLOT_END then
            error ("DB ran out of space for avoid items on item " .. i)
        end
    end
end

return ConfigureAvoids