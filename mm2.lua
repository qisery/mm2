--================================================================--
--                                                                --
--                LeatherHub | Murder Mystery 2                   --
--                  UI: Obsidian UI Library                       --
--                                                                --
--================================================================--

--================================================================--
--                    SERVICES & CONSTANTS                        --
--================================================================--

local Services = {
    Players = game:GetService("Players"),
    RunService = game:GetService("RunService"),
    UserInputService = game:GetService("UserInputService"),
    GuiService = game:GetService("GuiService"),
    HttpService = game:GetService("HttpService"),
    ReplicatedStorage = game:GetService("ReplicatedStorage"),
    Workspace = game:GetService("Workspace"),
}

local LocalPlayer = Services.Players.LocalPlayer

local API_URL = "https://mm2-api.onrender.com/api/all"
local OBSIDIAN_REPO = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"
local LOGO_URL = "https://raw.githubusercontent.com/qisery/mm2/main/moto1.jpg"

--================================================================--
--                     SESSION (re-execution)                     --
--================================================================--

local Session = {}
do
    local SESSION_KEY = "__LeatherHubMM2"
    local ok, shared = pcall(function()
        return type(getgenv) == "function" and getgenv() or _G
    end)
    local env = (ok and shared) or _G

    local store = env[SESSION_KEY]
    if type(store) ~= "table" then
        store = { generation = 0, connections = {} }
        env[SESSION_KEY] = store
    end

    for _, connection in ipairs(store.connections) do
        pcall(function()
            connection:Disconnect()
        end)
    end

    store.connections = {}
    store.generation = store.generation + 1

    function Session.track(connection)
        table.insert(store.connections, connection)
        return connection
    end
end

--================================================================--
--                          SCHEDULER                             --
--================================================================--

local Scheduler = {}
do
    local intervalTasks = {}
    local renderTasks = {}
    local reported = {}

    local function runTask(entry, elapsed)
        local ok, err = pcall(entry.fn, elapsed)
        if not ok and not reported[entry.name] then
            reported[entry.name] = true
            warn(("[LeatherHub] task '%s' errored and will be reported once: %s"):format(entry.name, tostring(err)))
        end
    end

    local function makeHandle(list, entry)
        local handle = {}

        function handle.stop()
            for index = #list, 1, -1 do
                if list[index] == entry then
                    table.remove(list, index)
                end
            end
        end

        return handle
    end

    function Scheduler.every(name, interval, fn)
        local entry = { name = name, interval = interval or 0, fn = fn, last = 0 }
        table.insert(intervalTasks, entry)
        return makeHandle(intervalTasks, entry)
    end

    function Scheduler.onHeartbeat(name, fn)
        return Scheduler.every(name, 0, fn)
    end

    function Scheduler.onRender(name, fn)
        local entry = { name = name, fn = fn }
        table.insert(renderTasks, entry)
        return makeHandle(renderTasks, entry)
    end

    Session.track(Services.RunService.Heartbeat:Connect(function()
        local now = os.clock()
        for index = #intervalTasks, 1, -1 do
            local entry = intervalTasks[index]
            if entry then
                local elapsed = now - entry.last
                if elapsed >= entry.interval then
                    entry.last = now
                    runTask(entry, elapsed)
                end
            end
        end
    end))

    Session.track(Services.RunService.RenderStepped:Connect(function(dt)
        for index = #renderTasks, 1, -1 do
            local entry = renderTasks[index]
            if entry then
                runTask(entry, dt)
            end
        end
    end))
end

--================================================================--
--                            UTIL                                --
--================================================================--

local Util = {}
do
    local Players = Services.Players
    local Workspace = Services.Workspace

    local ZERO_VECTOR2 = Vector2.new(0, 0)

    ----------------------------------------------------------------
    -- Drawing
    ----------------------------------------------------------------

    local drawingStub = setmetatable({}, {
        __index = function(_, key)
            if key == "Remove" or key == "Destroy" then
                return function() end
            end
            return nil
        end,
        __newindex = function() end,
    })

    local drawingAvailable = type(Drawing) == "table" and type(Drawing.new) == "function"

    function Util.newDrawing(class, props)
        if not drawingAvailable then
            return drawingStub
        end

        local ok, object = pcall(Drawing.new, class)
        if not ok or not object then
            return drawingStub
        end

        for key, value in pairs(props or {}) do
            pcall(function()
                object[key] = value
            end)
        end

        return object
    end

    function Util.drawingFont(name, fallback)
        local fonts = drawingAvailable and Drawing.Fonts or nil
        return (fonts and fonts[name]) or fallback or 0
    end

    ----------------------------------------------------------------
    -- Screen space
    ----------------------------------------------------------------

    function Util.worldToScreen(position)
        if type(WorldToScreen) == "function" then
            local ok, point, onScreen = pcall(WorldToScreen, position)
            if ok and point then
                return Vector2.new(point.X, point.Y), onScreen == true
            end
        end

        local camera = Workspace.CurrentCamera
        if not camera then
            return ZERO_VECTOR2, false
        end

        local point, onScreen = camera:WorldToViewportPoint(position)
        return Vector2.new(point.X, point.Y), onScreen
    end

    function Util.getMousePosition()
        local ok, position = pcall(function()
            return Services.UserInputService:GetMouseLocation()
        end)
        if ok and position then
            return position
        end
        return ZERO_VECTOR2
    end

    function Util.getMouseScreenPosition()
        local position = Util.getMousePosition()
        local ok, inset = pcall(function()
            return Services.GuiService:GetGuiInset()
        end)
        if ok and inset then
            return position + inset
        end
        return position
    end

    function Util.lerpColor(from, to, alpha)
        return Color3.new(
            from.R + (to.R - from.R) * alpha,
            from.G + (to.G - from.G) * alpha,
            from.B + (to.B - from.B) * alpha
        )
    end

    ----------------------------------------------------------------
    -- Character
    ----------------------------------------------------------------

    local cachedCharacter, cachedRoot

    function Util.getHRP()
        local character = LocalPlayer.Character
        if not character or not character.Parent then
            cachedCharacter, cachedRoot = nil, nil
            return nil
        end

        if cachedCharacter ~= character or not cachedRoot or cachedRoot.Parent ~= character then
            cachedCharacter = character
            cachedRoot = character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart
        end

        return cachedRoot
    end

    function Util.getPlayerHRP(player)
        local character = player and player.Character
        return character and character:FindFirstChild("HumanoidRootPart") or nil
    end

    function Util.isAlive(player)
        local character = (player or LocalPlayer).Character
        if not character then
            return false
        end
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        return humanoid ~= nil and humanoid.Health > 0
    end

    ----------------------------------------------------------------
    -- Roles
    ----------------------------------------------------------------

    function Util.hasTool(container, toolName)
        if not container then
            return false
        end
        for _, item in ipairs(container:GetChildren()) do
            if item:IsA("Tool") and item.Name == toolName then
                return true
            end
        end
        return false
    end

    function Util.playerHasTool(player, toolName)
        if not player then
            return false
        end
        return Util.hasTool(player.Character, toolName)
            or Util.hasTool(player:FindFirstChildOfClass("Backpack"), toolName)
    end

    function Util.getPlayerRole(player)
        if Util.playerHasTool(player, "Knife") then
            return "Murderer"
        end
        if Util.playerHasTool(player, "Gun") then
            return "Sheriff"
        end
        return "Innocent"
    end

    function Util.findPlayerWithTool(toolName)
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and Util.isAlive(player) and Util.playerHasTool(player, toolName) then
                local root = Util.getPlayerHRP(player)
                if root then
                    return player, root
                end
            end
        end
        return nil, nil
    end

    ----------------------------------------------------------------
    -- Map lookups
    ----------------------------------------------------------------

    function Util.findGunDrop()
        local direct = Workspace:FindFirstChild("GunDrop")
        if direct and direct:IsA("BasePart") then
            return direct
        end

        for _, child in ipairs(Workspace:GetChildren()) do
            if (child:IsA("Model") or child:IsA("Folder")) and not child:FindFirstChild("Humanoid") then
                local drop = child:FindFirstChild("GunDrop")
                if drop and drop:IsA("BasePart") then
                    return drop
                end

                if child.Name == "Normal" then
                    for _, map in ipairs(child:GetChildren()) do
                        local mapDrop = map:FindFirstChild("GunDrop")
                        if mapDrop and mapDrop:IsA("BasePart") then
                            return mapDrop
                        end
                    end
                end
            end
        end

        return nil
    end

    function Util.findCoinContainer()
        for _, child in ipairs(Workspace:GetChildren()) do
            local container = child:FindFirstChild("CoinContainer")
            if container then
                return container
            end
        end

        local normal = Workspace:FindFirstChild("Normal")
        if normal then
            for _, child in ipairs(normal:GetChildren()) do
                local container = child:FindFirstChild("CoinContainer")
                if container then
                    return container
                end
            end
            return normal:FindFirstChild("CoinContainer")
        end

        return nil
    end

    ----------------------------------------------------------------
    -- Text
    ----------------------------------------------------------------

    function Util.comma(value)
        local number = math.floor(tonumber(value) or 0)
        local sign = ""
        if number < 0 then
            sign = "-"
            number = -number
        end

        local text = tostring(number)
        while true do
            local replacements
            text, replacements = text:gsub("^(%d+)(%d%d%d)", "%1,%2")
            if replacements == 0 then
                break
            end
        end

        return sign .. text
    end

    function Util.cleanString(value)
        return (tostring(value):lower():gsub("[^%w]", ""))
    end

    function Util.toKeyCode(key)
        if typeof(key) == "EnumItem" then
            return key
        end
        if type(key) ~= "string" then
            return Enum.KeyCode.RightControl
        end
        return Enum.KeyCode[(key:gsub("%s+", ""))] or Enum.KeyCode.RightControl
    end

    function Util.tapKey(virtualKey)
        pcall(keypress, virtualKey)
        task.wait(0.02)
        pcall(keyrelease, virtualKey)
    end

    function Util.clickMouse()
        pcall(function()
            mouse1click()
        end)
    end

    function Util.isMouse1Down()
        if type(ismouse1pressed) ~= "function" then
            return false
        end
        local ok, pressed = pcall(ismouse1pressed)
        return ok and pressed == true
    end

    function Util.isKeyDown(virtualKey, keyCode)
        if type(iskeypressed) == "function" then
            local ok, pressed = pcall(iskeypressed, virtualKey)
            if ok then
                return pressed == true
            end
        end
        return Services.UserInputService:IsKeyDown(keyCode)
    end
end

--================================================================--
--                      MODULE REGISTRY                           --
--================================================================--

local Modules = {}
local moduleOrder = {}

local function defineModule(name, factory)
    Modules[name] = factory
    table.insert(moduleOrder, name)
end

--================================================================--
--            MODULE: UI (Obsidian loader + legacy adapter)       --
--================================================================--

defineModule("ui", function(Ctx)
    local function safeLoad(url)
        -- Network + loadstring: the reason pcall exists.
        local ok, loaded = pcall(function()
            return loadstring(game:HttpGet(url))()
        end)
        return ok and loaded or nil
    end

    local ObsidianLib = safeLoad(OBSIDIAN_REPO .. "Library.lua")
    if not ObsidianLib then
        error("failed to load the Obsidian UI library", 0)
    end

    local ThemeManager = safeLoad(OBSIDIAN_REPO .. "addons/ThemeManager.lua")
    local SaveManager = safeLoad(OBSIDIAN_REPO .. "addons/SaveManager.lua")

    ----------------------------------------------------------------
    -- Legacy adapter: bridges the old section/tab API used by the
    -- feature modules onto Obsidian's groupboxes.
    ----------------------------------------------------------------

    local uiIdCounter = 0
    local pendingTheme, pendingCornerRadius

    local function nextId(prefix, text)
        uiIdCounter = uiIdCounter + 1
        local cleaned = tostring(text or "element"):lower():gsub("[^%w]+", "_"):gsub("^_+", ""):gsub("_+$", "")
        if cleaned == "" then
            cleaned = "element"
        end
        return string.format("%s_%s_%d", prefix, cleaned, uiIdCounter)
    end

    local function toSelectedMap(value)
        if type(value) == "table" then
            if #value > 0 then
                local selected = {}
                for _, item in ipairs(value) do
                    selected[item] = true
                end
                return selected
            end
            return value
        end

        if type(value) == "string" and value ~= "" then
            return { [value] = true }
        end

        return {}
    end

    local function toSelectedList(value, values)
        if type(value) == "string" then
            return { value }
        end

        if type(value) ~= "table" then
            return {}
        end

        if #value > 0 then
            local out = {}
            for _, item in ipairs(value) do
                table.insert(out, item)
            end
            return out
        end

        local out = {}
        local seen = {}
        if type(values) == "table" then
            for _, candidate in ipairs(values) do
                if value[candidate] then
                    table.insert(out, candidate)
                    seen[candidate] = true
                end
            end
        end

        for key, state in pairs(value) do
            if type(key) == "string" and state == true and not seen[key] then
                table.insert(out, key)
                seen[key] = true
            elseif type(state) == "string" and not seen[state] then
                table.insert(out, state)
                seen[state] = true
            end
        end
        return out
    end

    local function normalizeSingle(value, values)
        if type(value) == "number" and type(values) == "table" then
            return values[value]
        end

        if type(value) ~= "table" then
            return value
        end

        if #value > 0 then
            return value[1]
        end

        if type(values) == "table" then
            for _, candidate in ipairs(values) do
                if value[candidate] then
                    return candidate
                end
            end
        end

        for key, state in pairs(value) do
            if type(key) == "string" and state == true then
                return key
            elseif type(state) == "string" then
                return state
            end
        end
        return nil
    end

    local function createSectionWrapper(groupbox)
        local section = {}

        function section:Label(text)
            local label = groupbox:AddLabel(tostring(text or ""))
            local state = { text = tostring(text or ""), color = nil }
            local wrapped = {}

            local function refreshLabel()
                if state.color then
                    label:SetText(string.format(
                        '<font color="rgb(%d,%d,%d)">%s</font>',
                        math.floor((state.color.R * 255) + 0.5),
                        math.floor((state.color.G * 255) + 0.5),
                        math.floor((state.color.B * 255) + 0.5),
                        state.text
                    ))
                else
                    label:SetText(state.text)
                end
            end

            function wrapped:SetText(newText)
                state.text = tostring(newText or "")
                refreshLabel()
            end

            function wrapped:SetColor(newColor)
                state.color = newColor
                refreshLabel()
            end

            return wrapped
        end

        function section:Button(text, callback)
            return groupbox:AddButton(tostring(text or "Button"), function()
                if callback then
                    callback()
                end
            end)
        end

        function section:Divider(text)
            return groupbox:AddDivider(text)
        end

        function section:Toggle(text, defaultValue, callback)
            local toggle = groupbox:AddToggle(nextId("toggle", text), {
                Text = tostring(text or "Toggle"),
                Default = defaultValue == true,
                Callback = function(state)
                    if callback then
                        callback(state)
                    end
                end,
            })

            local wrapped = {}

            function wrapped:AddKeybind(key, mode, bindCallback)
                return toggle:AddKeyPicker(nextId("keybind", text), {
                    Default = type(key) == "string" and key:upper() or "NONE",
                    Mode = mode or "Hold",
                    Text = tostring(text or "Keybind"),
                    SyncToggleState = false,
                    Callback = function(active)
                        if bindCallback then
                            bindCallback(active)
                        end
                    end,
                })
            end

            function wrapped:Set(value)
                toggle:SetValue(value == true)
            end

            return wrapped
        end

        function section:Colorpicker(text, defaultColor, callback)
            local anchor = groupbox:AddLabel(tostring(text or "Color"))
            return anchor:AddColorPicker(nextId("color", text), {
                Title = tostring(text or "Color"),
                Default = defaultColor or Color3.fromRGB(255, 255, 255),
                Callback = function(color)
                    if callback then
                        callback(color)
                    end
                end,
            })
        end

        function section:Slider(text, defaultValue, _rounding, minValue, maxValue, suffix, callback)
            return groupbox:AddSlider(nextId("slider", text), {
                Text = tostring(text or "Slider"),
                Default = tonumber(defaultValue) or 0,
                Min = tonumber(minValue) or 0,
                Max = tonumber(maxValue) or 100,
                Rounding = 0,
                Suffix = tostring(suffix or ""),
                Callback = function(value)
                    if callback then
                        callback(value)
                    end
                end,
            })
        end

        function section:Textbox(text, defaultValue, callback)
            return groupbox:AddInput(nextId("input", text), {
                Text = tostring(text or "Input"),
                Default = tostring(defaultValue or ""),
                Callback = function(value)
                    if callback then
                        callback(value)
                    end
                end,
            })
        end

        function section:Dropdown(text, defaultValue, values, multi, callback, tooltip, searchable)
            local dropdownValues = type(values) == "table" and values or {}
            local isMulti = multi == true

            local defaultSelection = defaultValue
            if isMulti then
                defaultSelection = toSelectedMap(defaultValue)
            elseif defaultSelection == "nil" then
                defaultSelection = nil
            elseif type(defaultSelection) == "table" then
                defaultSelection = defaultSelection[1]
            end

            local dropdown = groupbox:AddDropdown(nextId("dropdown", text), {
                Text = tostring(text or "Dropdown"),
                Values = dropdownValues,
                Default = defaultSelection,
                Multi = isMulti,
                AllowNull = true,
                Tooltip = tooltip,
                Searchable = searchable == true,
                Callback = function(value)
                    if not callback then
                        return
                    end
                    if isMulti then
                        callback(toSelectedList(value, dropdownValues))
                    else
                        callback(normalizeSingle(value, dropdownValues))
                    end
                end,
            })

            local wrapped = { _dropdown = dropdown, _values = dropdownValues, _multi = isMulti }

            function wrapped:Get()
                local current = wrapped._dropdown.Value
                if wrapped._multi then
                    return toSelectedList(current, wrapped._values)
                end
                return normalizeSingle(current, wrapped._values)
            end

            function wrapped:Set(value)
                if wrapped._multi then
                    wrapped._dropdown:SetValue(toSelectedMap(value))
                    return
                end

                if type(value) == "table" then
                    wrapped._dropdown:SetValue(value[1])
                else
                    wrapped._dropdown:SetValue(value)
                end
            end

            function wrapped:UpdateChoices(newValues)
                wrapped._values = type(newValues) == "table" and newValues or {}
                wrapped._dropdown:SetValues(wrapped._values)
            end

            function wrapped:AddChoice(choice)
                table.insert(wrapped._values, choice)
                wrapped._dropdown:AddValues(choice)
            end

            function wrapped:RemoveChoice(choice)
                for index = #wrapped._values, 1, -1 do
                    if wrapped._values[index] == choice then
                        table.remove(wrapped._values, index)
                    end
                end

                wrapped._dropdown:SetValues(wrapped._values)

                if wrapped._multi then
                    local selected = wrapped:Get()
                    for index = #selected, 1, -1 do
                        if selected[index] == choice then
                            table.remove(selected, index)
                        end
                    end
                    wrapped:Set(selected)
                elseif wrapped:Get() == choice then
                    wrapped._dropdown:SetValue(nil)
                end
            end

            return wrapped
        end

        return section
    end

    local function createTabWrapper(tab)
        local wrappedTab = {}

        function wrappedTab:Section(name, side)
            local title = tostring(name or "Section")
            if tostring(side or "Left") == "Right" then
                return createSectionWrapper(tab:AddRightGroupbox(title))
            end
            return createSectionWrapper(tab:AddLeftGroupbox(title))
        end

        return wrappedTab
    end

    local function configureSettingsTab(window, icon)
        local settingsTab = window:AddTab("UI Settings", icon or "settings")

        if ThemeManager then
            pcall(function()
                ThemeManager:SetLibrary(ObsidianLib)
                ThemeManager:SetFolder("LeatherHubMM2")
                ThemeManager:ApplyToTab(settingsTab, "palette")
                ThemeManager:LoadDefault()
            end)
        end

        if SaveManager then
            pcall(function()
                SaveManager:SetLibrary(ObsidianLib)
                SaveManager:IgnoreThemeSettings()
                SaveManager:SetFolder("LeatherHubMM2")
                SaveManager:BuildConfigSection(settingsTab, "save")
                SaveManager:LoadAutoloadConfig()
            end)
        end

        return createTabWrapper(settingsTab)
    end

    local adapter = {}

    function adapter:ApplyThemePreset(theme)
        pendingTheme = theme
    end

    function adapter:SetBackgroundEffect(_effect) end

    function adapter:SetRounding(rounding)
        pendingCornerRadius = tonumber(rounding) or pendingCornerRadius
    end

    function adapter:SetRowLines(_enabled) end

    function adapter:CreateWindow(options)
        local windowOptions = options or {}
        local size = windowOptions.size
        local mappedSize

        if typeof(size) == "Vector2" then
            mappedSize = UDim2.fromOffset(size.X, size.Y)
        elseif typeof(size) == "UDim2" then
            mappedSize = size
        end

        local logo = windowOptions.logo or windowOptions.Icon
        local icon = logo
        if type(icon) == "string" and icon:match("^https?://") then
            icon = nil
            if writefile and getcustomasset then
                local ok, asset = pcall(function()
                    local extension = logo:match("%.(%w+)$") or "png"
                    local fileName = "LeatherHubMM2_Logo." .. extension
                    if not (isfile and isfile(fileName)) then
                        writefile(fileName, game:HttpGet(logo))
                    end
                    return getcustomasset(fileName)
                end)
                if ok and asset then
                    icon = asset
                end
            end
        end

        local window = ObsidianLib:CreateWindow({
            Title = windowOptions.title or windowOptions.Title or "LeatherHub MM2",
            Footer = windowOptions.subtitle or windowOptions.Footer or "",
            Icon = icon,
            Size = mappedSize,
            CornerRadius = pendingCornerRadius or windowOptions.CornerRadius,
            ToggleKeybind = Util.toKeyCode(windowOptions.menuKey or windowOptions.ToggleKeybind),
            NotifySide = "Right",
        })

        if pendingTheme and ThemeManager then
            pcall(function()
                ThemeManager:SetLibrary(ObsidianLib)
                ThemeManager:ApplyTheme(pendingTheme)
            end)
        end

        local wrappedWindow = {}

        function wrappedWindow:Tab(name, iconName)
            return createTabWrapper(window:AddTab(tostring(name or "Tab"), iconName))
        end

        function wrappedWindow:AddSettingsTab(iconName)
            return configureSettingsTab(window, iconName or "settings")
        end

        return wrappedWindow
    end

    function adapter:Notify(title, description, duration, kind)
        local iconByKind = {
            success = "check",
            error = "triangle-alert",
            warning = "alert-triangle",
            info = "info",
        }

        if description == nil then
            ObsidianLib:Notify(tostring(title or ""), tonumber(duration) or 4)
            return
        end

        ObsidianLib:Notify({
            Title = tostring(title or "Notice"),
            Description = tostring(description or ""),
            Time = tonumber(duration) or 4,
            Icon = iconByKind[kind],
        })
    end

    ----------------------------------------------------------------
    -- Window + tabs
    ----------------------------------------------------------------

    adapter:ApplyThemePreset("Default")
    adapter:SetRounding(0)
    adapter:SetRowLines(true)

    local window = adapter:CreateWindow({
        title = "LeatherHub MM2",
        subtitle = "MenuKey: Right Alt | Discord.gg/kQs7zvTwnX",
        logo = LOGO_URL,
        logoSize = 32,
        size = Vector2.new(950, 650),
        menuKey = "RightAlt",
        autoSave = false,
        smartFps = false,
    })

    Ctx.Lib = adapter
    Ctx.window = window

    function Ctx.notify(text, title, duration)
        adapter:Notify(title or "Notification", text or "", duration or 3)
    end

    Ctx.tabs = {
        trade = window:Tab("Trade Checker", "swords"),
        values = window:Tab("Item Values", "search"),
        combat = window:Tab("Combat", "swords"),
        visuals = window:Tab("Visuals", "eye"),
        misc = window:Tab("Misc", "shield"),
        farm = window:Tab("Auto Farm", "zap"),
    }
end)

