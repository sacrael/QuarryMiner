local robot = require("robot")
local component = require("component")
local config = require("config")
local computer = require("computer")
local ItemFinder = require("ItemFinder")

QuarryAI = {}

-- CONSTANTS
local ANALYZE_DIRECTION = {
    DOWN = 0,
    UP = 1,
    BACK = 2,
    FRONT = 3,
    RIGHT = 4,
    LEFT = 5,
}

-- Geolyzer.analyze
--  0 == down
--  1 == up
--  2 == left
--  3 == front
--  4 == right
--  5 == back

local active_tool = nil

local function equiptTool (slot_index)

    if slot_index < 1 or slot_index > robot.inventorySize()
    or robot.count(slot_index) == 0 then
        print ("Cannot equip...")
    end

    local stack_info = component.inventory_controller.getStackInInternalSlot(slot_index)
    if stack_info ~= nil then
        -- only equip if there is actually something in the slot we are trying to 
        -- equipt from.
        active_tool = stack_info
        robot.select(slot_index)
        component.inventory_controller.equip()
    end
end

local function equiptFortune ()

    if ItemFinder.analyzeTool(active_tool).id == 8 then
        return true
    end

    -- find the fortune pick and equip it
    for i = config.TOOL_SLOTS.START, config.TOOL_SLOTS.END do
        local stack_info = component.inventory_controller.getStackInInternalSlot(i)
        local tool_info = ItemFinder.analyzeTool( stack_info )
        if tool_info ~= nil and tool_info.id == 8 then
            -- equip it
            active_tool = stack_info
            robot.select(i)
            component.inventory_controller.equip ()
            return true
        end
    end

    return false

end

function QuarryAI.harvestableBlock(block_info)

    for i = config.DB.AVOID_SLOTS.START, config.DB.AVOID_SLOTS.END do
        -- if any of the blocks in the avoid slot is equal to block_info, then return false
        if component.database.get(i) ~= nil and component.database.get(i).name == block_info.name then
            print("Block of name " .. block_info.name .. " CANNOT be harvested.")
            return false
        end
    end

    print("Block of name " .. block_info.name .. " can be harvested.")
    return true

end

function QuarryAI.fortunateBlock(block_info)
    -- return true if this block is a block that should be harvested with
    -- a fortune pick
    for i = config.DB.FORTUNE_SLOTS.START, config.DB.FORTUNE_SLOTS.END do
        if component.database.get(i) ~= nil and component.database.get(i).name == block_info.name then
            print("BLock of name " .. block_info.name .. " is fortunate.")
            return true
        end
    end
    
    return false
end

local function equiptOptimal (block_info)
    -- TODO implement
    -- Given information about the block we want to break, equipt the
    --  tool that will best break that block.

    if QuarryAI.fortunateBlock(block_info) and equiptFortune() then
        print("fortune pick equipt")
    else
        local minimum_tool = ItemFinder.findMinimumToolForBlock(block_info, active_tool)
        if minimum_tool > 0 then
            equiptFortune(minimum_tool)
        end
    end


end

local function shouldHarvest (block_info)

    return QuarryAI.harvestableBlock ( block_info )
end

local function sortByPriority (a, b)
    return a.priority < b.priority
end

