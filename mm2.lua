local HttpService = game:GetService("HttpService")
local API_URL = "https://mm2-api.onrender.com/api/all"

local Lib = loadstring(game:HttpGet("https://raw.githubusercontent.com/qisery/mm2/main/ui.lua"))() or INSui



local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local function getMouse()
    local ok, pos = pcall(function()
        return UserInputService:GetMouseLocation()
    end)

    if ok and pos then
        local inset = GuiService and GuiService:GetGuiInset() or Vector2.new(0, 0)
        return { X = pos.X - inset.X, Y = pos.Y - inset.Y }
    end

    return { X = 0, Y = 0 }
end
if not Lib then
    warn("Failed to load INS-ui")
    return
end

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local RoundTimerEnabled = false
local TimerLabel = Drawing.new("Text")
TimerLabel.Visible = false
TimerLabel.Center = true
TimerLabel.Outline = true
TimerLabel.Font = 2 -- UI
TimerLabel.Size = 28
TimerLabel.Color = Color3.fromRGB(255, 215, 0)
TimerLabel.Position = Vector2.new(500, 20) -- Will be updated in Heartbeat

pcall(function()
    local cam = workspace.CurrentCamera
    if cam then
        TimerLabel.Position = Vector2.new(cam.ViewportSize.X / 2, 20)
    end
end)

Lib:ApplyThemePreset("Crimson")
Lib:SetBackgroundEffect("Snow")
Lib:SetRounding(0)
Lib:SetRowLines(true)

local win = Lib:CreateWindow({
    title = "LeatherHub MM2",
    subtitle = "Search: Ctrl+Space",
    logo = "https://raw.githubusercontent.com/qisery/mm2/main/moto1.jpg",
    logoSize = 32,
    size = Vector2 and Vector2.new(950, 650) or nil,
    menuKey = "RightAlt",
    autoSave = false,
    smartFps = false
})

Lib:Notify("Loading...", "Fetching values from server, please wait.", 3)

local success, response = pcall(function()
    return game:HttpGet(API_URL)
end)

if not success or not response then
    Lib:Notify("Error!", "Could not reach API.", 5, "error")
    return
end

local decodedData = HttpService:JSONDecode(response)
local allItems = decodedData.items

local groupedItems = {}
local dropdownOptions = {} 
local itemValuesMap = {}   
local cleanNameToFullText = {}

for _, item in ipairs(allItems) do
    if item.name == "Ice Wing" then
        item.name = "Icewing"
    elseif item.name == "Gold Edlerwood Blade" then
        item.name = "Gold Elderwood Blade"
    end
    
    local cat = item.category
    if not groupedItems[cat] then
        groupedItems[cat] = {}
    end
    table.insert(groupedItems[cat], item)
    
    local valStr = tostring(item.value):gsub(",", "")
    local valNum = tonumber(valStr) or 0
    
    local dropText = item.name .. " [Val: " .. item.value .. "]"
    itemValuesMap[dropText] = valNum
    local cleaned = item.name:lower():gsub("[^%w]", "")
    if not cleanNameToFullText[cleaned] or valNum > (itemValuesMap[cleanNameToFullText[cleaned]] or 0) then
        cleanNameToFullText[cleaned] = dropText
    end
    table.insert(dropdownOptions, dropText)
end

table.sort(dropdownOptions, function(a, b)
    local valA = itemValuesMap[a] or 0
    local valB = itemValuesMap[b] or 0
    if valA == valB then
        return a < b
    end
    return valA > valB
end)

local function addItemToSection(section, item)
    local text = string.format("%s | Value: %s | Demand: %s | Stability: %s", 
        item.name, item.value, item.demand, item.stability)
    
    section:Button(text, function()
        Lib:Notify(item.name, "Value: " .. item.value .. "\nPress Ctrl+C to copy", 3)
    end)
end



local tradeTab = win:Tab("Trade Checker", "swords")

local yourSec = tradeTab:Section("Your Offer", "Left")
local theirSec = tradeTab:Section("Their Offer", "Right")
local resSec = tradeTab:Section("Result", "Full")

local yourTotal = 0
local theirTotal = 0

local yourValLabel = yourSec:Label("Total Value: 0")
local theirValLabel = theirSec:Label("Total Value: 0")
local finalResLabel = resSec:Label("Status: Waiting for items...")

local function updateResult()
    if yourTotal == 0 and theirTotal == 0 then
        finalResLabel:SetText("Status: Waiting for items...")
        finalResLabel:SetColor(Color3.fromRGB(200, 200, 200))
    elseif yourTotal > theirTotal then
        local loss = yourTotal - theirTotal
        finalResLabel:SetText("YOU LOSE! (Loss: " .. tostring(loss) .. ")")
        finalResLabel:SetColor(Color3.fromRGB(255, 50, 50))
    elseif theirTotal > yourTotal then
        local profit = theirTotal - yourTotal
        finalResLabel:SetText("YOU WIN! (Profit: " .. tostring(profit) .. ")")
        finalResLabel:SetColor(Color3.fromRGB(50, 255, 50))
    else
        finalResLabel:SetText("FAIR TRADE! (Equal Value)")
        finalResLabel:SetColor(Color3.fromRGB(255, 255, 255))
    end
end


local function getMyInventoryOptions()
    local pGui = game.Players.LocalPlayer:FindFirstChild("PlayerGui")
    if not pGui then return dropdownOptions end
    local inv = pGui:FindFirstChild("MainGUI") and pGui.MainGUI:FindFirstChild("Game") and pGui.MainGUI.Game:FindFirstChild("Inventory")
    if not inv then return dropdownOptions end
    local itemsContainer = inv:FindFirstChild("Main") and inv.Main:FindFirstChild("Weapons") and inv.Main.Weapons:FindFirstChild("Items") and inv.Main.Weapons.Items:FindFirstChild("Container")
    if not itemsContainer then return dropdownOptions end
    
    local foundItems = {}
    local totalValue = 0
    
    local function extractItem(itemFrame)
        if itemFrame:IsA("Frame") and itemFrame.Name:match("NewItem") then
            local itemNameFolder = itemFrame:FindFirstChild("ItemName")
            if itemNameFolder then
                local label = itemNameFolder:FindFirstChild("Label")
                if label and label:IsA("TextLabel") then
                    local rawText = label.Text or ""
                    local itemName = rawText:gsub("<[^>]+>", ""):match("^%s*(.-)%s*$")
                    if itemName and itemName ~= "" and itemName:lower() ~= "label" then
                        
                        local multiplier = 1
                        local itemLower = itemName:lower()
                        local multMatch1 = itemLower:match("x%s*(%d+)$")
                        local multMatch2 = itemLower:match("%(x%s*(%d+)%)$")
                        
                        if multMatch1 then multiplier = tonumber(multMatch1) or 1
                        elseif multMatch2 then multiplier = tonumber(multMatch2) or 1 end
                        
                        if multiplier == 1 then
                            for _, desc in ipairs(itemFrame:GetDescendants()) do
                                if desc:IsA("TextLabel") then
                                    local dName = desc.Name:lower()
                                    if dName:match("quant") or dName:match("amount") or dName:match("count") then
                                        local txt = desc.Text or ""
                                        local m = txt:match("x%s*(%d+)") or txt:match("^(%d+)$")
                                        if m then
                                            multiplier = tonumber(m) or 1
                                            break
                                        end
                                    end
                                end
                            end
                        end
                        
                        local cleanName = itemLower:gsub("%s*x%s*%d+$", ""):gsub("%s*%(x%s*%d+%)$", ""):match("^%s*(.-)%s*$")
                        
                        local isChroma = false
                        local descendants = itemFrame:GetDescendants()
                        for i = 1, #descendants do
                            local desc = descendants[i]
                            local dName = string.lower(desc.Name or "")
                            if string.find(dName, "chroma", 1, true) then
                                isChroma = true
                                break
                            elseif desc:IsA("TextLabel") and string.find(string.lower(desc.Text or ""), "chroma", 1, true) then
                                isChroma = true
                                break
                            elseif desc:IsA("ImageLabel") and string.find(desc.Image or "", "4589252033", 1, true) then
                                isChroma = true
                                break
                            end
                        end
                        
                        if isChroma and not string.find(cleanName, "chroma", 1, true) then
                            cleanName = "chroma " .. cleanName
                        end
                        
                        local targetClean = cleanName:gsub("[^%w]", "")
                        local fullText = cleanNameToFullText[targetClean]
                        if fullText then
                            local val = itemValuesMap[fullText] or 0
                            foundItems[fullText] = (foundItems[fullText] or 0) + multiplier
                            totalValue = totalValue + (val * multiplier)
                        end
                    end
                end
            end
        end
    end
    
    for _, tab in ipairs(itemsContainer:GetChildren()) do
        if tab:IsA("ScrollingFrame") then
            local tabContainer = tab:FindFirstChild("Container")
            if tabContainer then
                for _, child in ipairs(tabContainer:GetChildren()) do
                    if child:IsA("Frame") and child.Name:match("NewItem") then
                        extractItem(child)
                    elseif child:IsA("Frame") and child.Name ~= "UIGridLayout" and child.Name ~= "EventLayout" then
                        local eventContainer = child:FindFirstChild("Container")
                        if eventContainer then
                            for _, evChild in ipairs(eventContainer:GetChildren()) do
                                extractItem(evChild)
                            end
                        end
                    end
                end
            end
        end
    end
    
    local sorted = {}
    for item, qty in pairs(foundItems) do 
        local displayStr = item
        if qty > 1 then
            local namePart, restPart = item:match("^(.-)(%s*%[Val:.*)$")
            if namePart and restPart then
                displayStr = namePart .. " (x" .. tostring(qty) .. ")" .. restPart
            else
                displayStr = item .. " (x" .. tostring(qty) .. ")"
            end
        end
        table.insert(sorted, displayStr) 
    end
    table.sort(sorted, function(a, b)
        local cleanA = a:gsub("%s*%(x%d+%)", "")
        local cleanB = b:gsub("%s*%(x%d+%)", "")
        local valA = itemValuesMap[cleanA] or 0
        local valB = itemValuesMap[cleanB] or 0
        if valA == valB then return a < b end
        return valB < valA
    end)
    
    return sorted, totalValue
end

local myInventoryOptions, myTotalValue = getMyInventoryOptions()

local yourSelectedInv = {}
local yourSelectedAll = {}

local function updateYourTotal()
    yourTotal = 0
    for _, dropText in ipairs(yourSelectedInv) do
        local cleanDropText = dropText:gsub("%s*%(x%d+%)", "")
        local qty = tonumber(dropText:match("%(x(%d+)%)")) or 1
        yourTotal = yourTotal + ((itemValuesMap[cleanDropText] or 0) * qty)
    end
    for _, dropText in ipairs(yourSelectedAll) do
        local cleanDropText = dropText:gsub("%s*%(x%d+%)", "")
        local qty = tonumber(dropText:match("%(x(%d+)%)")) or 1
        yourTotal = yourTotal + ((itemValuesMap[cleanDropText] or 0) * qty)
    end
    yourValLabel:SetText("Total Value: " .. tostring(yourTotal))
    updateResult()
end

local yourDropdownInv = yourSec:Dropdown("Select From Inventory", {}, myInventoryOptions, true, function(selected)
    yourSelectedInv = selected
    updateYourTotal()
end, "Search your owned weapons", true)

local totalInvLabel = yourSec:Label("Total Inventory Value: " .. tostring(myTotalValue))

yourSec:Button("Refresh Inventory", function()
    local newOpts, newTotal = getMyInventoryOptions()
    myInventoryOptions = newOpts
    if yourDropdownInv.UpdateChoices then
        yourDropdownInv:UpdateChoices(myInventoryOptions)
        totalInvLabel:SetText("Total Inventory Value: " .. tostring(newTotal))
        Lib:Notify("Success", "Inventory refreshed! Total Value: " .. tostring(newTotal), 3, "success")
    end
end)

local yourDropdownAll = yourSec:Dropdown("Select From All Items", {}, dropdownOptions, true, function(selected)
    yourSelectedAll = selected
    updateYourTotal()
end, "Search any weapon", true)

yourSec:Button("Clear Your Offer", function()
    if yourDropdownInv.Set then yourDropdownInv:Set({}) end
    if yourDropdownAll.Set then yourDropdownAll:Set({}) end
    yourSelectedInv = {}
    yourSelectedAll = {}
    updateYourTotal()
end)

local theirDropdown = theirSec:Dropdown("Select Items", {}, dropdownOptions, true, function(selected)
    theirTotal = 0
    for _, dropText in ipairs(selected) do
        local cleanDropText = dropText:gsub("%s*%(x%d+%)", "")
        local qty = tonumber(dropText:match("%(x(%d+)%)")) or 1
        theirTotal = theirTotal + ((itemValuesMap[cleanDropText] or 0) * qty)
    end
    theirValLabel:SetText("Total Value: " .. tostring(theirTotal))
    updateResult()
end, "Search and select their weapons", true)

theirSec:Button("Clear Their Offer", function()
    theirDropdown:Set({})
end)

theirSec:Divider("Profile Scanner")

local function cleanString(str)
    return tostring(str):lower():gsub("[^%w]", "")
end

local function findFullItemName(cleanName)
    local target = cleanString(cleanName)
    return cleanNameToFullText[target]
end

local function getProfileItems()
    local detected = {}
    local pGui = LocalPlayer:FindFirstChild("PlayerGui")
    if not pGui then return detected end
    
    local vp = pGui.MainGUI.Game:FindFirstChild("ViewProfile")
    if not vp then return detected end
    
    local main = vp:FindFirstChild("Main")
    if not main then return detected end
    
    local w = main:FindFirstChild("Weapons")
    if not w then return detected end
    
    local items = w:FindFirstChild("Items")
    if not items then return detected end
    
    for _, child in ipairs(items:GetDescendants()) do
        if child:IsA("Frame") and (child.Name:match("^NewItem") or child.Name:match("^Item_")) then
            local itemNameFrame = child:FindFirstChild("ItemName")
            local label = itemNameFrame and itemNameFrame:FindFirstChild("Label")
            if label and label:IsA("TextLabel") and label.Text ~= "" and label.Text ~= "Label" and label.Text ~= "Loading..." then
                local rawText = label.Text or ""
                local cleanName = rawText:gsub("<[^>]+>", ""):match("^%s*(.-)%s*$")
                if cleanName and cleanName ~= "" then
                    cleanName = cleanName:lower():gsub("%s*x%s*%d+$", ""):gsub("%s*%(x%s*%d+%)$", "")
                    
                    local isChroma = false
                    for _, desc in ipairs(child:GetDescendants()) do
                        local dName = string.lower(desc.Name or "")
                        if string.find(dName, "chroma", 1, true) then
                            isChroma = true
                            break
                        elseif desc:IsA("TextLabel") and string.find(string.lower(desc.Text or ""), "chroma", 1, true) then
                            isChroma = true
                            break
                        elseif desc:IsA("ImageLabel") and string.find(desc.Image or "", "4589252033", 1, true) then
                            isChroma = true
                            break
                        end
                    end
                    
                    if isChroma and not string.find(cleanName, "chroma", 1, true) then
                        cleanName = "chroma " .. cleanName
                    end
                    
                    table.insert(detected, cleanName)
                end
            end
        end
    end
    return detected