--================================================================--
--                 MODULE: ITEM VALUES (API + tab)                --
--================================================================--

defineModule("values", function(Ctx)
    local Lib = Ctx.Lib
    local cleanString = Util.cleanString

    Lib:Notify("Loading...", "Fetching values from server, please wait.", 3)

    local ok, response = pcall(function()
        return game:HttpGet(API_URL)
    end)

    local decoded
    if ok and response then
        ok, decoded = pcall(function()
            return Services.HttpService:JSONDecode(response)
        end)
    end

    local items = ok and decoded and decoded.items or nil
    if not items then
        Lib:Notify("Error!", "Could not reach the values API. Trade tools are disabled this session.", 5, "error")
        return
    end

    local NAME_FIXES = {
        ["Ice Wing"] = "Icewing",
        ["Gold Edlerwood Blade"] = "Gold Elderwood Blade",
    }

    local grouped = {}
    local options = {}
    local valueByLabel = {}
    local labelByCleanName = {}

    for _, item in ipairs(items) do
        item.name = NAME_FIXES[item.name] or item.name

        local category = item.category
        grouped[category] = grouped[category] or {}
        table.insert(grouped[category], item)

        local value = tonumber((tostring(item.value):gsub(",", ""))) or 0
        local label = item.name .. " [Val: " .. item.value .. "]"
        valueByLabel[label] = value

        local cleaned = cleanString(item.name)
        if not labelByCleanName[cleaned] or value > (valueByLabel[labelByCleanName[cleaned]] or 0) then
            labelByCleanName[cleaned] = label
        end

        table.insert(options, label)
    end

    table.sort(options, function(a, b)
        local valueA = valueByLabel[a] or 0
        local valueB = valueByLabel[b] or 0
        if valueA == valueB then
            return a < b
        end
        return valueA > valueB
    end)

    local Values = {
        grouped = grouped,
        options = options,
        valueByLabel = valueByLabel,
        labelByCleanName = labelByCleanName,
    }

    function Values.findLabel(name)
        return labelByCleanName[cleanString(name)]
    end

    function Values.lookup(name)
        local label = labelByCleanName[cleanString(name)]
        if not label then
            return nil
        end
        return valueByLabel[label] or 0
    end

    function Values.sortByValue(labels)
        table.sort(labels, function(a, b)
            local valueA = valueByLabel[(a:gsub("%s*%(x%d+%)", ""))] or 0
            local valueB = valueByLabel[(b:gsub("%s*%(x%d+%)", ""))] or 0
            if valueA == valueB then
                return a < b
            end
            return valueA > valueB
        end)
        return labels
    end

    Ctx.Values = Values

    ----------------------------------------------------------------
    -- Browse tab
    ----------------------------------------------------------------

    local CATEGORY_GROUPS = {
        { name = "All Items", categories = { "ancient", "unique", "chroma", "godly", "legendary", "rare", "uncommon", "common", "vintage", "pets", "misc" } },
        { name = "Ancient", categories = { "ancient" } },
        { name = "Unique", categories = { "unique" } },
        { name = "Chromas", categories = { "chroma" } },
        { name = "Godly", categories = { "godly" } },
        { name = "Legendary", categories = { "legendary" } },
        { name = "Rare", categories = { "rare" } },
        { name = "Uncommon", categories = { "uncommon" } },
        { name = "Common", categories = { "common" } },
        { name = "Vintage", categories = { "vintage" } },
        { name = "Pets & Misc", categories = { "pets", "misc" } },
    }

    local browseSection = Ctx.tabs.values:Section("Browse Values", "Full")

    for _, group in ipairs(CATEGORY_GROUPS) do
        local groupOptions = {}

        for _, category in ipairs(group.categories) do
            for _, item in ipairs(grouped[category] or {}) do
                table.insert(groupOptions, string.format(
                    "%s [Val: %s | Dem: %s | Stab: %s]",
                    item.name, item.value, item.demand, item.stability
                ))
            end
        end

        if #groupOptions > 0 then
            browseSection:Dropdown(group.name, "nil", groupOptions, false, nil,
                "Browse & Search " .. group.name .. " Items", true)
        end
    end
end)

--================================================================--
--                     MODULE: TRADE CHECKER                      --
--================================================================--

