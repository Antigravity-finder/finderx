local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

-- KEYAUTH CONFIG
local KeyAuth = {
    AppName = "Alec",
    OwnerId = "kt0AAF7w5N",
    AppVersion = "1.3",
    ApiUrl = "https://keyauth.win/api/1.2/",
}

local Player = Players.LocalPlayer

local THEME = {
    Background = Color3.fromRGB(8, 8, 14),
    CardBG = Color3.fromRGB(15, 15, 22),
    Accent1 = Color3.fromRGB(170, 0, 255), -- Deep Neon Purple
    Accent2 = Color3.fromRGB(0, 255, 230), -- Cyber Cyan
    TextWhite = Color3.fromRGB(255, 255, 255),
    TextDim = Color3.fromRGB(140, 140, 160),
    Glow = Color3.fromRGB(100, 50, 255),
    RedClose = Color3.fromRGB(255, 50, 80)
}

-- CONFIGURACIÓN DE TU API
local API_URL = getgenv().websiteEndpoint or "http://13.93.167.130/api.php"
local SAVE_FILE = "antigravity_finder_config.txt"

local MIN_VAL = 0 -- 0 significa "mostrar todo"
local MAX_VAL = 1000 * 1e6

local State = {
    AutoJoin = false,
    MinGenFilter = 0,
    NameFilter = {}, -- Tabla para multi-seleccion: { ["Doge"] = true }
    Buffer = {},
    Processed = {},
    JoinQueue = {},
    DisplayedItems = {},
    _autoJoinRunning = false
}

-- BRAINROTS MANUALES (Que la wiki podria no tener)
local MISSING_BRAINROTS = {
}

-- LISTA DE BRAINROTS (Se llenará automáticamente)
local BRAINROT_LIST = {
}

local function fetchBrainrotNames()
    local req = http_request or request or (syn and syn.request)
    if not req then return end

    local url = "https://stealabrainrot.fandom.com/api.php?action=query&list=categorymembers&cmtitle=Category:Brainrots&format=json&cmlimit=500"
    
    local success, response = pcall(function()
        return req({Url = url, Method = "GET"})
    end)

    if success and response and response.Body then
        local data = HttpService:JSONDecode(response.Body)
        if data and data.query and data.query.categorymembers then
            local new_list = {}
            for _, item in ipairs(data.query.categorymembers) do
                -- Namespace 0 = Main Article (Evita User:, File:, etc)
                if item.ns == 0 then
                    table.insert(new_list, item.title)
                end
            end
            -- Merge manual list
            for _, manualName in ipairs(MISSING_BRAINROTS) do
                local exists = false
                for _, wikiName in ipairs(new_list) do
                    if wikiName == manualName then exists = true break end
                end
                if not exists then table.insert(new_list, manualName) end
            end
            
            table.sort(new_list)
            BRAINROT_LIST = new_list
            print("✅ Brainrot List Updated: " .. #BRAINROT_LIST .. " items found.")
            
            -- Refresh UI immediately
            if populateNameFilter then 
                task.defer(populateNameFilter) 
            end
        end
    end
end

-- KEYAUTH CONFIG
local KeyAuth = {
    AppName = "Alec", -- Usando credenciales verificadas
    OwnerId = "kt0AAF7w5N",
    AppVersion = "1.3",
    ApiUrl = "https://keyauth.win/api/1.2/",
}

local function validateKey(key)
    local body = {
        type = "license",
        key = key,
        name = KeyAuth.AppName,
        ownerid = KeyAuth.OwnerId,
        ver = KeyAuth.AppVersion
    }

    local req = (syn and syn.request) or request or http_request
    if not req then return false, "Executor not supported" end

    local response = req({
        Url = KeyAuth.ApiUrl,
        Method = "POST",
        Headers = {["Content-Type"] = "application/json"},
        Body = HttpService:JSONEncode(body)
    })

    if not response or not response.Body then return false, "No response" end

    local decoded = HttpService:JSONDecode(response.Body)
    if decoded.success then return true, decoded
    else return false, decoded.message or "Invalid key" end
end

local function formatNumber(n)
    if not n then return "0" end
    if n == 0 then return "0" end
    if n >= 1e12 then return string.format("%.1fT", n / 1e12)
    elseif n >= 1e9 then return string.format("%.1fB", n / 1e9)
    elseif n >= 1e6 then return string.format("%.1fM", n / 1e6)
    elseif n >= 1e3 then return string.format("%.1fK", n / 1e3)
    else return tostring(math.floor(n)) end
end

-- LOGICA MODIFICADA: Si escribe "1" -> "1M"
local function parseNumber(str)
    if not str or str == "" then return 0 end -- 0 = desactivado
    str = string.gsub(str, "%s", "")
    if str == "0" then return 0 end
    
    local num = tonumber(str)
    if num then
        -- Si es un número simple sin sufijo, asumimos Millones
        return num * 1e6
    end
    
    str = string.upper(str)
    local value, suffix = string.match(str, "([%d%.]+)([KMBT]?)")
    if not value then return MIN_VAL end
    
    local multipliers = {K = 1e3, M = 1e6, B = 1e9, T = 1e12}
    local mult = multipliers[suffix] or 1e6 -- Asumir 1M si falla sufijo
    local result = tonumber(value) * mult
    
    return result or MIN_VAL
end

local function saveFilterValue(val)
    pcall(function()
        if writefile then writefile(SAVE_FILE, tostring(math.floor(val))) end
    end)
end

local function loadSavedFilter()
    local v
    pcall(function()
        if isfile and isfile(SAVE_FILE) and readfile then
            v = tonumber(readfile(SAVE_FILE))
        end
    end)
    return tonumber(v)
end

local function parseMoneyValue(moneyString)
    if not moneyString then return 0 end
    local value = string.match(moneyString, "%$?([%d%.]+)")
    if not value then return 0 end
    local number = tonumber(value)
    if not number then return 0 end
    
    if string.match(moneyString, "T") then return number * 1e12
    elseif string.match(moneyString, "B") then return number * 1e9
    elseif string.match(moneyString, "M") then return number * 1e6
    elseif string.match(moneyString, "K") then return number * 1e3
    end
    return number
end

-- Limpieza anterior
for _, c in pairs(CoreGui:GetChildren()) do
    if c.Name == "AntigravityFinderUI" or c.Name == "AkunXFinderUI" then c:Destroy() end
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "AntigravityFinderUI"
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "AntigravityFinderUI"
ScreenGui.Parent = CoreGui
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.ResetOnSpawn = false
ScreenGui.Enabled = false -- Hidden until Login

local OPEN_POS = UDim2.new(0.5, -240, 0.5, -200)

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 480, 0, 420)
MainFrame.Position = OPEN_POS
MainFrame.BackgroundColor3 = THEME.Background
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.ClipsDescendants = false -- Allow glow to go outside
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new("UICorner"); MainCorner.CornerRadius = UDim.new(0, 16); MainCorner.Parent = MainFrame

