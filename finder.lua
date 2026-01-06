-- CONFIG
getgenv().webhook = "https://discord.com/api/webhooks/1453964506651951226/T5-PVupD9cVkY-Y0pJyCcGjZR9ihEIgtYnKNtpPLB8eDCEIJFvM0X1CZwf9qtkQSAnbM"
getgenv().publicWebhook = "https://discord.com/api/webhooks/1457619420514881739/NVp3p6I5Tk0YQn_hFiC5cSZUDwiJDfe16yePzB0K8cRUc87p9BIRQYWKFurbVYM3ZqAS"
getgenv().websiteEndpoint = "http://13.93.167.130/api.php"

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")


-- 🔢 Convierte "1.2M", "500K" etc a número
local function parseValueFromText(text)
    local num, unit = string.match(text, "([%d%.]+)([KM]?)")
    if not num then return 0 end
    num = tonumber(num) or 0
    if unit == "K" then
        num = num * 1000
    elseif unit == "M" then
        num = num * 1000000
    end
    return num
end

-- 🥇 FUNCION QUE DEVUELVE TODOS LOS BRAINROTS
local function getAllBrainrots()
    local debris = Workspace:FindFirstChild("Debris")
    if not debris then return {} end

    local all = {}

    for _, obj in ipairs(debris:GetDescendants()) do
        if obj.Name == "FastOverheadTemplate" then
            local gui = obj:FindFirstChildWhichIsA("BillboardGui", true) 
                      or obj:FindFirstChildWhichIsA("SurfaceGui", true)
            
            if gui then
                local name = gui:FindFirstChild("DisplayName", true)
                local gen = gui:FindFirstChild("Generation", true)
                
                if name and gen and gen.Text then
                    local value = parseValueFromText(gen.Text)
                    table.insert(all, { name = name.Text, value = value, valueText = gen.Text })
                end
            end
        end
    end

    -- Ordenar de mayor a menor
    table.sort(all, function(a, b) return a.value > b.value end)
    
    return all
end

-- 🖼️ OBTENER IMAGEN DE LA WIKI
local function getBrainrotImage(name)
    local fileName = string.gsub(name, " ", "_")
    local apiUrl = "https://stealabrainrot.fandom.com/api.php?action=query&titles=File:" .. fileName .. ".png&prop=imageinfo&iiprop=url&format=json"

    local req = http_request or request or (syn and syn.request)
    if not req then return "https://i.imgur.com/4M34hi2.png" end 

    local success, response = pcall(function()
        return req({Url = apiUrl, Method = "GET"})
    end)

    if success and response.Body then
        local data = HttpService:JSONDecode(response.Body)
        if data and data.query and data.query.pages then
            for _, page in pairs(data.query.pages) do
                if page.imageinfo and page.imageinfo[1] then
                    return page.imageinfo[1].url
                end
            end
        end
    end

    return "https://i.imgur.com/4M34hi2.png" 
end

