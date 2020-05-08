local QuarryAI = require("QuarryAI")

local TEST_ID = 0

-- First Test: analyzeNextDepth
if TEST_ID == 0 then
    QuarryAI.analyzeNextDepth ()
elseif TEST_ID == 1 then
    
    for i = 1, 5 do
        QuarryAI.analyzeNextDepth ()
    end
end