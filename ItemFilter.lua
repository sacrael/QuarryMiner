
ItemFilter = {}

function ItemFilter.Tinker (item_info, enchantment_req, label_req)

    -- if the item is not part of tinker's construct, return false
    if item_info.name == nil or item_info.sub(1, 10) ~= 'tconstruct' then
        return false
    
    -- if there are enchantment requirements but the item does not match
    -- the enchantment requirements, return false
    elseif enchantment_req ~= nil then

        if item_info.enchantments == nil then
            return false
        end

        for i=1, #enchantment_req do
            local enchantment_label = enchantment_req[i]
            local enchantment_found = false

            for j=1, #item_info.enchantments do
                if item_info.enchantments[j].label == enchantment_label then
                    enchantment_found = true
                end
            end

            if ~enchantment_found then
                return false
            end

        end

    -- if there are label requirements, but the item does not have the required
    -- label, return false
    elseif label_req ~= nil and item_info.label ~= label_req then
        return false 
    end

    -- if passes all requirements (has not yet returned false), then return true
    return true

end

return ItemFilter