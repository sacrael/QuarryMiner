local robot = require("robot")
local component = require("component")
local config = require("config")
local computer = require("computer")
local ItemFilter = require("ItemFilter")

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

local tool_requirements = {
    -- omit slots, so we can have 1 free space that is not left empty due to
    -- the item in the slot being equipt. Instead, search the 1st 4 slots and the
    -- equipt slot

    {label = "pickaxe",         required=true,      type={ {name="minecraft:stone_pickaxe", priority=1} }}, -- stone pickaxe
    {label= "iron pickaxe",     required=true,      type={ {name="minecraft:iron_pickaxe", priority=1} }}, -- iron pickaxe
    {label = "shovel",          required=true,      type={
                                                            {name="minecraft:stone_shovel", priority=1},
                                                            {name="monecraft:iron_shovel", priority=2}
                                                        }},
    {label = "axe",             required=true,      type={
                                                            {name="minecraft:stone_axe", priority=1},
                                                            {name="minecraft:iron_axe", priority=2}
                                                        }},
    {label = "silk pickaxe",    required=false,     type={ {
                                                             name="tconstruct:pickaxe",
                                                            filter= function(item) ItemFilter.Tinker(item, {"Silk Touch"}) end,
                                                            priority=1} }} -- silk touch pixkaxe
}

-- Geolyzer.analyze
--  0 == down
--  1 == up
--  2 == left
--  3 == front
--  4 == right
--  5 == back

local function harvestableBlock(block_info)

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

local function equiptOptimal (block_info)
    -- TODO implement
    -- Given information about the block we want to break, equipt the
    --  tool that will best break that block.

    local harvest_tool = block_info.harvestTool
    -- if there is no specified harvest tool, then any tool will do
    -- (this will rearly happen as most blocks have an optimal harvest tool)
    if harvest_tool ~= nil then

    end

end

local function shouldHarvest (direction_index)
    if direction_index < 0 or direction_index > 5 then
        return false
    end

    return harvestableBlock ( component.geolyzer.analyze(direction_index) )
end

local function sortByPriority (a, b)
    return a.priority < b.priority
end

function QuarryAI.prepare ()
    for i=1, #tool_requirements do
        table.sort (tool_requirements[i].type, sortByPriority)
    end
end

function QuarryAI.analyzeNextDepth ()
    -- assumption: robot is already positioned in the line it needs to mine in
    --  and is facing the direction parallel to the line
    -- expects: robot moves 1 step deeper into the line and checks for
    --  any important ores to mine/collect

    -- first, clear anything in front of it, pick it up if it is good material
    if robot.detect () then
        -- check if the block detected is what we want
        if shouldHarvest (ANALYZE_DIRECTION.FRONT) then
            equiptOptimal ( component.geolyzer.analyze(ANALYZE_DIRECTION.FRONT) )
            print ("Optimal weapon equipt for front block")
            robot.swing ()
            robot.suck ()
        else
            robot.swing ()
        end
    end

    -- then, move forward and analyze up, down, left and right
    robot.forward ()

    if shouldHarvest(ANALYZE_DIRECTION.DOWN) then
        equiptOptimal ( component.geolyzer.analyze(ANALYZE_DIRECTION.DOWN) )
        print ("Optimal weapon equipt for down block")
        robot.swingDown()
        robot.suckDown()
    end

    if shouldHarvest(ANALYZE_DIRECTION.UP) then
        equiptOptimal ( component.geolyzer.analyze(ANALYZE_DIRECTION.UP) )
        print ("Optimal weapon equipt for up block")
        robot.swingUp()
        robot.suckUp()
    end

    -- check right
    if shouldHarvest(ANALYZE_DIRECTION.RIGHT) then
        equiptOptimal ( component.geolyzer.analyze(ANALYZE_DIRECTION.RIGHT) )
        print ("Optimal weapon equipt for right block")
        robot.turnRight ()
        robot.swing ()
        robot.suck()
        robot.turnLeft ()
    end

    -- check left
    if shouldHarvest(ANALYZE_DIRECTION.LEFT) then
        equiptOptimal ( component.geolyzer.analyze(ANALYZE_DIRECTION.LEFT) )
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

local function hasTool (toolset, tool_name)

    for i = 1, #toolset do
        if toolset[i].name == tool_name then
            return true
        end
    end
    return false

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
    for i=1, #tool_requirements do
        if tool_requirements[i].required then

            -- check if any variation of this required too exists in out toolset
            local tool_found = false
            for j = 1, #tool_requirements[i].type do

                if hasTool(tools_, tool_requirements[i].type[j].name) then
                    tool_found = true
                end

            end

            -- if we didnt find one of the required tools, then we should replenish tools
            if not tool_found then
                return true
            end

        end
    end

    -- we have all required tools. Do not need to replenish
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
