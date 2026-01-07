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
    -- Remove special chars just in case, keep spaces for search
    local cleanName = string.gsub(name, "[^%w%s]", "")
    
    -- Use Search Generator to find the file (Fuzzy Match in File Namespace 6)
    -- This handles .jpg, .png, and capitalization automatically
    local query = HttpService:UrlEncode(cleanName)
    local apiUrl = "https://stealabrainrot.fandom.com/api.php?action=query&generator=search&gsrnamespace=6&gsrsearch=" .. query .. "&gsrlimit=1&prop=imageinfo&iiprop=url&format=json"

    local req = http_request or request or (syn and syn.request)
    if not req then return "https://i.imgur.com/4M34hi2.png" end 

    local success, response = pcall(function()
        return req({Url = apiUrl, Method = "GET"})
    end)

    if success and response.Body then
        local data = HttpService:JSONDecode(response.Body)
        if data and data.query and data.query.pages then
            -- Standard wiki response parsing for generator results
            for _, page in pairs(data.query.pages) do
                if page.imageinfo and page.imageinfo[1] and page.imageinfo[1].url then
                    return page.imageinfo[1].url
                end
            end
        end
    end

    -- Fallback to Antigravity Logo
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
    -- Format other brainrots list (Grouped)
    local listText = ""
    local grouped = {}
    
    for i = 2, #allBrainrots do
        local br = allBrainrots[i]
        local last = grouped[#grouped]
        
        -- Group if identical to previous
        if last and last.name == br.name and last.valueText == br.valueText then
            last.count = last.count + 1
        else
            table.insert(grouped, {name = br.name, valueText = br.valueText, count = 1})
        end
    end

    for i, g in ipairs(grouped) do
        if i > 15 then 
            listText = listText .. string.format("...and %d more\n", #grouped - 15)
            break 
        end
        
        if g.count > 1 then
            listText = listText .. string.format("- %s (%s) x%d\n", g.name, g.valueText, g.count)
        else
            listText = listText .. string.format("- %s (%s)\n", g.name, g.valueText)
        end
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

    -- PAYLOAD CONSTRUCTION
    -- Discord strict payload (Only allowed keys)
    local discordPayload = HttpService:JSONEncode({
        username = "Brainrot Notify",
        avatar_url = "https://i.imgur.com/4M34hi2.png",
        embeds = {embed}
    })

    -- API full payload (Includes extra data for tracking)
    local apiPayload = HttpService:JSONEncode({
        username = "Brainrot Notify",
        avatar_url = "https://i.imgur.com/4M34hi2.png",
        embeds = {embed},
        bestBrainrot = best,
        allBrainrots = allBrainrots,
        jobId = jobId,
        players = playerCount,
        maxPlayers = maxPlayers,
        botName = Players.LocalPlayer.Name
    })

    local req = http_request or request or (syn and syn.request)
    if not req then return end

    -- SEND TO DISCORD
    local successWebhook, errWebhook = pcall(function()
        req({
            Url = getgenv().webhook,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = discordPayload
        })
    end)
    if not successWebhook then warn("Webhook Error: " .. tostring(errWebhook)) end

    -- SEND TO API
    local successApi, errApi = pcall(function()
        req({
            Url = getgenv().websiteEndpoint,
            Method = "POST",
            Headers = {
                ["Content-Type"] = "application/json",
                ["Authorization"] = "h"
            },
            Body = apiPayload
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

-- 💾 PERSISTENCE (Visited Servers)
local VISITED_FILE = "visited_servers.json"
local Visited = {}

local function LoadVisited()
    -- Try to load existing
    if isfile and isfile(VISITED_FILE) then
        local s, r = pcall(readfile, VISITED_FILE)
        if s and r then
            pcall(function() Visited = HttpService:JSONDecode(r) end)
        end
    end
    
    -- Mark current as visited
    Visited[game.JobId] = os.time()
    
    -- Save
    if writefile then
        pcall(writefile, VISITED_FILE, HttpService:JSONEncode(Visited))
    end
end

-- Initialize
pcall(LoadVisited)

-- Remote Visit Check
local function CheckRemoteVisit(jobId)
    local req = http_request or request or (syn and syn.request)
    if not req then return true end -- Fail safe: let join if request unsupported
    
    local s, r = pcall(function()
        return req({
            Url = getgenv().websiteEndpoint,
            Method = "POST",
            Headers = {
                ["Content-Type"] = "application/json",
                ["Authorization"] = "h"
            },
            Body = HttpService:JSONEncode({
                type = "visit",
                jobId = jobId,
                botName = Players.LocalPlayer.Name
            })
        })
    end)
    
    if s and r and r.StatusCode == 200 then
        return true -- Successfully claimed
    else
        return false -- Taken or Error
    end
end

local function ServerHop()
    math.randomseed(tick())
    
    -- ULTRA FAST START: 0.1s - 1.5s delay (Just enough to de-sync threads)
    local startDelay = math.random(1, 15) / 10
    print(string.format("🦘 HOP: Speed Search starting in %.1fs...", startDelay))
    task.wait(startDelay)
    
    local PlaceId = game.PlaceId
    local TeleportService = game:GetService("TeleportService")
    local req = http_request or request or (syn and syn.request)
    
    -- Teleport Error Handler
    TeleportService.TeleportInitFailed:Connect(function(player, result, enum, message)
        warn("❌ Teleport Failed: " .. tostring(message))
        -- Retry logic implicitly handled by loop continuing or script re-executing on fail
    end)
    
    local cursor = ""
    
    while true do
        local candidates = {}
        local pagesScanned = 0
        
        -- PAGINATION LOOP: Fetch up to 5 pages to find GLOBAL BEST options
        repeat
            local url = "https://games.roblox.com/v1/games/" .. PlaceId .. "/servers/Public?sortOrder=Desc&limit=100&excludeFullGames=true"
            if cursor and cursor ~= "" then
                url = url .. "&cursor=" .. cursor
            end
            
            local success, raw = pcall(function()
                return req({Url = url, Method = "GET"}) 
            end)
    
            if success and raw and raw.Body then
                local result = HttpService:JSONDecode(raw.Body)
                if result and result.data then
                    cursor = result.nextPageCursor
                    
                    for _, server in ipairs(result.data) do
                        -- Strict Check: Must have space, valid ID, and NOT visited
                        if server.playing < server.maxPlayers and server.id ~= game.JobId and not Visited[server.id] then
                             table.insert(candidates, server)
                        end
                    end
                else
                    cursor = nil 
                end
            else
                cursor = nil
            end
            
            pagesScanned = pagesScanned + 1
            -- Stop if we have a solid pool of 'Elite' servers or scanned enough
        until (not cursor) or (#candidates >= 20) or (pagesScanned >= 5)

        -- PROCESS CANDIDATES
        if #candidates > 0 then
            -- 1. Sort by Player Count (Highest First) - The "Best" servers
            table.sort(candidates, function(a,b) return a.playing > b.playing end)
            
            -- 2. Select the "Elite Few" (Top 5)
            local elite = {}
            for i = 1, math.min(#candidates, 5) do
                table.insert(elite, candidates[i])
            end
            
            -- 3. Shuffle the Elite to avoid Bot Collision (All bots racing for #1)
            -- This makes them distribute among the top 5 best servers
            for i = #elite, 2, -1 do
                local j = math.random(i)
                elite[i], elite[j] = elite[j], elite[i]
            end

            -- 4. Fast Attempt Loop
            for _, target in ipairs(elite) do
                if CheckRemoteVisit(target.id) then
                    Visited[target.id] = os.time()
                    if writefile then
                        pcall(writefile, VISITED_FILE, HttpService:JSONEncode(Visited))
                    end
                    
                    print("⚡ ELITE JOIN: " .. target.id .. " [" .. target.playing .. " Plrs]")
                    
                    TeleportService:TeleportToPlaceInstance(PlaceId, target.id, Players.LocalPlayer)
                    
                    -- Wait comfortably for TP. If it fails, loop continues next iter.
                    task.wait(20) 
                    warn("⚠️ Teleport stalled. Retrying search...")
                else
                     -- Mark as visited so we don't check again in this session
                     Visited[target.id] = os.time() 
                end
            end
        else
            warn("⚠️ No valid servers found in top pages. Resetting cursor...")
            cursor = "" -- Reset to start from top
            task.wait(2)
        end
        
        task.wait(0.5)
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
    -- Start Hopping immediately in parallel
    task.spawn(ServerHop)

    while not getgenv().BrainrotFinderStop do
        local all = getAllBrainrots()
        if #all > 0 then
            local best = all[1]
            local last = getgenv().LastBrainrotSent
            
            -- Verificar si es el mismo MEJOR brainrot
            local isSame = last and 
                           last.name == best.name and 
                           last.value == best.value and 
                           last.jobId == game.JobId
            
            local isNewServer = (not last) or (last.jobId ~= game.JobId)
            local isBetter = last and (best.value > last.value) -- User requested: "mayor que el anterior"

            if isNewServer or (not isSame) then
                -- Log only if new server OR different item found
                -- (Note: We send even if value is lower to keep data accurate, 
                -- but concurrency ensures we definitely see 'Better' ones instantly)
                print("🥇 Mejor brainrot local:", best.name, "Value:", best.value)
                sendWebhook(all, game.JobId)
                
                getgenv().LastBrainrotSent = {
                    name = best.name, 
                    value = best.value, 
                    jobId = game.JobId 
                }
            end
        end
        task.wait(0.5) -- Faster scanning
    end
    getgenv().BrainrotFinderLoop = false
end)