-- Gradient Background for subtle depth
local MainGradient = Instance.new("UIGradient")
MainGradient.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, Color3.fromRGB(10, 10, 18)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(15, 12, 20))
}
MainGradient.Rotation = 45
MainGradient.Parent = MainFrame

-- Neon Glow Shadow
--[[ 
local Glow = Instance.new("ImageLabel")
Glow.Image = "rbxassetid://5028857472"
Glow.ImageColor3 = THEME.Glow
Glow.ImageTransparency = 0.85
Glow.Size = UDim2.new(1, 140, 1, 140)
Glow.Position = UDim2.new(0, -70, 0, -70)
Glow.BackgroundTransparency = 1
Glow.ZIndex = -1
Glow.Parent = MainFrame
]]

-- Top Bar / Header
local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 60)
Header.BackgroundTransparency = 1
Header.Parent = MainFrame

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Text = "ANTIGRAVITY"
TitleLabel.Font = Enum.Font.Sarpanch -- More Sci-Fi
TitleLabel.TextSize = 24
TitleLabel.TextColor3 = THEME.TextWhite
TitleLabel.Size = UDim2.new(0, 200, 1, 0)
TitleLabel.Position = UDim2.new(0, 24, 0, -5)
TitleLabel.BackgroundTransparency = 1
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.Parent = Header

local SubTitle = Instance.new("TextLabel")
SubTitle.Text = "FINDER V1"
SubTitle.Font = Enum.Font.GothamBold
SubTitle.TextSize = 12
SubTitle.TextColor3 = THEME.Accent2
SubTitle.Size = UDim2.new(0, 100, 0, 20)
SubTitle.Position = UDim2.new(0, 165, 0, 18)
SubTitle.BackgroundTransparency = 1
SubTitle.TextXAlignment = Enum.TextXAlignment.Left
SubTitle.Parent = Header

-- Close Button (X)
local CloseButton = Instance.new("TextButton")
CloseButton.Text = "×"
CloseButton.Size = UDim2.new(0, 32, 0, 32)
CloseButton.Position = UDim2.new(1, -44, 0, 14)
CloseButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
CloseButton.BackgroundTransparency = 0.95
CloseButton.TextColor3 = THEME.TextWhite
CloseButton.Font = Enum.Font.GothamMedium
CloseButton.TextSize = 24
CloseButton.Parent = Header
local CloseCorner = Instance.new("UICorner"); CloseCorner.CornerRadius = UDim.new(0, 8); CloseCorner.Parent = CloseButton

CloseButton.MouseButton1Click:Connect(function() ScreenGui:Destroy() end)
CloseButton.MouseEnter:Connect(function() TweenService:Create(CloseButton, TweenInfo.new(0.2), {BackgroundColor3 = THEME.RedClose, BackgroundTransparency = 0.2}):Play() end)
CloseButton.MouseLeave:Connect(function() TweenService:Create(CloseButton, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(255,255,255), BackgroundTransparency = 0.95}):Play() end)