function QuarryAI.analyzeNextDepth ()
    -- assumption: robot is already positioned in the line it needs to mine in
    --  and is facing the direction parallel to the line
    -- expects: robot moves 1 step deeper into the line and checks for
    --  any important ores to mine/collect

    -- first, clear anything in front of it, pick it up if it is good material
    if robot.detect () then
        -- check if the block detected is what we want
        local block_info = component.geolyzer.analyze(ANALYZE_DIRECTION.FRONT)
        if shouldHarvest (block_info) then
            equiptOptimal ( block_info )
            print ("Optimal weapon equipt for front block")
            robot.swing ()
            robot.suck ()
        else
            robot.swing ()
        end
    end

    -- then, move forward and analyze up, down, left and right
    local block_info
    robot.forward ()

    block_info = component.geolyzer.analyze(ANALYZE_DIRECTION.DOWN)
    if shouldHarvest(block_info) then
        equiptOptimal ( block_info )
        print ("Optimal weapon equipt for down block")
        robot.swingDown()
        robot.suckDown()
    end

    block_info = component.geolyzer.analyze(ANALYZE_DIRECTION.UP)
    if shouldHarvest(block_info) then
        equiptOptimal ( block_info )
        print ("Optimal weapon equipt for up block")
        robot.swingUp()
        robot.suckUp()
    end

    -- check right
    block_info = component.geolyzer.analyze(ANALYZE_DIRECTION.RIGHT)
    if shouldHarvest(block_info) then
        equiptOptimal ( block_info )
        print ("Optimal weapon equipt for right block")
        robot.turnRight ()
        robot.swing()
        robot.suck()
        robot.turnLeft ()
    end

    -- check left
    block_info = component.geolyzer.analyze(ANALYZE_DIRECTION.LEFT)
    if shouldHarvest(block_info) then
        equiptOptimal ( block_info )
        print ("Optimal weapon equipt for left block")
        robot.turnLeft ()
        robot.swing()
        robot.suck()
        robot.turnRight ()
    end

end

local function shouldCharge ()
    -- default
    return (computer.energy() / computer.maxEnergy()) < 0.4
end

local function shouldReplenishTools ()
    -- check in the slots highlighted for tool storage and active
    -- hand slot, see if every item identified as required is
    -- in these slots

    local tools_ = {}
    for i=config.TOOL_SLOTS.START, config.TOOL_SLOTS.END do
        if robot.count(i) > 0 then
            table.insert( tools_, component.inventory_controller.getStackInInternalSlot(i) )
        end
    end

    -- get the tool that is equip
    robot.select(1)
    component.inventory_controller.equip ()
    if robot.count(1)  > 0 then
        table.insert( tools_, component.inventory_controller.getStackInInternalSlot(1) )
    end
    -- not necessary to re-equipt original tool since we equiptOptimal before we break
    -- any block

    -- analyze tools_ with tool_requirements. If any required tools are not present,
    -- we have to return to base to replenish tools
    for i = 1, #ItemFinder.tool_requirements do
        if ItemFinder.tool_requirements[i].required then

            -- check through all the tools in my inventory
            local tool_found = false
            for j = 0, #tools_ do

                -- if the tool has been found and it has the same tool
                -- id, then we set tool_found to true and break
                local tool_info = ItemFinder.analyzeTool(tools_[j])
                if tool_info.id == ItemFinder.tool_requirements[i].id then
                    tool_found = true
                    break
                end
            end

            -- if the tool has not been found, then we need to return
            -- to base to replenish the tools
            if not tool_found then return true end

        end
    end
    return false

end

local function shouldClearInventory ()

    -- check if there is at least 1 slot available b/w 5 and 16
    for i = config.RESOURCE_SLOTS.START, config.RESOURCE_SLOTS.END do
        if i <= robot.inventorySize () and robot.count(i) == 0.0 then
            return true
        end
    end

    return false

end

local function returnToBase (arg)
    local purpose = arg.purpose == nil and "clear inventory" or arg.purpose

end

function QuarryAI.clearDepth (starting_depth)
    -- starting_depth specifies from where in the depth we are starting from.
    -- This is necessary in the case where we are returning to a position that
    -- was stopped preemptively due to insufficient tools or low battery

    for i=starting_depth, config.MINE_DEPTH do

        if shouldCharge () then
            returnToBase{purpose="recharge"}
            return
        elseif shouldReplenishTools () then
            returnToBase{purpose="replenish tools"}
            return
        elseif shouldClearInventory () then
            returnToBase{purpose="clear inventory"}
        else
            QuarryAI.analyzeNextDepth ()
        end
    end
end

return QuarryAI
