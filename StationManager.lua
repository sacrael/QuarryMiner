-- Station Manager
--  manages functions that the robot uses to interact with its
--  setup station

local robot = require("robot")
local component = require("component")

local StationManager = {}

-- we assume y-displacement is always 0, so we have to reset any forward/backeward movement that we do
local x_displacement = 0
local z_displacement = 0

local station_points = {
    ore_storage_1 = {z = 1, x = -1},
    ore_storage_2 = {z = -1, x = -1},
    tool_storage = {x = -2},

    -- where we store the coal if our generator is not using it
    energy_resource_storage = {x = 1},

    -- where we store the coal to enter the generator
    energy_usage_storage = {x = 2, z = 2, y = 1}
}

local function stationMotion (displacement_vec, static_action_function)
    -- displacement_vec (table): describes where within the station we want our robot to move
    -- static_action_function (function): describes the function to execute once we reach the position
    --      we want in our station.
    --      This is not separated into a separate function bc, if we ever have a y displacement, we need
    --      to execute our function after applying y displacement, then reset the y displacement to 0 after
    --      the function is executed so that our assumption remains true that y displacement should always be 0
    --      after the execution of any of our functions

    print ("In StationMotion:")
    
    for k, v in pairs(displacement_vec) do
        print(k, v)
    end

    local x_disp_ = displacement_vec.x == nil and 0 or displacement_vec.x
    x_disp_ = x_disp_ - x_displacement

    print ("x disp: ".. x_disp_)

    local z_disp_ = displacement_vec.z == nil and 0 or displacement_vec.z
    z_disp_ = z_disp_ - z_displacement

    print ("z disp: ".. z_disp_)
    -- at the end of our motion, y_displacement needs to be reset
    local y_disp_ = displacement_vec.y == nil and 0 or displacement_vec.y

    print ("y disp: " .. y_disp_)

    -- if no motion is to be executed, do not move
    if x_disp_ == 0 and y_disp_ == 0 and z_disp_ == 0 then
        return
    end

    -- move in x dimension first
    if x_disp_ > 0 then
        -- moveing right
        robot.turnRight()
    elseif x_disp_ < 0 then
        robot.turnLeft()
    end

    for i = 1, math.abs(x_disp_) do
        robot.forward ()
    end
    
    -- reset rotations
    if x_disp_ > 0 then
        robot.turnLeft()
    elseif x_disp_ < 0 then
        robot.turnRight()
    end

    -- then move in the z dimension
    for i = 1, math.abs(z_disp_) do
        if z_disp_ > 0 then
            robot.up()
        elseif z_disp_ < 0 then
            robot.down()
        end
    end

    -- move in the y dimension if we have any
    for i = 1, math.abs(y_disp_) do
        if y_disp_ > 0 then
            robot.forward ()
        elseif y_disp_ < 0 then
            robot.back()
        end
    end

    -- execute our action
    static_action_function ()

    -- reset y displacement
    for i = 1, math.abs(y_disp_) do
        if y_disp_ > 0 then
            robot.back ()
        elseif y_disp_ < 0 then
            robot.forward()
        end
    end

    -- now store our x and z displacement globally so it remains consistent with future motion
    x_displacement = x_displacement + x_disp_
    z_displacement = z_displacement + z_disp_

end

function StationManager.informPositionReset ()
    x_displacement = 0
    z_displacement = 0
end

function belongsInOreStorage () 
    -- TODO implement
    return true
end

function findAndDropOres ()
    -- loop through the iventory and determine if the item is
    -- an ore. If so, drop it into chest.
    for i = 1, robot.inventorySize () do 
        -- if the item should be in our ore storage, drop it there
        if belongsInOreStorage (component.inventory_controller.getStackInInternalSlot(i)) then
            robot.drop(i)
        end
    end
end

function StationManager.depositOresIntoStorage (storage_id)
    -- move to the storage location
    -- TODO make it store items into chest

    print ("In depositOresIntoStorage()")
    print ("\tStorage ID: " .. storage_id)
    if storage_id == 1 then
        stationMotion(station_points.ore_storage_1, findAndDropOres)
    elseif storage_id == 2 then
        stationMotion(station_points.ore_storage_2, findAndDropOres)
    end
end


return StationManager