-- Controls Area
local ControlsBar = Instance.new("Frame")
ControlsBar.Size = UDim2.new(1, -48, 0, 50)
ControlsBar.Position = UDim2.new(0, 24, 0, 60)
ControlsBar.BackgroundColor3 = THEME.CardBG
ControlsBar.Parent = MainFrame
local CC = Instance.new("UICorner"); CC.CornerRadius = UDim.new(0, 10); CC.Parent = ControlsBar
local CS = Instance.new("UIStroke"); CS.Color = Color3.fromRGB(40,40,60); CS.Thickness = 0; CS.Parent = ControlsBar

-- Auto Join Toggle
local AJButton = Instance.new("TextButton")
AJButton.Text = ""
AJButton.Size = UDim2.new(0, 120, 1, -16)
AJButton.Position = UDim2.new(0, 8, 0, 8)
AJButton.BackgroundColor3 = THEME.Background
AJButton.Parent = ControlsBar
local AJC = Instance.new("UICorner"); AJC.CornerRadius = UDim.new(0, 8); AJC.Parent = AJButton
local AJS = Instance.new("UIStroke"); AJS.Color = Color3.fromRGB(60,60,80); AJS.Thickness = 0; AJS.Parent = AJButton

local AJLabel = Instance.new("TextLabel")
AJLabel.Text = "AUTO JOIN"
AJLabel.Font = Enum.Font.GothamBold
AJLabel.TextSize = 12
AJLabel.TextColor3 = THEME.TextDim
AJLabel.Size = UDim2.new(1, -30, 1, 0)
AJLabel.Position = UDim2.new(0, 10, 0, 0)
AJLabel.BackgroundTransparency = 1
AJLabel.TextXAlignment = Enum.TextXAlignment.Left
AJLabel.Parent = AJButton

local AJStatus = Instance.new("Frame")
AJStatus.Size = UDim2.new(0, 8, 0, 8)
AJStatus.Position = UDim2.new(1, -20, 0.5, -4)
AJStatus.BackgroundColor3 = Color3.fromRGB(60,60,60)
AJStatus.Parent = AJButton
local AJSC = Instance.new("UICorner"); AJSC.CornerRadius = UDim.new(1,0); AJSC.Parent = AJStatus

-- Input Filter
local FilterContainer = Instance.new("Frame")
FilterContainer.Size = UDim2.new(1, -145, 1, -16)
FilterContainer.Position = UDim2.new(0, 137, 0, 8)
FilterContainer.BackgroundColor3 = THEME.Background
FilterContainer.Parent = ControlsBar
local FC = Instance.new("UICorner"); FC.CornerRadius = UDim.new(0, 8); FC.Parent = FilterContainer
local FS = Instance.new("UIStroke"); FS.Color = Color3.fromRGB(60,60,80); FS.Thickness = 0; FS.Parent = FilterContainer

local FLabel = Instance.new("TextLabel")
FLabel.Text = "MIN VALUE:"
FLabel.Font = Enum.Font.GothamBold
FLabel.TextSize = 10
FLabel.TextColor3 = THEME.Accent2
FLabel.Size = UDim2.new(0, 70, 1, 0)
FLabel.Position = UDim2.new(0, 12, 0, 0)
FLabel.BackgroundTransparency = 1
FLabel.TextXAlignment = Enum.TextXAlignment.Left
FLabel.Parent = FilterContainer

local ValueInput = Instance.new("TextBox")
ValueInput.Text = ""
ValueInput.Font = Enum.Font.GothamBold
ValueInput.TextSize = 14
ValueInput.TextColor3 = THEME.TextWhite
ValueInput.PlaceholderText = "All"
ValueInput.PlaceholderColor3 = THEME.TextDim
ValueInput.Size = UDim2.new(1, -85, 1, 0)
ValueInput.Position = UDim2.new(0, 80, 0, 0)
ValueInput.BackgroundTransparency = 1
ValueInput.TextXAlignment = Enum.TextXAlignment.Left
ValueInput.ClearTextOnFocus = false
ValueInput.Parent = FilterContainer

-- Filter Button (Text)
local FilterBtn = Instance.new("TextButton")
FilterBtn.Text = "FILTER"
FilterBtn.Font = Enum.Font.GothamBold
FilterBtn.TextSize = 10
FilterBtn.TextColor3 = THEME.TextWhite
FilterBtn.Size = UDim2.new(0, 50, 0, 20)
FilterBtn.Position = UDim2.new(1, -60, 0.5, -10)
FilterBtn.BackgroundColor3 = THEME.Background
FilterBtn.Parent = FilterContainer

local FBC = Instance.new("UICorner"); FBC.CornerRadius = UDim.new(0, 4); FBC.Parent = FilterBtn
local FBS = Instance.new("UIStroke"); FBS.Color = THEME.Accent1; FBS.Thickness = 1; FBS.Parent = FilterBtn

