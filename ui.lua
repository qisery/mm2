local HttpService = game:GetService("HttpService")
local API_URL = "https://mm2-api.onrender.com/api/all"

local Lib = loadstring(game:HttpGet("https://raw.githubusercontent.com/neaxusxgod-png/INS-ui/main/uilib.min.lua"))() or INSui



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
    doAutoKillActive = true
    task.spawn(function()
        local startTime = tick()
        while doAutoKillActive do
            pcall(function()
                local character = game.Players.LocalPlayer and game.Players.LocalPlayer.Character
                if character then
                    local backpack = game.Players.LocalPlayer:FindFirstChildOfClass("Backpack")
                    local hasGun = (backpack and backpack:FindFirstChild("Gun")) or character:FindFirstChild("Gun")
                    if hasGun and KillAllEnabled then
                        local attempts = 0
                        for _, player in ipairs(game.Players:GetPlayers()) do
                            if player ~= game.Players.LocalPlayer and player.Character then
                                local hum = player.Character:FindFirstChildOfClass("Humanoid")
                                local root = player.Character:FindFirstChild("HumanoidRootPart")
                                if hum and hum.Health > 0 and root then
                                    attempts = attempts + 1
                                    shootGunAt(root.Position)
                                    task.wait(0.08)
                                end
                            end
                        end
                        if attempts == 0 then
                            task.wait(0.2)
                        end
                    end
                end
            end)
            if not ignoreLimit and tick() - startTime >= 8 then
                break
            end
            task.wait(0.03)
        end
        doAutoKillActive = false
    end)
