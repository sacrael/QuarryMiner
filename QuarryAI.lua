local robot = require("robot")
local component = require("component")
local config = require("config")
local computer = require("computer")

QuarryAI = {}

-- CONSTANTS
local ANALYZE_DIRECTION = {
    DOWN = 0,
    UP = 1,
    LEFT = 2,
    FRONT = 3,
    RIGHT = 4,
    BACK = 5
}

local tool_requirements = {
    -- omit slots, so we can have 1 free space that is not left empty due to 
    -- the item in the slot being equipt. Instead, search the 1st 4 slots and the 
    -- equipt slot
    
    {label = "pickaxe", type={ {name="minecraft:stone_pickaxe", required=true} }}, -- stone pickaxe
    {label= "iron pickaxe", type={ {name="minecraft:iron_pickaxe", required=true} }}, -- iron pickaxe
    {label = "shovel", type={ {name="minecraft:stone_shovel", required=true}, {name="monecraft:iron_shovel"} }}, -- stone/iron shovel
    {label = "axe", type={ {name="minecraft:stone_axe", required=true}, {name="minecraft:iron_axe"} }},  -- stone/iron axe
    {label = "silk pickaxe", type={ {name="tconstruct:pickaxe"} }} -- silk touch pixkaxe
}

-- Geolyzer.analyze
--  0 == down
--  1 == up
--  2 == left
--  3 == front
--  4 == right
--  5 == back

local function harvestableBlock(block_info)
    -- TODO implement
    return true
end

local function equiptOptimal (block_info)
    -- TODO implement
    -- Given information about the block we want to break, equipt the
    --  tool that will best break that block.
end

local function shouldHarvest (direction_index)
    if direction_index < 0 or direction_index > 5 then
        return false
    end

    block_info = component.geolyzer.analyze(direction_index)
    return harvestableBlock (block_info)
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
        robot.swingDown()
        robot.suckDown()
    end

    if shouldHarvest(ANALYZE_DIRECTION.UP) then
        equiptOptimal ( component.geolyzer.analyze(ANALYZE_DIRECTION.UP) )
        robot.swingUp()
        robot.suckUp()
    end

    -- check right
    if shouldHarvest(ANALYZE_DIRECTION.RIGHT) then
        equiptOptimal ( component.geolyzer.analyze(ANALYZE_DIRECTION.RIGHT) )
        robot.turnRight ()
        robot.swing ()
        robot.suck()
        robot.turnLeft ()
    end

    -- check left
    if shouldHarvest(ANALYZE_DIRECTION.LEFT) then 
        equiptOptimal ( component.geolyzer.analyze(ANALYZE_DIRECTION.LEFT) )
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
    --
end

local function shouldClearInventory ()

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