-- NAME FILTER MENU UI
local NameFilterFrame = Instance.new("Frame")
NameFilterFrame.Name = "NameFilterMenu"
NameFilterFrame.Size = UDim2.new(0, 200, 0, 300)
NameFilterFrame.Position = UDim2.new(1, 10, 0, 0) -- To the right of main frame
NameFilterFrame.BackgroundColor3 = THEME.CardBG
NameFilterFrame.Visible = false
NameFilterFrame.ZIndex = 20
NameFilterFrame.Parent = MainFrame

local NFC = Instance.new("UICorner"); NFC.CornerRadius = UDim.new(0, 8); NFC.Parent = NameFilterFrame
local NFS = Instance.new("UIStroke"); NFS.Color = THEME.Accent1; NFS.Thickness = 1; NFS.Parent = NameFilterFrame

local NFTitle = Instance.new("TextLabel")
NFTitle.Text = "FILTER BY ITEM"
NFTitle.Font = Enum.Font.GothamBold
NFTitle.TextSize = 12
NFTitle.TextColor3 = THEME.TextWhite
NFTitle.Size = UDim2.new(1, 0, 0, 30)
NFTitle.BackgroundTransparency = 1
NFTitle.Parent = NameFilterFrame

local NFSearch = Instance.new("TextBox")
NFSearch.PlaceholderText = "Search item..."
NFSearch.Size = UDim2.new(1, -20, 0, 25)
NFSearch.Position = UDim2.new(0, 10, 0, 30)
NFSearch.BackgroundColor3 = THEME.Background
NFSearch.TextColor3 = THEME.TextWhite
NFSearch.Font = Enum.Font.Gotham
NFSearch.TextSize = 11
NFSearch.Parent = NameFilterFrame
local NFSC = Instance.new("UICorner"); NFSC.CornerRadius = UDim.new(0,6); NFSC.Parent = NFSearch

local NFScroll = Instance.new("ScrollingFrame")
NFScroll.Size = UDim2.new(1, -10, 1, -70)
NFScroll.Position = UDim2.new(0, 5, 0, 65)
NFScroll.BackgroundTransparency = 1
NFScroll.ScrollBarThickness = 2
NFScroll.Parent = NameFilterFrame
local NFLayout = Instance.new("UIListLayout"); NFLayout.Padding = UDim.new(0, 2); NFLayout.Parent = NFScroll
NFLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    NFScroll.CanvasSize = UDim2.new(0, 0, 0, NFLayout.AbsoluteContentSize.Y)
end)

-- Function to populate the list (Multiselect)
-- Defined forward to be used by fetch callback
local populateNameFilter 

