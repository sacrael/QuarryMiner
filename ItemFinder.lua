local robot = require("robot")
local config = require("config")

ItemFinder = {}

ItemFinder.tool_requirements = {
    {id = 1, name="minecraft:stone_pickaxe", required=true, info={harvestTool="pickaxe", harvestLevel=1}},
    {id = 2, name="minecraft:iron_pickaxe", required=true, info={harvestTool="pickaxe", harvestLevel=2}},
    {id = 3, name="minecraft:diamond_pickaxe", required=false, info={harvestTool="pickaxe", harvestLevel=3}},
    {id = 4, name="minecraft:stone_shovel", required=true, info={harvestTool="shovel", harvestLevel=1}},
    {id = 5, name="minecraft:iron_shovel", required=false, info={harvestTool="shovel", harvestLevel=2}},
    {id = 6, name="minecraft:stone_axe", required=true, info={harvestTool="axe", harvestLevel=1}},
    {id = 7, name="minecraft:iron_axe", required=false, info={harvestTool="axe", harvestLevel=2}},
    {id = 8, name="tconstruct:pickaxe", required=true, enchantments={"Fortune III"}, info={harvestTool="pickaxe", harvestLevel=3}}
}

local function tableContains (table_, value)
    for i = 1, #table_ do
        if table_[i] == value then
            return true
        end
    end
    return false
end

function ItemFinder.containsEnchantment (item_info, value)

    if item_info.enchantments == nil then return false end

    for i = 1, #item_info.enchantments do
        if item_info.enchantments[i].label == value then
            return true
        end
    end
    return false
end

function ItemFinder.analyzeTool (slot_info)
    -- given a slot info analyzed by inventory_controller, return
    -- the info table in tool_requirements if this is a tool listed.
    -- Otherwise, return nil

    if slot_info == nil then return nil end

    for i = 1, #ItemFinder.tool_requirements do
        if ItemFinder.tool_requirements[i].name == slot_info.name then
            -- further evaluate if this is the item
            
            -- (1) check if there are enchantment params and see if they apply to the item
            if ItemFinder.tool_requirements[i].enchantments ~= nil then

                for j=1, #ItemFinder.tool_requirements[i].enchantments do
                    if not ItemFinder.containsEnchantment(slot_info, ItemFinder.tool_requirements[i].enchantments[j]) then
                    -- if SLOT_INFO ENCHANTMENTS DOESNT HAVE TOOL_REQUIREMENT ENCHANTMENTS then
                        goto continue
                    end
                end

            end

            return ItemFinder.tool_requirements[i]

        end

        ::continue::
    end

    return nil
end

function ItemFinder.compareSlotWithBlock (block_info, slot_info, strict)
    -- Given a block, analyzed by the geolyzer, and a slot info,
    -- analyzed by the inventory_controller, return true if the item
    -- in the slot can be used to mine the block

    if slot_info == nil then return false end
    if block_info == nil then return false end

    -- print("Analyzing tool")
    local slot_tool = ItemFinder.analyzeTool(slot_info)
    if slot_tool == nil then return false end
    -- print("This is one of the core tools")

    -- print("slot_tool.info.harvestTool == block_info.harvestTool ? " .. tostring(slot_tool.info.harvestTool == block_info.harvestTool))
    -- print("slot_tool.info.harvestTool >= block_info.harbestLevel ? " .. tostring(slot_tool.info.harvestLevel >= block_info.harvestLevel))

    -- check if the tool has the required harvestLevel and harvestTool values
    if strict and slot_tool.info.harvestTool == block_info.harvestTool and slot_tool.info.harvestLevel == block_info.harvestLevel then
        return true
    elseif not strict and slot_tool.info.harvestTool == block_info.harvestTool and slot_tool.info.harvestLevel >= block_info.harvestLevel then
        return true
    end

    return false
end

function ItemFinder.findMinimumToolForBlock(block_info, equipt_tool)

    local minimum_level = nil
    local minimum_slot_index = nil

    -- first check with the already equipt tool
    if robot.durability () > 0 and ItemFinder.compareSlotWithBlock(block_info, equipt_tool, false) then
        local tool_analysis = ItemFinder.analyzeTool(equipt_tool)

        if tool_analysis.info.harvestLevel >= block_info.harvestLevel then
            minimum_slot_index = 0
            minimul_level = tool_analysis.info.harvestLevel - block_info.harvestLevel

            -- if the difference is 0, then this tool is alredy at the minimum level to mine the block, so return it
            if minimum_level == 0 then
                return 0
            end
        end
    end

    for i=config.TOOL_SLOTS.START, config.TOOL_SLOTS.END do

        local slot_info = component.inventory_controller.getStackInInternalSlot(i)


        if ItemFinder.compareSlotWithBlock(block_info, slot_info, false) then

            local slot_analysis = ItemFinder.analyzeTool(slot_info)

            if slot_analysis.info.harvestLevel >= block_info.harvestLevel 
            and (minimum_level == nil or slot_analysis.info.harvestLevel - block_info.harvestLevel < minimum_level) then
                minimum_slot_index = i
                minimum_level = slot_analysis.info.harvestLevel - block_info.harvestLevel

                -- if the difference is 0, then this tool is alredy at the minimum level to mine the block, so return it
                if minimum_level == 0 then
                    return minimum_slot_index
                end
            end

        end
    end

    -- return the index of the the least qualifiable tool
    return minimum_slot_index
    -- minimum_slot_index == 0 means qualified tool is already equip

end

return ItemFinder