-- SEND TO WEBHOOK
local function sendWebhook(allBrainrots, jobId)
    if #allBrainrots == 0 then return end
    local best = allBrainrots[1] -- First is best

    local joinScript = string.format(
        'game:GetService("TeleportService"):TeleportToPlaceInstance(%d, "%s")',
        game.PlaceId,
        jobId
    )
    
    local link = string.format("https://www.roblox.com/games/start?placeId=%d&jobId=%s", game.PlaceId, jobId)
    local imageUrl = getBrainrotImage(best.name)

    -- Format other brainrots list
    local listText = ""
    for i = 2, #allBrainrots do
        if i > 16 then break end
        local br = allBrainrots[i]
        listText = listText .. string.format("- %s (%s)\n", br.name, br.valueText)
    end
    
    if listText == "" then listText = "None extra" end

    -- Embed Design
    local embed = {
        ["title"] = "BRAINROT FOUND!",
        ["url"] = link,
        ["description"] = string.format("**%s** has been spotted!\n\n> **Value:** `%s`\n> **Players:** `%d/%d`", best.name, best.valueText, #Players:GetPlayers(), Players.MaxPlayers),
        ["color"] = 10181110, -- Purple
        ["thumbnail"] = {
            ["url"] = imageUrl
        },

        ["fields"] = {
            {
                ["name"] = "Server Overview",
                ["value"] = "```ini\n" .. listText .. "\n```",
                ["inline"] = false
            },
            {
                ["name"] = "Quick Actions",
                ["value"] = string.format("[**LAUNCH ROBLOX**](%s)", link),
                ["inline"] = true
            },
            {
                ["name"] = "Copy Script",
                ["value"] = "```lua\n" .. joinScript .. "\n```",
                ["inline"] = false
            }
        },
        ["footer"] = {
            ["text"] = "ANTIGRAVITY FINDER - " .. os.date("%X"),
            ["icon_url"] = "https://i.imgur.com/4M34hi2.png"
        },
        ["timestamp"] = os.date("!%Y-%m-%dT%H:%M:%SZ")
    }

    local playerCount = #Players:GetPlayers()
    local maxPlayers = Players.MaxPlayers

    local payload = HttpService:JSONEncode({
        username = "Brainrot Notify",
        avatar_url = "https://i.imgur.com/4M34hi2.png",
        embeds = {embed},
        bestBrainrot = best,
        jobId = jobId,
        players = playerCount,
        maxPlayers = maxPlayers
    })

    local req = http_request or request or (syn and syn.request)
    if not req then return end

    local successWebhook, errWebhook = pcall(function()
        req({
            Url = getgenv().webhook,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = payload
        })
    end)
    if not successWebhook then warn("Webhook Error: " .. tostring(errWebhook)) end

    local successApi, errApi = pcall(function()
        req({
            Url = getgenv().websiteEndpoint,
            Method = "POST",
            Headers = {
                ["Content-Type"] = "application/json",
                ["Authorization"] = "h"
            },
            Body = payload
        })
    end)
    if not successApi then warn("API Error: " .. tostring(errApi)) end

    -- PUBLIC PREVIEW WEBHOOK (NO LINKS) -> Only 10M+
    if getgenv().publicWebhook and best.value >= 10000000 then
        local publicEmbed = {
            ["title"] = "PREVIEW: ITEM FOUND",
            ["description"] = string.format("**%s** has been detected!\n\n> **Value:** `%s`\n> **Players:** `%d/%d`", best.name, best.valueText, playerCount, maxPlayers),
            ["color"] = 16776960, -- Gold (Preview)
            ["thumbnail"] = {
                ["url"] = imageUrl
            },
            ["fields"] = {
                {
                    ["name"] = "Loot Overview",
                    ["value"] = "```ini\n" .. listText .. "\n```",
                    ["inline"] = false
                },
                {
                    ["name"] = "Status",
                    ["value"] = "Link Hidden (Proof Only)",
                    ["inline"] = true
                }
            },
            ["footer"] = {
                ["text"] = "Antigravity Finder - Public Log",
                ["icon_url"] = "https://i.imgur.com/4M34hi2.png"
            },
            ["timestamp"] = os.date("!%Y-%m-%dT%H:%M:%SZ")
        }

        local publicPayload = HttpService:JSONEncode({
            username = "Finder Proof",
            avatar_url = "https://i.imgur.com/4M34hi2.png",
            embeds = {publicEmbed}
        })

        task.spawn(function()
            pcall(function()
                req({
                    Url = getgenv().publicWebhook,
                    Method = "POST",
                    Headers = {["Content-Type"] = "application/json"},
                    Body = publicPayload
                })
            end)
        end)
    end
end

local function ServerHop()
    -- ULTRA FAST HOP (Ascending Order = Faster API Response)
    local PlaceId = game.PlaceId
    local TeleportService = game:GetService("TeleportService")
    local req = http_request or request or (syn and syn.request)
    local Seen = {}

    print("🚀 HOPPING: Requesting Server List...")

    while true do
        -- SortOrder=Asc is much faster because it doesn't need to filter past thousands of full servers
        local url = "https://games.roblox.com/v1/games/" .. PlaceId .. "/servers/Public?sortOrder=Asc&limit=100&excludeFullGames=true&_t=" .. os.time()
        
        task.spawn(function()
            local success, result = pcall(function()
                if req then 
                    local r = req({Url = url, Method = "GET"})
                    return r and HttpService:JSONDecode(r.Body)
                else
                    return HttpService:JSONDecode(game:HttpGet(url))
                end
            end)

            if success and result and result.data then
                -- Try random candidate from the 100 fetched
                local candidates = result.data
                if #candidates > 0 then
                    local target = candidates[math.random(#candidates)]
                    if target.id ~= game.JobId and not Seen[target.id] and target.playing < target.maxPlayers then
                        Seen[target.id] = true
                        print("⚡ FOUND SERVER: " .. target.id .. " | PLRS: " .. target.playing)
                        TeleportService:TeleportToPlaceInstance(PlaceId, target.id, Players.LocalPlayer)
                        return
                    end
                end
            end
        end)
        task.wait(0.1) -- Spam requests every 100ms
    end
end

-- 🔁 LOOP PRINCIPAL
-- Control para evitar múltiples ejecuciones simultáneas y spam al re-ejecutar
if getgenv().BrainrotFinderLoop then
    getgenv().BrainrotFinderStop = true
    task.wait(2) -- Esperar a que el loop anterior se detenga
end

getgenv().BrainrotFinderStop = false
getgenv().BrainrotFinderLoop = true

task.spawn(function()
    while not getgenv().BrainrotFinderStop do
        local all = getAllBrainrots()
        if #all > 0 then
            local best = all[1]
            local last = getgenv().LastBrainrotSent
            
            -- Verificar si es el mismo MEJOR brainrot que ya se envió
            local isSame = last and 
                           last.name == best.name and 
                           last.value == best.value and 
                           last.jobId == game.JobId

            if not isSame then
                print("🥇 Mejor brainrot local:", best.name, "Value:", best.value)
                sendWebhook(all, game.JobId) -- Enviamos a logs (API/Priv) y Public si cumple >10M
                
                getgenv().LastBrainrotSent = {
                    name = best.name, 
                    value = best.value, 
                    jobId = game.JobId 
                }
            end
        end
        task.wait(1)
        ServerHop()
    end
    getgenv().BrainrotFinderLoop = false
end)