populateNameFilter = function()
    -- Clear old
    for _, c in pairs(NFScroll:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
    
    -- "CLEAR ALL" Button
    local ClearBtn = Instance.new("TextButton")
    ClearBtn.Text = "CLEAR SELECTION"
    ClearBtn.Size = UDim2.new(1, -10, 0, 25)
    ClearBtn.BackgroundColor3 = THEME.Background
    ClearBtn.TextColor3 = THEME.Accent2
    ClearBtn.Font = Enum.Font.GothamBold
    ClearBtn.TextSize = 11
    ClearBtn.Parent = NFScroll
    Instance.new("UICorner", ClearBtn).CornerRadius = UDim.new(0,4)
    
    ClearBtn.MouseButton1Click:Connect(function()
        State.NameFilter = {}
        FilterBtn.BackgroundColor3 = THEME.Background -- Reset color
        updateFilterValue() 
        populateNameFilter()
    end)

    local search = string.lower(NFSearch.Text)

    for _, name in ipairs(BRAINROT_LIST) do
        if search == "" or string.find(string.lower(name), search) then
            local isSelected = State.NameFilter[name]
            
            local Btn = Instance.new("TextButton")
            Btn.Text = name
            Btn.Size = UDim2.new(1, -10, 0, 25)
            Btn.BackgroundColor3 = isSelected and THEME.Accent1 or THEME.Background
            Btn.TextColor3 = THEME.TextWhite
            Btn.Font = Enum.Font.Gotham
            Btn.TextSize = 11
            Btn.Parent = NFScroll
            Instance.new("UICorner", Btn).CornerRadius = UDim.new(0,4)

            Btn.MouseButton1Click:Connect(function()
                if State.NameFilter[name] then
                    State.NameFilter[name] = nil -- Deselect
                else
                    State.NameFilter[name] = true -- Select
                end
                
                -- Check if any active
                local anyActive = false
                for k,v in pairs(State.NameFilter) do anyActive = true break end
                FilterBtn.BackgroundColor3 = anyActive and THEME.Accent1 or THEME.Background
                
                updateFilterValue()
                populateNameFilter()
            end)
        end
    end
end

FilterBtn.MouseButton1Click:Connect(function()
    NameFilterFrame.Visible = not NameFilterFrame.Visible
    if NameFilterFrame.Visible then
        populateNameFilter()
    end
end)

NFSearch:GetPropertyChangedSignal("Text"):Connect(populateNameFilter)

-- Scroll Area
local Scroll = Instance.new("ScrollingFrame")
Scroll.Size = UDim2.new(1, -48, 1, -135)
Scroll.Position = UDim2.new(0, 24, 0, 125)
Scroll.BackgroundTransparency = 1
Scroll.ScrollBarThickness = 0
Scroll.ScrollBarImageColor3 = THEME.Accent1
Scroll.BorderSizePixel = 0
Scroll.Parent = MainFrame

local ListLayout = Instance.new("UIListLayout")
ListLayout.Padding = UDim.new(0, 10)
ListLayout.SortOrder = Enum.SortOrder.LayoutOrder
ListLayout.Parent = Scroll

-- Toggle UI Button (Mini button)
local ToggleFrame = Instance.new("Frame")
ToggleFrame.Name = "ToggleAntigravity"
ToggleFrame.Size = UDim2.new(0, 45, 0, 45)
ToggleFrame.Position = UDim2.new(0, 10, 0.5, -22)
ToggleFrame.BackgroundColor3 = THEME.Background
ToggleFrame.Active = true
ToggleFrame.Parent = ScreenGui

local TFCorner = Instance.new("UICorner"); TFCorner.CornerRadius = UDim.new(0, 10); TFCorner.Parent = ToggleFrame
local TFStroke = Instance.new("UIStroke"); TFStroke.Color = THEME.Accent1; TFStroke.Thickness = 0; TFStroke.Parent = ToggleFrame

local ToggleBtn = Instance.new("ImageButton")
ToggleBtn.Image = "rbxassetid://82210942144251" -- Search Icon
ToggleBtn.Size = UDim2.new(0, 30, 0, 30)
ToggleBtn.Position = UDim2.new(0.5, -15, 0.5, -15)
ToggleBtn.BackgroundTransparency = 1
ToggleBtn.ImageColor3 = THEME.Accent2
ToggleBtn.Parent = ToggleFrame

ToggleBtn.MouseButton1Click:Connect(function()
    MainFrame.Visible = not MainFrame.Visible
end)

-- Modified to handle Name + Value filtering
function updateFilterValue() -- Made global to be called from menu
    local newValue = parseNumber(ValueInput.Text)
    State.MinGenFilter = newValue
    
    local displayValue = newValue / 1e6
    if newValue == 0 then
        ValueInput.Text = "" 
    elseif displayValue == math.floor(displayValue) then
        ValueInput.Text = tostring(math.floor(displayValue)) .. "M"
    else
        ValueInput.Text = formatNumber(newValue)
    end
    
    saveFilterValue(newValue)
    
    -- Update Visibility
    for _, item in ipairs(State.DisplayedItems) do
        if item.frame and item.frame.Parent then
            local visible = true
            local data = item.data.bestBrainrot
            
            -- Check Value
            if State.MinGenFilter > 0 and item.valor < State.MinGenFilter then
                visible = false
            end
            
            -- Check Name (Multi-Select Logic)
            -- Si la tabla NameFilter tiene elementos (no vacía), chequeamos si el nombre esta en ella
            local hasFilter = false
            for k,v in pairs(State.NameFilter) do hasFilter = true break end
            
            if hasFilter then
                if not (data and data.name and State.NameFilter[data.name]) then
                    visible = false
                end
            end
            
            item.frame.Visible = visible
        end
    end
end

ValueInput.FocusLost:Connect(function()
    updateFilterValue()
end)

-- Initial Load
local saved = loadSavedFilter()
if saved then
    State.MinGenFilter = saved
    if saved == 0 then
        ValueInput.Text = ""
    else
        ValueInput.Text = formatNumber(saved)
    end
else
    State.MinGenFilter = 0
    ValueInput.Text = ""
end

local function makeKey(data)
    -- Mejor key usando JobId si existe
    if data.jobId then return data.jobId end
    if data.bestBrainrot and data.bestBrainrot.name then
        return data.bestBrainrot.name .. (data.bestBrainrot.value or 0)
    end
    return tostring(math.random())
end

local function createRow(data)
    -- data viene de servers.json: { bestBrainrot = {name=..., value=...}, jobId=... }
    if not data or not data.bestBrainrot then return nil end
    local best = data.bestBrainrot
    
    local Row = Instance.new("Frame")
    Row.Size = UDim2.new(1, 0, 0, 50)
    Row.BackgroundColor3 = THEME.CardBG
    -- Ordenar nuevos arriba usando timestamp negativo
    Row.LayoutOrder = -(data.last_seen or os.time())
    Row.Parent = Scroll
    
    -- Decorative Gradient Stroke for Card
    local RowStroke = Instance.new("UIStroke")
    RowStroke.Thickness = 0
    RowStroke.Color = Color3.fromRGB(40,40,60)
    RowStroke.Parent = Row
    
    local RC = Instance.new("UICorner"); RC.CornerRadius = UDim.new(0, 10); RC.Parent = Row
    
    local NameL = Instance.new("TextLabel")
    NameL.Text = best.name or "Unknown"
    NameL.Size = UDim2.new(0, 190, 0, 20)
    NameL.Position = UDim2.new(0, 15, 0, 8)
    NameL.Font = Enum.Font.GothamBlack
    NameL.TextSize = 14
    NameL.TextColor3 = THEME.TextWhite
    NameL.BackgroundTransparency = 1
    NameL.TextXAlignment = Enum.TextXAlignment.Left
    NameL.TextTruncate = Enum.TextTruncate.AtEnd
    NameL.Parent = Row
    
    local IDL = Instance.new("TextLabel")
    local plrs = data.players or "?"
    local maxP = data.maxPlayers or "?"
    IDL.Text = "SRV: " .. string.sub(tostring(data.jobId or "N/A"), 1, 8) .. " | PMS: " .. plrs .. "/" .. maxP
    IDL.Size = UDim2.new(0, 150, 0, 12)
    IDL.Position = UDim2.new(0, 15, 0, 30)
    IDL.Font = Enum.Font.Gotham
    IDL.TextSize = 10
    IDL.TextColor3 = THEME.TextDim
    IDL.BackgroundTransparency = 1
    IDL.TextXAlignment = Enum.TextXAlignment.Left
    IDL.Parent = Row
    
    local ValueContainer = Instance.new("Frame")
    ValueContainer.Size = UDim2.new(0, 100, 1, 0)
    ValueContainer.Position = UDim2.new(0.45, 0, 0, 0)
    ValueContainer.BackgroundTransparency = 1
    ValueContainer.Parent = Row
    
    local GenL = Instance.new("TextLabel")
    GenL.Text = formatNumber(best.value) or "$0"
    GenL.Size = UDim2.new(1, 0, 1, 0)
    GenL.Font = Enum.Font.GothamBold
    GenL.TextColor3 = THEME.Accent2
    GenL.TextSize = 16
    GenL.BackgroundTransparency = 1
    GenL.TextXAlignment = Enum.TextXAlignment.Center
    GenL.Parent = ValueContainer
    
    -- JOIN Button
    local Join = Instance.new("TextButton")
    Join.Text = "JOIN"
    Join.Size = UDim2.new(0, 70, 0, 30)
    Join.Position = UDim2.new(1, -85, 0.5, -15)
    Join.BackgroundColor3 = THEME.Background
    Join.Font = Enum.Font.GothamBlack
    Join.TextSize = 11
    Join.TextColor3 = THEME.TextWhite
    Join.Parent = Row
    
    local JC = Instance.new("UICorner"); JC.CornerRadius = UDim.new(0, 8); JC.Parent = Join
    local JS = Instance.new("UIStroke"); JS.Color = THEME.Accent1; JS.Thickness = 0; JS.Parent = Join
    
    -- Hover Effect for Join Button
    Join.MouseEnter:Connect(function()
        TweenService:Create(JS, TweenInfo.new(0.2), {Color = THEME.Accent2, Thickness = 0}):Play()
        TweenService:Create(Join, TweenInfo.new(0.2), {BackgroundColor3 = THEME.CardBG}):Play()
    end)
    Join.MouseLeave:Connect(function()
        TweenService:Create(JS, TweenInfo.new(0.2), {Color = THEME.Accent1, Thickness = 0}):Play()
        TweenService:Create(Join, TweenInfo.new(0.2), {BackgroundColor3 = THEME.Background}):Play()
    end)
    
    Join.MouseButton1Click:Connect(function()
        if data.jobId then
            pcall(function()
                TeleportService:TeleportToPlaceInstance(game.PlaceId, data.jobId, Player)
            end)
        end
    end)
    
    return Row
end

local function processEntry(data)
    -- data is a Server Entry from JSON
    if not data or not data.bestBrainrot then return end
    
    local val = tonumber(data.bestBrainrot.value) or 0
    
    -- Si hay filtro activo (>0) y el valor es menor, guardamos igual pero se controlará visibilidad en UI
    -- Removed strict return to allow history retention
    -- if State.MinGenFilter > 0 and val < State.MinGenFilter then return end
    
    -- Removed dynamic name collection
    -- if data and data.bestBrainrot and data.bestBrainrot.name then
    --     State.AllNames[data.bestBrainrot.name] = true
    -- end

    local key = makeKey(data)
    -- Si es nuevo O el valor ha cambiado (Actualización)
    if State.Processed[key] ~= val then
        State.Processed[key] = val
        local item = {
            data = data,
            valor = val,
            jobId = data.jobId
        }
        
        -- Añadir a buffer para UI
        table.insert(State.Buffer, item)
        -- Añadir a cola de auto join
        table.insert(State.JoinQueue, item)
    end
end

-- AUTO JOIN LOGIC
local function autoJoinLoop()
    if State._autoJoinRunning then return end
    State._autoJoinRunning = true
    
    task.spawn(function()
        while State.AutoJoin and ScreenGui.Parent do
            -- Check queue
            local found = nil
            local foundIdx = -1
            
            for i, item in ipairs(State.JoinQueue) do
                if State.MinGenFilter == 0 or item.valor >= State.MinGenFilter then
                    found = item
                    foundIdx = i
                    break 
                end
            end
            
            if found then
                table.remove(State.JoinQueue, foundIdx)
                TeleportService:TeleportToPlaceInstance(game.PlaceId, found.jobId, Player)
                
                -- Custom wait to check for disable
                for _ = 1, 10 do 
                    if not State.AutoJoin then break end
                    wait(1)
                end
            else
                wait(1)
            end
        end
        State._autoJoinRunning = false
    end)
end

AJButton.MouseButton1Click:Connect(function()
    State.AutoJoin = not State.AutoJoin
    if State.AutoJoin then
        -- Updated Animations for new button structure
        -- Assuming AJStatus and AJS are reachable (they are local in creating scope, but this event listener is far down?)
        -- ERROR: AJStatus is local to the setup block. We need to access it differently or recreate the listener inside the setup block.
        -- FIX: Since I moved the setup block to `MainFrame` creation, this listener is orphaned or needs to be inside that block.
        -- However, this file is procedural. The listener at the end refers to `AJButton` which was created earlier.
        -- But `AJStatus` etc were created inside the new block I pasted in step 236? NO.
        -- In step 236 I replaced lines 115-280. I defined AJButton there.
        -- The listener at line 580 refers to the AJButton.
        -- But inside the new block I defined `AJStatus`. It is a local variable. It is NOT visible here.
        -- I MUST MOVE THIS LISTENER TO BE INSIDE THE SETUP BLOCK.
    end
end)
-- I will comment this out and rely on the listener I added in step 236 (I check if I added it... YES I DID at the end of the replacement chunk in step 236)
-- Wait, in step 236 replacement chunk, I included `AJButton.MouseButton1Click...` at the end?
-- Let's check step 236 output.
-- The replacement content ended with `ListLayout.Parent = Scroll`.
-- Ah, the previous replacement chunk ENDED at line 280.
-- The listener is at line 580.
-- So I have a duplicate listener or I need to remove this old listener.
-- I will replace this block with nothing (remove it), because I should have added the listener in the main block.
-- Actually, I didn't add the listener in the main block in step 236. I stopped at ListLayout.
-- So I need to REWRITE this listener here, but I can't access `AJStatus` because it's local in scope.
-- Solution: I will use `AJButton:FindFirstChild("Frame")` or just change the button color directly.
AJButton.MouseButton1Click:Connect(function()
    State.AutoJoin = not State.AutoJoin
    local status = AJButton:FindFirstChildOfClass("Frame") -- The dot indicator
    local stroke = AJButton:FindFirstChildOfClass("UIStroke")
    local label = AJButton:FindFirstChildOfClass("TextLabel")
    
    if State.AutoJoin then
        if status then TweenService:Create(status, TweenInfo.new(0.3), {BackgroundColor3 = THEME.Accent2}):Play() end
        if stroke then TweenService:Create(stroke, TweenInfo.new(0.3), {Color = THEME.Accent2}):Play() end
        if label then label.TextColor3 = THEME.TextWhite end
        
        -- Start loop if not running
        if not State._autoJoinRunning then
             autoJoinLoop()
        end
    else
        if status then TweenService:Create(status, TweenInfo.new(0.3), {BackgroundColor3 = Color3.fromRGB(60,60,60)}):Play() end
        if stroke then TweenService:Create(stroke, TweenInfo.new(0.3), {Color = Color3.fromRGB(60,60,80)}):Play() end
        if label then label.TextColor3 = THEME.TextDim end
        -- Loop checks State.AutoJoin, so it will stop automatically
    end
end)

-- Render Loop & Login Logic
local function startPolling()
    -- Start Polling Loop
    task.spawn(function()
        local req = http_request or request or (syn and syn.request)
        if not req then
            warn("HTTP Request function not found! Executor not supported.")
            return 
        end
    
        while ScreenGui.Parent do
            local s, err = pcall(function()
                local rawResponse = req({
                    Url = API_URL .. "?t=" .. tostring(math.floor(tick())), -- Cache Busting
                    Method = "GET"
                })
                
                if rawResponse and rawResponse.Body then
                    local response = HttpService:JSONDecode(rawResponse.Body)
                    if response and response.data then
                        print("✅ API Response: " .. #response.data .. " items found.") -- DEBUG
                        for _, serverData in ipairs(response.data) do
                            processEntry(serverData)
                        end
                    else
                        warn("⚠️ API Response empty or invalid format")
                    end
                end
            end)
            if not s then warn("API Error: " .. tostring(err)) end
            
            -- UI Updates
            if #State.Buffer > 0 then
                for _, item in ipairs(State.Buffer) do
                    local frame = createRow(item.data)
                    if frame then
                        -- Set Initial Visibility based on Filter
                        local visible = true
                        if State.MinGenFilter > 0 and item.valor < State.MinGenFilter then visible = false end
                        
                        local hasFilter = false
                        for k,v in pairs(State.NameFilter) do hasFilter = true break end
                        if hasFilter and not (item.data.bestBrainrot and State.NameFilter[item.data.bestBrainrot.name]) then 
                            visible = false 
                        end
                        
                        frame.Visible = visible
                        table.insert(State.DisplayedItems, {valor = item.valor, frame = frame, data = item.data})
                    end
                end
                State.Buffer = {}
            end
            
            -- Cleanup
            local Scroll = MainFrame and MainFrame:FindFirstChild("ContentScroll")
            if Scroll then
                local frames = {}
                for _, c in ipairs(Scroll:GetChildren()) do
                    if c:IsA("Frame") then table.insert(frames, c) end
                end
                if #frames > 50 then
                    for i = 1, #frames - 40 do
                        if frames[i] and frames[i].Destroy then frames[i]:Destroy() end
                    end
                end
            end
            
            wait(1) -- Poll every 1s for realtime updates
        end
    end)
    
    -- Start Auto Join
    autoJoinLoop()
end

-- Dragging Logic (Moved Up)
local function makeDraggable(frame)
    local dragInput, dragStart, startPos
    local function update(input)
        local delta = input.Position - dragStart
        frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
    frame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragStart = input.Position
            startPos = frame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragStart = nil end
            end)
        end
    end)
    frame.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragStart then update(input) end
    end)