end

local detectedDropdown

theirSec:Button("Scan Opened Profile", function()
    local detected = getProfileItems()
    if #detected == 0 then
        if detectedDropdown then
            detectedDropdown:UpdateChoices({})
            detectedDropdown:Set({})
        end
        Lib:Notify("No items", "No items detected! Ensure you have someone's profile open and clicked 'Inventory'.", 3)
        return
    end
    
    local matchedList = {}
    for _, cleanName in ipairs(detected) do
        local fullText = findFullItemName(cleanName)
        if fullText then
            table.insert(matchedList, fullText)
        end
    end
    
    table.sort(matchedList, function(a, b)
        local cleanA = a:gsub("%s*%(x%d+%)", "")
        local cleanB = b:gsub("%s*%(x%d+%)", "")
        local valA = itemValuesMap[cleanA] or 0
        local valB = itemValuesMap[cleanB] or 0
        if valA == valB then return a < b end
        return valB < valA
    end)
    
    if #matchedList == 0 then
        if detectedDropdown then
            detectedDropdown:UpdateChoices({})
            detectedDropdown:Set({})
        end
        Lib:Notify("No matches", "Profile items detected but they don't match the MM2 values list.", 3, "warning")
    else
        if detectedDropdown then
            detectedDropdown:UpdateChoices(matchedList)
            detectedDropdown:Set({})
        end
        Lib:Notify("Success", "Scanned " .. tostring(#matchedList) .. " items! Check the dropdown below.", 3, "success")
    end
end)

detectedDropdown = theirSec:Dropdown("Scanned Profile Items", {}, {}, true, function(selected)
    local current = {}
    local oldSelected = theirDropdown:Get()
    if type(oldSelected) == "table" then
        for _, v in ipairs(oldSelected) do
            table.insert(current, v)
        end
    elseif type(oldSelected) == "string" and oldSelected ~= "" then
        table.insert(current, oldSelected)
    end
    
    if type(selected) == "table" then
        for _, item in ipairs(selected) do
            local exists = false
            for _, val in ipairs(current) do
                if val == item then exists = true; break end
            end
            if not exists then
                table.insert(current, item)
            end
        end
    elseif type(selected) == "string" and selected ~= "" then
        local exists = false
        for _, val in ipairs(current) do
            if val == selected then exists = true; break end
        end
        if not exists then
            table.insert(current, selected)
        end
    end
    
    theirDropdown:Set(current)
    
    theirTotal = 0
    for _, dropText in ipairs(current) do
        local cleanDropText = dropText:gsub("%s*%(x%d+%)", "")
        local qty = tonumber(dropText:match("%(x(%d+)%)")) or 1
        theirTotal = theirTotal + ((itemValuesMap[cleanDropText] or 0) * qty)
    end
    theirValLabel:SetText("Total Value: " .. tostring(theirTotal))
    updateResult()
end, "Select items to add to their offer", true)

theirSec:Button("Clear Scanned Items", function()
    if detectedDropdown then
        detectedDropdown:UpdateChoices({})
        detectedDropdown:Set({})
    end
end)

resSec:Button("Clear All Tables", function()
    if yourDropdownInv and yourDropdownInv.Set then yourDropdownInv:Set({}) end
    if yourDropdownAll and yourDropdownAll.Set then yourDropdownAll:Set({}) end
    if theirDropdown and theirDropdown.Set then theirDropdown:Set({}) end

    
    yourSelectedInv = {}
    yourSelectedAll = {}
    yourTotal = 0
    theirTotal = 0
    
    yourValLabel:SetText("Total Value: 0")
    theirValLabel:SetText("Total Value: 0")
    updateResult()
end)



local valuesTab = win:Tab("Item Values", "search")
local valuesSec = valuesTab:Section("Browse Values", "Full")

local categoryGroups = {
    {name = "All Items", categories = {"ancient", "unique", "chroma", "godly", "legendary", "rare", "uncommon", "common", "vintage", "pets", "misc"}},
    {name = "Ancient", categories = {"ancient"}},
    {name = "Unique", categories = {"unique"}},
    {name = "Chromas", categories = {"chroma"}},
    {name = "Godly", categories = {"godly"}},
    {name = "Legendary", categories = {"legendary"}},
    {name = "Rare", categories = {"rare"}},
    {name = "Uncommon", categories = {"uncommon"}},
    {name = "Common", categories = {"common"}},
    {name = "Vintage", categories = {"vintage"}},
    {name = "Pets & Misc", categories = {"pets", "misc"}}
}

for _, group in ipairs(categoryGroups) do
    local dropdownOptionsForGroup = {}
    
    for _, catName in ipairs(group.categories) do
        if groupedItems[catName] then
            for _, item in ipairs(groupedItems[catName]) do
                local dropText = string.format("%s [Val: %s | Dem: %s | Stab: %s]", item.name, item.value, item.demand, item.stability)
                table.insert(dropdownOptionsForGroup, dropText)
            end
        end
    end
    
    if #dropdownOptionsForGroup > 0 then
        local valDrop
        valDrop = valuesSec:Dropdown(group.name, "nil", dropdownOptionsForGroup, false, function(selected)
            
        end, "Browse & Search " .. group.name .. " Items", true)
    end
end




local combatTab = win:Tab("Combat", "swords")
local visualsTab = win:Tab("Visuals", "eye")
local miscTab = win:Tab("Misc", "shield")

local uiSec = visualsTab:Section("UI & Timers", "Left")
uiSec:Toggle("Show Round Timer", false, function(state)
    RoundTimerEnabled = state
    TimerLabel.Visible = state
end)

uiSec:Colorpicker("Timer Color", Color3.fromRGB(255, 215, 0), function(color)
    TimerLabel.Color = color
end)

local protectionSec = miscTab:Section("Protection", "Left")
local steppedConnection = nil
local PlayersService = game:GetService("Players")
local RS = game:GetService("RunService")

local function antiFlingLoop()
    for _, player in ipairs(PlayersService:GetPlayers()) do
        if player ~= PlayersService.LocalPlayer and player.Character then
            
            
            for _, v in ipairs(player.Character:GetChildren()) do
                if v:IsA("BasePart") then
                    v.CanCollide = false
                elseif v:IsA("Accessory") then
                    local handle = v:FindFirstChild("Handle")
                    if handle and handle:IsA("BasePart") then
                        handle.CanCollide = false
                    end
                end
            end
        end
    end
end

local AntiFlingEnabled = false
protectionSec:Toggle("Enable Anti-Fling", false, function(state)
    AntiFlingEnabled = state
    if state then
        Lib:Notify("Protection", "Anti-Fling is now ON", 3, "success")
    else
        Lib:Notify("Protection", "Anti-Fling is now OFF", 3, "warning")
        for _, player in ipairs(PlayersService:GetPlayers()) do
            if player ~= PlayersService.LocalPlayer and player.Character then
                for _, v in ipairs(player.Character:GetChildren()) do
                    if v:IsA("BasePart") then
                        v.CanCollide = true
                    elseif v:IsA("Accessory") then
                        local handle = v:FindFirstChild("Handle")
                        if handle and handle:IsA("BasePart") then
                            handle.CanCollide = true
                        end
                    end
                end
            end
        end
    end
end)

task.spawn(function()
    while true do
        if AntiFlingEnabled then
            antiFlingLoop()
        end
        task.wait(0.2)
    end
end)

local animSec = miscTab:Section("Spin", "Right")
local AnimSpooferEnabled = false

local ANIM_PLATFORMSTAND_OFFSET = 0x1E8
local ANIM_ANIMATION_ID_OFFSET = 0xD0

task.spawn(function()
    local success, response = pcall(function() return game:HttpGet("https://imtheo.lol/Offsets/Offsets.json") end)
    if success and response then
        local ok, parsed = pcall(function() return game:GetService("HttpService"):JSONDecode(response) end)
        if ok and type(parsed) == "table" then
            local function deepSearch(tbl, targetString)
                targetString = targetString:lower()
                for key, val in pairs(tbl) do
                    if type(key) == "string" and string.find(key:lower(), targetString, 1, true) then
                        if type(val) == "number" then return val end
                        if type(val) == "string" then return tonumber(val) or tonumber(val, 16) end
                    elseif type(val) == "table" then
                        local found = deepSearch(val, targetString)
                        if found then return found end
                    end
                end
                return nil
            end
            local dynamicPS = deepSearch(parsed, "platformstand")
            local dynamicAnim = deepSearch(parsed, "animationid")
            if dynamicPS then ANIM_PLATFORMSTAND_OFFSET = dynamicPS end
            if dynamicAnim then ANIM_ANIMATION_ID_OFFSET = dynamicAnim end
        end
    end
end)

local function read_std_string(addr)
    local size = memory_read("uintptr_t", addr + 0x10)
    local cap = memory_read("uintptr_t", addr + 0x18)
    if size == 0 then return "" end
    local ptr = (cap >= 16) and memory_read("uintptr_t", addr) or addr
    local bytes = {}
    for i = 0, size - 1 do bytes[i + 1] = string.char(memory_read("byte", ptr + i)) end
    return table.concat(bytes)
end

local function write_std_string(addr, newStr)
    local cap = memory_read("uintptr_t", addr + 0x18)
    if #newStr > cap then return false end
    local ptr = (cap >= 16) and memory_read("uintptr_t", addr) or addr
    for i = 1, #newStr do memory_write("byte", ptr + i - 1, string.byte(newStr, i)) end
    memory_write("byte", ptr + #newStr, 0)
    memory_write("uintptr_t", addr + 0x10, #newStr)
    return true
end

local function inflate_capacity_if_needed(animObj, targetStr)
    local addr = animObj.Address + ANIM_ANIMATION_ID_OFFSET
    local cap = memory_read("uintptr_t", addr + 0x18)
    if cap >= #targetStr then return true end
    if setscriptable then pcall(setscriptable, animObj, "AnimationId", true) end
    local ok = pcall(function() animObj.AnimationId = targetStr end)
    if not ok and sethiddenproperty then pcall(function() sethiddenproperty(animObj, "AnimationId", targetStr) end) end
    cap = memory_read("uintptr_t", addr + 0x18)
    if cap >= #targetStr then return true end
    local strVal = Instance.new("StringValue")
    strVal.Name = "TempProxy"
    strVal.Value = targetStr
    local strAddr = strVal.Address
    if strAddr then
        local targetLen = #targetStr
        local foundOffset = nil
        for offset = 0x10, 0x150, 8 do
            local s = memory_read("uintptr_t", strAddr + offset + 0x10)
            local c = memory_read("uintptr_t", strAddr + offset + 0x18)
            if s == targetLen and c >= targetLen and c < targetLen + 100 then
                foundOffset = offset
                break
            end
        end
        if foundOffset then
            local theftAddr = strAddr + foundOffset
            for i = 0, 24, 8 do
                local temp = memory_read("uintptr_t", addr + i)
                local newVal = memory_read("uintptr_t", theftAddr + i)
                memory_write("uintptr_t", addr + i, newVal)
                memory_write("uintptr_t", theftAddr + i, temp)
            end
            return true
        end
    end
    return false
end

local OriginalAnimations = {}
local TargetAnimations = {
    idle = "http://www.roblox.com/asset/?id=138257730945066",
    walk = "http://www.roblox.com/asset/?id=83198550003129",
    run = "http://www.roblox.com/asset/?id=130619106001706",
    jump = "http://www.roblox.com/asset/?id=123329302355957",
    fall = "http://www.roblox.com/asset/?id=70905428714112",
    swim = "http://www.roblox.com/asset/?id=90023041430816",
    climb = "http://www.roblox.com/asset/?id=95386679149396"
}

local function applyCustomAnimations()
    local player = game:GetService("Players").LocalPlayer
    if not player or not player.Character then return end
    local hum = player.Character:FindFirstChild("Humanoid")
    local animate = player.Character:FindFirstChild("Animate")
    if not hum or not animate or not hum.Address then return end
    
    pcall(function() memory_write("byte", hum.Address + ANIM_PLATFORMSTAND_OFFSET, 1) end)
    task.wait(0.1)
    
    for folderName, targetIdStr in pairs(TargetAnimations) do
        local folder = animate:FindFirstChild(folderName)
        if folder then
            local anims = {}
            for _, child in ipairs(folder:GetChildren()) do
                if child:IsA("Animation") then table.insert(anims, child) end
            end
            
            if not OriginalAnimations[folderName] then
                OriginalAnimations[folderName] = {}
                for i, animObj in ipairs(anims) do
                    local addr = animObj.Address + ANIM_ANIMATION_ID_OFFSET
                    OriginalAnimations[folderName][i] = read_std_string(addr)
                end
            end
            
            for i, animObj in ipairs(anims) do
                local toApply = AnimSpooferEnabled and targetIdStr or (OriginalAnimations[folderName][i] or "")
                if toApply ~= "" then
                    local addr = animObj.Address + ANIM_ANIMATION_ID_OFFSET
                    if read_std_string(addr) ~= toApply then
                        inflate_capacity_if_needed(animObj, toApply)
                        write_std_string(addr, toApply)
                    end
                end
            end
        end
    end
    
    task.wait(0.1)
    pcall(function() memory_write("byte", hum.Address + ANIM_PLATFORMSTAND_OFFSET, 0) end)
end

task.spawn(function()
    local lastCharAddr = nil
    while true do
        task.wait(0.5)
        local player = game:GetService("Players").LocalPlayer
        if player and player.Character then
            local hum = player.Character:FindFirstChild("Humanoid")
            if hum and hum.Address then
                if lastCharAddr ~= hum.Address then
                    lastCharAddr = hum.Address
                    task.wait(0.5)
                    OriginalAnimations = {}
                    if AnimSpooferEnabled then
                        applyCustomAnimations()
                    end
                end
            end
        end
    end
end)

animSec:Toggle("Enable Spin", false, function(state)
    AnimSpooferEnabled = state
    applyCustomAnimations()
    if state then
        Lib:Notify("Spin", "Spin enabled!", 3, "success")
    else
        Lib:Notify("Spin", "Spin disabled!", 3, "warning")
    end
end)


local AntiAfkEnabled = false
local MOVE_KEYS = { 0x57, 0x41, 0x53, 0x44 }

local function tapKey(vk)
    pcall(keypress, vk)
    task.wait(0.02)
    pcall(keyrelease, vk)
end

protectionSec:Toggle("Enable Anti-AFK", false, function(state)
    AntiAfkEnabled = state
    if state then
        Lib:Notify("Protection", "Anti-AFK is now ON", 3, "success")
    else
        Lib:Notify("Protection", "Anti-AFK is now OFF", 3, "warning")
    end
end)

task.spawn(function()
    math.randomseed(math.floor(os.clock() * 100000))
    while true do
        if AntiAfkEnabled then
            local vk = MOVE_KEYS[math.random(1, #MOVE_KEYS)]
            tapKey(vk)
            task.wait(300) 
        else
            task.wait(0.5)
        end
    end
end)

local roleSec = miscTab:Section("Role Notifier", "Left")

local RoleNotifierEnabled = false
local CurrentMurderer = nil
local CurrentSheriff = nil

roleSec:Toggle("Enable Role Alerts", false, function(state)
    RoleNotifierEnabled = state
    if not state then
        CurrentMurderer = nil
        CurrentSheriff = nil
    end
end)

local function scanForRoles()
    local foundMurds = {}
    local foundSheriffs = {}
    
    for _, p in ipairs(game:GetService("Players"):GetPlayers()) do
        if p.Character then
            local bp = p:FindFirstChildOfClass("Backpack")
            local function got(c, n) return c and c:FindFirstChild(n) ~= nil end
            
            if got(bp, "Knife") or got(p.Character, "Knife") then
                table.insert(foundMurds, p.Name)
            elseif got(bp, "Gun") or got(p.Character, "Gun") then
                table.insert(foundSheriffs, p.Name)
            end
        end
    end
    
    local murdStr = table.concat(foundMurds, ", ")
    local sherStr = table.concat(foundSheriffs, ", ")
    
    if murdStr == "" then murdStr = nil end
    if sherStr == "" then sherStr = nil end
    
    if murdStr ~= CurrentMurderer then
        CurrentMurderer = murdStr
        if CurrentMurderer then
            Lib:Notify("Role Alert", "Murderer is: " .. CurrentMurderer, 5, "error")
        end
    end
    
    if sherStr ~= CurrentSheriff then
        CurrentSheriff = sherStr
        if CurrentSheriff then
            Lib:Notify("Role Alert", "Sheriff is: " .. CurrentSheriff, 5, "info")
        end
    end
end

task.spawn(function()
    while true do
        if RoleNotifierEnabled then
            pcall(scanForRoles)
        end
        task.wait(1)
    end
end)



local miscSec = visualsTab:Section("Gun & Trap ESP", "Left")

local GunESPEnabled = false
local ESP_Objects = {}

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local GunDropPart = nil
local GunDropPartPosition = nil
local SavedHrp = nil
local DistanceTextCache = ""

local Vector2New = Vector2.new
local OffsetUp = Vector2New(10, -16)
local OffsetDown = Vector2New(10, 22)

local Square = (Drawing and Drawing.new or function() return {} end)("Square")
local GunLabel = (Drawing and Drawing.new or function() return {} end)("Text")
local DistanceLabel = (Drawing and Drawing.new or function() return {} end)("Text")

ESP_Objects.Square = Square
ESP_Objects.GunLabel = GunLabel
ESP_Objects.DistanceLabel = DistanceLabel

Square.Color = Color3.fromRGB(0, 255, 0)
Square.Size = Vector2New(20, 20)
Square.Visible = false

GunLabel.Color = Color3.fromRGB(0, 255, 0)
GunLabel.Font = (Drawing and Drawing.Fonts or {}).ProximaSoftBold or 0
GunLabel.Size = 16
GunLabel.Text = "GunDrop"
GunLabel.Center = true
GunLabel.Outline = true
GunLabel.Visible = false

DistanceLabel.Color = Color3.fromRGB(0, 255, 0)
DistanceLabel.Font = (Drawing and Drawing.Fonts or {}).ProximaSoftBold or 0
DistanceLabel.Size = 14
DistanceLabel.Text = ""
DistanceLabel.Center = true
DistanceLabel.Outline = true
DistanceLabel.Visible = false

local SquareSize = Square.Size
local Camera = Workspace.CurrentCamera

local CustomW2S = type(WorldToScreen) == "function" and WorldToScreen or function(pos)
    local sp, os = Camera:WorldToViewportPoint(pos)
    return Vector2New(sp.X, sp.Y), os
end

local function GetGunDrop()
    if GunDropPart and GunDropPart.Parent then
        pcall(function() GunDropPartPosition = GunDropPart.Position end)
        return
    end

    local Found = false
    local g = workspace:FindFirstChild("GunDrop")
    if g and g:IsA("BasePart") then
        GunDropPart = g; Found = true
    else
        for _, v in ipairs(workspace:GetChildren()) do
            if (v:IsA("Model") or v:IsA("Folder")) and not v:FindFirstChild("Humanoid") then
                g = v:FindFirstChild("GunDrop")
                if g and g:IsA("BasePart") then
                    GunDropPart = g; Found = true; break
                end
                if v.Name == "Normal" then
                    for _, map in ipairs(v:GetChildren()) do
                        local mg = map:FindFirstChild("GunDrop")
                        if mg and mg:IsA("BasePart") then
                            GunDropPart = mg; Found = true; break
                        end
                    end
                end
            end
            if Found then break end
        end
    end

    if Found then
        pcall(function() GunDropPartPosition = GunDropPart.Position end)
        if ESP_Objects and not ESP_Objects.GunDroppedNotified then
            ESP_Objects.GunDroppedNotified = true
            Lib:Notify("Gun Dropped!", "The Sheriff's gun is on the ground!", 4, "warning")
        end
    else
        GunDropPart = nil
        GunDropPartPosition = nil
        Square.Visible = false
        GunLabel.Visible = false
        DistanceLabel.Visible = false
        if ESP_Objects then ESP_Objects.GunDroppedNotified = false end
    end
end

local function UpdateHrp()
    local Character = LocalPlayer.Character
    local Hrp = Character and Character.PrimaryPart
    SavedHrp = Hrp or nil
end

local MaxDistance = 1000
local CachedDistanceNumber = 0

task.spawn(function()
    while true do
        if GunESPEnabled then
            GetGunDrop()
            UpdateHrp()
            
            if GunDropPart and SavedHrp and GunDropPartPosition then
                pcall(function()
                    local Distance = (SavedHrp.Position - GunDropPartPosition).Magnitude
                    CachedDistanceNumber = Distance
                    DistanceTextCache = string.format("%.1f studs", Distance)
                end)
            else
                CachedDistanceNumber = 9999
            end
        end
        task.wait(0.3)
    end
end)

RunService.RenderStepped:Connect(function()
    if not GunESPEnabled or not GunDropPart or not GunDropPart.Parent or not SavedHrp or not SavedHrp.Parent or not GunDropPartPosition or CachedDistanceNumber > MaxDistance then 
        Square.Visible = false
        GunLabel.Visible = false
        DistanceLabel.Visible = false
        return 
    end
    
    local pos = nil
    pcall(function()
        pos = GunDropPart.Position
    end)
    
    if not GunDropPart or not GunDropPart.Parent or not pos then
        Square.Visible = false
        GunLabel.Visible = false
        DistanceLabel.Visible = false
        return
    end
    
    local Position, OnScreen = CustomW2S(pos)
    
    if not OnScreen then 
        Square.Visible = false
        GunLabel.Visible = false
        DistanceLabel.Visible = false
        return 
    end
    local Pos2D = Vector2New(Position.X, Position.Y)

    local BoxPosition = Pos2D - SquareSize
    Square.Position = BoxPosition
    Square.Visible = true

    GunLabel.Position = BoxPosition + OffsetUp
    GunLabel.Visible = true

    DistanceLabel.Text = DistanceTextCache
    DistanceLabel.Position = BoxPosition + OffsetDown
    DistanceLabel.Visible = true
end)

miscSec:Toggle("Enable Gun ESP", false, function(state)
    GunESPEnabled = state
    if not state then
        Square.Visible = false
        GunLabel.Visible = false
        DistanceLabel.Visible = false
    end
end)

miscSec:Colorpicker("Gun ESP Color", Color3.fromRGB(0, 255, 0), function(color)
    if ESP_Objects then
        ESP_Objects.Square.Color = color
        ESP_Objects.GunLabel.Color = color
        ESP_Objects.DistanceLabel.Color = color
    end
    _G.CurrentGunESPColor = color
end)

miscSec:Colorpicker("Trap ESP Color", Color3.fromRGB(255, 50, 50), function(color)
    if TrapESP_Objects then
        for _, objs in pairs(TrapESP_Objects) do
            if objs.Square then objs.Square.Color = color end
            if objs.Label then objs.Label.Color = color end
            if objs.Dist then objs.Dist.Color = color end
        end
    end
    _G.CurrentTrapESPColor = color
end)

local TrapESPEnabled = false
local TrapESP_Objects = {}
local CachedTraps = {}

local function ClearTrapESP()
    for trap, objs in pairs(TrapESP_Objects) do
        if objs.Square then objs.Square:Remove() end
        if objs.Label then objs.Label:Remove() end
        if objs.Dist then objs.Dist:Remove() end
    end
    TrapESP_Objects = {}
    CachedTraps = {}
end

miscSec:Toggle("Enable Trap ESP", false, function(state)
    TrapESPEnabled = state
    if not state then
        ClearTrapESP()
    end
end)


task.spawn(function()
    while true do
        if TrapESPEnabled then
            local newTraps = {}
            for _, v in ipairs(workspace:GetChildren()) do
                if v.Name == "Trap" or string.find(v.Name, "HiddenTrap") then
                    local p = v:IsA("BasePart") and v or v:FindFirstChildWhichIsA("BasePart")
                    if p then table.insert(newTraps, p) end
                end
                if v.Name == "Normal" then
                    for _, mapFolder in ipairs(v:GetChildren()) do
                        if mapFolder.Name == "Trap" or string.find(mapFolder.Name, "HiddenTrap") then
                            local p = mapFolder:IsA("BasePart") and mapFolder or mapFolder:FindFirstChildWhichIsA("BasePart")
                            if p then table.insert(newTraps, p) end
                        else
                            for _, sub in ipairs(mapFolder:GetChildren()) do
                                if sub.Name == "Trap" or string.find(sub.Name, "HiddenTrap") then
                                    local p = sub:IsA("BasePart") and sub or sub:FindFirstChildWhichIsA("BasePart")
                                    if p then table.insert(newTraps, p) end
                                end
                            end
                        end
                    end
                end
            end
            CachedTraps = newTraps
        end
        task.wait(0.5)
    end
end)

RunService.RenderStepped:Connect(function()
    if not TrapESPEnabled then return end
    
    local trapMap = {}
    for _, t in ipairs(CachedTraps) do
        if t and t.Parent then
            trapMap[t] = true
        end
    end
    
    for t, objs in pairs(TrapESP_Objects) do
        if not trapMap[t] then
            if objs.Square then objs.Square:Remove() end
            if objs.Label then objs.Label:Remove() end
            if objs.Dist then objs.Dist:Remove() end
            TrapESP_Objects[t] = nil
        end
    end
    
    local hrp = nil
    if LocalPlayer.Character then
        hrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    end
    local cam = workspace.CurrentCamera
    if not cam then return end
    
    for t, _ in pairs(trapMap) do
        if not TrapESP_Objects[t] then
            local sq = (Drawing and Drawing.new or function() return {} end)("Square")
            sq.Color = _G.CurrentTrapESPColor or Color3.fromRGB(255, 50, 50)
            sq.Size = Vector2.new(20, 20)
            
            local lbl = (Drawing and Drawing.new or function() return {} end)("Text")
            lbl.Color = _G.CurrentTrapESPColor or Color3.fromRGB(255, 50, 50)
            lbl.Font = (Drawing and Drawing.Fonts or {}).UI or 0
            lbl.Size = 15
            lbl.Text = "TRAP"
            lbl.Center = true
            lbl.Outline = true
            
            local distLbl = (Drawing and Drawing.new or function() return {} end)("Text")
            distLbl.Color = _G.CurrentTrapESPColor or Color3.fromRGB(255, 50, 50)
            distLbl.Font = (Drawing and Drawing.Fonts or {}).UI or 0
            distLbl.Size = 13
            distLbl.Center = true
            distLbl.Outline = true
            
            TrapESP_Objects[t] = {Square = sq, Label = lbl, Dist = distLbl}
        end
        
        local objs = TrapESP_Objects[t]
        
        local CustomW2S = type(WorldToScreen) == "function" and WorldToScreen or function(pos)
            local sp, os = cam:WorldToViewportPoint(pos)
            return Vector2.new(sp.X, sp.Y), os
        end
        
        local pos = nil
        pcall(function()
            pos = t.Position
        end)
        
        if pos then
            local pos2dRaw, onScreen = CustomW2S(pos)
            
            if onScreen then
                local pos2d = Vector2.new(pos2dRaw.X, pos2dRaw.Y)
                objs.Square.Position = pos2d - (objs.Square.Size / 2)
                objs.Square.Visible = true
                
                objs.Label.Position = pos2d - Vector2.new(0, 18)
                objs.Label.Visible = true
                
                if hrp then
                    local d = (hrp.Position - pos).Magnitude
                    objs.Dist.Text = string.format("%.1f", d)
                    objs.Dist.Position = pos2d + Vector2.new(0, 10)
                    objs.Dist.Visible = true
                else
                    objs.Dist.Visible = false
                end
            else
                objs.Square.Visible = false
                objs.Label.Visible = false
                objs.Dist.Visible = false
            end
        else
            objs.Square.Visible = false
            objs.Label.Visible = false
            objs.Dist.Visible = false
        end
    end
end)




local combatSec = combatTab:Section("Combat", "Left")

local AutoGetGunEnabled = false

local function GrabGunNow(isAuto)
    local Workspace = game:GetService("Workspace")
    local LocalPlayer = game:GetService("Players").LocalPlayer
    local Character = LocalPlayer.Character
    if not Character then return end
    local Hrp = Character:FindFirstChild("HumanoidRootPart")
    if not Hrp then return end

    local gunDrop = nil
    
    local p = workspace:FindFirstChild("GunDrop")
    if p and p:IsA("BasePart") then gunDrop = p end
    
    if not gunDrop then
        for _, v in ipairs(workspace:GetChildren()) do
            if (v:IsA("Model") or v:IsA("Folder")) and not v:FindFirstChild("Humanoid") then
                local g = v:FindFirstChild("GunDrop")
                if g and g:IsA("BasePart") then
                    gunDrop = g
                    break
                end
                
                if v.Name == "Normal" then
                    for _, map in ipairs(v:GetChildren()) do
                        local mg = map:FindFirstChild("GunDrop")
                        if mg and mg:IsA("BasePart") then
                            gunDrop = mg
                            break
                        end
                    end
                end
            end
            if gunDrop then break end
        end
    end

    if not gunDrop then 
        if not isAuto then
            Lib:Notify("Not Found", "No dropped gun found on the map!", 3)
        end
        return false
    end
    
    if isAuto then
        local dist = (Hrp.Position - gunDrop.Position).Magnitude
        
        if dist > 1000 then
            return false
        end
    end
    

    local oldCFrame = Hrp.CFrame
    
    
    Hrp.CFrame = gunDrop.CFrame
    
    
    task.wait()
    
    
    if Hrp then
        Hrp.CFrame = oldCFrame
    end
    
    return true
end

combatSec:Toggle("Auto Get Gun", false, function(state)
    AutoGetGunEnabled = state
end)


combatSec:Button("Teleport to Dropped Gun", function()
    GrabGunNow(false)
end)

local isGetGunKeybindEnabled = false
local getGunKeyToggle = combatSec:Toggle("Get Gun (Hotkey)", false, function(state)
    isGetGunKeybindEnabled = state
end)
getGunKeyToggle:AddKeybind("g", "Hold", function(active)
    if active and isGetGunKeybindEnabled then
        task.spawn(function()
            GrabGunNow(false)
        end)
    end
end)

task.spawn(function()
    while true do
        if AutoGetGunEnabled then
            local hasGunAlready = false
            local isMurderer = false
            pcall(function()
                local lp = game:GetService("Players").LocalPlayer
                local c = lp.Character
                local bp = lp:FindFirstChild("Backpack")
                local function gotGun(con)
                    return con and con:FindFirstChild("Gun") ~= nil
                end
                local function gotKnife(con)
                    return con and con:FindFirstChild("Knife") ~= nil
                end
                hasGunAlready = gotGun(c) or gotGun(bp)
                isMurderer = gotKnife(c) or gotKnife(bp)
            end)

            if not hasGunAlready and not isMurderer then
                local attempted = GrabGunNow(true)
                if attempted then
                    task.wait(1.5)
                end
            end
        end
        task.wait(0.1)
    end
end)

local doAutoKillActive = false
local function doAutoKill(ignoreLimit)
    if doAutoKillActive then return end
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local knife = nil
    local function getKnife(c)
        if not c then return nil end
        
        return c:FindFirstChild("Knife")
    end

    knife = getKnife(char) or getKnife(LocalPlayer:FindFirstChild("Backpack"))
    if not knife then
        Lib:Notify("Auto Kill", "You must be the Murderer (Knife not found)!", 3, "error")
        doAutoKillActive = false
        return
    end

    
    local function forceEquipKnife()
        if knife and knife.Parent ~= char then
            local hum = char:FindFirstChild("Humanoid")
            if hum then
                
                pcall(keypress, 0x31)
                task.wait(0.05)
                pcall(keyrelease, 0x31)
            else
                knife.Parent = char
            end
        end
    end
    
    forceEquipKnife()
    
    
    task.wait(0.5)
    task.wait(0.2)
    
    local spamming = true

    local function getAlivePlayers()
        local plrs = {}
        for _, p in ipairs(game:GetService("Players"):GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local eHum = p.Character:FindFirstChild("Humanoid")
                local eHrp = p.Character:FindFirstChild("HumanoidRootPart")
                if eHum and eHrp and eHum.Health > 0 and p.Name ~= LocalPlayer.Name then
                    local dist = (hrp.Position - eHrp.Position).Magnitude
                    if ignoreLimit or dist <= 500 then
                        table.insert(plrs, p)
                    end
                end
            end
        end
        return plrs
    end

    local targets = getAlivePlayers()
    if #targets == 0 then
        Lib:Notify("Auto Kill", "No targets found!", 3)
        return
    end

    doAutoKillActive = true
    Lib:Notify("Auto Kill", "Starting! Eradicating " .. #targets .. " players.", 3, "warning")

    local maxAttempts = 50 
    local attempts = 0
    
    while doAutoKillActive and attempts < maxAttempts do
        if not char or not hrp or not hrp.Parent then break end
        
        local cam = workspace.CurrentCamera
        local lookDir = cam.CFrame.LookVector
        lookDir = Vector3.new(lookDir.X, 0, lookDir.Z).Unit
        
        local bringPos = hrp.Position + (lookDir * 3.5) 
        local bringCF = CFrame.lookAt(bringPos, hrp.Position)
        
        pcall(function()
            hrp.CFrame = CFrame.lookAt(hrp.Position, Vector3.new(bringPos.X, hrp.Position.Y, bringPos.Z))
        end)
        
        local anyoneAlive = false
        for _, target in ipairs(targets) do
            local tChar = target.Character
            local tHrp = tChar and tChar:FindFirstChild("HumanoidRootPart")
            local tHum = tChar and tChar:FindFirstChild("Humanoid")
            
            if tHrp and tHum and tHum.Health > 0 then
                anyoneAlive = true
                pcall(function()
                    tHrp.CFrame = bringCF
                    tHrp.AssemblyLinearVelocity = Vector3.zero
                    tHrp.AssemblyAngularVelocity = Vector3.zero
                end)
            end
        end
        
        if not anyoneAlive then
            break
        end
        
        pcall(function() mouse1click() end)
        pcall(function() if knife then knife:Activate() end end)
        
        task.wait(0.05)
        attempts = attempts + 1
    end
    
    spamming = false
    doAutoKillActive = false
    Lib:Notify("Auto Kill", "Eradication Complete!", 3, "success")
end

combatSec:Button("Kill All (Button)", function()
    task.spawn(doAutoKill)
end)

local isKillKeybindEnabled = false
local killKeyToggle = combatSec:Toggle("Kill All (Hotkey)", false, function(state)
    isKillKeybindEnabled = state
end)
killKeyToggle:AddKeybind("k", "Hold", function(active)
    if active and isKillKeybindEnabled then
        task.spawn(doAutoKill)
    end
end)

local AutoKillAllEnabled = false
combatSec:Toggle("Auto Kill All (Loop)", false, function(state)
    AutoKillAllEnabled = state
    if state then
        Lib:Notify("Auto Kill", "Auto Kill All loop started!", 3, "success")
    end
end)

task.spawn(function()
    while true do
        if AutoKillAllEnabled then
            pcall(doAutoKill)
            task.wait(1)
        else
            task.wait(0.5)
        end
    end
end)


local KnifeAuraEnabled = false
local KnifeAuraRange = 15

combatSec:Toggle("Knife Aura", false, function(state)
    KnifeAuraEnabled = state
    if state then
        Lib:Notify("Knife Aura", "Active! Range: " .. KnifeAuraRange .. " studs", 3, "success")
    end
end)

combatSec:Slider("Knife Aura Range", 15, 1, 5, 50, " studs", function(v)
    KnifeAuraRange = v
end)

task.spawn(function()
    while true do
        if KnifeAuraEnabled then
            local char = LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if hrp then
                local knife = char:FindFirstChild("Knife")
                if not knife then
                    local bp = LocalPlayer:FindFirstChild("Backpack")
                    if bp then knife = bp:FindFirstChild("Knife") end
                end
                if knife then
                    knife.Parent = char
                    for _, p in ipairs(game:GetService("Players"):GetPlayers()) do
                        if p ~= LocalPlayer and p.Character then
                            local tHrp = p.Character:FindFirstChild("HumanoidRootPart")
                            local tHum = p.Character:FindFirstChild("Humanoid")
                            if tHrp and tHum and tHum.Health > 0 then
                                local dist = (hrp.Position - tHrp.Position).Magnitude
                                if dist <= KnifeAuraRange then
                                    pcall(function() mouse1click() end)
                                    pcall(function() knife:Activate() end)
                                end
                            end
                        end
                    end
                end
            end
        end
        task.wait(0.1)
    end
end)


local HitTracerEnabled = false
local HitTracerColor = Color3.fromRGB(0, 255, 100)
local HitTracerRainbow = false
local HitTracerDuration = 3
local lastHitTracerShot = 0
local HitTracerSheriffOnly = false
local HitTracerBoxThickness = 1
local HitTracerGlowEnabled = false
local HitTracerLineEnabled = false
local HitTracerLineColor = Color3.fromRGB(255, 255, 255)
local HitTracerLineThickness = 2


local KillEffectEnabled = false
local KillEffectSheriffOnly = false
local KillEffectStyle = "Random"
local KillEffectDurationMultiplier = 3
local KillEffectVersion = "New (V2)"

local HitSoundsEnabled = false
local HitSoundsOnlyCustom = false
local CustomHitSounds = {"(None)"}
local customSoundsCombo = nil
local HitSoundIndex = 1

local activeKE = {}
local kePools = {
    Circle = {}, Line = {}, Triangle = {}, Square = {}
}

for i = 1, 40 do local c = Drawing.new("Circle"); c.Visible = false; c.Filled = false; table.insert(kePools.Circle, c) end
for i = 1, 250 do local l = Drawing.new("Line"); l.Visible = false; table.insert(kePools.Line, l) end
for i = 1, 150 do local t = Drawing.new("Triangle"); t.Visible = false; t.Filled = true; table.insert(kePools.Triangle, t) end
for i = 1, 100 do local s = Drawing.new("Square"); s.Visible = false; s.Filled = true; table.insert(kePools.Square, s) end

local function spawnKE(shape, props)
    local maxAllowed = (shape == "Circle" and 40) or (shape == "Square" and 100) or (shape == "Triangle" and 150) or 250
    local count = 0
    for _, e in ipairs(activeKE) do if e.shape == shape then count = count + 1 end end
    if count >= maxAllowed then return end
    props.shape = shape
    props.life = 0
    if shape ~= "Circle" then
        props.maxLife = (props.maxLife or 1) * KillEffectDurationMultiplier
    else
        props.maxLife = (props.maxLife or 1)
    end
    table.insert(activeKE, props)
end

local kEffectIndex = 0
local function triggerKillEffect(hitPos, style)
    if style == "Random" then
        local allStyles = {"Laser Eyes", "Cosmic Nova", "Blood Splatter", "Holy Smite", "Toxic Splash", "Ice Shatter", "Void Collapse", "Cyber Glitch", "Sparkler", "Sakura Petals"}
        kEffectIndex = kEffectIndex + math.random(1, 5)
        style = allStyles[(kEffectIndex % #allStyles) + 1]
    end

    if KillEffectVersion == "Old (V1)" then
        if style == "Laser Eyes" then
            spawnKE("Circle", {pos=hitPos, r=10, maxR=250, maxLife=0.6, color=Color3.fromRGB(255, 0, 0), t=5, shrink=true})
            for i=1, 40 do
                spawnKE("Line", {pos=hitPos, vel=Vector3.new(math.random(-150,150), math.random(-50,150), math.random(-150,150)), length=math.random(20,50), maxLife=math.random(50,80)/100, color=Color3.fromRGB(255, 0, 0), t=3})
            end
        elseif style == "Cosmic Nova" then
            spawnKE("Circle", {pos=hitPos, r=0, maxR=300, maxLife=0.8, color=Color3.fromRGB(150, 0, 255), t=8})
            for i=1, 60 do
                spawnKE("Line", {pos=hitPos, vel=Vector3.new(math.random(-100,100), math.random(-100,100), math.random(-100,100)), length=math.random(20,50), maxLife=math.random(60,100)/100, color=Color3.fromRGB(0, 255, 255), t=3})
            end
        elseif style == "Blood Splatter" then
            for i=1, 10 do spawnKE("Circle", {pos=hitPos+Vector3.new(math.random(-10,10),math.random(-10,10),math.random(-10,10)), r=0, maxR=math.random(30,80), maxLife=math.random(40,70)/100, color=Color3.fromRGB(180, 0, 0), t=5}) end
            for i=1, 50 do spawnKE("Triangle", {pos=hitPos, vel=Vector3.new(math.random(-50,50), math.random(20,60), math.random(-50,50)), grav=Vector3.new(0,-150,0), rot=CFrame.Angles(0,0,0), rotV=CFrame.Angles(math.random()*2,0,0), size=2, maxLife=0.8, color=Color3.fromRGB(150,0,0)}) end
        elseif style == "Holy Smite" then
            spawnKE("Circle", {pos=hitPos, r=0, maxR=250, maxLife=0.5, color=Color3.fromRGB(255, 255, 255), t=10})
            for i=1, 40 do spawnKE("Line", {pos=hitPos + Vector3.new(math.random(-30,30), 200, math.random(-30,30)), vel=Vector3.new(0,-800,0), length=100, maxLife=0.4, color=Color3.fromRGB(255,215,0), t=4}) end
        elseif style == "Toxic Splash" then
            for i=1, 15 do spawnKE("Circle", {pos=hitPos, r=0, maxR=math.random(20,60), maxLife=0.6, color=Color3.fromRGB(50, 255, 50), t=4}) end
            for i=1, 40 do spawnKE("Square", {pos=hitPos, vel=Vector3.new(math.random(-40,40), math.random(30,80), math.random(-40,40)), grav=Vector3.new(0,-60,0), size=15, maxLife=0.8, color=Color3.fromRGB(50,255,50)}) end
        elseif style == "Ice Shatter" then
            spawnKE("Circle", {pos=hitPos, r=0, maxR=180, maxLife=0.5, color=Color3.fromRGB(150, 255, 255), t=5})
            for i=1, 50 do spawnKE("Triangle", {pos=hitPos, vel=Vector3.new(math.random(-150,150), math.random(-30,80), math.random(-150,150)), grav=Vector3.new(0,-50,0), rot=CFrame.Angles(0,0,0), rotV=CFrame.Angles(0,0,0), size=2, maxLife=0.7, color=Color3.fromRGB(255,255,255)}) end
        elseif style == "Void Collapse" then
            spawnKE("Circle", {pos=hitPos, r=300, maxR=0, maxLife=1.0, color=Color3.fromRGB(50, 0, 100), t=15, shrink=true})
            for i=1, 50 do spawnKE("Line", {pos=hitPos + Vector3.new(math.random(-100,100), math.random(-100,100), math.random(-100,100)), vel=Vector3.new(0,0,0), pullTarget=hitPos, pullSpeed=150, length=20, maxLife=1.0, color=Color3.fromRGB(150,50,255), t=3}) end
        elseif style == "Cyber Glitch" then
            for i=1, 40 do spawnKE("Square", {pos=hitPos + Vector3.new(math.random(-40,40), math.random(-40,40), math.random(-40,40)), size=20, maxLife=0.6, color=(math.random()>0.5 and Color3.fromRGB(255,0,255) or Color3.fromRGB(0,255,255))}) end
            for i=1, 40 do spawnKE("Line", {pos=hitPos, vel=Vector3.new(math.random(-100,100), math.random(-100,100), math.random(-100,100)), length=30, maxLife=0.5, color=Color3.fromRGB(0,255,255), t=4}) end
        elseif style == "Sparkler" then
            spawnKE("Circle", {pos=hitPos, r=0, maxR=150, maxLife=0.4, color=Color3.fromRGB(255, 255, 100), t=5})
            for i=1, 60 do spawnKE("Line", {pos=hitPos, vel=Vector3.new(math.random(-120,120), math.random(40,150), math.random(-120,120)), grav=Vector3.new(0,-100,0), length=15, maxLife=0.8, color=Color3.fromRGB(255,200,50), t=2}) end
        elseif style == "Sakura Petals" then
            for i=1, 50 do spawnKE("Triangle", {pos=hitPos + Vector3.new(math.random(-20,20), math.random(10,40), math.random(-20,20)), vel=Vector3.new(math.random(-30,30), math.random(-5,15), math.random(-30,30)), grav=Vector3.new(0,-5,0), sway=2, rot=CFrame.Angles(0,0,0), rotV=CFrame.Angles(0,0,0), size=2, maxLife=2.0, color=Color3.fromRGB(255,160,200)}) end
        end
        return
    end

    if style == "Laser Eyes" then
        spawnKE("Circle", {pos=hitPos, r=10, maxR=350, maxLife=0.8, color=Color3.fromRGB(math.random(220,255), 0, 0), color2=Color3.fromRGB(255, math.random(100,160), 0), t=10, shrink=true})
        spawnKE("Circle", {pos=hitPos, r=0, maxR=180, maxLife=0.6, color=Color3.fromRGB(255, math.random(80,120), 0), color2=Color3.fromRGB(255, 255, math.random(0,100)), t=6})
        for i=1, 150 do
            spawnKE("Line", {
                pos=hitPos, vel=Vector3.new(math.random(-250,250), math.random(-50,300), math.random(-250,250)),
                length=math.random(30,80), maxLife=math.random(50,110)/100,
                color=Color3.fromRGB(math.random(200,255), math.random(0,40), 0), color2=Color3.fromRGB(255, math.random(150,220), 0), color3=Color3.fromRGB(255, 255, math.random(150,255)), t=math.random(3,6)
            })
        end
        for i=1, 80 do
            spawnKE("Triangle", {
                pos=hitPos, vel=Vector3.new(math.random(-100,100), math.random(50,150), math.random(-100,100)),
                grav=Vector3.new(0,-120,0), rot=CFrame.Angles(math.random()*6,math.random()*6,math.random()*6),
                rotV=CFrame.Angles(math.random(-20,20)/100,math.random(-20,20)/100,math.random(-20,20)/100),
                size=math.random(15,35)/10, maxLife=math.random(70,120)/100, color=Color3.fromRGB(255, math.random(20,80), 0), color2=Color3.fromRGB(255, math.random(180,220), math.random(20,80))
            })
        end
    elseif style == "Cosmic Nova" then
        spawnKE("Circle", {pos=hitPos, r=0, maxR=400, maxLife=1.2, color=Color3.fromRGB(math.random(120,180), 0, 255), color2=Color3.fromRGB(0, math.random(200,255), 255), t=12})
        spawnKE("Circle", {pos=hitPos, r=0, maxR=250, maxLife=0.9, color=Color3.fromRGB(0, math.random(200,255), 255), color2=Color3.fromRGB(255, 255, 255), t=8})
        spawnKE("Circle", {pos=hitPos, r=500, maxR=0, maxLife=1.1, color=Color3.fromRGB(math.random(180,220), math.random(80,120), 255), color2=Color3.fromRGB(math.random(30,80), 0, math.random(120,180)), t=5, shrink=true})
        for i=1, 200 do
            spawnKE("Line", {
                pos=hitPos, vel=Vector3.new(math.random(-200,200), math.random(-200,200), math.random(-200,200)),
                length=math.random(25,75), maxLife=math.random(70,160)/100,
                color=Color3.fromRGB(math.random(80,150),0,255), color2=Color3.fromRGB(0,math.random(200,255),255), color3=Color3.fromRGB(math.random(200,255),255,255), t=3
            })
        end
        for i=1, 80 do
            spawnKE("Square", {
                pos=hitPos + Vector3.new(math.random(-100,100), math.random(-100,100), math.random(-100,100)),
                pullTarget=hitPos, pullSpeed=150,
                size=math.random(20,40), maxLife=1.2, color=Color3.fromRGB(math.random(200,255),0,255), color2=Color3.fromRGB(0,math.random(200,255),255)
            })
        end
    elseif style == "Blood Splatter" then
        for i=1, 25 do
            spawnKE("Circle", {pos=hitPos + Vector3.new(math.random(-15,15),math.random(-15,15),math.random(-15,15)), r=0, maxR=math.random(40,120), maxLife=math.random(50,90)/100, color=Color3.fromRGB(math.random(120,180), 0, 0), color2=Color3.fromRGB(math.random(200,255), 0, 0), t=math.random(6,12)})
        end
        for i=1, 150 do
            spawnKE("Line", {
                pos=hitPos, vel=Vector3.new(math.random(-100,100), math.random(-30,120), math.random(-100,100)),
                grav=Vector3.new(0,-200,0), length=math.random(15,45), maxLife=math.random(80,180)/100,
                color=Color3.fromRGB(math.random(180,255), 0, 0), color2=Color3.fromRGB(math.random(50,100), 0, 0), t=math.random(4,8)
            })
        end
        for i=1, 100 do
            spawnKE("Triangle", {
                pos=hitPos, vel=Vector3.new(math.random(-60,60), math.random(20,80), math.random(-60,60)),
                grav=Vector3.new(0,-250,0), rot=CFrame.Angles(math.random()*6,math.random()*6,math.random()*6), rotV=CFrame.Angles(math.random()*3,0,0),
                size=math.random(15,30)/10, maxLife=math.random(80,150)/100, color=Color3.fromRGB(math.random(130,180),0,0), color2=Color3.fromRGB(math.random(30,70),0,0)
            })
        end
    elseif style == "Holy Smite" then
        -- Devastating celestial explosion!
        spawnKE("Circle", {pos=hitPos, r=0, maxR=600, maxLife=1.2, color=Color3.fromRGB(255, 255, 255), color2=Color3.fromRGB(255, 215, 0), t=30, shrink=true})
        spawnKE("Circle", {pos=hitPos, r=200, maxR=0, maxLife=0.8, color=Color3.fromRGB(255, 255, 150), t=15})
        -- Ground impact shockwave (fast horizontal lines)
        for i=1, 100 do
            spawnKE("Line", {
                pos=hitPos, vel=Vector3.new(math.random(-600,600), 0, math.random(-600,600)),
                length=math.random(40,120), maxLife=0.6, color=Color3.fromRGB(255,255,255), color2=Color3.fromRGB(255,215,0), t=6
            })
        end
        -- Celestial ascension (Gold squares flying UP)
        for i=1, 80 do
            spawnKE("Square", {
                pos=hitPos + Vector3.new(math.random(-100,100), math.random(0,50), math.random(-100,100)),
                vel=Vector3.new(0, math.random(200,500), 0), size=math.random(20,50), maxLife=1.2,
                color=Color3.fromRGB(255, math.random(200,255), 0), color2=Color3.fromRGB(255,255,255), flicker=true
            })
        end
        -- Divine spear strikes from heaven
        for i=1, 60 do
            spawnKE("Line", {
                pos=hitPos + Vector3.new(math.random(-150,150), math.random(300,800), math.random(-150,150)),
                vel=Vector3.new(0, -1500, 0), length=math.random(150,300), maxLife=0.5,
                color=Color3.fromRGB(255,255,255), color2=Color3.fromRGB(255,math.random(150,215),0), t=12
            })
        end
    elseif style == "Toxic Splash" then
        for i=1, 35 do
            spawnKE("Circle", {pos=hitPos + Vector3.new(math.random(-25,25),math.random(-15,30),math.random(-25,25)), r=0, maxR=math.random(30,90), maxLife=math.random(50,140)/100, color=Color3.fromRGB(math.random(30,80), 255, math.random(30,80)), color2=Color3.fromRGB(0, math.random(100,180), 0), t=math.random(4,10)})
        end
        for i=1, 120 do
            spawnKE("Triangle", {
                pos=hitPos, vel=Vector3.new(math.random(-60,60), math.random(30,100), math.random(-60,60)),
                grav=Vector3.new(0,-60,0), rot=CFrame.Angles(0,0,0), rotV=CFrame.Angles(math.random()*0.2,math.random()*0.2,0),
                size=math.random(15,30)/10, maxLife=math.random(80,180)/100, color=Color3.fromRGB(math.random(80,140),255,math.random(30,80)), color2=Color3.fromRGB(math.random(10,30),math.random(80,140),math.random(10,30))
            })
        end
        for i=1, 60 do
            spawnKE("Square", {
                pos=hitPos, vel=Vector3.new(math.random(-40,40), math.random(50,120), math.random(-40,40)),
                grav=Vector3.new(0,-80,0), size=math.random(15,25), maxLife=math.random(60,140)/100, color=Color3.fromRGB(math.random(30,80),255,math.random(30,80))
            })
        end
    elseif style == "Ice Shatter" then
        for i=1, 15 do
            spawnKE("Circle", {pos=hitPos, r=0, maxR=math.random(150,250), maxLife=0.6, color=Color3.fromRGB(math.random(120,180), 255, 255), color2=Color3.fromRGB(255, 255, 255), t=5})
        end
        for i=1, 150 do
            spawnKE("Triangle", {
                pos=hitPos, vel=Vector3.new(math.random(-200,200), math.random(-50,100), math.random(-200,200)),
                grav=Vector3.new(0,-80,0), rot=CFrame.Angles(math.random()*6,math.random()*6,math.random()*6), rotV=CFrame.Angles(math.random()*0.4,0,0),
                size=math.random(15,40)/10, maxLife=math.random(60,120)/100, color=Color3.fromRGB(math.random(150,200),255,255), color2=Color3.fromRGB(255,255,255)
            })
        end
        for i=1, 100 do
            spawnKE("Line", {
                pos=hitPos, vel=Vector3.new(math.random(-250,250), math.random(-50,50), math.random(-250,250)),
                length=math.random(25,70), maxLife=0.6, color=Color3.fromRGB(math.random(180,220),255,255), color2=Color3.fromRGB(255,255,255), t=4
            })
        end
    elseif style == "Void Collapse" then
        spawnKE("Circle", {pos=hitPos, r=450, maxR=0, maxLife=1.4, color=Color3.fromRGB(0, 0, 0), color2=Color3.fromRGB(math.random(30,80), 0, math.random(80,150)), t=25, shrink=true})
        spawnKE("Circle", {pos=hitPos, r=300, maxR=0, maxLife=1.0, color=Color3.fromRGB(math.random(20,60), 0, math.random(60,100)), color2=Color3.fromRGB(math.random(80,120), 0, math.random(180,220)), t=15, shrink=true})
        for i=1, 150 do
            spawnKE("Line", {
                pos=hitPos + Vector3.new(math.random(-150,150), math.random(-150,150), math.random(-150,150)), 
                vel=Vector3.new(0,0,0), pullTarget=hitPos, pullSpeed=math.random(150, 300), length=math.random(25,50), maxLife=1.4, color=Color3.fromRGB(math.random(100,180),math.random(20,80),255), color2=Color3.fromRGB(0,0,0), t=5
            })
        end
        for i=1, 100 do
            spawnKE("Triangle", {
                pos=hitPos + Vector3.new(math.random(-100,100), math.random(-100,100), math.random(-100,100)),
                pullTarget=hitPos, pullSpeed=200, rot=CFrame.Angles(math.random()*6,math.random()*6,math.random()*6), rotV=CFrame.Angles(0.2,0.2,0.2),
                size=math.random(20,35)/10, maxLife=1.4, color=Color3.fromRGB(math.random(60,100),0,math.random(100,150)), color2=Color3.fromRGB(math.random(200,255),0,255)
            })
        end
    elseif style == "Cyber Glitch" then
        for i=1, 100 do
            spawnKE("Square", {
                pos=hitPos + Vector3.new(math.random(-60,60), math.random(-60,60), math.random(-60,60)),
                size=math.random(25,60), maxLife=math.random(40,100)/100, color=(math.random()>0.5 and Color3.fromRGB(255,math.random(0,50),255) or Color3.fromRGB(math.random(0,50),255,255)), color2=Color3.fromRGB(255,255,255), flicker=true
            })
        end
        for i=1, 150 do
            spawnKE("Line", {
                pos=hitPos + Vector3.new(math.random(-50,50), math.random(-50,50), math.random(-50,50)), 
                vel=Vector3.new(math.random(-150,150), math.random(-150,150), math.random(-150,150)), length=math.random(30,100), maxLife=math.random(40,90)/100, color=Color3.fromRGB(math.random(0,50),255,255), color2=Color3.fromRGB(255,math.random(0,50),255), t=7, flicker=true
            })
        end
    elseif style == "Sparkler" then
        spawnKE("Circle", {pos=hitPos, r=0, maxR=200, maxLife=0.5, color=Color3.fromRGB(255, 255, math.random(100,200)), color2=Color3.fromRGB(255, 255, 255), t=8})
        for i=1, 200 do
            spawnKE("Line", {
                pos=hitPos, vel=Vector3.new(math.random(-180,180), math.random(50,200), math.random(-180,180)),
                grav=Vector3.new(0,-150,0), length=math.random(10,25), maxLife=math.random(70,150)/100, color=Color3.fromRGB(255,255,math.random(100,255)), color2=Color3.fromRGB(255,math.random(50,150),0), t=4
            })
        end
        for i=1, 80 do
            spawnKE("Triangle", {
                pos=hitPos, vel=Vector3.new(math.random(-120,120), math.random(80,250), math.random(-120,120)),
                grav=Vector3.new(0,-180,0), rot=CFrame.Angles(math.random()*6,math.random()*6,math.random()*6), rotV=CFrame.Angles(math.random()*0.5,math.random()*0.5,0),
                size=math.random(10,20)/10, maxLife=math.random(70,140)/100, color=Color3.fromRGB(255,math.random(180,220),math.random(50,100)), color2=Color3.fromRGB(255,255,255)
            })
        end
    elseif style == "Sakura Petals" then
        for i=1, 150 do
            spawnKE("Triangle", {
                pos=hitPos + Vector3.new(math.random(-30,30), math.random(10,60), math.random(-30,30)),
                vel=Vector3.new(math.random(-50,50), math.random(-5,25), math.random(-50,50)),
                grav=Vector3.new(0,-10,0), sway=math.random(20,50)/10, rot=CFrame.Angles(math.random()*6,math.random()*6,math.random()*6), rotV=CFrame.Angles(0.02,0.05,0.02),
                size=math.random(15,30)/10, maxLife=math.random(250,500)/100, color=Color3.fromRGB(255,math.random(140,180),math.random(180,230)), color2=Color3.fromRGB(255,math.random(200,230),255)
            })
        end
    end
end

local function lerpColor(c1, c2, alpha)
    local r = c1.R + (c2.R - c1.R) * alpha
    local g = c1.G + (c2.G - c1.G) * alpha
    local b = c1.B + (c2.B - c1.B) * alpha
    return Color3.new(r, g, b)
end

RunService.RenderStepped:Connect(function(dt)
    if not KillEffectEnabled and #activeKE == 0 then return end
    
    local cam = game:GetService("Workspace").CurrentCamera
    local function WTS(p)
        if type(WorldToScreen) == "function" then
            local w, on = WorldToScreen(p)
            if on then return w, on end
        end
        local ok, vp, on = pcall(function() return cam:WorldToViewportPoint(p) end)
        if ok and on then return Vector2.new(vp.X, vp.Y), on end
        return Vector2.new(0,0), false
    end
    
    local cIdx, lIdx, tIdx, sIdx = 1, 1, 1, 1
    
    for i = #activeKE, 1, -1 do
        local e = activeKE[i]
        e.life = e.life + dt
        if e.life >= e.maxLife then
            table.remove(activeKE, i)
        else
            local prog = e.life / e.maxLife
            
            if e.vel then 
                e.pos = e.pos + e.vel * dt 
                e.vel = e.vel * (1 - math.min(1, dt * 3))
            end
            if e.grav then 
                e.vel = e.vel + e.grav * dt 
                e.grav = e.grav * (1 - math.min(1, dt * 2))
            end
            if e.pullTarget then
                local dir = (e.pullTarget - e.pos)
                if dir.Magnitude > 1 then
                    e.pos = e.pos + dir.Unit * e.pullSpeed * dt
                end
            end
            if e.sway then
                e.pos = e.pos + Vector3.new(math.sin(e.life * e.sway) * 5 * dt, 0, math.cos(e.life * e.sway * 0.7) * 5 * dt)
            end
            if e.rot then e.rot = e.rot * e.rotV end
            
            local sPos, onScreen = WTS(e.pos)
            
            if onScreen then
                local renderColor = e.color
                if e.color2 then
                    if prog < 0.5 then
                        renderColor = lerpColor(e.color, e.color2, prog * 2)
                    else
                        renderColor = lerpColor(e.color2, e.color3 or e.color2, (prog - 0.5) * 2)
                    end
                end
                
                if e.flicker then
                    renderColor = (math.random() > 0.5) and renderColor or Color3.new(1,1,1)
                end

                if e.shape == "Circle" and cIdx <= 40 then
                    local c = kePools.Circle[cIdx]
                    if e.shrink then
                        c.Radius = e.r - ((e.r - e.maxR) * prog)
                    else
                        c.Radius = e.r + ((e.maxR - e.r) * math.pow(prog, 0.5))
                    end
                    c.Position = sPos
                    c.Color = renderColor
                    c.Transparency = 1 - prog
                    c.Thickness = math.max(1, (e.t or 5) * (1 - prog))
                    c.Visible = true
                    cIdx = cIdx + 1
                elseif e.shape == "Line" and lIdx <= 250 then
                    local l = kePools.Line[lIdx]
                    local tail = e.pos - (e.vel and e.vel.Unit * e.length or Vector3.new(0,e.length,0))
                    local sTail, tOn = WTS(tail)
                    if tOn then
                        l.From = sTail
                        l.To = sPos
                        l.Color = renderColor
                        l.Transparency = 1 - prog
                        l.Thickness = e.t or 2
                        l.Visible = true
                        lIdx = lIdx + 1
                    end
                elseif e.shape == "StaticLine" and lIdx <= 250 then
                    local l = kePools.Line[lIdx]
                    local s2, on2 = WTS(e.pos2)
                    if onScreen and on2 then
                        l.From = sPos
                        l.To = s2
                        l.Color = renderColor
                        l.Transparency = 1 - prog
                        l.Thickness = e.t or 3
                        l.Visible = true
                        lIdx = lIdx + 1
                    end
                elseif e.shape == "Triangle" and tIdx <= 150 then
                    local size = e.size * (1 - prog)
                    local p1 = e.pos + (e.rot * Vector3.new(0, size, 0))
                    local p2 = e.pos + (e.rot * Vector3.new(-size, -size, 0))
                    local p3 = e.pos + (e.rot * Vector3.new(size, -size, 0))
                    local s1, on1 = WTS(p1)
                    local s2, on2 = WTS(p2)
                    local s3, on3 = WTS(p3)
                    if on1 and on2 and on3 then
                        local t = kePools.Triangle[tIdx]
                        t.PointA = s1; t.PointB = s2; t.PointC = s3
                        t.Color = renderColor
                        t.Transparency = 1 - prog
                        t.Visible = true
                        tIdx = tIdx + 1
                    end
                elseif e.shape == "Square" and sIdx <= 100 then
                    local sq = kePools.Square[sIdx]
                    if e.flicker then
                        sq.Position = sPos + Vector2.new(math.random(-10,10), math.random(-10,10))
                        sq.Transparency = (math.random()>0.5) and 1 or 0
                    else
                        sq.Position = sPos - Vector2.new(e.size/2, e.size/2)
                        sq.Transparency = 1 - prog
                    end
                    sq.Size = Vector2.new(e.size, e.size)
                    sq.Color = renderColor
                    sq.Visible = true
                    sIdx = sIdx + 1
                end
            end
        end
    end
    
    for i = cIdx, 40 do kePools.Circle[i].Visible = false end
    for i = lIdx, 250 do kePools.Line[i].Visible = false end
    for i = tIdx, 150 do kePools.Triangle[i].Visible = false end
    for i = sIdx, 100 do kePools.Square[i].Visible = false end
end)

local function CustomW2S(p)
    if type(WorldToScreen) == "function" then
        local ok, pos2d, onScreen = pcall(WorldToScreen, p)
        if ok and pos2d then return pos2d, onScreen end
    end
    local cam = workspace.CurrentCamera
    if cam then
        local ok, vp, on = pcall(function() return cam:WorldToViewportPoint(p) end)
        if ok and vp then
            return Vector2.new(vp.X, vp.Y), on
        end
    end
    return Vector2.new(0,0), false
end

local function spawnHitTracerCube(cframe, size, duration, color)
    local s = size / 2
    local localVerts = {
        Vector3.new(-s.X, -s.Y, -s.Z), Vector3.new( s.X, -s.Y, -s.Z),
        Vector3.new( s.X,  s.Y, -s.Z), Vector3.new(-s.X,  s.Y, -s.Z),
        Vector3.new(-s.X, -s.Y,  s.Z), Vector3.new( s.X, -s.Y,  s.Z),
        Vector3.new( s.X,  s.Y,  s.Z), Vector3.new(-s.X,  s.Y,  s.Z)
    }
    
    local worldVerts = {}
    for i = 1, 8 do
        local ok, wp = pcall(function() return cframe:PointToWorldSpace(localVerts[i]) end)
        if not ok or not wp then wp = cframe.Position + localVerts[i] end
        worldVerts[i] = wp
    end
    
    local edges = {
        {1, 2}, {2, 3}, {3, 4}, {4, 1},
        {5, 6}, {6, 7}, {7, 8}, {8, 5},
        {1, 5}, {2, 6}, {3, 7}, {4, 8}
    }
    
    local lines = {}
    local glowLines = {}
    for i = 1, #edges do
        if HitTracerGlowEnabled then
            glowLines[i] = {}
            for g = 1, 2 do
                local gLine = (Drawing and Drawing.new or function() return {Remove = function() end} end)("Line")
                if type(gLine) == "table" and gLine.Thickness then
                    gLine.Thickness = HitTracerBoxThickness + (g * 4)
                    gLine.Color = color
                    gLine.Visible = false
                    pcall(function() gLine.ZIndex = 0 end)
                    table.insert(glowLines[i], gLine)
                end
            end
        end
        
        local line = (Drawing and Drawing.new or function() return {Remove = function() end} end)("Line")
        if type(line) == "table" and not line.Thickness then break end
        line.Thickness = HitTracerBoxThickness
        line.Color = color
        line.Visible = false
        pcall(function() line.ZIndex = 1 end)
        lines[i] = line
    end
    
    if #lines == 0 then return end
    
    local startTime = os.clock()
    local conn
    
    conn = RunService.RenderStepped:Connect(function()
        local elapsed = os.clock() - startTime
        
        if elapsed > duration then
            for _, line in pairs(lines) do pcall(function() line:Remove() end) end
            for _, gList in pairs(glowLines) do
                for _, gLine in ipairs(gList) do pcall(function() gLine:Remove() end) end
            end
            if conn then conn:Disconnect() end
            return
        end
        
        local alpha = 1 - (elapsed / duration)
        
        if HitTracerRainbow then
            local hue = (os.clock() % 2) / 2
            local rbColor = Color3.fromHSV(hue, 1, 1)
            for _, line in pairs(lines) do pcall(function() line.Color = rbColor end) end
            for _, gList in pairs(glowLines) do
                for _, gLine in ipairs(gList) do pcall(function() gLine.Color = rbColor end) end
            end
        end

        for i, edge in ipairs(edges) do
            local p1 = worldVerts[edge[1]]
            local p2 = worldVerts[edge[2]]
            
            local s1, on1 = CustomW2S(p1)
            local s2, on2 = CustomW2S(p2)
            
            local line = lines[i]
            if line and on1 and on2 then
                line.From = Vector2.new(s1.X, s1.Y)
                line.To = Vector2.new(s2.X, s2.Y)
                line.Transparency = alpha
                line.Visible = true
                
                if glowLines[i] then
                    for g, gLine in ipairs(glowLines[i]) do
                        gLine.From = line.From
                        gLine.To = line.To
                        gLine.Transparency = alpha * (0.75 - (g * 0.2))
                        gLine.Visible = true
                    end
                end
            elseif line then
                line.Visible = false
                if glowLines[i] then
                    for _, gLine in ipairs(glowLines[i]) do gLine.Visible = false end
                end
            end
        end
    end)
end

local function spawnHitTracerConnectionLine(startPos, endPos, duration, color, thickness)
    local line = (Drawing and Drawing.new or function() return {Remove = function() end} end)("Line")
    if type(line) == "table" and not line.Thickness then return end
    line.Thickness = thickness
    line.Color = color
    line.Visible = false
    
    local glowLine
    if HitTracerGlowEnabled then
        glowLine = (Drawing and Drawing.new or function() return {Remove = function() end} end)("Line")
        if type(glowLine) == "table" and glowLine.Thickness then
            glowLine.Thickness = thickness + 4
            glowLine.Color = color
            glowLine.Visible = false
        end
    end
    
    local startTime = os.clock()
    local lastUpdate = 0
    local conn
    
    conn = RunService.RenderStepped:Connect(function()
        local elapsed = os.clock() - startTime
        if elapsed > duration then
            pcall(function() line:Remove() end)
            if glowLine then pcall(function() glowLine:Remove() end) end
            if conn then conn:Disconnect() end
            return
        end
        
        local alpha = 1 - (elapsed / duration)
        
        if HitTracerRainbow then
            local hue = (os.clock() % 2) / 2
            local rbColor = Color3.fromHSV(hue, 1, 1)
            pcall(function() line.Color = rbColor end)
            if glowLine then pcall(function() glowLine.Color = rbColor end) end
        end

        local s1, on1 = CustomW2S(startPos)
        local s2, on2 = CustomW2S(endPos)
        
        if not ok2 or not on2 then
            line.Visible = false
            if glowLine then glowLine.Visible = false end
            return
        end
        

        
        if ok1 and on1 then
            line.From = Vector2.new(s1.X, s1.Y)
            line.To = Vector2.new(s2.X, s2.Y)
            line.Transparency = alpha
            line.Visible = true
            
            if glowLine then
                glowLine.From = line.From
                glowLine.To = line.To
                glowLine.Transparency = alpha * 0.3
                glowLine.Visible = true
            end
        else
            line.Visible = false
            if glowLine then glowLine.Visible = false end
        end
    end)
end

local function drawFullHitTracer(character, duration, color)
    local ok, children = pcall(function() return character:GetChildren() end)
    if not ok or type(children) ~= "table" then return end
    
    for _, part in ipairs(children) do
        if typeof(part) == "Instance" and part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
            local okTrans, trans = pcall(function() return part.Transparency end)
            if not okTrans or type(trans) ~= "number" or trans < 1 then
                local okCF, cf = pcall(function() return part.CFrame end)
                local okSz, sz = pcall(function() return part.Size end)
                if okCF and okSz and typeof(cf) == "CFrame" and typeof(sz) == "Vector3" then
                    spawnHitTracerCube(cf, sz, duration, color)
                end
            end
        end
    end
end

local function getClosestPlayerToMouseForTracer()
    local LocalPlayer = game:GetService("Players").LocalPlayer
    local mouse = getMouse()
    if not mouse then return nil end
    local mousePos = Vector2.new(mouse.X, mouse.Y)
    
    local okPlayers, allPlayers = pcall(function() return game:GetService("Players"):GetPlayers() end)
    if not okPlayers or type(allPlayers) ~= "table" then return nil end
    
    local closestDist = math.huge
    local closestPlayer = nil
    
    local CustomW2S = type(WorldToScreen) == "function" and WorldToScreen or function(p) return Vector2.new(0,0), false end

    for _, player in ipairs(allPlayers) do
        if player.Name ~= LocalPlayer.Name and player.Character then
            local hrp = player.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                local okW2S, sc, on = pcall(CustomW2S, hrp.Position)
                if okW2S and sc and on then
                    local dx = mousePos.X - sc.X
                    local dy = mousePos.Y - sc.Y
                    local dist = math.sqrt(dx*dx + dy*dy)
                    if dist < closestDist then
                        closestDist = dist
                        closestPlayer = player
                    end
                end
            end
        end
    end
    
    return closestPlayer
end

local wasMousePressed = false
local sheriffHadGun = false
local sheriffMurdererName = nil
local sheriffMurdererHealth = 100
local sheriffLastTarget = nil

RunService.RenderStepped:Connect(function()
    if not HitTracerEnabled and not (KillEffectEnabled and not KillEffectSheriffOnly) then return end
    
    local isPressed = (type(ismouse1pressed) == "function" and ismouse1pressed()) or false
    
    if isPressed and not wasMousePressed then
        local lp = game:GetService("Players").LocalPlayer
        local char = lp and lp.Character
        local isHoldingGun = char and char:FindFirstChild("Gun")
        
        local canShoot = true
        if HitTracerEnabled and HitTracerSheriffOnly then
            if not isHoldingGun or (os.clock() - lastHitTracerShot) < 2 then
                canShoot = false
            end
        end
        
        if canShoot or (KillEffectEnabled and not KillEffectSheriffOnly) then
            local target = getClosestPlayerToMouseForTracer()
            if target and target.Character then
                

                if HitTracerEnabled and canShoot then
                    if HitTracerSheriffOnly then
                        lastHitTracerShot = os.clock()
                        sheriffLastTarget = target
                    else
                        drawFullHitTracer(target.Character, HitTracerDuration, HitTracerColor)
                    end
                    
                    if HitTracerLineEnabled then
                        local lpChar = game:GetService("Players").LocalPlayer.Character
                        if lpChar then
                            local arm = lpChar:FindFirstChild("Right Arm") or lpChar:FindFirstChild("RightHand")
                            local head = lpChar:FindFirstChild("Head")
                            local myHrp = lpChar:FindFirstChild("HumanoidRootPart")
                            local tHrp = target.Character:FindFirstChild("HumanoidRootPart") or target.Character:FindFirstChild("Torso")
                            
                            if arm and tHrp then
                                local start3D = arm.Position
                                local cam = game:GetService("Workspace").CurrentCamera
                                if cam and head and myHrp then
                                    local okCam, camPos = pcall(function() return cam.CFrame.Position end)
                                    if okCam and camPos and (camPos - head.Position).Magnitude < 2 then
                                        local okCF, myCF = pcall(function() return myHrp.CFrame end)
                                        if okCF and myCF then
                                            start3D = head.Position + (myCF.LookVector * 2) - Vector3.new(0, 0.5, 0)
                                        end
                                    end
                                elseif myHrp and (arm.Position - myHrp.Position).Magnitude > 5 then
                                    start3D = myHrp.Position
                                end
                                spawnHitTracerConnectionLine(start3D, tHrp.Position, HitTracerDuration, HitTracerLineColor, HitTracerLineThickness)
                            end
                        end
                    end
                end
                

                if KillEffectEnabled and not KillEffectSheriffOnly then
                    local hrp = target.Character:FindFirstChild("HumanoidRootPart")
                    if hrp then triggerKillEffect(hrp.Position, KillEffectStyle) end
                end
            end
        end
    end
    wasMousePressed = isPressed
end)

task.spawn(function()
    while true do
        pcall(function()
            if not (HitTracerEnabled and HitTracerSheriffOnly) and not (KillEffectEnabled and KillEffectSheriffOnly) and not HitSoundsEnabled then return end
            
            local lp = game:GetService("Players").LocalPlayer
            local char = lp and lp.Character
            local bp = lp and lp:FindFirstChild("Backpack")
            
            local hasGun = false
            if char then
                for _, v in ipairs(char:GetChildren()) do
                    if v.ClassName == "Tool" and string.lower(v.Name) == "gun" then hasGun = true end
                end
            end
            if bp then
                for _, v in ipairs(bp:GetChildren()) do
                    if v.ClassName == "Tool" and string.lower(v.Name) == "gun" then hasGun = true end
                end
            end
            sheriffHadGun = hasGun
            
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= lp and p.Character then
                    local hasKnife = false
                    for _, v in ipairs(p.Character:GetChildren()) do
                        if v.ClassName == "Tool" and string.lower(v.Name) == "knife" then hasKnife = true end
                    end
                    local pBp = p:FindFirstChild("Backpack")
                    if pBp and not hasKnife then
                        for _, v in ipairs(pBp:GetChildren()) do
                            if v.ClassName == "Tool" and string.lower(v.Name) == "knife" then hasKnife = true end
                        end
                    end
                    
                    if hasKnife then
                        if sheriffMurdererName ~= p.Name then
                            sheriffMurdererName = p.Name
                            sheriffMurdererHealth = 100
                        end
                        
                        local hum = p.Character:FindFirstChild("Humanoid")
                        if hum then
                            local hp = hum.Health
                            if sheriffMurdererHealth > 0 and hp <= 0 and sheriffHadGun then
                                if HitTracerEnabled and HitTracerSheriffOnly then
                                    drawFullHitTracer(p.Character, HitTracerDuration, HitTracerColor)
                                end
                                if KillEffectEnabled and KillEffectSheriffOnly then
                                    local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                                    if hrp then triggerKillEffect(hrp.Position, KillEffectStyle) end
                                end
                                if HitSoundsEnabled then
                                    local pool = {}
                                    local defaultTexts = {"Hit!", "Boom!", "Eliminated!", "Headshot!", "Wasted!", "Smacked!", "Oof!", "Gotcha!"}
                                    
                                    local activeCustoms = {}
                                    if customSoundsCombo then
                                        local selected = customSoundsCombo:Get()
                                        if type(selected) == "table" then
                                            for k, v in pairs(selected) do
                                                if type(k) == "string" and v == true and k ~= "(None)" then table.insert(activeCustoms, k)
                                                elseif type(v) == "string" and v ~= "(None)" then table.insert(activeCustoms, v) end
                                            end
                                        elseif type(selected) == "string" and selected ~= "(None)" then
                                            table.insert(activeCustoms, selected)
                                        end
                                    end

                                    if HitSoundsOnlyCustom then
                                        pool = #activeCustoms > 0 and activeCustoms or {"(No Custom Sounds)"}
                                    else
                                        for _, v in ipairs(defaultTexts) do table.insert(pool, v) end
                                        for _, v in ipairs(activeCustoms) do table.insert(pool, v) end
                                    end
                                    
                                    if type(notify) == "function" and #pool > 0 then
                                        if HitSoundIndex > #pool then HitSoundIndex = 1 end
                                        notify(pool[HitSoundIndex], "Matcha", 4)
                                        HitSoundIndex = HitSoundIndex + 1
                                    end
                                end
                            end
                            sheriffMurdererHealth = hp
                        end
                    end
                end
            end
        end)
        task.wait(0.1)
    end
end)

local tracerSec = visualsTab:Section("Hit Tracers", "Right")

tracerSec:Toggle("Enable Hit Tracers", false, function(state)
    HitTracerEnabled = state
end)

tracerSec:Toggle("Enable Glow Effect", false, function(state)
    HitTracerGlowEnabled = state
end)

tracerSec:Toggle("Sheriff Only Mode (Gun)", false, function(state)
    HitTracerSheriffOnly = state
end)

tracerSec:Colorpicker("Hit Tracer Color", HitTracerColor, function(color)
    HitTracerColor = color
end)

tracerSec:Toggle("Rainbow Tracer", false, function(state)
    HitTracerRainbow = state
end)

tracerSec:Slider("Tracer Thickness (Box)", 1, 1, 1, 10, "", function(v)
    HitTracerBoxThickness = v
end)

tracerSec:Slider("Tracer Duration", 3, 1, 1, 10, " sec", function(v)
    HitTracerDuration = v
end)

tracerSec:Toggle("Enable Connecting Line", false, function(state)
    HitTracerLineEnabled = state
end)

tracerSec:Colorpicker("Connecting Line Color", HitTracerLineColor, function(color)
    HitTracerLineColor = color
end)

tracerSec:Slider("Connecting Line Thickness", 2, 1, 1, 10, "", function(v)
    HitTracerLineThickness = v
end)

local effectSec = visualsTab:Section("Kill Effects", "Right")

effectSec:Toggle("Enable Kill Effects", false, function(state)
    KillEffectEnabled = state
end)

effectSec:Toggle("Sheriff Only Mode", false, function(state)
    KillEffectSheriffOnly = state
end)

effectSec:Dropdown("Effect Style", "Random", {"Random", "Laser Eyes", "Cosmic Nova", "Blood Splatter", "Holy Smite", "Toxic Splash", "Ice Shatter", "Void Collapse", "Cyber Glitch", "Sparkler", "Sakura Petals"}, false, function(val)
    if type(val) == "table" then
        KillEffectStyle = val[1] or "Random"
    else
        KillEffectStyle = val
    end
end)

effectSec:Dropdown("Effect Version", "New (V2)", {"New (V2)", "Old (V1)"}, false, function(val)
    if type(val) == "table" then
        KillEffectVersion = val[1] or "New (V2)"
    else
        KillEffectVersion = val
    end
end)

effectSec:Slider("Effect Duration", 3, 1, 1, 10, "x", function(v)
    KillEffectDurationMultiplier = v
end)

local soundSec = visualsTab:Section("Hit Sounds", "Left")

soundSec:Toggle("Hit Sounds (Send Notification)", false, function(state)
    HitSoundsEnabled = state
end)

soundSec:Toggle("Only Custom Sounds", false, function(state)
    HitSoundsOnlyCustom = state
end)

local hitSoundInput = ""
soundSec:Textbox("Custom Text", "", function(text)
    hitSoundInput = text
end)

soundSec:Button("Add Custom Text", function()
    if hitSoundInput and hitSoundInput ~= "" then
        table.insert(CustomHitSounds, hitSoundInput)
        if customSoundsCombo then
            if #CustomHitSounds == 1 then
                customSoundsCombo:RemoveChoice("(None)")
            end
            customSoundsCombo:AddChoice(hitSoundInput)
        end
        if type(notify) == "function" then
            notify("Added: " .. hitSoundInput, "Matcha", 4)
        end
    end
end)

customSoundsCombo = soundSec:Dropdown("Added Customs", {}, {"(None)"}, true, function(val)
end)

soundSec:Button("Remove Selected Custom", function()
    if customSoundsCombo then
        local selected = customSoundsCombo:Get()
        local toRemove = {}
        if type(selected) == "table" then
            for k, v in pairs(selected) do
                if type(k) == "string" and v == true and k ~= "(None)" then table.insert(toRemove, k)
                elseif type(v) == "string" and v ~= "(None)" then table.insert(toRemove, v) end
            end
        elseif type(selected) == "string" and selected ~= "(None)" then
            table.insert(toRemove, selected)
        end
        
        for _, textToRemove in ipairs(toRemove) do
            customSoundsCombo:RemoveChoice(textToRemove)
            for i = #CustomHitSounds, 1, -1 do
                if CustomHitSounds[i] == textToRemove then
                    table.remove(CustomHitSounds, i)
                end
            end
        end
        
        if #CustomHitSounds == 0 then
            table.insert(CustomHitSounds, "(None)")
            customSoundsCombo:AddChoice("(None)")
        end
        if #toRemove > 0 and type(notify) == "function" then
            notify("Removed " .. #toRemove .. " sounds", "Matcha", 4)
        end
    end
end)

soundSec:Button("Test Hit Sound", function()
    local pool = {}
    local defaultTexts = {"Hit!", "Boom!", "Eliminated!", "Headshot!", "Wasted!", "Smacked!", "Oof!", "Gotcha!"}
    
    local activeCustoms = {}
    if customSoundsCombo then
        local selected = customSoundsCombo:Get()
        if type(selected) == "table" then
            for k, v in pairs(selected) do
                if type(k) == "string" and v == true and k ~= "(None)" then table.insert(activeCustoms, k)
                elseif type(v) == "string" and v ~= "(None)" then table.insert(activeCustoms, v) end
            end
        elseif type(selected) == "string" and selected ~= "(None)" then
            table.insert(activeCustoms, selected)
        end
    end

    if HitSoundsOnlyCustom then
        pool = #activeCustoms > 0 and activeCustoms or {"(No Custom Sounds)"}
    else
        for _, v in ipairs(defaultTexts) do table.insert(pool, v) end
        for _, v in ipairs(activeCustoms) do table.insert(pool, v) end
    end
    
    if type(notify) == "function" and #pool > 0 then
        if HitSoundIndex > #pool then HitSoundIndex = 1 end
        notify(pool[HitSoundIndex], "Matcha", 4)
        HitSoundIndex = HitSoundIndex + 1
    end
end)


local knifeSec = combatTab:Section("Magic Knife", "Right")

local MagicKnifeEnabled = false

local MagicKnifeFov = 150
local MagicKnifeFovVisible = true

local fovCircle = Drawing.new("Circle")
fovCircle.Color = Color3.fromRGB(255, 255, 255)
fovCircle.Thickness = 1
fovCircle.Filled = false
fovCircle.Visible = false

local mkLockedTarget = nil
local mkLastEPress = 0
local mkOriginalLook = nil
local mkRestored = false
local Camera = workspace.CurrentCamera

local function W2S(pos)
    if type(WorldToScreen) == "function" then return WorldToScreen(pos) end
    local w, on = Camera:WorldToViewportPoint(pos)
    return Vector2.new(w.X, w.Y), on
end

local function checkEKey()
    if type(iskeypressed) == "function" then return iskeypressed(0x45) end
    return game:GetService("UserInputService"):IsKeyDown(Enum.KeyCode.E)
end

local mouse = getMouse()

local currentFovPos = Vector2.new(0, 0)

RunService.RenderStepped:Connect(function()
    if not fovCircle then return end
    
    local isKatil = false
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Knife") then
        isKatil = true
    end
    local bp = LocalPlayer:FindFirstChild("Backpack")
    if bp and bp:FindFirstChild("Knife") then
        isKatil = true
    end

    if MagicKnifeFovVisible and isKatil then
        fovCircle.Visible = MagicKnifeEnabled
    else
        fovCircle.Visible = false
    end
    fovCircle.Radius = MagicKnifeFov
    
    local targetPos = Vector2.new(mouse.X, mouse.Y + 58)
    if currentFovPos.X == 0 and currentFovPos.Y == 0 then
        currentFovPos = targetPos
    else
        currentFovPos = Vector2.new(
            currentFovPos.X + (targetPos.X - currentFovPos.X) * 0.2,
            currentFovPos.Y + (targetPos.Y - currentFovPos.Y) * 0.2
        )
    end
    fovCircle.Position = currentFovPos
end)

task.spawn(function()
    local wasPressed = false
    while true do
        task.wait(0.05)
        pcall(function()
            if not MagicKnifeEnabled then wasPressed = false return end
            local pressed = checkEKey()
            if pressed and not wasPressed then
                local charFolder = workspace:FindFirstChild(LocalPlayer.Name)
                if charFolder and charFolder:FindFirstChild("Knife") then

                    local myRoot = charFolder:FindFirstChild("HumanoidRootPart")
                    if myRoot then
                        mkOriginalLook = myRoot.CFrame.LookVector
                    end

                    local mouseX, mouseY = mouse.X, mouse.Y
                    local closest, closestDist = nil, math.huge
                    for _, player in pairs(Players:GetPlayers()) do
                        if player.Name ~= LocalPlayer.Name then
                            local pChar = player.Character
                            if pChar then
                                local pHRP = pChar:FindFirstChild("HumanoidRootPart")
                                if pHRP then
                                    local screenPos, onScreen = W2S(pHRP.Position)
                                    if onScreen then
                                        local dx   = screenPos.X - mouseX
                                        local dy   = screenPos.Y - mouseY
                                        local dist = math.sqrt(dx*dx + dy*dy)
                                        if dist < MagicKnifeFov and dist < closestDist then
                                            closestDist = dist
                                            closest     = player
                                        end
                                    end
                                end
                            end
                        end
                    end
                    mkLockedTarget = closest
                    if mkLockedTarget and mkLockedTarget.Character and mkLockedTarget.Character:FindFirstChild("HumanoidRootPart") then
                        Camera.CFrame = CFrame.lookAt(Camera.CFrame.Position, mkLockedTarget.Character.HumanoidRootPart.Position)
                    end
                    mkLastEPress = os.clock()
                    mkRestored   = false
                end
            end
            wasPressed = pressed
        end)
    end
end)

RunService.Heartbeat:Connect(function()
    pcall(function()
        if not MagicKnifeEnabled then return end
        if mkLastEPress == 0 then return end
        if not mkLockedTarget then return end
        local elapsed = os.clock() - mkLastEPress

        if elapsed > 1.1 then
            if not mkRestored and mkOriginalLook then
                local charFolder = workspace:FindFirstChild(LocalPlayer.Name)
                if charFolder then
                    local myRoot = charFolder:FindFirstChild("HumanoidRootPart")
                    if myRoot then
                        Camera.CFrame = CFrame.lookAt(Camera.CFrame.Position, Camera.CFrame.Position + myRoot.CFrame.LookVector)
                        mkRestored = true
                    end
                end
            end
            return
        end

        if elapsed < 0.85 then return end

        local charFolder = workspace:FindFirstChild(LocalPlayer.Name)
        if not charFolder then return end
        local knife  = charFolder:FindFirstChild("Knife")
        if not knife then return end
        local handle = knife:FindFirstChild("Handle")
        if not handle then return end
        local tChar = mkLockedTarget.Character
        if not tChar then return end
        local tHRP  = tChar:FindFirstChild("HumanoidRootPart")
        if not tHRP then return end
        local myRoot = charFolder:FindFirstChild("HumanoidRootPart")
        if not myRoot then return end

        handle.CFrame = tHRP.CFrame

        for _, child in ipairs(workspace:GetChildren()) do
            if child.Name == "Knife" and child:IsA("BasePart") then
                child.CFrame = tHRP.CFrame
            end
        end
    end)
end)

knifeSec:Toggle("Knife Teleport", false, function(state)
    MagicKnifeEnabled = state
    if state then
        Lib:Notify("Magic Knife", "Silent Aim enabled! Equip knife and press E to throw at nearest player.", 4, "success")
    else
        Lib:Notify("Magic Knife", "Silent Aim disabled.", 3, "warning")
    end
end)




knifeSec:Toggle("Show FOV Circle", true, function(state)
    MagicKnifeFovVisible = state
end)

knifeSec:Slider("FOV Radius", 150, 10, 10, 300, "", function(v)
    MagicKnifeFov = v
end)

knifeSec:Colorpicker("FOV Circle Color", Color3.fromRGB(255, 255, 255), function(color)
    if fovCircle then fovCircle.Color = color end
end)

local farmTab = win:Tab("Auto Farm", "zap")
local farmSec = farmTab:Section("Coin Farm", "Left")

local FarmConfig = {
    AutoFarmEnabled = false,
    MaxCoins = 40,
    TweenSpeed = 25
}
local collectedCoinsThisRound = 0

local HIDE_OFFSET = 6

local function getHRP()
    local c = LocalPlayer.Character
    if c then return c:FindFirstChild("HumanoidRootPart") end
    return nil
end

local function isAlive()
    local c = LocalPlayer.Character
    if not c then return false end
    local h = c:FindFirstChild("Humanoid")
    if not h or h.Health <= 0 then return false end
    
    local inRound = false
    pcall(function()
        local pGui = LocalPlayer:FindFirstChild("PlayerGui")
        if pGui and pGui:FindFirstChild("MainGUI") and pGui.MainGUI:FindFirstChild("Game") then
            inRound = true
        end
    end)
    
    if not inRound then return false end
    
    return true
end

local function isBagFull()
    if collectedCoinsThisRound >= FarmConfig.MaxCoins then
        return true
    end
    local current_coins = 0
    pcall(function()
        local pGui = LocalPlayer:FindFirstChild("PlayerGui")
        if not pGui then return end
        local coinBags = pGui:FindFirstChild("MainGUI") and pGui.MainGUI:FindFirstChild("Game") and pGui.MainGUI.Game:FindFirstChild("CoinBags")
        if not coinBags then return end
        for _, v in ipairs(coinBags:GetDescendants()) do
            if v:IsA("TextLabel") and v.Visible then
                local num = string.match(v.Text or "", "%d+")
                if num then
                    current_coins = math.max(current_coins, tonumber(num) or 0)
                end
            end
        end
    end)
    return current_coins >= FarmConfig.MaxCoins
end

local function findCoinContainer()
    for _, map in ipairs(workspace:GetChildren()) do
        if map:FindFirstChild("CoinContainer") then
            return map.CoinContainer
        end
    end
    local normal = workspace:FindFirstChild("Normal")
    if normal then
        for _, child in ipairs(normal:GetChildren()) do
            if child:FindFirstChild("CoinContainer") then
                return child.CoinContainer
            end
        end
        if normal:FindFirstChild("CoinContainer") then
            return normal.CoinContainer
        end
    end
    return nil
end

local function isMM2Gun(v)
    if not v or not v:IsA("Tool") then return false end
    return v.Name == "Gun"
end

local function isMM2Knife(v)
    if not v or not v:IsA("Tool") then return false end
    return v.Name == "Knife"
end

local function findMurderer()
    for _, p in ipairs(PlayersService:GetPlayers()) do
        if p ~= LocalPlayer and p.Character then
            local bp = p:FindFirstChild("Backpack")
            local function hasKnife(container)
                if not container then return false end
                for _, v in ipairs(container:GetChildren()) do
                    if isMM2Knife(v) then return true end
                end
                return false
            end
            if hasKnife(p.Character) or hasKnife(bp) then
                return p
            end
        end
    end
    return nil
end

local function getMyRole()
    local char = LocalPlayer.Character
    local bp = LocalPlayer:FindFirstChild("Backpack")
    
    local function checkItems(container)
        if not container then return nil end
        for _, v in ipairs(container:GetChildren()) do
            if isMM2Gun(v) then
                return "Sheriff"
            elseif isMM2Knife(v) then
                return "Murderer"
            end
        end
        return nil
    end
    
    local role = checkItems(char)
    if role then return role end
    role = checkItems(bp)
    if role then return role end
    
    return "Innocent"
end

local function handlePostFarmAction()
    local myRole = getMyRole()
    local hrp = getHRP()
    
    if myRole == "Murderer" then
        if FarmConfig.AutoKillAfterFarm then
            if hrp then
                hrp.CFrame = CFrame.new(-1.79, -64.45, -85.25)
                task.wait(0.2)
            end
            task.spawn(function()
                doAutoKill(true) 
            end)
            return true
        end
    else
        if hrp then
            hrp.CFrame = CFrame.new(hrp.Position.X, -500, hrp.Position.Z)
        end
        return true
    end
    return false
end

local farmThreadActive = false
local antiFallConnection = nil
local noclipConnection = nil

local function getMapName()
    local normal = workspace:FindFirstChild("Normal")
    if normal then
        for _, v in ipairs(normal:GetChildren()) do
            if v:IsA("Model") or v:IsA("Folder") then
                return string.lower(v.Name)
            end
        end
    end
    return ""
end

local function runFarm()
    if farmThreadActive then return end
    farmThreadActive = true
    
    local can = true
    local first = true
    local offset = 5
    
    local function isValid(obj) return obj and obj.Parent ~= nil end
    local function isAlive()
        local c = LocalPlayer.Character
        if not c or not c:FindFirstChild("Humanoid") or c.Humanoid.Health <= 0 then return false end
        if LocalPlayer:GetAttribute("Alive") == false then return false end
        return true
    end

    local function magnitude(a, b)
        local dx = a.X - b.X
        local dy = a.Y - b.Y
        local dz = a.Z - b.Z
        return math.sqrt(dx * dx + dy * dy + dz * dz)
    end

    local function setNoclip()
        local char = LocalPlayer and LocalPlayer.Character
        if char and char.Parent then
            for _, part in ipairs(char:GetChildren()) do
                if part:IsA("BasePart") then
                    part.CanCollide = false
                end
            end
        end
    end

    local function findCoinContainer()
        for _, obj in ipairs(workspace:GetChildren()) do
            if obj:IsA("Model") then
                local container = obj:FindFirstChild("CoinContainer")
                if container then return container end
            end
        end
        return nil
    end

    if antiFallConnection then antiFallConnection:Disconnect(); antiFallConnection = nil end
    antiFallConnection = game:GetService("RunService").Heartbeat:Connect(function()
        if farmThreadActive and FarmConfig.AutoFarmEnabled then
            local hrp = getHRP()
            if hrp then hrp.Velocity = Vector3.new(0, 0, 0) end
            setNoclip()
        end
    end)

    if noclipConnection then noclipConnection:Disconnect(); noclipConnection = nil end
    noclipConnection = game:GetService("RunService").Stepped:Connect(function()
        if farmThreadActive and FarmConfig.AutoFarmEnabled then
            setNoclip()
        end
    end)

    while FarmConfig.AutoFarmEnabled do
        task.wait(0.05)

        local rtp = workspace:FindFirstChild("RoundTimerPart")
        if rtp and rtp:GetAttribute("Time") and rtp:GetAttribute("Time") <= 0 then
            first = true
            task.wait(0.5)
            continue
        end

        if not isAlive() then
            first = true
            task.wait(0.5)
            continue
        end

        local coins = 0
        pcall(function()
            coins = tonumber(LocalPlayer.PlayerGui.MainGUI.Game.CoinBags.Container.Coin.CurrencyFrame.Icon.Coins.Text) or 0
        end)

        if coins >= FarmConfig.MaxCoins then
            handlePostFarmAction()
            task.wait(1)
            continue
        end

        local container = findCoinContainer()
        if not container then
            first = true
            task.wait(0.5)
            continue
        end

        local char = LocalPlayer.Character
        if not char then continue end

        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then continue end

        local coin = nil
        local best = math.huge

        for _, obj in ipairs(container:GetChildren()) do
            if isValid(obj) and obj.Name == "Coin_Server" and obj:FindFirstChild("TouchInterest") then
                local dist = magnitude(obj.Position, hrp.Position)
                if dist < best then
                    best = dist
                    coin = obj
                end
            end
        end

        setNoclip()

        if coin and can and FarmConfig.AutoFarmEnabled then
            can = false
            local speed = first and 999 or math.max(10, FarmConfig.TweenSpeed)
            
            local cPos = coin.Position
            local startPos = hrp.Position
            local safeStart = Vector3.new(startPos.X, startPos.Y - offset, startPos.Z)
            local safeTarget = Vector3.new(cPos.X, cPos.Y - offset, cPos.Z)
            
            local dist = (safeStart - safeTarget).Magnitude
            local duration = dist / speed
            
            if duration > 0.001 then
                local t0 = os.clock()
                local finished = false
                local conn
                
                conn = game:GetService("RunService").RenderStepped:Connect(function()
                    if not FarmConfig.AutoFarmEnabled or not isAlive() or not isValid(hrp) or not isValid(coin) then
                        finished = true
                        conn:Disconnect()
                        return
                    end
                    
                    local elapsed = os.clock() - t0
                    local alpha = math.min(1, elapsed / duration)
                    
                    local newPos = safeStart:Lerp(safeTarget, alpha)
                    hrp.CFrame = CFrame.new(newPos.X, newPos.Y, newPos.Z)
                    hrp.Velocity = Vector3.new(0, 0, 0)
                    
                    if alpha >= 1 then
                        finished = true
                        conn:Disconnect()
                    end
                end)
                
                while not finished do
                    task.wait()
                end
            end
            
            if isValid(hrp) and isValid(coin) and FarmConfig.AutoFarmEnabled then
                hrp.CFrame = CFrame.new(cPos.X, cPos.Y, cPos.Z)
            end
            
            can = true
            first = false
        end
    end

    farmThreadActive = false
    if antiFallConnection then antiFallConnection:Disconnect(); antiFallConnection = nil end
    if noclipConnection then noclipConnection:Disconnect(); noclipConnection = nil end
end

farmSec:Toggle("Enable Auto Farm", false, function(state)
    FarmConfig.AutoFarmEnabled = state
    if state then
        task.spawn(runFarm)
        Lib:Notify("Auto Farm", "Started farming!", 3, "success")
    else
        local hrp = getHRP()
        
        
        local character = LocalPlayer.Character
        if character then
            for _, v in ipairs(character:GetDescendants()) do
                if v:IsA("BasePart") then v.CanCollide = true end
            end
        end
        Lib:Notify("Auto Farm", "Stopped farming.", 3, "warning")
    end
end)

farmSec:Toggle("Kill All if Murderer (After Farm)", false, function(state)
    FarmConfig.AutoKillAfterFarm = state
end)

farmSec:Slider("Max Coins Limit", 40, 1, 10, 50, "", function(v) FarmConfig.MaxCoins = v end)
farmSec:Slider("Movement Speed", 25, 1, 1, 30, "", function(v) FarmConfig.TweenSpeed = v end)

win:AddSettingsTab("cog")

game:GetService("RunService").Heartbeat:Connect(function()
    pcall(function()
        if RoundTimerEnabled then
            local cam = workspace.CurrentCamera
            if cam then
                TimerLabel.Position = Vector2.new(cam.ViewportSize.X / 2, 20)
            end
            
            local timerPart = workspace:FindFirstChild("RoundTimerPart")
            if timerPart then
                local surfaceGui = timerPart:FindFirstChild("SurfaceGui")
                if surfaceGui then
                    local timerText = surfaceGui:FindFirstChild("Timer")
                    if timerText and timerText.Text then
                        TimerLabel.Text = "Round Time: " .. timerText.Text
                    end
                end
            else
                TimerLabel.Text = "Round Time: --:--"
            end
        end
    end)
end)

Lib:Notify("Success!", "Trade Checker, ESP and Gingerscope Skin loaded!", 5, "success")