defineModule("trade", function(Ctx)
    local Lib = Ctx.Lib
    local Values = Ctx.Values
    local comma = Util.comma

    local tradeTab = Ctx.tabs.trade
    local yourSection = tradeTab:Section("Your Offer", "Left")
    local theirSection = tradeTab:Section("Their Offer", "Right")
    local resultSection = tradeTab:Section("Result", "Full")

    if not Values then
        resultSection:Label("Item values are unavailable - the values API could not be reached.")
        return
    end

    local MAX_SLOTS = 4 

    ----------------------------------------------------------------
    -- Menu labels
    ----------------------------------------------------------------

    local yourValueLabel = yourSection:Label("Total Value: 0")
    local yourSlotLabels = {}
    for index = 1, MAX_SLOTS do
        yourSlotLabels[index] = yourSection:Label("")
    end

    local theirValueLabel = theirSection:Label("Total Value: 0")
    local theirSlotLabels = {}
    for index = 1, MAX_SLOTS do
        theirSlotLabels[index] = theirSection:Label("")
    end

    local liveStatusLabel = resultSection:Label("Live Mode: waiting for a trade to open...")
    local livePartnerLabel = resultSection:Label("Trading with: -")
    local resultLabel = resultSection:Label("Status: Waiting for items...")

    ----------------------------------------------------------------
    -- Live trade plumbing
    ----------------------------------------------------------------

    local tradeRemotes = Services.ReplicatedStorage:WaitForChild("Trade", 10)
    local tradeGui = LocalPlayer:WaitForChild("PlayerGui", 10)
    tradeGui = tradeGui and tradeGui:WaitForChild("TradeGUI", 10)

    if not (tradeRemotes and tradeRemotes:FindFirstChild("UpdateTrade") and tradeGui) then
        liveStatusLabel:SetText("Live Mode: the MM2 trade GUI was not found in this place.")
        return
    end

    local Sync
    do

        local ok, module = pcall(function()
            return require(Services.ReplicatedStorage:WaitForChild("Database"):WaitForChild("Sync"))
        end)
        Sync = ok and module or nil
    end

    local liveMode = true      
    local tradeOpen = false     
    local haveEvent = false     
    local livePartner = ""

    local liveYour = { items = {}, total = 0, unpriced = 0 }
    local liveTheir = { items = {}, total = 0, unpriced = 0 }

    local overlayEnabled = true
    local overlayTags = true
    local updateOverlay

    local function displayNameFor(itemId, itemType)
        local record
        if Sync then
            if itemType and Sync[itemType] then
                record = Sync[itemType][itemId]
            end
            if not record then
                record = (Sync.Item and Sync.Item[itemId]) or (Sync.Pets and Sync.Pets[itemId])
            end
        end

        if not record then
            return tostring(itemId)
        end

        local name = record.ItemName or record.Name or tostring(itemId)
        if record.Chroma and not tostring(name):lower():find("chroma", 1, true) then
            name = "Chroma " .. name
        end
        return name
    end

    local function buildFromOffer(offerTable)
        local offer = { items = {}, total = 0, unpriced = 0 }
        if type(offerTable) ~= "table" then
            return offer
        end

        for _, entry in pairs(offerTable) do
            if type(entry) == "table" then
                local itemId = entry[1] or entry.ItemID
                local amount = tonumber(entry[2] or entry.Amount) or 1
                local itemType = entry[3] or entry.ItemType

                if itemId then
                    local name = displayNameFor(itemId, itemType)
                    local value = Values.lookup(name)
                    if value then
                        offer.total = offer.total + (value * amount)
                    else
                        offer.unpriced = offer.unpriced + 1
                    end
                    table.insert(offer.items, { name = name, qty = amount, value = value })
                end
            end
        end

        return offer
    end

    local function getTradeFrame()
        local container = tradeGui:FindFirstChild("Container")
        return container and container:FindFirstChild("Trade")
    end

    local CHROMA_IMAGE_ID = "4589252033"

    local function isChromaFrame(frame)
        local tags = frame:FindFirstChild("Tags")
        local chromaTag = tags and tags:FindFirstChild("Chroma")
        if chromaTag and chromaTag:IsA("GuiObject") then
            return chromaTag.Visible
        end

        for _, descendant in ipairs(frame:GetDescendants()) do
            if string.find(string.lower(descendant.Name or ""), "chroma", 1, true) then
                return true
            elseif descendant:IsA("TextLabel") and string.find(string.lower(descendant.Text or ""), "chroma", 1, true) then
                return true
            elseif descendant:IsA("ImageLabel") and string.find(descendant.Image or "", CHROMA_IMAGE_ID, 1, true) then
                return true
            end
        end

        return false
    end

    local function withChromaPrefix(name, frame)
        if not isChromaFrame(frame) then
            return name
        end
        if string.find(string.lower(name), "chroma", 1, true) then
            return name
        end
        return "Chroma " .. name
    end

    local function readSlotItem(slot)
        if not (slot and slot.Visible) then
            return nil
        end

        local nameFrame = slot:FindFirstChild("ItemName")
        local label = nameFrame and nameFrame:FindFirstChild("Label")
        if not (label and label:IsA("TextLabel")) then
            return nil
        end

        local name = ((label.Text or ""):gsub("<[^>]+>", "")):match("^%s*(.-)%s*$")
        local lowered = name:lower()
        if name == "" or lowered == "loading" or lowered == "label" then
            return nil
        end

        name = withChromaPrefix(name, slot)

        local quantity = 1
        local container = slot:FindFirstChild("Container")
        local amountLabel = container and container:FindFirstChild("Amount")
        if amountLabel and amountLabel:IsA("TextLabel") then
            quantity = tonumber((amountLabel.Text or ""):match("x%s*(%d+)")) or 1
        end

        return { name = name, qty = quantity, value = Values.lookup(name) }
    end

    local function buildFromUI(offerFrame)
        local offer = { items = {}, total = 0, unpriced = 0 }
        local container = offerFrame and offerFrame:FindFirstChild("Container")
        if not container then
            return offer
        end

        for index = 1, MAX_SLOTS do
            local item = readSlotItem(container:FindFirstChild("NewItem" .. index))
            if item then
                if item.value then
                    offer.total = offer.total + (item.value * item.qty)
                else
                    offer.unpriced = offer.unpriced + 1
                end
                table.insert(offer.items, item)
            end
        end

        return offer
    end

    ----------------------------------------------------------------
    -- Rendering
    ----------------------------------------------------------------

    local COLOR_ITEM = Color3.fromRGB(220, 220, 220)
    local COLOR_UNPRICED = Color3.fromRGB(255, 180, 60)
    local COLOR_NEUTRAL = Color3.fromRGB(200, 200, 200)
    local COLOR_WIN = Color3.fromRGB(50, 255, 50)
    local COLOR_LOSE = Color3.fromRGB(255, 50, 50)
    local COLOR_FAIR = Color3.fromRGB(255, 255, 255)

    local yourTotal, theirTotal = 0, 0
    local yourSelectedInventory, yourSelectedAll, theirSelected = {}, {}, {}

    local function liveActive()
        return liveMode and tradeOpen
    end

    local function renderSlots(labels, items)
        for index = 1, MAX_SLOTS do
            local item = items[index]
            if not item then
                labels[index]:SetText("")
            else
                local quantity = item.qty > 1 and (" x" .. tostring(item.qty)) or ""
                if item.value then
                    labels[index]:SetText(item.name .. quantity .. " - " .. comma(item.value * item.qty))
                    labels[index]:SetColor(COLOR_ITEM)
                else
                    labels[index]:SetText(item.name .. quantity .. " - [no value listed]")
                    labels[index]:SetColor(COLOR_UNPRICED)
                end
            end
        end
    end

    local function updateResult()
        if yourTotal == 0 and theirTotal == 0 then
            resultLabel:SetText("Status: Waiting for items...")
            resultLabel:SetColor(COLOR_NEUTRAL)
        elseif yourTotal > theirTotal then
            resultLabel:SetText("YOU LOSE! (Loss: " .. comma(yourTotal - theirTotal) .. ")")
            resultLabel:SetColor(COLOR_LOSE)
        elseif theirTotal > yourTotal then
            resultLabel:SetText("YOU WIN! (Profit: " .. comma(theirTotal - yourTotal) .. ")")
            resultLabel:SetColor(COLOR_WIN)
        else
            resultLabel:SetText("FAIR TRADE! (Equal Value)")
            resultLabel:SetColor(COLOR_FAIR)
        end
    end

    local function sumManual(list)
        local total = 0
        for _, label in ipairs(list) do
            local quantity = tonumber(label:match("%(x(%d+)%)")) or 1
            total = total + ((Values.valueByLabel[(label:gsub("%s*%(x%d+%)", ""))] or 0) * quantity)
        end
        return total
    end

    local function recompute()
        if liveActive() then
            yourTotal = liveYour.total
            theirTotal = liveTheir.total

            renderSlots(yourSlotLabels, liveYour.items)
            renderSlots(theirSlotLabels, liveTheir.items)

            local yourSuffix = liveYour.unpriced > 0 and (" (" .. liveYour.unpriced .. " unpriced)") or ""
            local theirSuffix = liveTheir.unpriced > 0 and (" (" .. liveTheir.unpriced .. " unpriced)") or ""
            yourValueLabel:SetText("Total Value: " .. comma(yourTotal) .. yourSuffix)
            theirValueLabel:SetText("Total Value: " .. comma(theirTotal) .. theirSuffix)

            liveStatusLabel:SetText("Live Mode: reading " .. (haveEvent and "trade data" or "trade window") .. " (manual lists ignored)")
            liveStatusLabel:SetColor(COLOR_WIN)
            livePartnerLabel:SetText("Trading with: " .. (livePartner ~= "" and livePartner or "-"))
        else
            yourTotal = sumManual(yourSelectedInventory) + sumManual(yourSelectedAll)
            theirTotal = sumManual(theirSelected)

            renderSlots(yourSlotLabels, {})
            renderSlots(theirSlotLabels, {})

            yourValueLabel:SetText("Total Value: " .. comma(yourTotal))
            theirValueLabel:SetText("Total Value: " .. comma(theirTotal))

            if liveMode then
                liveStatusLabel:SetText("Live Mode: waiting for a trade to open...")
                liveStatusLabel:SetColor(COLOR_NEUTRAL)
            else
                liveStatusLabel:SetText("Live Mode: OFF - using manual selections")
                liveStatusLabel:SetColor(COLOR_UNPRICED)
            end
            livePartnerLabel:SetText("Trading with: -")
        end

        updateResult()

        if updateOverlay then
            updateOverlay()
        end
    end

    ----------------------------------------------------------------
    -- In-game trade overlay
    ----------------------------------------------------------------


    do
        local PANEL_W_MIN, PANEL_W_MAX, PANEL_H, BAR_H, TAG_H = 280, 620, 80, 26, 18
        local OVERLAY_NAME = "LeatherHubTradeOverlay"

        local COL_WIN = Color3.fromRGB(60, 220, 110)
        local COL_LOSE = Color3.fromRGB(240, 70, 70)
        local COL_FAIR = Color3.fromRGB(235, 235, 235)
        local COL_PANEL = Color3.fromRGB(22, 22, 26)
        local COL_TAG = Color3.fromRGB(16, 16, 20)
        local COL_TRACK = Color3.fromRGB(44, 44, 52)
        local COL_STROKE = Color3.fromRGB(70, 70, 82)
        local COL_DETAIL = Color3.fromRGB(185, 185, 195)

        local function make(class, props, parent)
            local instance = Instance.new(class)
            for property, value in pairs(props) do
                instance[property] = value
            end
            instance.Parent = parent
            return instance
        end

        local function overlayParent()
            local ok, hidden = pcall(function()
                return gethui and gethui()
            end)
            if ok and hidden then
                return hidden
            end

            local okCore, coreGui = pcall(function()
                return game:GetService("CoreGui")
            end)
            if okCore and coreGui then
                return coreGui
            end

            return LocalPlayer:WaitForChild("PlayerGui")
        end

        for _, place in ipairs({ overlayParent(), LocalPlayer:FindFirstChild("PlayerGui") }) do
            local stale = place and place:FindFirstChild(OVERLAY_NAME)
            if stale then
                stale:Destroy()
            end
        end

        local screen = Instance.new("ScreenGui")
        screen.Name = OVERLAY_NAME
        screen.ResetOnSpawn = false
        screen.DisplayOrder = 9999
        screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        screen.IgnoreGuiInset = tradeGui.IgnoreGuiInset
        screen.Enabled = false

        if not pcall(function()
            screen.Parent = overlayParent()
        end) then
            screen.Parent = LocalPlayer:WaitForChild("PlayerGui")
        end

        pcall(function()
            if syn and syn.protect_gui then
                syn.protect_gui(screen)
            end
        end)

        local panel = make("Frame", {
            Name = "Panel",
            BackgroundColor3 = COL_PANEL,
            BackgroundTransparency = 0.08,
            BorderSizePixel = 0,
            Size = UDim2.fromOffset(PANEL_W_MIN, PANEL_H),
            Visible = false,
        }, screen)
        make("UICorner", { CornerRadius = UDim.new(0, 8) }, panel)
        make("UIStroke", { Color = COL_STROKE, Thickness = 1, Transparency = 0.25 }, panel)

        local statusLabel = make("TextLabel", {
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(0, 6),
            Size = UDim2.new(1, 0, 0, 20),
            Font = Enum.Font.GothamBold,
            TextSize = 16,
            Text = "WAITING FOR ITEMS",
            TextColor3 = COL_FAIR,
        }, panel)

        local bar = make("Frame", {
            BackgroundColor3 = COL_TRACK,
            BorderSizePixel = 0,
            Position = UDim2.new(0, 10, 0, 30),
            Size = UDim2.new(1, -20, 0, BAR_H),
        }, panel)
        make("UICorner", { CornerRadius = UDim.new(0, 4) }, bar)

        local fill = make("Frame", {
            BackgroundColor3 = COL_FAIR,
            BorderSizePixel = 0,
            Size = UDim2.new(0, 0, 1, 0),
            ZIndex = 2,
        }, bar)
        make("UICorner", { CornerRadius = UDim.new(0, 4) }, fill)

        make("Frame", {
            BackgroundColor3 = Color3.fromRGB(255, 255, 255),
            BackgroundTransparency = 0.3,
            BorderSizePixel = 0,
            AnchorPoint = Vector2.new(0.5, 0),
            Position = UDim2.new(0.5, 0, 0, 0),
            Size = UDim2.new(0, 2, 1, 0),
            ZIndex = 3,
        }, bar)

        local yourBarLabel = make("TextLabel", {
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 8, 0, 0),
            Size = UDim2.new(0.5, -10, 1, 0),
            Font = Enum.Font.GothamBold,
            TextSize = 13,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextColor3 = Color3.fromRGB(255, 255, 255),
            TextStrokeTransparency = 0.4,
            Text = "YOU 0",
            ZIndex = 4,
        }, bar)

        local theirBarLabel = make("TextLabel", {
            BackgroundTransparency = 1,
            AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.new(1, -8, 0, 0),
            Size = UDim2.new(0.5, -10, 1, 0),
            Font = Enum.Font.GothamBold,
            TextSize = 13,
            TextXAlignment = Enum.TextXAlignment.Right,
            TextColor3 = Color3.fromRGB(255, 255, 255),
            TextStrokeTransparency = 0.4,
            Text = "0 THEM",
            ZIndex = 4,
        }, bar)

        local detailLabel = make("TextLabel", {
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 10, 0, 59),
            Size = UDim2.new(1, -20, 0, 16),
            Font = Enum.Font.Gotham,
            TextSize = 12,
            TextColor3 = COL_DETAIL,
            Text = "",
        }, panel)

        local SIDES = { { key = "your", frame = "YourOffer" }, { key = "their", frame = "TheirOffer" } }
        local slotTags = { your = {}, their = {} }
        local slotFrames = { your = {}, their = {} }

        for _, side in ipairs(SIDES) do
            for index = 1, MAX_SLOTS do
                local tag = make("TextLabel", {
                    Name = side.key .. "Tag" .. index,
                    BackgroundColor3 = COL_TAG,
                    BackgroundTransparency = 0.15,
                    BorderSizePixel = 0,
                    Font = Enum.Font.GothamBold,
                    TextSize = 12,
                    TextColor3 = COL_FAIR,
                    Text = "",
                    Visible = false,
                    ZIndex = 2,
                }, screen)
                make("UICorner", { CornerRadius = UDim.new(0, 4) }, tag)
                make("UIStroke", { Color = COL_STROKE, Thickness = 1, Transparency = 0.35 }, tag)
                slotTags[side.key][index] = tag
            end
        end

        local function refreshPanel()
            local pot = liveYour.total + liveTheir.total
            local diff = liveTheir.total - liveYour.total
            local colour, text

            if pot == 0 then
                colour, text = COL_FAIR, "WAITING FOR ITEMS"
            elseif diff > 0 then
                colour, text = COL_WIN, "YOU WIN  +" .. comma(diff)
            elseif diff < 0 then
                colour, text = COL_LOSE, "YOU LOSE  -" .. comma(-diff)
            else
                colour, text = COL_FAIR, "FAIR TRADE"
            end

            statusLabel.Text = text
            statusLabel.TextColor3 = colour
            fill.BackgroundColor3 = colour
            fill.Size = UDim2.new(pot > 0 and (liveYour.total / pot) or 0, 0, 1, 0)

            yourBarLabel.Text = "YOU  " .. comma(liveYour.total)
            theirBarLabel.Text = comma(liveTheir.total) .. "  THEM"

            local unpriced = liveYour.unpriced + liveTheir.unpriced
            local detail = "Trading with " .. (livePartner ~= "" and livePartner or "-")
            if unpriced > 0 then
                detail = detail .. "  |  " .. unpriced .. " item" .. (unpriced == 1 and "" or "s") .. " with no listed value"
                detailLabel.TextColor3 = COLOR_UNPRICED
            else
                detailLabel.TextColor3 = COL_DETAIL
            end
            detailLabel.Text = detail
        end

        local lastRead = 0

        local function readSlots(trade)
            for _, side in ipairs(SIDES) do
                local container = trade:FindFirstChild(side.frame)
                container = container and container:FindFirstChild("Container")

                for index = 1, MAX_SLOTS do
                    local slot = container and container:FindFirstChild("NewItem" .. index)
                    local item = overlayTags and slot and readSlotItem(slot) or nil
                    slotFrames[side.key][index] = item and slot or nil

                    local tag = slotTags[side.key][index]
                    if item then
                        if item.value then
                            tag.Text = comma(item.value * item.qty)
                            tag.TextColor3 = COL_FAIR
                        else
                            tag.Text = "?"
                            tag.TextColor3 = COLOR_UNPRICED
                        end
                    end
                end
            end
        end

        local function layout()
            local trade = getTradeFrame()
            local show = overlayEnabled and tradeGui.Enabled and trade ~= nil and trade.AbsoluteSize.X > 0
            if screen.Enabled ~= show then
                screen.Enabled = show
            end
            if not show then
                return
            end

            if screen.IgnoreGuiInset ~= tradeGui.IgnoreGuiInset then
                screen.IgnoreGuiInset = tradeGui.IgnoreGuiInset
            end

            local position, size = trade.AbsolutePosition, trade.AbsoluteSize
            local width = math.clamp(size.X, PANEL_W_MIN, PANEL_W_MAX)
            local y = position.Y - PANEL_H - 8
            if y < 4 then
                y = position.Y + 8 -- no room above: sit inside the window
            end

            panel.Size = UDim2.fromOffset(width, PANEL_H)
            panel.Position = UDim2.fromOffset(math.max(math.floor(position.X + (size.X - width) / 2), 4), math.floor(y))
            panel.Visible = true

            local now = os.clock()
            if now - lastRead > 0.1 then
                lastRead = now
                readSlots(trade)
            end

            for _, side in ipairs(SIDES) do
                for index = 1, MAX_SLOTS do
                    local slot = slotFrames[side.key][index]
                    local tag = slotTags[side.key][index]
                    if slot and slot.Parent and slot.Visible then
                        local slotPosition, slotSize = slot.AbsolutePosition, slot.AbsoluteSize
                        tag.Size = UDim2.fromOffset(math.max(math.floor(slotSize.X), 44), TAG_H)
                        tag.Position = UDim2.fromOffset(math.floor(slotPosition.X), math.floor(slotPosition.Y + 2))
                        tag.Visible = true
                    else
                        tag.Visible = false
                    end
                end
            end
        end

        updateOverlay = function()
            refreshPanel()
            layout()
        end

        Scheduler.onRender("trade.overlay", layout)
    end

    ----------------------------------------------------------------
    -- Live trade hooks
    ----------------------------------------------------------------

    local function onUpdateTrade(state)
        if type(state) ~= "table" then
            return
        end

        local meKey, themKey
        if state.Player1 and state.Player1.Player == LocalPlayer then
            meKey, themKey = "Player1", "Player2"
        elseif state.Player2 and state.Player2.Player == LocalPlayer then
            meKey, themKey = "Player2", "Player1"
        else
            return
        end

        liveYour = buildFromOffer(state[meKey].Offer)
        liveTheir = buildFromOffer(state[themKey].Offer)

        local partner = state[themKey].Player
        livePartner = (partner and partner.Name) or livePartner
        haveEvent = true
        tradeOpen = true

        recompute()
    end

    Session.track(tradeRemotes.UpdateTrade.OnClientEvent:Connect(function(state)

        local ok, err = pcall(onUpdateTrade, state)
        if not ok then
            warn("[LeatherHub] UpdateTrade handler failed: " .. tostring(err))
        end
    end))

    Session.track(tradeGui:GetPropertyChangedSignal("Enabled"):Connect(function()
        tradeOpen = tradeGui.Enabled
        if not tradeOpen then
            haveEvent = false
            livePartner = ""
            liveYour = { items = {}, total = 0, unpriced = 0 }
            liveTheir = { items = {}, total = 0, unpriced = 0 }
        end
        recompute()
    end))

    Scheduler.every("trade.poll", 0.4, function()
        if not ((liveMode or overlayEnabled) and tradeGui.Enabled and not haveEvent) then
            return
        end

        tradeOpen = true
        local trade = getTradeFrame()
        if not trade then
            return
        end

        local yourFrame = trade:FindFirstChild("YourOffer")
        local theirFrame = trade:FindFirstChild("TheirOffer")
        liveYour = buildFromUI(yourFrame)
        liveTheir = buildFromUI(theirFrame)

        local usernameLabel = theirFrame and theirFrame:FindFirstChild("Username")
        if usernameLabel and usernameLabel:IsA("TextLabel") then
            livePartner = (usernameLabel.Text or ""):gsub("[%(%)]", "")
        end

        recompute()
    end)

    resultSection:Toggle("Live Mode (read trade window)", true, function(state)
        liveMode = state
        recompute()
    end)

    resultSection:Toggle("In-Game Trade Overlay", true, function(state)
        overlayEnabled = state
        if updateOverlay then
            updateOverlay()
        end
    end)

    resultSection:Toggle("Overlay Item Value Tags", true, function(state)
        overlayTags = state
        if updateOverlay then
            updateOverlay()
        end
    end)

    ----------------------------------------------------------------
    -- Manual: your offer
    ----------------------------------------------------------------

    local function readInventoryItem(itemFrame, found)
        local nameFrame = itemFrame:FindFirstChild("ItemName")
        local label = nameFrame and nameFrame:FindFirstChild("Label")
        if not (label and label:IsA("TextLabel")) then
            return 0
        end

        local name = ((label.Text or ""):gsub("<[^>]+>", "")):match("^%s*(.-)%s*$")
        if not name or name == "" or name:lower() == "label" then
            return 0
        end

        local lowered = name:lower()
        local quantity = tonumber(lowered:match("x%s*(%d+)$") or lowered:match("%(x%s*(%d+)%)$")) or 1

        if quantity == 1 then
            for _, descendant in ipairs(itemFrame:GetDescendants()) do
                if descendant:IsA("TextLabel") then
                    local descendantName = descendant.Name:lower()
                    if descendantName:match("quant") or descendantName:match("amount") or descendantName:match("count") then
                        local text = descendant.Text or ""
                        local match = text:match("x%s*(%d+)") or text:match("^(%d+)$")
                        if match then
                            quantity = tonumber(match) or 1
                            break
                        end
                    end
                end
            end
        end

        local cleanName = lowered:gsub("%s*x%s*%d+$", ""):gsub("%s*%(x%s*%d+%)$", ""):match("^%s*(.-)%s*$")
        cleanName = withChromaPrefix(cleanName, itemFrame)

        local itemLabel = Values.findLabel(cleanName)
        if not itemLabel then
            return 0
        end

        found[itemLabel] = (found[itemLabel] or 0) + quantity
        return (Values.valueByLabel[itemLabel] or 0) * quantity
    end

    local function getInventoryOptions()
        local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
        local inventory = playerGui
            and playerGui:FindFirstChild("MainGUI")
            and playerGui.MainGUI:FindFirstChild("Game")
            and playerGui.MainGUI.Game:FindFirstChild("Inventory")
        local itemsContainer = inventory
            and inventory:FindFirstChild("Main")
            and inventory.Main:FindFirstChild("Weapons")
            and inventory.Main.Weapons:FindFirstChild("Items")
            and inventory.Main.Weapons.Items:FindFirstChild("Container")

        if not itemsContainer then
            return Values.options, 0
        end

        local found = {}
        local totalValue = 0

        local function collect(frame)
            if frame:IsA("Frame") and frame.Name:match("NewItem") then
                totalValue = totalValue + readInventoryItem(frame, found)
            end
        end

        for _, tab in ipairs(itemsContainer:GetChildren()) do
            if tab:IsA("ScrollingFrame") then
                local tabContainer = tab:FindFirstChild("Container")
                if tabContainer then
                    for _, child in ipairs(tabContainer:GetChildren()) do
                        if child:IsA("Frame") and child.Name:match("NewItem") then
                            collect(child)
                        elseif child:IsA("Frame") and child.Name ~= "UIGridLayout" and child.Name ~= "EventLayout" then
                            local eventContainer = child:FindFirstChild("Container")
                            if eventContainer then
                                for _, eventChild in ipairs(eventContainer:GetChildren()) do
                                    collect(eventChild)
                                end
                            end
                        end
                    end
                end
            end
        end

        local sorted = {}
        for itemLabel, quantity in pairs(found) do
            local display = itemLabel
            if quantity > 1 then
                local namePart, restPart = itemLabel:match("^(.-)(%s*%[Val:.*)$")
                if namePart and restPart then
                    display = namePart .. " (x" .. tostring(quantity) .. ")" .. restPart
                else
                    display = itemLabel .. " (x" .. tostring(quantity) .. ")"
                end
            end
            table.insert(sorted, display)
        end

        return Values.sortByValue(sorted), totalValue
    end

    local inventoryOptions, inventoryTotal = getInventoryOptions()

    local yourInventoryDropdown = yourSection:Dropdown("Select From Inventory", {}, inventoryOptions, true, function(selected)
        yourSelectedInventory = selected
        recompute()
    end, "Search your owned weapons", true)

    local inventoryTotalLabel = yourSection:Label("Total Inventory Value: " .. comma(inventoryTotal))

    yourSection:Button("Refresh Inventory", function()
        local options, total = getInventoryOptions()
        yourInventoryDropdown:UpdateChoices(options)
        inventoryTotalLabel:SetText("Total Inventory Value: " .. comma(total))
        Lib:Notify("Success", "Inventory refreshed! Total Value: " .. comma(total), 3, "success")
    end)

    local yourAllDropdown = yourSection:Dropdown("Select From All Items", {}, Values.options, true, function(selected)
        yourSelectedAll = selected
        recompute()
    end, "Search any weapon", true)

    yourSection:Button("Clear Your Offer", function()
        yourInventoryDropdown:Set({})
        yourAllDropdown:Set({})
        yourSelectedInventory = {}
        yourSelectedAll = {}
        recompute()
    end)

    ----------------------------------------------------------------
    -- Manual: their offer
    ----------------------------------------------------------------

    local theirDropdown = theirSection:Dropdown("Select Items", {}, Values.options, true, function(selected)
        theirSelected = selected
        recompute()
    end, "Search and select their weapons", true)

    theirSection:Button("Clear Their Offer", function()
        theirDropdown:Set({})
        theirSelected = {}
        recompute()
    end)

    theirSection:Divider("Profile Scanner")

    local function getProfileItems()
        local detected = {}
        local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
        local items = playerGui
            and playerGui:FindFirstChild("MainGUI")
            and playerGui.MainGUI:FindFirstChild("Game")
            and playerGui.MainGUI.Game:FindFirstChild("ViewProfile")
        items = items and items:FindFirstChild("Main")
        items = items and items:FindFirstChild("Weapons")
        items = items and items:FindFirstChild("Items")

        if not items then
            return detected
        end

        for _, child in ipairs(items:GetDescendants()) do
            if child:IsA("Frame") and (child.Name:match("^NewItem") or child.Name:match("^Item_")) then
                local nameFrame = child:FindFirstChild("ItemName")
                local label = nameFrame and nameFrame:FindFirstChild("Label")
                if label and label:IsA("TextLabel")
                    and label.Text ~= "" and label.Text ~= "Label" and label.Text ~= "Loading..." then
                    local name = ((label.Text or ""):gsub("<[^>]+>", "")):match("^%s*(.-)%s*$")
                    if name and name ~= "" then
                        name = name:lower():gsub("%s*x%s*%d+$", ""):gsub("%s*%(x%s*%d+%)$", "")
                        table.insert(detected, withChromaPrefix(name, child))
                    end
                end
            end
        end

        return detected
    end

    local scannedDropdown

    theirSection:Button("Scan Opened Profile", function()
        local detected = getProfileItems()

        local matched = {}
        for _, name in ipairs(detected) do
            local label = Values.findLabel(name)
            if label then
                table.insert(matched, label)
            end
        end

        if #detected == 0 then
            scannedDropdown:UpdateChoices({})
            scannedDropdown:Set({})
            Lib:Notify("No items", "No items detected! Ensure you have someone's profile open and clicked 'Inventory'.", 3)
        elseif #matched == 0 then
            scannedDropdown:UpdateChoices({})
            scannedDropdown:Set({})
            Lib:Notify("No matches", "Profile items detected but they don't match the MM2 values list.", 3, "warning")
        else
            scannedDropdown:UpdateChoices(Values.sortByValue(matched))
            scannedDropdown:Set({})
            Lib:Notify("Success", "Scanned " .. tostring(#matched) .. " items! Check the dropdown below.", 3, "success")
        end
    end)

    scannedDropdown = theirSection:Dropdown("Scanned Profile Items", {}, {}, true, function(selected)
        local current = {}
        local seen = {}

        local existing = theirDropdown:Get()
        if type(existing) == "table" then
            for _, value in ipairs(existing) do
                if not seen[value] then
                    seen[value] = true
                    table.insert(current, value)
                end
            end
        elseif type(existing) == "string" and existing ~= "" then
            seen[existing] = true
            table.insert(current, existing)
        end

        local additions = type(selected) == "table" and selected or { selected }
        for _, item in ipairs(additions) do
            if type(item) == "string" and item ~= "" and not seen[item] then
                seen[item] = true
                table.insert(current, item)
            end
        end

        theirDropdown:Set(current)
        theirSelected = current
        recompute()
    end, "Select items to add to their offer", true)

    theirSection:Button("Clear Scanned Items", function()
        scannedDropdown:UpdateChoices({})
        scannedDropdown:Set({})
    end)

    resultSection:Button("Clear All Tables", function()
        yourInventoryDropdown:Set({})
        yourAllDropdown:Set({})
        theirDropdown:Set({})
        yourSelectedInventory = {}
        yourSelectedAll = {}
        theirSelected = {}
        recompute()
    end)

    tradeOpen = tradeGui.Enabled
    recompute()
end)

--================================================================--
--       MODULE: MISC (protection, role alerts, teleports)        --
--                + the round timer overlay                       --
--================================================================--

defineModule("misc", function(Ctx)
    local Lib = Ctx.Lib
    local Players = Services.Players
    local Workspace = Services.Workspace

    local state = {
        antiFling = false,
        antiAfk = false,
        roleAlerts = false,
        roundTimer = false,
    }

    ----------------------------------------------------------------
    -- Visuals: round timer
    ----------------------------------------------------------------

    local timerLabel = Util.newDrawing("Text", {
        Visible = false,
        Center = true,
        Outline = true,
        Font = 6, 
        Size = 28,
        Color = Color3.fromRGB(255, 215, 0),
        Position = Vector2.new(500, 20),
    })

    local timerSection = Ctx.tabs.visuals:Section("UI & Timers", "Left")

    timerSection:Toggle("Show Round Timer", false, function(enabled)
        state.roundTimer = enabled
        timerLabel.Visible = enabled
    end)

    timerSection:Colorpicker("Timer Color", Color3.fromRGB(255, 215, 0), function(color)
        timerLabel.Color = color
    end)

    Scheduler.every("misc.roundTimer", 0.1, function()
        if not state.roundTimer then
            return
        end

        local camera = Workspace.CurrentCamera
        if camera then
            timerLabel.Position = Vector2.new(camera.ViewportSize.X / 2, 20)
        end

        local timerPart = Workspace:FindFirstChild("RoundTimerPart")
        local surfaceGui = timerPart and timerPart:FindFirstChild("SurfaceGui")
        local text = surfaceGui and surfaceGui:FindFirstChild("Timer")

        if text and text.Text then
            timerLabel.Text = "Time Left: " .. text.Text
        else
            timerLabel.Text = "Time Left: --:--"
        end
    end)

    ----------------------------------------------------------------
    -- Protection
    ----------------------------------------------------------------

    local protectionSection = Ctx.tabs.misc:Section("Protection", "Left")

    local function setPlayersCollidable(collidable)
        for _, player in ipairs(Players:GetPlayers()) do
            local character = player ~= LocalPlayer and player.Character
            if character then
                for _, part in ipairs(character:GetChildren()) do
                    if part:IsA("BasePart") then
                        part.CanCollide = collidable
                    elseif part:IsA("Accessory") then
                        local handle = part:FindFirstChild("Handle")
                        if handle and handle:IsA("BasePart") then
                            handle.CanCollide = collidable
                        end
                    end
                end
            end
        end
    end

    protectionSection:Toggle("Enable Anti-Fling", false, function(enabled)
        state.antiFling = enabled
        if enabled then
            Lib:Notify("Protection", "Anti-Fling is now ON", 3, "success")
        else
            Lib:Notify("Protection", "Anti-Fling is now OFF", 3, "warning")
            setPlayersCollidable(true)
        end
    end)

    Scheduler.every("misc.antiFling", 0.2, function()
        if state.antiFling then
            setPlayersCollidable(false)
        end
    end)

    local ANTI_AFK_KEYS = { 0x57, 0x41, 0x53, 0x44 } -- W A S D
    local ANTI_AFK_PERIOD = 300
    local lastAntiAfkTap = 0

    protectionSection:Toggle("Enable Anti-AFK", false, function(enabled)
        state.antiAfk = enabled
        lastAntiAfkTap = os.clock()
        Lib:Notify("Protection", "Anti-AFK is now " .. (enabled and "ON" or "OFF"), 3, enabled and "success" or "warning")
    end)

    math.randomseed(math.floor(os.clock() * 100000))

    Scheduler.every("misc.antiAfk", 0.5, function()
        if not state.antiAfk or (os.clock() - lastAntiAfkTap) < ANTI_AFK_PERIOD then
            return
        end
        lastAntiAfkTap = os.clock()
        task.spawn(Util.tapKey, ANTI_AFK_KEYS[math.random(1, #ANTI_AFK_KEYS)])
    end)

    ----------------------------------------------------------------
    -- Role notifier
    ----------------------------------------------------------------

    local roleSection = Ctx.tabs.misc:Section("Role Notifier", "Left")

    local currentMurderer, currentSheriff

    roleSection:Toggle("Enable Role Alerts", false, function(enabled)
        state.roleAlerts = enabled
        if not enabled then
            currentMurderer, currentSheriff = nil, nil
        end
    end)

    Scheduler.every("misc.roleAlerts", 1, function()
        if not state.roleAlerts then
            return
        end

        local murderers, sheriffs = {}, {}
        for _, player in ipairs(Players:GetPlayers()) do
            if player.Character then
                local role = Util.getPlayerRole(player)
                if role == "Murderer" then
                    table.insert(murderers, player.Name)
                elseif role == "Sheriff" then
                    table.insert(sheriffs, player.Name)
                end
            end
        end

        local murdererNames = #murderers > 0 and table.concat(murderers, ", ") or nil
        local sheriffNames = #sheriffs > 0 and table.concat(sheriffs, ", ") or nil

        if murdererNames ~= currentMurderer then
            currentMurderer = murdererNames
            if currentMurderer then
                Lib:Notify("Role Alert", "Murderer is: " .. currentMurderer, 5, "error")
            end
        end

        if sheriffNames ~= currentSheriff then
            currentSheriff = sheriffNames
            if currentSheriff then
                Lib:Notify("Role Alert", "Sheriff is: " .. currentSheriff, 5, "info")
            end
        end
    end)

    ----------------------------------------------------------------
    -- Teleports
    ----------------------------------------------------------------

    local teleportSection = Ctx.tabs.misc:Section("Teleport", "Right")

    local function getBounds(root)
        if not root then
            return nil, nil
        end

        if root:IsA("BasePart") then
            return root.Position, root.Position.Y + (root.Size.Y * 0.5)
        end

        if root:IsA("Model") then
            local ok, cframe, size = pcall(function()
                return root:GetBoundingBox()
            end)
            if ok and cframe and size then
                return cframe.Position, cframe.Position.Y + (size.Y * 0.5)
            end
        end

        local min = Vector3.new(math.huge, math.huge, math.huge)
        local max = Vector3.new(-math.huge, -math.huge, -math.huge)
        local found = false

        for _, part in ipairs(root:GetDescendants()) do
            if part:IsA("BasePart") then
                found = true
                local half = part.Size * 0.5
                local low, high = part.Position - half, part.Position + half
                min = Vector3.new(math.min(min.X, low.X), math.min(min.Y, low.Y), math.min(min.Z, low.Z))
                max = Vector3.new(math.max(max.X, high.X), math.max(max.Y, high.Y), math.max(max.Z, high.Z))
            end
        end

        if not found then
            return nil, nil
        end

        return (min + max) * 0.5, max.Y
    end

    local function getActiveMapRoot()
        local normal = Workspace:FindFirstChild("Normal")
        if normal then
            for _, map in ipairs(normal:GetChildren()) do
                if (map:IsA("Model") or map:IsA("Folder")) and map:FindFirstChildWhichIsA("BasePart", true) then
                    return map
                end
            end
            if normal:FindFirstChildWhichIsA("BasePart", true) then
                return normal
            end
        end

        for _, object in ipairs(Workspace:GetChildren()) do
            if object:FindFirstChild("CoinContainer", true) then
                return object
            end
        end

        return nil
    end

    local function getLobbyRoot()
        local lobby = Workspace:FindFirstChild("Lobby")
        if lobby then
            return lobby
        end
        for _, object in ipairs(Workspace:GetChildren()) do
            if string.find(string.lower(object.Name), "lobby") then
                return object
            end
        end
        return nil
    end

    local function getLobbyFountainPosition()
        local lobby = getLobbyRoot()
        if not lobby then
            return nil
        end

        local fountain
        if string.find(string.lower(lobby.Name), "fountain") then
            fountain = lobby
        else
            for _, object in ipairs(lobby:GetDescendants()) do
                if string.find(string.lower(object.Name), "fountain") then
                    fountain = object
                    break
                end
            end
        end

        if fountain then
            local center, topY = getBounds(fountain)
            if center and topY then
                return Vector3.new(center.X, topY + 20, center.Z)
            end
        end

        local fallback = lobby:IsA("BasePart") and lobby or lobby:FindFirstChildWhichIsA("BasePart", true)
        if fallback then
            return fallback.Position + Vector3.new(0, 8, 0)
        end

        return nil
    end

    local function teleportTo(cframe)
        local root = Util.getHRP()
        if not root then
            Lib:Notify("Teleport", "You have no character right now.", 3)
            return false
        end
        root.CFrame = cframe
        return true
    end

    teleportSection:Button("Teleport to Lobby", function()
        local position = getLobbyFountainPosition()
        if not position then
            Lib:Notify("Teleport", "Lobby not found.", 3)
            return
        end
        teleportTo(CFrame.new(position))
    end)

    local function teleportToRole(toolName, roleLabel)
        local player, root = Util.findPlayerWithTool(toolName)
        if not root then
            Lib:Notify("Teleport", "No active " .. roleLabel .. " found.", 3)
            return
        end

        local behind = root.Position - (root.CFrame.LookVector * 3) + Vector3.new(0, 2, 0)
        if teleportTo(CFrame.new(behind, root.Position)) then
            Lib:Notify("Teleport", "Teleported to " .. roleLabel .. ": " .. player.Name, 3)
        end
    end

    teleportSection:Button("Teleport to Murderer", function()
        teleportToRole("Knife", "murderer")
    end)

    teleportSection:Button("Teleport to Sheriff", function()
        teleportToRole("Gun", "sheriff")
    end)

    teleportSection:Button("Teleport Above Map", function()
        local mapRoot = getActiveMapRoot()
        if not mapRoot then
            Lib:Notify("Teleport", "No active map found.", 3)
            return
        end

        local center, topY = getBounds(mapRoot)
        if center and topY then
            teleportTo(CFrame.new(center.X, topY + 60, center.Z))
            return
        end

        local part = mapRoot:IsA("BasePart") and mapRoot or mapRoot:FindFirstChildWhichIsA("BasePart", true)
        if not part then
            Lib:Notify("Teleport", "No active map found.", 3)
            return
        end

        teleportTo(CFrame.new(part.Position + Vector3.new(0, 60, 0)))
    end)

end)

--================================================================--
--          MODULE: ESP (role highlights, gun drop, traps)        --
--================================================================--

defineModule("esp", function(Ctx)
    local Lib = Ctx.Lib
    local Players = Services.Players
    local Workspace = Services.Workspace
    local worldToScreen = Util.worldToScreen

    local state = {
        gun = false,
        trap = false,
        innocent = false,
        sheriff = false,
        murderer = false,
    }

    local espSection = Ctx.tabs.visuals:Section("Gun & Trap ESP", "Left")
    local roleSection = Ctx.tabs.visuals:Section("Role ESP", "Right")

    ----------------------------------------------------------------
    -- Role ESP
    ----------------------------------------------------------------

    local ROLE_COLORS = {
        Innocent = Color3.fromRGB(255, 255, 255),
        Sheriff = Color3.fromRGB(0, 0, 255),
        Murderer = Color3.fromRGB(255, 0, 0),
    }

    local ROLE_ENABLED_KEY = {
        Innocent = "innocent",
        Sheriff = "sheriff",
        Murderer = "murderer",
    }

    local highlights = {}

    local function clearRoleESP(player)
        local highlight = highlights[player]
        if highlight then
            highlight:Destroy()
            highlights[player] = nil
        end
    end

    local function clearAllRoleESP()
        for player in pairs(highlights) do
            clearRoleESP(player)
        end
    end

    local function updateRoleESP(player)
        local character = player ~= LocalPlayer and player.Character
        if not character or not character.Parent or not Util.isAlive(player) then
            clearRoleESP(player)
            return
        end

        local role = Util.getPlayerRole(player)
        if not state[ROLE_ENABLED_KEY[role]] then
            clearRoleESP(player)
            return
        end

        local color = ROLE_COLORS[role] or ROLE_COLORS.Innocent
        local highlight = highlights[player]
        if not highlight or not highlight.Parent then
            highlight = Instance.new("Highlight")
            highlight.Name = "MM2RoleESP"
            highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            highlight.FillTransparency = 0.7
            highlight.OutlineTransparency = 0
            highlights[player] = highlight
        end

        highlight.Adornee = character
        highlight.FillColor = color
        highlight.OutlineColor = color
        if highlight.Parent ~= character then
            highlight.Parent = character
        end
    end

    local function refreshAllRoleESP()
        for player in pairs(highlights) do
            if not player or player.Parent ~= Players then
                clearRoleESP(player)
            end
        end

        for _, player in ipairs(Players:GetPlayers()) do
            updateRoleESP(player)
        end
    end

    roleSection:Toggle("Innocents ESP", false, function(enabled)
        state.innocent = enabled
        refreshAllRoleESP()
    end)

    roleSection:Toggle("Sheriff ESP", false, function(enabled)
        state.sheriff = enabled
        refreshAllRoleESP()
    end)

    roleSection:Toggle("Murderer ESP", false, function(enabled)
        state.murderer = enabled
        refreshAllRoleESP()
    end)

    Session.track(Players.PlayerRemoving:Connect(clearRoleESP))

    Scheduler.every("esp.roles", 0.2, function()
        if state.innocent or state.sheriff or state.murderer then
            refreshAllRoleESP()
        elseif next(highlights) then
            clearAllRoleESP()
        end
    end)

    ----------------------------------------------------------------
    -- Gun drop ESP
    ----------------------------------------------------------------

    local GUN_MAX_DISTANCE = 1000
    local GUN_BOX_SIZE = Vector2.new(20, 20)
    local LABEL_OFFSET_UP = Vector2.new(10, -16)
    local LABEL_OFFSET_DOWN = Vector2.new(10, 22)

    local gunColor = Color3.fromRGB(0, 255, 0)

    local gunBox = Util.newDrawing("Square", {
        Color = gunColor,
        Size = GUN_BOX_SIZE,
        Visible = false,
    })

    local gunLabel = Util.newDrawing("Text", {
        Color = gunColor,
        Font = Util.drawingFont("ProximaSoftBold"),
        Size = 16,
        Text = "GunDrop",
        Center = true,
        Outline = true,
        Visible = false,
    })

    local gunDistanceLabel = Util.newDrawing("Text", {
        Color = gunColor,
        Font = Util.drawingFont("ProximaSoftBold"),
        Size = 14,
        Text = "",
        Center = true,
        Outline = true,
        Visible = false,
    })

    local gunDrop, gunDropPosition
    local gunDistance, gunDistanceText = math.huge, ""
    local gunDropNotified = false

    local function hideGunESP()
        gunBox.Visible = false
        gunLabel.Visible = false
        gunDistanceLabel.Visible = false
    end

    espSection:Toggle("Enable Gun ESP", false, function(enabled)
        state.gun = enabled
        if not enabled then
            hideGunESP()
        end
    end)

    espSection:Colorpicker("Gun ESP Color", gunColor, function(color)
        gunColor = color
        gunBox.Color = color
        gunLabel.Color = color
        gunDistanceLabel.Color = color
    end)

    Scheduler.every("esp.gunScan", 0.3, function()
        if not state.gun then
            return
        end

        if not (gunDrop and gunDrop.Parent) then
            gunDrop = Util.findGunDrop()
        end

        if not gunDrop then
            gunDropPosition = nil
            gunDistance = math.huge
            gunDropNotified = false
            hideGunESP()
            return
        end

        if not gunDropNotified then
            gunDropNotified = true
            Lib:Notify("Gun Dropped!", "The Sheriff's gun is on the ground!", 4, "warning")
        end

        gunDropPosition = gunDrop.Position

        local root = Util.getHRP()
        if root then
            gunDistance = (root.Position - gunDropPosition).Magnitude
            gunDistanceText = string.format("%.1f studs", gunDistance)
        else
            gunDistance = math.huge
        end
    end)

    Scheduler.onRender("esp.gunDraw", function()
        if not state.gun
            or not gunDrop
            or not gunDrop.Parent
            or not gunDropPosition
            or gunDistance > GUN_MAX_DISTANCE then
            hideGunESP()
            return
        end

        local position, onScreen = worldToScreen(gunDrop.Position)
        if not onScreen then
            hideGunESP()
            return
        end

        local corner = position - GUN_BOX_SIZE
        gunBox.Position = corner
        gunBox.Visible = true

        gunLabel.Position = corner + LABEL_OFFSET_UP
        gunLabel.Visible = true

        gunDistanceLabel.Text = gunDistanceText
        gunDistanceLabel.Position = corner + LABEL_OFFSET_DOWN
        gunDistanceLabel.Visible = true
    end)

    ----------------------------------------------------------------
    -- Trap ESP
    ----------------------------------------------------------------

    local TRAP_BOX_SIZE = Vector2.new(20, 20)

    local trapColor = Color3.fromRGB(255, 50, 50)
    local trapDrawings = {}
    local trapParts = {}

    local function isTrapNamed(name)
        return name == "Trap" or string.find(name, "HiddenTrap") ~= nil
    end

    local function collectTrap(object, out)
        if not isTrapNamed(object.Name) then
            return false
        end
        local part = object:IsA("BasePart") and object or object:FindFirstChildWhichIsA("BasePart")
        if part then
            table.insert(out, part)
        end
        return true
    end

    local function clearTrapESP()
        for _, drawings in pairs(trapDrawings) do
            drawings.box:Remove()
            drawings.label:Remove()
            drawings.distance:Remove()
        end
        trapDrawings = {}
        trapParts = {}
    end

    espSection:Colorpicker("Trap ESP Color", trapColor, function(color)
        trapColor = color
        for _, drawings in pairs(trapDrawings) do
            drawings.box.Color = color
            drawings.label.Color = color
            drawings.distance.Color = color
        end
    end)

    espSection:Toggle("Enable Trap ESP", false, function(enabled)
        state.trap = enabled
        if not enabled then
            clearTrapESP()
        end
    end)

    Scheduler.every("esp.trapScan", 0.5, function()
        if not state.trap then
            return
        end

        local found = {}
        for _, child in ipairs(Workspace:GetChildren()) do
            collectTrap(child, found)

            if child.Name == "Normal" then
                for _, mapChild in ipairs(child:GetChildren()) do
                    if not collectTrap(mapChild, found) then
                        for _, sub in ipairs(mapChild:GetChildren()) do
                            collectTrap(sub, found)
                        end
                    end
                end
            end
        end

        trapParts = found
    end)

    local function trapDrawingsFor(part)
        local drawings = trapDrawings[part]
        if drawings then
            return drawings
        end

        drawings = {
            box = Util.newDrawing("Square", { Color = trapColor, Size = TRAP_BOX_SIZE }),
            label = Util.newDrawing("Text", {
                Color = trapColor,
                Font = Util.drawingFont("UI"),
                Size = 15,
                Text = "TRAP",
                Center = true,
                Outline = true,
            }),
            distance = Util.newDrawing("Text", {
                Color = trapColor,
                Font = Util.drawingFont("UI"),
                Size = 13,
                Center = true,
                Outline = true,
            }),
        }

        trapDrawings[part] = drawings
        return drawings
    end

    Scheduler.onRender("esp.trapDraw", function()
        if not state.trap then
            return
        end

        local alive = {}
        for _, part in ipairs(trapParts) do
            if part and part.Parent then
                alive[part] = true
            end
        end

        for part, drawings in pairs(trapDrawings) do
            if not alive[part] then
                drawings.box:Remove()
                drawings.label:Remove()
                drawings.distance:Remove()
                trapDrawings[part] = nil
            end
        end

        local root = Util.getHRP()

        for part in pairs(alive) do
            local drawings = trapDrawingsFor(part)
            local position, onScreen = worldToScreen(part.Position)

            if onScreen then
                drawings.box.Position = position - (TRAP_BOX_SIZE / 2)
                drawings.box.Visible = true

                drawings.label.Position = position - Vector2.new(0, 18)
                drawings.label.Visible = true

                if root then
                    drawings.distance.Text = string.format("%.1f", (root.Position - part.Position).Magnitude)
                    drawings.distance.Position = position + Vector2.new(0, 10)
                    drawings.distance.Visible = true
                else
                    drawings.distance.Visible = false
                end
            else
                drawings.box.Visible = false
                drawings.label.Visible = false
                drawings.distance.Visible = false
            end
        end
    end)
end)

--================================================================--
--      MODULE: COMBAT (gun grab, kill all, knife aura)           --
--================================================================--

defineModule("combat", function(Ctx)
    local Lib = Ctx.Lib
    local Players = Services.Players
    local Workspace = Services.Workspace

    local state = {
        autoGetGun = false,
        getGunHotkey = false,
        killHotkey = false,
        autoKillLoop = false,
        knifeAura = false,
        knifeAuraRange = 15,
    }

    local combatSection = Ctx.tabs.combat:Section("Combat", "Left")

    ----------------------------------------------------------------
    -- Auto get gun
    ----------------------------------------------------------------

    local GUN_GRAB_RANGE = 1000
    local GUN_GRAB_COOLDOWN = 1.5

    local function grabGun(isAuto)
        local root = Util.getHRP()
        if not root then
            return false
        end

        local gunDrop = Util.findGunDrop()
        if not gunDrop then
            if not isAuto then
                Lib:Notify("Not Found", "No dropped gun found on the map!", 3)
            end
            return false
        end

        if isAuto and (root.Position - gunDrop.Position).Magnitude > GUN_GRAB_RANGE then
            return false
        end

        local origin = root.CFrame
        root.CFrame = gunDrop.CFrame
        task.wait()

        if root.Parent then
            root.CFrame = origin
        end

        return true
    end

    combatSection:Toggle("Auto Get Gun", false, function(enabled)
        state.autoGetGun = enabled
    end)

    combatSection:Button("Teleport to Dropped Gun", function()
        grabGun(false)
    end)

    local getGunToggle = combatSection:Toggle("Get Gun (Hotkey)", false, function(enabled)
        state.getGunHotkey = enabled
    end)

    getGunToggle:AddKeybind("g", "Hold", function(active)
        if active and state.getGunHotkey then
            task.spawn(grabGun, false)
        end
    end)

    local nextGunGrab = 0

    Scheduler.every("combat.autoGetGun", 0.1, function()
        if not state.autoGetGun or os.clock() < nextGunGrab then
            return
        end

        if Util.playerHasTool(LocalPlayer, "Gun") or Util.playerHasTool(LocalPlayer, "Knife") then
            return
        end

        nextGunGrab = os.clock() + GUN_GRAB_COOLDOWN
        task.spawn(grabGun, true)
    end)

    ----------------------------------------------------------------
    -- Kill all
    ----------------------------------------------------------------

    local KILL_ALL_RANGE = 500
    local KILL_ALL_MAX_ATTEMPTS = 50
    local KNIFE_SLOT_KEY = 0x31 -- "1"

    local autoKillRunning = false

    local function collectKillTargets(root, ignoreRange)
        local targets = {}
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and Util.isAlive(player) then
                local targetRoot = Util.getPlayerHRP(player)
                if targetRoot and (ignoreRange or (root.Position - targetRoot.Position).Magnitude <= KILL_ALL_RANGE) then
                    table.insert(targets, player)
                end
            end
        end
        return targets
    end

    local function killLoop(root, knife, targets)
        local attempts = 0

        while autoKillRunning and attempts < KILL_ALL_MAX_ATTEMPTS do
            if not root.Parent then
                break
            end

            local camera = Workspace.CurrentCamera
            local look = camera.CFrame.LookVector
            look = Vector3.new(look.X, 0, look.Z).Unit

            local bringPosition = root.Position + (look * 3.5)
            local bringCFrame = CFrame.lookAt(bringPosition, root.Position)

            root.CFrame = CFrame.lookAt(root.Position, Vector3.new(bringPosition.X, root.Position.Y, bringPosition.Z))

            local anyoneAlive = false
            for _, target in ipairs(targets) do
                local targetRoot = Util.getPlayerHRP(target)
                if targetRoot and Util.isAlive(target) then
                    anyoneAlive = true
                    pcall(function()
                        targetRoot.CFrame = bringCFrame
                        targetRoot.AssemblyLinearVelocity = Vector3.zero
                        targetRoot.AssemblyAngularVelocity = Vector3.zero
                    end)
                end
            end

            if not anyoneAlive then
                break
            end

            Util.clickMouse()
            knife:Activate()

            task.wait(0.05)
            attempts = attempts + 1
        end
    end

    local function runAutoKill(ignoreRange)
        if autoKillRunning then
            return
        end

        local character = LocalPlayer.Character
        local root = Util.getHRP()
        if not (character and root) then
            return
        end

        local knife = character:FindFirstChild("Knife")
            or (LocalPlayer:FindFirstChildOfClass("Backpack") and LocalPlayer:FindFirstChildOfClass("Backpack"):FindFirstChild("Knife"))

        if not knife then
            Lib:Notify("Auto Kill", "You must be the Murderer (Knife not found)!", 3, "error")
            return
        end

        if knife.Parent ~= character then
            if character:FindFirstChildOfClass("Humanoid") then
                Util.tapKey(KNIFE_SLOT_KEY)
            else
                knife.Parent = character
            end
        end

        task.wait(0.7)

        local targets = collectKillTargets(root, ignoreRange)
        if #targets == 0 then
            Lib:Notify("Auto Kill", "No targets found!", 3)
            return
        end

        autoKillRunning = true
        Lib:Notify("Auto Kill", "Starting! Eradicating " .. #targets .. " players.", 3, "warning")

        local ok, err = pcall(killLoop, root, knife, targets)
        autoKillRunning = false

        if ok then
            Lib:Notify("Auto Kill", "Eradication Complete!", 3, "success")
        else
            Lib:Notify("Auto Kill", "Stopped: " .. tostring(err), 4, "error")
        end
    end

    Ctx.Combat = { runAutoKill = runAutoKill }

    combatSection:Button("Kill All (Button)", function()
        task.spawn(runAutoKill)
    end)

    local killToggle = combatSection:Toggle("Kill All (Hotkey)", false, function(enabled)
        state.killHotkey = enabled
    end)

    killToggle:AddKeybind("k", "Hold", function(active)
        if active and state.killHotkey then
            task.spawn(runAutoKill)
        end
    end)

    combatSection:Toggle("Auto Kill All (Loop)", false, function(enabled)
        state.autoKillLoop = enabled
        if enabled then
            Lib:Notify("Auto Kill", "Auto Kill All loop started!", 3, "success")
        end
    end)

    Scheduler.every("combat.autoKillLoop", 1, function()
        if state.autoKillLoop and not autoKillRunning then
            task.spawn(runAutoKill)
        end
    end)

    ----------------------------------------------------------------
    -- Knife aura
    ----------------------------------------------------------------

    combatSection:Toggle("Knife Aura", false, function(enabled)
        state.knifeAura = enabled
        if enabled then
            Lib:Notify("Knife Aura", "Active! Range: " .. state.knifeAuraRange .. " studs", 3, "success")
        end
    end)

    combatSection:Slider("Knife Aura Range", 15, 1, 5, 50, " studs", function(value)
        state.knifeAuraRange = value
    end)

    Scheduler.every("combat.knifeAura", 0.1, function()
        if not state.knifeAura then
            return
        end

        local character = LocalPlayer.Character
        local root = Util.getHRP()
        if not (character and root) then
            return
        end

        local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
        local knife = character:FindFirstChild("Knife") or (backpack and backpack:FindFirstChild("Knife"))
        if not knife then
            return
        end

        knife.Parent = character

        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and Util.isAlive(player) then
                local targetRoot = Util.getPlayerHRP(player)
                if targetRoot and (root.Position - targetRoot.Position).Magnitude <= state.knifeAuraRange then
                    Util.clickMouse()
                    knife:Activate()
                end
            end
        end
    end)
end)

--================================================================--
--        MODULE: VFX (kill effects, hit tracers, hit sounds)     --
--================================================================--


defineModule("vfx", function(Ctx)
    local Players = Services.Players
    local worldToScreen = Util.worldToScreen
    local lerpColor = Util.lerpColor
    local random = math.random

    local visualsTab = Ctx.tabs.visuals

    ----------------------------------------------------------------
    -- Palette
    ----------------------------------------------------------------

    local Palette = {
        WHITE = Color3.fromRGB(255, 255, 255),
        BLACK = Color3.fromRGB(0, 0, 0),
        GOLD = Color3.fromRGB(255, 215, 0),
        HOLY_WARM = Color3.fromRGB(255, 255, 150),
        RED = Color3.fromRGB(255, 0, 0),
        BLOOD = Color3.fromRGB(180, 0, 0),
        BLOOD_DARK = Color3.fromRGB(150, 0, 0),
        CYAN = Color3.fromRGB(0, 255, 255),
        MAGENTA = Color3.fromRGB(255, 0, 255),
        VIOLET = Color3.fromRGB(150, 0, 255),
        VOID = Color3.fromRGB(50, 0, 100),
        VOID_LIGHT = Color3.fromRGB(150, 50, 255),
        TOXIC = Color3.fromRGB(50, 255, 50),
        ICE = Color3.fromRGB(150, 255, 255),
        SPARK = Color3.fromRGB(255, 255, 100),
        SPARK_WARM = Color3.fromRGB(255, 200, 50),
        SAKURA = Color3.fromRGB(255, 160, 200),
    }

    local Shade = {
        laser = function() return Color3.fromRGB(random(220, 255), 0, 0) end,
        laserSpark = function() return Color3.fromRGB(random(200, 255), random(0, 40), 0) end,
        ember = function() return Color3.fromRGB(255, random(100, 160), 0) end,
        emberBright = function() return Color3.fromRGB(255, random(150, 220), 0) end,
        emberPale = function() return Color3.fromRGB(255, 255, random(150, 255)) end,
        flame = function() return Color3.fromRGB(255, random(20, 80), 0) end,
        flameAsh = function() return Color3.fromRGB(255, random(180, 220), random(20, 80)) end,

        nova = function() return Color3.fromRGB(random(120, 180), 0, 255) end,
        novaDeep = function() return Color3.fromRGB(random(80, 150), 0, 255) end,
        novaBright = function() return Color3.fromRGB(random(200, 255), 0, 255) end,
        starlight = function() return Color3.fromRGB(0, random(200, 255), 255) end,
        starlightPale = function() return Color3.fromRGB(random(200, 255), 255, 255) end,
        nebula = function() return Color3.fromRGB(random(180, 220), random(80, 120), 255) end,
        nebulaDark = function() return Color3.fromRGB(random(30, 80), 0, random(120, 180)) end,

        blood = function() return Color3.fromRGB(random(120, 180), 0, 0) end,
        bloodBright = function() return Color3.fromRGB(random(180, 255), 0, 0) end,
        bloodDeep = function() return Color3.fromRGB(random(50, 100), 0, 0) end,
        bloodClot = function() return Color3.fromRGB(random(130, 180), 0, 0) end,
        bloodDry = function() return Color3.fromRGB(random(30, 70), 0, 0) end,

        holyGold = function() return Color3.fromRGB(255, random(200, 255), 0) end,
        holySpear = function() return Color3.fromRGB(255, random(150, 215), 0) end,

        toxic = function() return Color3.fromRGB(random(30, 80), 255, random(30, 80)) end,
        toxicDeep = function() return Color3.fromRGB(0, random(100, 180), 0) end,
        toxicLeaf = function() return Color3.fromRGB(random(80, 140), 255, random(30, 80)) end,
        toxicShadow = function() return Color3.fromRGB(random(10, 30), random(80, 140), random(10, 30)) end,

        ice = function() return Color3.fromRGB(random(120, 180), 255, 255) end,
        iceShard = function() return Color3.fromRGB(random(150, 200), 255, 255) end,
        iceMist = function() return Color3.fromRGB(random(180, 220), 255, 255) end,

        voidCore = function() return Color3.fromRGB(random(30, 80), 0, random(80, 150)) end,
        voidInner = function() return Color3.fromRGB(random(20, 60), 0, random(60, 100)) end,
        voidRim = function() return Color3.fromRGB(random(80, 120), 0, random(180, 220)) end,
        voidStrand = function() return Color3.fromRGB(random(100, 180), random(20, 80), 255) end,
        voidDust = function() return Color3.fromRGB(random(60, 100), 0, random(100, 150)) end,

        glitchPink = function() return Color3.fromRGB(255, random(0, 50), 255) end,
        glitchCyan = function() return Color3.fromRGB(random(0, 50), 255, 255) end,

        sparkCore = function() return Color3.fromRGB(255, 255, random(100, 200)) end,
        sparkTrail = function() return Color3.fromRGB(255, 255, random(100, 255)) end,
        sparkFade = function() return Color3.fromRGB(255, random(50, 150), 0) end,
        sparkShard = function() return Color3.fromRGB(255, random(180, 220), random(50, 100)) end,

        petal = function() return Color3.fromRGB(255, random(140, 180), random(180, 230)) end,
        petalPale = function() return Color3.fromRGB(255, random(200, 230), 255) end,
    }

    ----------------------------------------------------------------
    -- Particle engine
    ----------------------------------------------------------------

    local POOL_LIMITS = { Circle = 40, Line = 250, Triangle = 150, Square = 100 }

    local pools = {}
    for shape, limit in pairs(POOL_LIMITS) do
        local pool = {}
        for _ = 1, limit do
            table.insert(pool, Util.newDrawing(shape, {
                Visible = false,
                Filled = shape ~= "Circle" and shape ~= "Line",
            }))
        end
        pools[shape] = pool
    end

    local particles = {}

    local state = {
        killEffects = false,
        killEffectsSheriffOnly = false,
        killEffectStyle = "Random",
        killEffectVersion = "New (V2)",
        killEffectDuration = 3,

        tracers = false,
        tracerSheriffOnly = false,
        tracerRainbow = false,
        tracerGlow = false,
        tracerColor = Color3.fromRGB(0, 255, 100),
        tracerDuration = 3,
        tracerThickness = 1,
        tracerLine = false,
        tracerLineColor = Color3.fromRGB(255, 255, 255),
        tracerLineThickness = 2,

        hitSounds = false,
        hitSoundsOnlyCustom = false,
    }

    local function spawnParticle(shape, props)
        local limit = POOL_LIMITS[shape] or 0
        local live = 0
        for _, particle in ipairs(particles) do
            if particle.shape == shape then
                live = live + 1
            end
        end

        if live >= limit then
            return
        end

        props.shape = shape
        props.life = 0
        props.maxLife = props.maxLife or 1

        if shape ~= "Circle" then
            props.maxLife = props.maxLife * state.killEffectDuration
        end

        table.insert(particles, props)
    end

    ----------------------------------------------------------------
    -- Kill effect styles
    ----------------------------------------------------------------

    local Styles = { ["Old (V1)"] = {}, ["New (V2)"] = {} }

    local V1 = Styles["Old (V1)"]

    V1["Laser Eyes"] = function(pos)
        spawnParticle("Circle", { pos = pos, r = 10, maxR = 250, maxLife = 0.6, color = Palette.RED, t = 5, shrink = true })
        for _ = 1, 40 do
            spawnParticle("Line", { pos = pos,
                vel = Vector3.new(random(-150, 150), random(-50, 150), random(-150, 150)),
                length = random(20, 50), maxLife = random(50, 80) / 100, color = Palette.RED, t = 3 })
        end
    end

    V1["Cosmic Nova"] = function(pos)
        spawnParticle("Circle", { pos = pos, r = 0, maxR = 300, maxLife = 0.8, color = Palette.VIOLET, t = 8 })
        for _ = 1, 60 do
            spawnParticle("Line", { pos = pos,
                vel = Vector3.new(random(-100, 100), random(-100, 100), random(-100, 100)),
                length = random(20, 50), maxLife = random(60, 100) / 100, color = Palette.CYAN, t = 3 })
        end
    end

    V1["Blood Splatter"] = function(pos)
        for _ = 1, 10 do
            spawnParticle("Circle", { pos = pos + Vector3.new(random(-10, 10), random(-10, 10), random(-10, 10)),
                r = 0, maxR = random(30, 80), maxLife = random(40, 70) / 100, color = Palette.BLOOD, t = 5 })
        end
        for _ = 1, 50 do
            spawnParticle("Triangle", { pos = pos,
                vel = Vector3.new(random(-50, 50), random(20, 60), random(-50, 50)),
                grav = Vector3.new(0, -150, 0), rot = CFrame.Angles(0, 0, 0),
                rotV = CFrame.Angles(math.random() * 2, 0, 0), size = 2, maxLife = 0.8,
                color = Palette.BLOOD_DARK })
        end
    end

    V1["Holy Smite"] = function(pos)
        spawnParticle("Circle", { pos = pos, r = 0, maxR = 250, maxLife = 0.5, color = Palette.WHITE, t = 10 })
        for _ = 1, 40 do
            spawnParticle("Line", { pos = pos + Vector3.new(random(-30, 30), 200, random(-30, 30)),
                vel = Vector3.new(0, -800, 0), length = 100, maxLife = 0.4, color = Palette.GOLD, t = 4 })
        end
    end

    V1["Toxic Splash"] = function(pos)
        for _ = 1, 15 do
            spawnParticle("Circle", { pos = pos, r = 0, maxR = random(20, 60), maxLife = 0.6, color = Palette.TOXIC, t = 4 })
        end
        for _ = 1, 40 do
            spawnParticle("Square", { pos = pos,
                vel = Vector3.new(random(-40, 40), random(30, 80), random(-40, 40)),
                grav = Vector3.new(0, -60, 0), size = 15, maxLife = 0.8, color = Palette.TOXIC })
        end
    end

    V1["Ice Shatter"] = function(pos)
        spawnParticle("Circle", { pos = pos, r = 0, maxR = 180, maxLife = 0.5, color = Palette.ICE, t = 5 })
        for _ = 1, 50 do
            spawnParticle("Triangle", { pos = pos,
                vel = Vector3.new(random(-150, 150), random(-30, 80), random(-150, 150)),
                grav = Vector3.new(0, -50, 0), rot = CFrame.Angles(0, 0, 0), rotV = CFrame.Angles(0, 0, 0),
                size = 2, maxLife = 0.7, color = Palette.WHITE })
        end
    end

    V1["Void Collapse"] = function(pos)
        spawnParticle("Circle", { pos = pos, r = 300, maxR = 0, maxLife = 1.0, color = Palette.VOID, t = 15, shrink = true })
        for _ = 1, 50 do
            spawnParticle("Line", { pos = pos + Vector3.new(random(-100, 100), random(-100, 100), random(-100, 100)),
                vel = Vector3.new(0, 0, 0), pullTarget = pos, pullSpeed = 150, length = 20, maxLife = 1.0,
                color = Palette.VOID_LIGHT, t = 3 })
        end
    end

    V1["Cyber Glitch"] = function(pos)
        for _ = 1, 40 do
            spawnParticle("Square", { pos = pos + Vector3.new(random(-40, 40), random(-40, 40), random(-40, 40)),
                size = 20, maxLife = 0.6, color = math.random() > 0.5 and Palette.MAGENTA or Palette.CYAN })
        end
        for _ = 1, 40 do
            spawnParticle("Line", { pos = pos,
                vel = Vector3.new(random(-100, 100), random(-100, 100), random(-100, 100)), length = 30,
                maxLife = 0.5, color = Palette.CYAN, t = 4 })
        end
    end

    V1["Sparkler"] = function(pos)
        spawnParticle("Circle", { pos = pos, r = 0, maxR = 150, maxLife = 0.4, color = Palette.SPARK, t = 5 })
        for _ = 1, 60 do
            spawnParticle("Line", { pos = pos,
                vel = Vector3.new(random(-120, 120), random(40, 150), random(-120, 120)),
                grav = Vector3.new(0, -100, 0), length = 15, maxLife = 0.8, color = Palette.SPARK_WARM, t = 2 })
        end
    end

    V1["Sakura Petals"] = function(pos)
        for _ = 1, 50 do
            spawnParticle("Triangle", { pos = pos + Vector3.new(random(-20, 20), random(10, 40), random(-20, 20)),
                vel = Vector3.new(random(-30, 30), random(-5, 15), random(-30, 30)),
                grav = Vector3.new(0, -5, 0), sway = 2, rot = CFrame.Angles(0, 0, 0),
                rotV = CFrame.Angles(0, 0, 0), size = 2, maxLife = 2.0, color = Palette.SAKURA })
        end
    end

    local V2 = Styles["New (V2)"]

    V2["Laser Eyes"] = function(pos)
        spawnParticle("Circle", { pos = pos, r = 10, maxR = 350, maxLife = 0.8, color = Shade.laser(), color2 = Shade.ember(), t = 10, shrink = true })
        spawnParticle("Circle", { pos = pos, r = 0, maxR = 180, maxLife = 0.6, color = Shade.ember(), color2 = Color3.fromRGB(255, 255, random(0, 100)), t = 6 })

        for _ = 1, 150 do
            spawnParticle("Line", { pos = pos,
                vel = Vector3.new(random(-250, 250), random(-50, 300), random(-250, 250)),
                length = random(30, 80), maxLife = random(50, 110) / 100, color = Shade.laserSpark(),
                color2 = Shade.emberBright(), color3 = Shade.emberPale(), t = random(3, 6) })
        end

        for _ = 1, 80 do
            spawnParticle("Triangle", { pos = pos,
                vel = Vector3.new(random(-100, 100), random(50, 150), random(-100, 100)),
                grav = Vector3.new(0, -120, 0),
                rot = CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6),
                rotV = CFrame.Angles(random(-20, 20) / 100, random(-20, 20) / 100, random(-20, 20) / 100),
                size = random(15, 35) / 10, maxLife = random(70, 120) / 100, color = Shade.flame(),
                color2 = Shade.flameAsh() })
        end
    end

    V2["Cosmic Nova"] = function(pos)
        spawnParticle("Circle", { pos = pos, r = 0, maxR = 400, maxLife = 1.2, color = Shade.nova(), color2 = Shade.starlight(), t = 12 })
        spawnParticle("Circle", { pos = pos, r = 0, maxR = 250, maxLife = 0.9, color = Shade.starlight(), color2 = Palette.WHITE, t = 8 })
        spawnParticle("Circle", { pos = pos, r = 500, maxR = 0, maxLife = 1.1, color = Shade.nebula(), color2 = Shade.nebulaDark(), t = 5, shrink = true })

        for _ = 1, 200 do
            spawnParticle("Line", { pos = pos,
                vel = Vector3.new(random(-200, 200), random(-200, 200), random(-200, 200)),
                length = random(25, 75), maxLife = random(70, 160) / 100, color = Shade.novaDeep(),
                color2 = Shade.starlight(), color3 = Shade.starlightPale(), t = 3 })
        end

        for _ = 1, 80 do
            spawnParticle("Square", { pos = pos + Vector3.new(random(-100, 100), random(-100, 100), random(-100, 100)),
                pullTarget = pos, pullSpeed = 150, size = random(20, 40), maxLife = 1.2,
                color = Shade.novaBright(), color2 = Shade.starlight() })
        end
    end

    V2["Blood Splatter"] = function(pos)
        for _ = 1, 25 do
            spawnParticle("Circle", { pos = pos + Vector3.new(random(-15, 15), random(-15, 15), random(-15, 15)),
                r = 0, maxR = random(40, 120), maxLife = random(50, 90) / 100, color = Shade.blood(),
                color2 = Shade.bloodBright(), t = random(6, 12) })
        end

        for _ = 1, 150 do
            spawnParticle("Line", { pos = pos,
                vel = Vector3.new(random(-100, 100), random(-30, 120), random(-100, 100)),
                grav = Vector3.new(0, -200, 0), length = random(15, 45), maxLife = random(80, 180) / 100,
                color = Shade.bloodBright(), color2 = Shade.bloodDeep(), t = random(4, 8) })
        end

        for _ = 1, 100 do
            spawnParticle("Triangle", { pos = pos,
                vel = Vector3.new(random(-60, 60), random(20, 80), random(-60, 60)),
                grav = Vector3.new(0, -250, 0),
                rot = CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6),
                rotV = CFrame.Angles(math.random() * 3, 0, 0), size = random(15, 30) / 10,
                maxLife = random(80, 150) / 100, color = Shade.bloodClot(), color2 = Shade.bloodDry() })
        end
    end

    V2["Holy Smite"] = function(pos)
        spawnParticle("Circle", { pos = pos, r = 0, maxR = 600, maxLife = 1.2, color = Palette.WHITE, color2 = Palette.GOLD, t = 30, shrink = true })
        spawnParticle("Circle", { pos = pos, r = 200, maxR = 0, maxLife = 0.8, color = Palette.HOLY_WARM, t = 15 })

        for _ = 1, 100 do
            spawnParticle("Line", { pos = pos, vel = Vector3.new(random(-600, 600), 0, random(-600, 600)),
                length = random(40, 120), maxLife = 0.6, color = Palette.WHITE, color2 = Palette.GOLD, t = 6 })
        end

        for _ = 1, 80 do
            spawnParticle("Square", { pos = pos + Vector3.new(random(-100, 100), random(0, 50), random(-100, 100)),
                vel = Vector3.new(0, random(200, 500), 0), size = random(20, 50), maxLife = 1.2,
                color = Shade.holyGold(), color2 = Palette.WHITE, flicker = true })
        end

        for _ = 1, 60 do
            spawnParticle("Line", { pos = pos + Vector3.new(random(-150, 150), random(300, 800), random(-150, 150)),
                vel = Vector3.new(0, -1500, 0), length = random(150, 300), maxLife = 0.5, color = Palette.WHITE,
                color2 = Shade.holySpear(), t = 12 })
        end
    end

    V2["Toxic Splash"] = function(pos)
        for _ = 1, 35 do
            spawnParticle("Circle", { pos = pos + Vector3.new(random(-25, 25), random(-15, 30), random(-25, 25)),
                r = 0, maxR = random(30, 90), maxLife = random(50, 140) / 100, color = Shade.toxic(),
                color2 = Shade.toxicDeep(), t = random(4, 10) })
        end

        for _ = 1, 120 do
            spawnParticle("Triangle", { pos = pos,
                vel = Vector3.new(random(-60, 60), random(30, 100), random(-60, 60)),
                grav = Vector3.new(0, -60, 0), rot = CFrame.Angles(0, 0, 0),
                rotV = CFrame.Angles(math.random() * 0.2, math.random() * 0.2, 0), size = random(15, 30) / 10,
                maxLife = random(80, 180) / 100, color = Shade.toxicLeaf(), color2 = Shade.toxicShadow() })
        end

        for _ = 1, 60 do
            spawnParticle("Square", { pos = pos,
                vel = Vector3.new(random(-40, 40), random(50, 120), random(-40, 40)),
                grav = Vector3.new(0, -80, 0), size = random(15, 25), maxLife = random(60, 140) / 100,
                color = Shade.toxic() })
        end
    end

    V2["Ice Shatter"] = function(pos)
        for _ = 1, 15 do
            spawnParticle("Circle", { pos = pos, r = 0, maxR = random(150, 250), maxLife = 0.6,
                color = Shade.ice(), color2 = Palette.WHITE, t = 5 })
        end

        for _ = 1, 150 do
            spawnParticle("Triangle", { pos = pos,
                vel = Vector3.new(random(-200, 200), random(-50, 100), random(-200, 200)),
                grav = Vector3.new(0, -80, 0),
                rot = CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6),
                rotV = CFrame.Angles(math.random() * 0.4, 0, 0), size = random(15, 40) / 10,
                maxLife = random(60, 120) / 100, color = Shade.iceShard(), color2 = Palette.WHITE })
        end

        for _ = 1, 100 do
            spawnParticle("Line", { pos = pos,
                vel = Vector3.new(random(-250, 250), random(-50, 50), random(-250, 250)),
                length = random(25, 70), maxLife = 0.6, color = Shade.iceMist(), color2 = Palette.WHITE,
                t = 4 })
        end
    end

    V2["Void Collapse"] = function(pos)
        spawnParticle("Circle", { pos = pos, r = 450, maxR = 0, maxLife = 1.4, color = Palette.BLACK, color2 = Shade.voidCore(), t = 25, shrink = true })
        spawnParticle("Circle", { pos = pos, r = 300, maxR = 0, maxLife = 1.0, color = Shade.voidInner(), color2 = Shade.voidRim(), t = 15, shrink = true })

        for _ = 1, 150 do
            spawnParticle("Line", { pos = pos + Vector3.new(random(-150, 150), random(-150, 150), random(-150, 150)),
                vel = Vector3.new(0, 0, 0), pullTarget = pos, pullSpeed = random(150, 300),
                length = random(25, 50), maxLife = 1.4, color = Shade.voidStrand(), color2 = Palette.BLACK,
                t = 5 })
        end

        for _ = 1, 100 do
            spawnParticle("Triangle", { pos = pos + Vector3.new(random(-100, 100), random(-100, 100), random(-100, 100)),
                pullTarget = pos, pullSpeed = 200,
                rot = CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6),
                rotV = CFrame.Angles(0.2, 0.2, 0.2), size = random(20, 35) / 10, maxLife = 1.4,
                color = Shade.voidDust(), color2 = Shade.novaBright() })
        end
    end

    V2["Cyber Glitch"] = function(pos)
        for _ = 1, 100 do
            spawnParticle("Square", { pos = pos + Vector3.new(random(-60, 60), random(-60, 60), random(-60, 60)),
                size = random(25, 60), maxLife = random(40, 100) / 100,
                color = math.random() > 0.5 and Shade.glitchPink() or Shade.glitchCyan(),
                color2 = Palette.WHITE, flicker = true })
        end

        for _ = 1, 150 do
            spawnParticle("Line", { pos = pos + Vector3.new(random(-50, 50), random(-50, 50), random(-50, 50)),
                vel = Vector3.new(random(-150, 150), random(-150, 150), random(-150, 150)),
                length = random(30, 100), maxLife = random(40, 90) / 100, color = Shade.glitchCyan(),
                color2 = Shade.glitchPink(), t = 7, flicker = true })
        end
    end

    V2["Sparkler"] = function(pos)
        spawnParticle("Circle", { pos = pos, r = 0, maxR = 200, maxLife = 0.5, color = Shade.sparkCore(), color2 = Palette.WHITE, t = 8 })

        for _ = 1, 200 do
            spawnParticle("Line", { pos = pos,
                vel = Vector3.new(random(-180, 180), random(50, 200), random(-180, 180)),
                grav = Vector3.new(0, -150, 0), length = random(10, 25), maxLife = random(70, 150) / 100,
                color = Shade.sparkTrail(), color2 = Shade.sparkFade(), t = 4 })
        end

        for _ = 1, 80 do
            spawnParticle("Triangle", { pos = pos,
                vel = Vector3.new(random(-120, 120), random(80, 250), random(-120, 120)),
                grav = Vector3.new(0, -180, 0),
                rot = CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6),
                rotV = CFrame.Angles(math.random() * 0.5, math.random() * 0.5, 0), size = random(10, 20) / 10,
                maxLife = random(70, 140) / 100, color = Shade.sparkShard(), color2 = Palette.WHITE })
        end
    end

    V2["Sakura Petals"] = function(pos)
        for _ = 1, 150 do
            spawnParticle("Triangle", { pos = pos + Vector3.new(random(-30, 30), random(10, 60), random(-30, 30)),
                vel = Vector3.new(random(-50, 50), random(-5, 25), random(-50, 50)),
                grav = Vector3.new(0, -10, 0), sway = random(20, 50) / 10,
                rot = CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6),
                rotV = CFrame.Angles(0.02, 0.05, 0.02), size = random(15, 30) / 10,
                maxLife = random(250, 500) / 100, color = Shade.petal(), color2 = Shade.petalPale() })
        end
    end

    local STYLE_NAMES = {
        "Laser Eyes", "Cosmic Nova", "Blood Splatter", "Holy Smite", "Toxic Splash",
        "Ice Shatter", "Void Collapse", "Cyber Glitch", "Sparkler", "Sakura Petals",
    }

    local styleCursor = 0

    local function triggerKillEffect(position, styleName)
        if styleName == "Random" then
            styleCursor = styleCursor + random(1, 5)
            styleName = STYLE_NAMES[(styleCursor % #STYLE_NAMES) + 1]
        end

        local set = Styles[state.killEffectVersion] or Styles["New (V2)"]
        local spawn = set[styleName]
        if spawn then
            spawn(position)
        end
    end

    ----------------------------------------------------------------
    -- Particle rendering
    ----------------------------------------------------------------

    Scheduler.onRender("vfx.particles", function(dt)
        if not state.killEffects and #particles == 0 then
            return
        end

        local used = { Circle = 0, Line = 0, Triangle = 0, Square = 0 }

        for index = #particles, 1, -1 do
            local particle = particles[index]
            particle.life = particle.life + dt

            if particle.life >= particle.maxLife then
                table.remove(particles, index)
            else
                local progress = particle.life / particle.maxLife

                if particle.vel then
                    particle.pos = particle.pos + particle.vel * dt
                    particle.vel = particle.vel * (1 - math.min(1, dt * 3))
                end
                if particle.grav then
                    particle.vel = particle.vel + particle.grav * dt
                    particle.grav = particle.grav * (1 - math.min(1, dt * 2))
                end
                if particle.pullTarget then
                    local direction = particle.pullTarget - particle.pos
                    if direction.Magnitude > 1 then
                        particle.pos = particle.pos + direction.Unit * particle.pullSpeed * dt
                    end
                end
                if particle.sway then
                    particle.pos = particle.pos + Vector3.new(
                        math.sin(particle.life * particle.sway) * 5 * dt,
                        0,
                        math.cos(particle.life * particle.sway * 0.7) * 5 * dt
                    )
                end
                if particle.rot then
                    particle.rot = particle.rot * particle.rotV
                end

                local screenPos, onScreen = worldToScreen(particle.pos)

                if onScreen then
                    local color = particle.color
                    if particle.color2 then
                        if progress < 0.5 then
                            color = lerpColor(particle.color, particle.color2, progress * 2)
                        else
                            color = lerpColor(particle.color2, particle.color3 or particle.color2, (progress - 0.5) * 2)
                        end
                    end

                    if particle.flicker and math.random() > 0.5 then
                        color = Palette.WHITE
                    end

                    local shape = particle.shape

                    if shape == "Circle" and used.Circle < POOL_LIMITS.Circle then
                        used.Circle = used.Circle + 1
                        local circle = pools.Circle[used.Circle]
                        if particle.shrink then
                            circle.Radius = particle.r - ((particle.r - particle.maxR) * progress)
                        else
                            circle.Radius = particle.r + ((particle.maxR - particle.r) * math.pow(progress, 0.5))
                        end
                        circle.Position = screenPos
                        circle.Color = color
                        circle.Transparency = 1 - progress
                        circle.Thickness = math.max(1, (particle.t or 5) * (1 - progress))
                        circle.Visible = true

                    elseif shape == "Line" and used.Line < POOL_LIMITS.Line then
                        local tail = particle.pos - (particle.vel and particle.vel.Unit * particle.length or Vector3.new(0, particle.length, 0))
                        local tailPos, tailOnScreen = worldToScreen(tail)
                        if tailOnScreen then
                            used.Line = used.Line + 1
                            local line = pools.Line[used.Line]
                            line.From = tailPos
                            line.To = screenPos
                            line.Color = color
                            line.Transparency = 1 - progress
                            line.Thickness = particle.t or 2
                            line.Visible = true
                        end

                    elseif shape == "Triangle" and used.Triangle < POOL_LIMITS.Triangle then
                        local size = particle.size * (1 - progress)
                        local a, aOn = worldToScreen(particle.pos + (particle.rot * Vector3.new(0, size, 0)))
                        local b, bOn = worldToScreen(particle.pos + (particle.rot * Vector3.new(-size, -size, 0)))
                        local c, cOn = worldToScreen(particle.pos + (particle.rot * Vector3.new(size, -size, 0)))
                        if aOn and bOn and cOn then
                            used.Triangle = used.Triangle + 1
                            local triangle = pools.Triangle[used.Triangle]
                            triangle.PointA, triangle.PointB, triangle.PointC = a, b, c
                            triangle.Color = color
                            triangle.Transparency = 1 - progress
                            triangle.Visible = true
                        end

                    elseif shape == "Square" and used.Square < POOL_LIMITS.Square then
                        used.Square = used.Square + 1
                        local square = pools.Square[used.Square]
                        if particle.flicker then
                            square.Position = screenPos + Vector2.new(random(-10, 10), random(-10, 10))
                            square.Transparency = math.random() > 0.5 and 1 or 0
                        else
                            square.Position = screenPos - Vector2.new(particle.size / 2, particle.size / 2)
                            square.Transparency = 1 - progress
                        end
                        square.Size = Vector2.new(particle.size, particle.size)
                        square.Color = color
                        square.Visible = true
                    end
                end
            end
        end

        for shape, limit in pairs(POOL_LIMITS) do
            for index = used[shape] + 1, limit do
                pools[shape][index].Visible = false
            end
        end
    end)

    ----------------------------------------------------------------
    -- Hit tracers
    ----------------------------------------------------------------

    local CUBE_EDGES = {
        { 1, 2 }, { 2, 3 }, { 3, 4 }, { 4, 1 },
        { 5, 6 }, { 6, 7 }, { 7, 8 }, { 8, 5 },
        { 1, 5 }, { 2, 6 }, { 3, 7 }, { 4, 8 },
    }

    local tracers = {}

    local function newTracerLine(thickness, color, zIndex)
        return Util.newDrawing("Line", {
            Thickness = thickness,
            Color = color,
            Visible = false,
            ZIndex = zIndex,
        })
    end

    local function destroyTracer(tracer)
        for _, segment in ipairs(tracer.segments) do
            segment.line:Remove()
            for _, glow in ipairs(segment.glow) do
                glow:Remove()
            end
        end
    end

    local function spawnCubeTracer(cframe, size, duration, color)
        local half = size / 2
        local corners = {
            Vector3.new(-half.X, -half.Y, -half.Z), Vector3.new(half.X, -half.Y, -half.Z),
            Vector3.new(half.X, half.Y, -half.Z), Vector3.new(-half.X, half.Y, -half.Z),
            Vector3.new(-half.X, -half.Y, half.Z), Vector3.new(half.X, -half.Y, half.Z),
            Vector3.new(half.X, half.Y, half.Z), Vector3.new(-half.X, half.Y, half.Z),
        }

        local worldCorners = {}
        for index = 1, 8 do
            worldCorners[index] = cframe:PointToWorldSpace(corners[index])
        end

        local segments = {}
        for _, edge in ipairs(CUBE_EDGES) do
            local glow = {}
            if state.tracerGlow then
                for layer = 1, 2 do
                    table.insert(glow, newTracerLine(state.tracerThickness + (layer * 4), color, 0))
                end
            end

            table.insert(segments, {
                line = newTracerLine(state.tracerThickness, color, 1),
                glow = glow,
                from = worldCorners[edge[1]],
                to = worldCorners[edge[2]],
            })
        end

        table.insert(tracers, { segments = segments, start = os.clock(), duration = duration })
    end

    local function spawnLineTracer(fromPosition, toPosition, duration, color, thickness)
        local glow = {}
        if state.tracerGlow then
            table.insert(glow, newTracerLine(thickness + 4, color, 0))
        end

        table.insert(tracers, {
            segments = { { line = newTracerLine(thickness, color, 1), glow = glow, from = fromPosition, to = toPosition } },
            start = os.clock(),
            duration = duration,
        })
    end

    local function drawCharacterTracer(character, duration, color)
        for _, part in ipairs(character:GetChildren()) do
            if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" and part.Transparency < 1 then
                spawnCubeTracer(part.CFrame, part.Size, duration, color)
            end
        end
    end

    Scheduler.onRender("vfx.tracers", function()
        if #tracers == 0 then
            return
        end

        local now = os.clock()
        local rainbow = state.tracerRainbow and Color3.fromHSV((now % 2) / 2, 1, 1) or nil

        for index = #tracers, 1, -1 do
            local tracer = tracers[index]
            local elapsed = now - tracer.start

            if elapsed > tracer.duration then
                destroyTracer(tracer)
                table.remove(tracers, index)
            else
                local alpha = 1 - (elapsed / tracer.duration)

                for _, segment in ipairs(tracer.segments) do
                    local from, fromOn = worldToScreen(segment.from)
                    local to, toOn = worldToScreen(segment.to)
                    local line = segment.line

                    if fromOn and toOn then
                        if rainbow then
                            line.Color = rainbow
                        end
                        line.From = from
                        line.To = to
                        line.Transparency = alpha
                        line.Visible = true

                        for layer, glow in ipairs(segment.glow) do
                            if rainbow then
                                glow.Color = rainbow
                            end
                            glow.From = from
                            glow.To = to
                            glow.Transparency = alpha * (0.75 - (layer * 0.2))
                            glow.Visible = true
                        end
                    else
                        line.Visible = false
                        for _, glow in ipairs(segment.glow) do
                            glow.Visible = false
                        end
                    end
                end
            end
        end
    end)

    ----------------------------------------------------------------
    -- Hit sounds
    ----------------------------------------------------------------

    local DEFAULT_HIT_TEXTS = { "Hit!", "Boom!", "Eliminated!", "Headshot!", "Wasted!", "Smacked!", "Oof!", "Gotcha!" }

    local customHitTexts = { "(None)" }
    local customSoundsDropdown
    local hitSoundIndex = 1

    local function selectedCustomTexts()
        local selected = customSoundsDropdown and customSoundsDropdown:Get()
        local out = {}

        if type(selected) == "table" then
            for key, value in pairs(selected) do
                if type(key) == "string" and value == true and key ~= "(None)" then
                    table.insert(out, key)
                elseif type(value) == "string" and value ~= "(None)" then
                    table.insert(out, value)
                end
            end
        elseif type(selected) == "string" and selected ~= "(None)" then
            table.insert(out, selected)
        end

        return out
    end

    local function playHitSound()
        local customs = selectedCustomTexts()
        local pool

        if state.hitSoundsOnlyCustom then
            pool = #customs > 0 and customs or { "(No Custom Sounds)" }
        else
            pool = {}
            for _, text in ipairs(DEFAULT_HIT_TEXTS) do
                table.insert(pool, text)
            end
            for _, text in ipairs(customs) do
                table.insert(pool, text)
            end
        end

        if #pool == 0 then
            return
        end

        if hitSoundIndex > #pool then
            hitSoundIndex = 1
        end

        Ctx.notify(pool[hitSoundIndex], "LeatherHub", 4)
        hitSoundIndex = hitSoundIndex + 1
    end

    ----------------------------------------------------------------
    -- Triggers
    ----------------------------------------------------------------

    local lastTracerShot = 0

    local function targetUnderCursor()
        local mouse = Util.getMousePosition()
        local closest, closestDistance = nil, math.huge

        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                local root = Util.getPlayerHRP(player)
                if root then
                    local position, onScreen = worldToScreen(root.Position)
                    if onScreen then
                        local distance = (position - mouse).Magnitude
                        if distance < closestDistance then
                            closestDistance, closest = distance, player
                        end
                    end
                end
            end
        end

        return closest
    end

    local function tracerOrigin()
        local character = LocalPlayer.Character
        if not character then
            return nil
        end

        local arm = character:FindFirstChild("Right Arm") or character:FindFirstChild("RightHand")
        if not arm then
            return nil
        end

        local head = character:FindFirstChild("Head")
        local root = Util.getHRP()
        local camera = Services.Workspace.CurrentCamera

        if camera and head and root and (camera.CFrame.Position - head.Position).Magnitude < 2 then
            return head.Position + (root.CFrame.LookVector * 2) - Vector3.new(0, 0.5, 0)
        end

        if root and (arm.Position - root.Position).Magnitude > 5 then
            return root.Position
        end

        return arm.Position
    end

    local mouseWasDown = false

    Scheduler.onRender("vfx.shotWatcher", function()
        local wantsTracer = state.tracers
        local wantsEffect = state.killEffects and not state.killEffectsSheriffOnly
        if not wantsTracer and not wantsEffect then
            mouseWasDown = false
            return
        end

        local isDown = Util.isMouse1Down()
        if not isDown or mouseWasDown then
            mouseWasDown = isDown
            return
        end
        mouseWasDown = true

        local canTrace = state.tracers
        if canTrace and state.tracerSheriffOnly then
            local character = LocalPlayer.Character
            local holdingGun = character and character:FindFirstChild("Gun") ~= nil
            canTrace = holdingGun and (os.clock() - lastTracerShot) >= 2
        end

        if not canTrace and not wantsEffect then
            return
        end

        local target = targetUnderCursor()
        local character = target and target.Character
        if not character then
            return
        end

        if canTrace then
            if state.tracerSheriffOnly then
                lastTracerShot = os.clock()
            else
                drawCharacterTracer(character, state.tracerDuration, state.tracerColor)
            end

            if state.tracerLine then
                local origin = tracerOrigin()
                local targetRoot = Util.getPlayerHRP(target) or character:FindFirstChild("Torso")
                if origin and targetRoot then
                    spawnLineTracer(origin, targetRoot.Position, state.tracerDuration, state.tracerLineColor, state.tracerLineThickness)
                end
            end
        end

        if wantsEffect then
            local targetRoot = Util.getPlayerHRP(target)
            if targetRoot then
                triggerKillEffect(targetRoot.Position, state.killEffectStyle)
            end
        end
    end)

    local watchedMurderer, watchedHealth = nil, 100

    Scheduler.every("vfx.sheriffWatcher", 0.1, function()
        local needsWatcher = (state.tracers and state.tracerSheriffOnly)
            or (state.killEffects and state.killEffectsSheriffOnly)
            or state.hitSounds
        if not needsWatcher then
            return
        end

        local weHaveGun = Util.playerHasTool(LocalPlayer, "Gun")

        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character and Util.playerHasTool(player, "Knife") then
                if watchedMurderer ~= player.Name then
                    watchedMurderer = player.Name
                    watchedHealth = 100
                end

                local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
                if humanoid then
                    local health = humanoid.Health

                    if watchedHealth > 0 and health <= 0 and weHaveGun then
                        if state.tracers and state.tracerSheriffOnly then
                            drawCharacterTracer(player.Character, state.tracerDuration, state.tracerColor)
                        end

                        if state.killEffects and state.killEffectsSheriffOnly then
                            local root = Util.getPlayerHRP(player)
                            if root then
                                triggerKillEffect(root.Position, state.killEffectStyle)
                            end
                        end

                        if state.hitSounds then
                            playHitSound()
                        end
                    end

                    watchedHealth = health
                end
            end
        end
    end)

    ----------------------------------------------------------------
    -- UI
    ----------------------------------------------------------------

    local tracerSection = visualsTab:Section("Hit Tracers", "Right")

    tracerSection:Toggle("Enable Hit Tracers", false, function(enabled)
        state.tracers = enabled
    end)

    tracerSection:Toggle("Enable Glow Effect", false, function(enabled)
        state.tracerGlow = enabled
    end)

    tracerSection:Toggle("Sheriff Only Mode (Gun)", false, function(enabled)
        state.tracerSheriffOnly = enabled
    end)

    tracerSection:Colorpicker("Hit Tracer Color", state.tracerColor, function(color)
        state.tracerColor = color
    end)

    tracerSection:Toggle("Rainbow Tracer", false, function(enabled)
        state.tracerRainbow = enabled
    end)

    tracerSection:Slider("Tracer Thickness (Box)", 1, 1, 1, 10, "", function(value)
        state.tracerThickness = value
    end)

    tracerSection:Slider("Tracer Duration", 3, 1, 1, 10, " sec", function(value)
        state.tracerDuration = value
    end)

    tracerSection:Toggle("Enable Connecting Line", false, function(enabled)
        state.tracerLine = enabled
    end)

    tracerSection:Colorpicker("Connecting Line Color", state.tracerLineColor, function(color)
        state.tracerLineColor = color
    end)

    tracerSection:Slider("Connecting Line Thickness", 2, 1, 1, 10, "", function(value)
        state.tracerLineThickness = value
    end)

    local effectSection = visualsTab:Section("Kill Effects", "Right")

    effectSection:Toggle("Enable Kill Effects", false, function(enabled)
        state.killEffects = enabled
    end)

    effectSection:Toggle("Sheriff Only Mode", false, function(enabled)
        state.killEffectsSheriffOnly = enabled
    end)

    local styleOptions = { "Random" }
    for _, name in ipairs(STYLE_NAMES) do
        table.insert(styleOptions, name)
    end

    effectSection:Dropdown("Effect Style", "Random", styleOptions, false, function(value)
        state.killEffectStyle = type(value) == "table" and (value[1] or "Random") or value
    end)

    effectSection:Dropdown("Effect Version", "New (V2)", { "New (V2)", "Old (V1)" }, false, function(value)
        state.killEffectVersion = type(value) == "table" and (value[1] or "New (V2)") or value
    end)

    effectSection:Slider("Effect Duration", 3, 1, 1, 10, "x", function(value)
        state.killEffectDuration = value
    end)

    local soundSection = visualsTab:Section("Hit Sounds", "Left")

    soundSection:Toggle("Hit Sounds (Send Notification)", false, function(enabled)
        state.hitSounds = enabled
    end)

    soundSection:Toggle("Only Custom Sounds", false, function(enabled)
        state.hitSoundsOnlyCustom = enabled
    end)

    local pendingCustomText = ""

    soundSection:Textbox("Custom Text", "", function(text)
        pendingCustomText = text
    end)

    soundSection:Button("Add Custom Text", function()
        if pendingCustomText == "" then
            return
        end

        if #customHitTexts == 1 and customHitTexts[1] == "(None)" then
            table.remove(customHitTexts, 1)
            customSoundsDropdown:RemoveChoice("(None)")
        end

        table.insert(customHitTexts, pendingCustomText)
        customSoundsDropdown:AddChoice(pendingCustomText)
        Ctx.notify("Added: " .. pendingCustomText, "LeatherHub", 4)
    end)

    customSoundsDropdown = soundSection:Dropdown("Added Customs", {}, { "(None)" }, true, nil)

    soundSection:Button("Remove Selected Custom", function()
        local selected = selectedCustomTexts()

        for _, text in ipairs(selected) do
            customSoundsDropdown:RemoveChoice(text)
            for index = #customHitTexts, 1, -1 do
                if customHitTexts[index] == text then
                    table.remove(customHitTexts, index)
                end
            end
        end

        if #customHitTexts == 0 then
            table.insert(customHitTexts, "(None)")
            customSoundsDropdown:AddChoice("(None)")
        end

        if #selected > 0 then
            Ctx.notify("Removed " .. #selected .. " sounds", "LeatherHub", 4)
        end
    end)

    soundSection:Button("Test Hit Sound", playHitSound)
end)

--================================================================--
--                   MODULE: MAGIC KNIFE                          --
--================================================================--

defineModule("magicKnife", function(Ctx)
    local Lib = Ctx.Lib
    local Players = Services.Players
    local Workspace = Services.Workspace
    local worldToScreen = Util.worldToScreen

    local E_KEY = 0x45
    local LOCK_START = 0.85   
    local LOCK_END = 1.1      
    local FOV_SMOOTHING = 0.2

    local state = {
        enabled = false,
        showFov = true,
        fovRadius = 150,
    }

    local fovCircle = Util.newDrawing("Circle", {
        Color = Color3.fromRGB(255, 255, 255),
        Thickness = 1,
        Filled = false,
        Visible = false,
    })

    local lockedTarget = nil
    local lockedAt = 0
    local cameraReleased = true
    local fovPosition = nil

    local function holdingKnife()
        return Util.playerHasTool(LocalPlayer, "Knife")
    end

    ----------------------------------------------------------------
    -- FOV circle
    ----------------------------------------------------------------

    Scheduler.onRender("magicKnife.fov", function()
        fovCircle.Visible = state.enabled and state.showFov and holdingKnife()
        if not fovCircle.Visible then
            return
        end

        fovCircle.Radius = state.fovRadius

        local target = Util.getMouseScreenPosition()
        if not fovPosition then
            fovPosition = target
        else
            fovPosition = fovPosition + (target - fovPosition) * FOV_SMOOTHING
        end

        fovCircle.Position = fovPosition
    end)

    ----------------------------------------------------------------
    -- Target lock
    ----------------------------------------------------------------

    local function closestTargetInFov()
        local mouse = Util.getMousePosition()
        local closest, closestDistance = nil, math.huge

        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                local root = Util.getPlayerHRP(player)
                if root then
                    local position, onScreen = worldToScreen(root.Position)
                    if onScreen then
                        local distance = (position - mouse).Magnitude
                        if distance < state.fovRadius and distance < closestDistance then
                            closestDistance, closest = distance, player
                        end
                    end
                end
            end
        end

        return closest
    end

    local ePressed = false

    Scheduler.every("magicKnife.input", 0.05, function()
        if not state.enabled then
            ePressed = false
            return
        end

        local pressed = Util.isKeyDown(E_KEY, Enum.KeyCode.E)
        if pressed and not ePressed then
            ePressed = true

            local character = LocalPlayer.Character
            if character and character:FindFirstChild("Knife") then
                lockedTarget = closestTargetInFov()

                local targetRoot = lockedTarget and Util.getPlayerHRP(lockedTarget)
                local camera = Workspace.CurrentCamera
                if targetRoot and camera then
                    camera.CFrame = CFrame.lookAt(camera.CFrame.Position, targetRoot.Position)
                end

                lockedAt = os.clock()
                cameraReleased = false
            end
        elseif not pressed then
            ePressed = false
        end
    end)

    Scheduler.onHeartbeat("magicKnife.follow", function()
        if not state.enabled or not lockedTarget or lockedAt == 0 then
            return
        end

        local character = LocalPlayer.Character
        local camera = Workspace.CurrentCamera
        local elapsed = os.clock() - lockedAt

        if elapsed > LOCK_END then
            if not cameraReleased then
                local root = Util.getHRP()
                if root and camera then
                    camera.CFrame = CFrame.lookAt(camera.CFrame.Position, camera.CFrame.Position + root.CFrame.LookVector)
                end
                cameraReleased = true
            end
            return
        end

        if elapsed < LOCK_START or not character then
            return
        end

        local knife = character:FindFirstChild("Knife")
        local handle = knife and knife:FindFirstChild("Handle")
        local targetRoot = Util.getPlayerHRP(lockedTarget)
        if not (handle and targetRoot) then
            return
        end

        handle.CFrame = targetRoot.CFrame

        for _, child in ipairs(Workspace:GetChildren()) do
            if child.Name == "Knife" and child:IsA("BasePart") then
                child.CFrame = targetRoot.CFrame
            end
        end
    end)

    ----------------------------------------------------------------
    -- UI
    ----------------------------------------------------------------

    local knifeSection = Ctx.tabs.combat:Section("Magic Knife", "Right")

    knifeSection:Toggle("Knife Teleport", false, function(enabled)
        state.enabled = enabled
        if enabled then
            Lib:Notify("Magic Knife", "Silent Aim enabled! Equip knife and press E to throw at nearest player.", 4, "success")
        else
            lockedTarget = nil
            lockedAt = 0
            Lib:Notify("Magic Knife", "Silent Aim disabled.", 3, "warning")
        end
    end)

    knifeSection:Toggle("Show FOV Circle", true, function(enabled)
        state.showFov = enabled
    end)

    knifeSection:Slider("FOV Radius", 150, 10, 10, 300, "", function(value)
        state.fovRadius = value
    end)

    knifeSection:Colorpicker("FOV Circle Color", Color3.fromRGB(255, 255, 255), function(color)
        fovCircle.Color = color
    end)
end)

--================================================================--
--                      MODULE: AUTO FARM                         --
--================================================================--

defineModule("farm", function(Ctx)
    local Lib = Ctx.Lib
    local Workspace = Services.Workspace
    local RunService = Services.RunService or game:GetService("RunService")

    local SAFE_OFFSET = 5
    local MAX_STEP = 6           
    local BELOW_MAP_Y = -500
    local SAFE_Y_MARGIN = 25
    local TRAVEL_TIMEOUT = 10
    local TOUCH_ATTEMPTS = 4
    local HOLD_FRAMES = 10
    local PICKUP_WOBBLE = 0.8
    local COIN_COOLDOWN = 5      
    local MURDERER_CAMP_SPOT = CFrame.new(-1.79, -64.45, -85.25)

    local PRONE_ROT = CFrame.Angles(math.rad(-90), 0, 0)
    local PRONE_UP = PRONE_ROT.UpVector

    local fireTouch = (typeof(firetouchinterest) == "function" and firetouchinterest)
        or (typeof(fireTouchInterest) == "function" and fireTouchInterest)
        or nil

    local config = {
        enabled = false,
        killAfterFarm = false,
        layFlat = true,
        removeBarriers = true,
        maxCoins = 40,
        speed = 25,
    }

    local farmRunning = false
    local bagHandled = false
    local coinLabel = nil
    local originalCollisions = {}
    local noclipParts = {}
    local lastNoclipRefresh = 0
    local coinCooldown = {}

    local function isValid(object)
        return object and object.Parent ~= nil
    end

    ----------------------------------------------------------------
    -- NOCLIP
    ----------------------------------------------------------------

    local function refreshNoclipParts()
        table.clear(noclipParts)
        local character = LocalPlayer.Character
        if not (character and character.Parent) then
            return
        end

        for _, part in ipairs(character:GetDescendants()) do
            if part:IsA("BasePart") then
                noclipParts[#noclipParts + 1] = part
                if originalCollisions[part] == nil then
                    originalCollisions[part] = part.CanCollide
                end
            end
        end
        lastNoclipRefresh = os.clock()
    end

    local function setNoclip()
        if os.clock() - lastNoclipRefresh > 1 then
            refreshNoclipParts()
        end
        for i = #noclipParts, 1, -1 do
            local part = noclipParts[i]
            if not isValid(part) then
                table.remove(noclipParts, i)
            elseif part.CanCollide then
                part.CanCollide = false
            end
        end
    end

    local function restoreCollisions()
        for part, original in pairs(originalCollisions) do
            if isValid(part) and original then
                pcall(function() part.CanCollide = true end)
            end
        end
        table.clear(originalCollisions)
        table.clear(noclipParts)
    end

    ----------------------------------------------------------------
    -- BARRIERS
    ----------------------------------------------------------------

    local BARRIER_NAMES = {
        Invis = true,
        InvisWall = true,
        InvisWalls = true,
        Barrier = true,
        Barriers = true,
    }

    local barrierWatcher = nil

    local function isBarrier(object)
        if not BARRIER_NAMES[object.Name] then
            return false
        end

        return object:IsA("BasePart") or object:IsA("Folder")
            or (object:IsA("Model") and not object:FindFirstChildOfClass("Humanoid"))
    end

    local function removeBarrier(object)
        if not isValid(object) then
            return false
        end
        return (pcall(object.Destroy, object))
    end

    local function sweepBarriers()
        local removed = 0
        for _, object in ipairs(Workspace:GetDescendants()) do

            if object:IsDescendantOf(Workspace) and isBarrier(object) and removeBarrier(object) then
                removed = removed + 1
            end
        end
        return removed
    end

    local function startBarrierWatcher()
        if barrierWatcher then
            return
        end

        barrierWatcher = Workspace.DescendantAdded:Connect(function(object)
            if config.enabled and config.removeBarriers and isBarrier(object) then
                removeBarrier(object)
            end
        end)
    end

    local function stopBarrierWatcher()
        if barrierWatcher then
            barrierWatcher:Disconnect()
            barrierWatcher = nil
        end
    end

    ----------------------------------------------------------------
    -- PRONE
    ----------------------------------------------------------------

    local function getHumanoid()
        local character = LocalPlayer.Character
        return character and character:FindFirstChildOfClass("Humanoid") or nil
    end

    local function setProne(active)
        local humanoid = getHumanoid()
        if not humanoid then
            return
        end
        pcall(function()
            humanoid.PlatformStand = active
            humanoid.AutoRotate = not active
        end)
    end

    local function facing(root)
        if config.layFlat then
            return PRONE_ROT
        end
        return root.CFrame - root.CFrame.Position
    end

    local function placeAt(root, position)
        root.CFrame = CFrame.new(position) * facing(root)
    end

    local function holdProne(root)
        if not config.layFlat then
            return
        end
        local humanoid = getHumanoid()
        if humanoid and not humanoid.PlatformStand then
            setProne(true)
        end
        if root.CFrame.UpVector:Dot(PRONE_UP) < 0.999 then
            placeAt(root, root.Position)
        end
    end

    ----------------------------------------------------------------
    -- STATE
    ----------------------------------------------------------------

    local function canFarm()
        if not Util.isAlive() then
            return false
        end
        return LocalPlayer:GetAttribute("Alive") ~= false
    end

    local function safeY(y)
        local floor = BELOW_MAP_Y
        local ok, height = pcall(function() return Workspace.FallenPartsDestroyHeight end)
        if ok and type(height) == "number" then
            floor = height + SAFE_Y_MARGIN
        end
        return math.max(y, floor)
    end

    local function getPos(object)
        if not isValid(object) then
            return nil
        end
        if object:IsA("BasePart") then
            return object.Position
        elseif object:IsA("Model") then
            local ok, pivot = pcall(object.GetPivot, object)
            if ok then return pivot.Position end
        end
        return nil
    end

    local function zeroVelocity(root)
        local ok = pcall(function()
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
        end)
        if not ok then
            pcall(function() root.Velocity = Vector3.zero end)
        end
    end

    local function getCarriedCoins()
        if not isValid(coinLabel) then
            local node = LocalPlayer:FindFirstChild("PlayerGui")
            local path = { "MainGUI", "Game", "CoinBags", "Container", "Coin", "CurrencyFrame", "Icon", "Coins" }
            for _, name in ipairs(path) do
                node = node and node:FindFirstChild(name)
            end
            coinLabel = node
        end
        if not isValid(coinLabel) then
            return 0
        end
        return tonumber((tostring(coinLabel.Text):gsub("%D", ""))) or 0
    end

    local function roundOver()
        local timerPart = Workspace:FindFirstChild("RoundTimerPart")
        if not isValid(timerPart) then
            return false
        end
        local remaining = timerPart:GetAttribute("Time")
        return type(remaining) == "number" and remaining <= 0
    end

    local function benchCoin(coin)
        coinCooldown[coin] = os.clock() + COIN_COOLDOWN
    end

    local function isBenched(coin)
        local expiry = coinCooldown[coin]
        if not expiry then
            return false
        end
        if os.clock() >= expiry then
            coinCooldown[coin] = nil
            return false
        end
        return true
    end

    local function nearestCoin(container, position)
        local closest, closestDistance = nil, math.huge

        for _, object in ipairs(container:GetChildren()) do
            if isValid(object) and object.Name == "Coin_Server" and object:FindFirstChild("TouchInterest") then
                if not isBenched(object) then
                    local coinPos = getPos(object)
                    if coinPos then
                        local distance = (coinPos - position).Magnitude
                        if distance < closestDistance then
                            closestDistance, closest = distance, object
                        end
                    end
                end
            end
        end

        return closest
    end

    ----------------------------------------------------------------
    -- MOVEMENT
    ----------------------------------------------------------------

    local function stepTo(root, goal, dt)
        local current = root.Position
        local delta = goal - current
        local distance = delta.Magnitude

        if distance < 0.1 then
            zeroVelocity(root)
            return true
        end

        local step = math.min(math.max(1, config.speed) * dt, MAX_STEP, distance)
        local nextPos = current + (delta.Unit * step)
        nextPos = Vector3.new(nextPos.X, safeY(nextPos.Y), nextPos.Z)

        placeAt(root, nextPos)
        zeroVelocity(root)
        return false
    end

    local function moveTo(root, getGoal, timeout)
        local deadline = os.clock() + timeout

        while true do
            if not config.enabled then return false end
            if not isValid(root) then return false end
            if os.clock() > deadline then return false end
            if not canFarm() then return false end

            local goal = getGoal()
            if not goal then return false end

            local dt = RunService.Heartbeat:Wait()
            if stepTo(root, goal, dt) then return true end
        end
    end

    local function overlapCoin(root, coin)
        for i = 1, HOLD_FRAMES do
            if not config.enabled then return end
            if not isValid(root) or not isValid(coin) then return end

            local coinPos = getPos(coin)
            if not coinPos then return end

            local wobble = (i % 2 == 0) and PICKUP_WOBBLE or -PICKUP_WOBBLE
            local goal = Vector3.new(coinPos.X, safeY(coinPos.Y + wobble), coinPos.Z)
            placeAt(root, goal)
            zeroVelocity(root)
            RunService.Heartbeat:Wait()
        end
    end

    local function collectCoin(root, coin)

        moveTo(root, function()
            local coinPos = getPos(coin)
            return coinPos and Vector3.new(coinPos.X, safeY(coinPos.Y - SAFE_OFFSET), coinPos.Z) or nil
        end, TRAVEL_TIMEOUT)

        if not isValid(coin) then return true end

        -- preferred: collect from below without surfacing
        if fireTouch and coin:IsA("BasePart") then
            for _ = 1, TOUCH_ATTEMPTS do
                if not isValid(coin) then return true end
                pcall(fireTouch, root, coin, 0)
                RunService.Heartbeat:Wait()
                pcall(fireTouch, root, coin, 1)
                RunService.Heartbeat:Wait()
            end
            if not isValid(coin) then return true end
        end

        if not config.enabled then return false end
        moveTo(root, function()
            local coinPos = getPos(coin)
            return coinPos and Vector3.new(coinPos.X, safeY(coinPos.Y), coinPos.Z) or nil
        end, TRAVEL_TIMEOUT)

        overlapCoin(root, coin)
        return not isValid(coin)
    end

    local function afterBagFull()
        local root = Util.getHRP()
        if not root then
            return
        end

        if Util.getPlayerRole(LocalPlayer) == "Murderer" then
            if not config.killAfterFarm then
                return
            end

            moveTo(root, function() return MURDERER_CAMP_SPOT.Position end, TRAVEL_TIMEOUT)
            task.wait(0.2)

            if Ctx.Combat then
                task.spawn(Ctx.Combat.runAutoKill, true)
            end
            return
        end

        moveTo(root, function()
            return Vector3.new(root.Position.X, safeY(BELOW_MAP_Y), root.Position.Z)
        end, TRAVEL_TIMEOUT)
    end

    ----------------------------------------------------------------
    -- LOOP
    ----------------------------------------------------------------

    local function runFarm()
        if farmRunning then
            return
        end
        farmRunning = true
        bagHandled = false
        table.clear(coinCooldown)

        if not fireTouch then
            Lib:Notify("Auto Farm", "No firetouchinterest - surfacing to grab coins.", 4, "warning")
        end

        if config.removeBarriers then
            startBarrierWatcher()
            local removed = sweepBarriers()
            if removed > 0 then
                Lib:Notify("Auto Farm", "Removed " .. removed .. " barriers.", 3, "success")
            end
        end

        setProne(config.layFlat)

        local keepAlive = Scheduler.onHeartbeat("farm.keepAlive", function()
            local root = Util.getHRP()
            if root then
                zeroVelocity(root)
                holdProne(root)
            end
            setNoclip()
        end)

        while config.enabled do
            task.wait(0.1)

            if roundOver() then
                coinLabel = nil
                bagHandled = false
                table.clear(coinCooldown)
                task.wait(0.5)
            elseif not canFarm() then
                task.wait(0.5)
            else
                local carried = getCarriedCoins()
                if carried < config.maxCoins then
                    bagHandled = false
                end

                if carried >= config.maxCoins then

                    if not bagHandled then
                        bagHandled = true
                        local ok, err = pcall(afterBagFull)
                        if not ok then
                            warn("[farm] afterBagFull: " .. tostring(err))
                        end
                    end
                    task.wait(1)
                else
                    local container = Util.findCoinContainer()
                    local root = Util.getHRP()

                    if not container or not root then
                        task.wait(0.5)
                    else
                        setNoclip()

                        local coin = nearestCoin(container, root.Position)
                        if coin then
                            -- pcall so an error mid-run can't wedge the loop
                            local ok, collected = pcall(collectCoin, root, coin)
                            if not ok then
                                warn("[farm] collect: " .. tostring(collected))
                                benchCoin(coin)
                            elseif not collected then
                                benchCoin(coin)
                            end
                        end
                    end
                end
            end
        end

        keepAlive.stop()
        stopBarrierWatcher()
        setProne(false)
        farmRunning = false
    end

    ----------------------------------------------------------------
    -- UI
    ----------------------------------------------------------------

    local farmSection = Ctx.tabs.farm:Section("Coin Farm", "Left")

    farmSection:Toggle("Enable Auto Farm", false, function(enabled)
        config.enabled = enabled
        if enabled then
            task.spawn(runFarm)
            Lib:Notify("Auto Farm", "Started farming!", 3, "success")
        else
            restoreCollisions()
            stopBarrierWatcher()
            setProne(false)
            Lib:Notify("Auto Farm", "Stopped farming.", 3, "warning")
        end
    end)

    farmSection:Toggle("Lay Flat (Under Map Look)", true, function(enabled)
        config.layFlat = enabled
        if config.enabled then
            setProne(enabled)
        elseif not enabled then
            setProne(false)
        end
    end)

    farmSection:Toggle("Remove Map Barriers", true, function(enabled)
        config.removeBarriers = enabled
        if not enabled then
            stopBarrierWatcher()
        elseif config.enabled then
            startBarrierWatcher()
            sweepBarriers()
        end
    end)

    farmSection:Toggle("Kill All if Murderer (After Farm)", false, function(enabled)
        config.killAfterFarm = enabled
    end)

    farmSection:Slider("Max Coins Limit", 40, 1, 10, 50, "", function(value)
        config.maxCoins = value
    end)

    farmSection:Slider("Movement Speed", 25, 1, 1, 30, "", function(value)
        config.speed = value
    end)
end)

--================================================================--
--                     MODULE: SETTINGS TAB                       --
--================================================================--

defineModule("settings", function(Ctx)
    Ctx.window:AddSettingsTab("cog")
end)

--================================================================--
--                           LOADER                               --
--================================================================--

do
    local Ctx = {
        Services = Services,
        LocalPlayer = LocalPlayer,
        Session = Session,
        Scheduler = Scheduler,
        Util = Util,
    }

    for _, name in ipairs(moduleOrder) do
        local ok, err = pcall(Modules[name], Ctx)
        if not ok then
            warn(("[LeatherHub] module '%s' failed to load: %s"):format(name, tostring(err)))

            if name == "ui" then
                return
            end
        end
    end

    Ctx.Lib:Notify("Success!", "Trade Checker and ESP loaded!", 5, "success")
end