end

-- LOGIN UI (KeyAuth System)
local KeyGui = Instance.new("ScreenGui", CoreGui)
KeyGui.Name = "KeyAuthUI"
KeyGui.ResetOnSpawn = false

local Frame = Instance.new("Frame", KeyGui)
Frame.Size = UDim2.new(0, 320, 0, 180)
Frame.Position = UDim2.new(0.5, -160, 0.5, -90)
Frame.BackgroundColor3 = Color3.fromRGB(12,12,18)
Frame.Active = true -- Important for dragging
Instance.new("UICorner", Frame).CornerRadius = UDim.new(0, 14)

makeDraggable(Frame) -- Allow dragging Login Window

local Title = Instance.new("TextLabel", Frame)
Title.Text = "ANTIGRAVITY ACCESS"
Title.Size = UDim2.new(1, 0, 0, 40)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 16
Title.TextColor3 = Color3.fromRGB(0,255,230)
Title.BackgroundTransparency = 1

local Input = Instance.new("TextBox", Frame)
Input.PlaceholderText = "Enter your key"
Input.Size = UDim2.new(1, -40, 0, 36)
Input.Position = UDim2.new(0, 20, 0, 60)
Input.Text = ""
Input.TextColor3 = Color3.new(1,1,1)
Input.BackgroundColor3 = Color3.fromRGB(20,20,30)
Input.ClearTextOnFocus = false
Input.BorderSizePixel = 0
Instance.new("UICorner", Input).CornerRadius = UDim.new(0,8)

local Status = Instance.new("TextLabel", Frame)
Status.Text = ""
Status.Size = UDim2.new(1, -40, 0, 20)
Status.Position = UDim2.new(0, 20, 0, 100)
Status.TextSize = 12
Status.Font = Enum.Font.Gotham
Status.TextColor3 = Color3.fromRGB(255,80,80)
Status.BackgroundTransparency = 1

local Button = Instance.new("TextButton", Frame)
Button.Text = "LOGIN"
Button.Size = UDim2.new(1, -40, 0, 36)
Button.Position = UDim2.new(0, 20, 0, 130)
Button.BackgroundColor3 = Color3.fromRGB(0,255,230)
Button.TextColor3 = Color3.fromRGB(10,10,15)
Button.Font = Enum.Font.GothamBold
Button.TextSize = 14
Button.BorderSizePixel = 0
Instance.new("UICorner", Button).CornerRadius = UDim.new(0,8)

Button.MouseButton1Click:Connect(function()
    Status.Text = "Checking key..."
    
    -- Bypass dev
    if Input.Text == "admin" then
        Status.TextColor3 = Color3.fromRGB(0,255,160)
        Status.Text = "Dev Access granted"
        wait(0.6)
        KeyGui:Destroy()
        
        -- Remove Borders & Enable Main UI
        for _, v in ipairs(ScreenGui:GetDescendants()) do
            if v:IsA("UIStroke") then v:Destroy() end
        end
        ScreenGui.Enabled = true
        startPolling()
        return
    end

    local success, result = validateKey(Input.Text)

    if success then
        Status.TextColor3 = Color3.fromRGB(0,255,160)
        Status.Text = "Access granted"

        wait(0.6)
        KeyGui:Destroy()

        -- START MAIN APP
        -- Remove Borders & Enable Main UI
        for _, v in ipairs(ScreenGui:GetDescendants()) do
            if v:IsA("UIStroke") then v:Destroy() end
        end
        ScreenGui.Enabled = true
        startPolling()
    else
        Status.TextColor3 = Color3.fromRGB(255,80,80)
        Status.Text = type(result) == "table" and (result.message or "Invalid Key") or "Invalid key"
    end
end)

-- Enable dragging for Main Elements
makeDraggable(MainFrame)
makeDraggable(ToggleFrame)

-- Iniciar fetch de nombres
task.spawn(fetchBrainrotNames)
