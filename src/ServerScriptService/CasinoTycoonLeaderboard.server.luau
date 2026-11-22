-- Plaza leaderboard: global top cash with a session-only fallback in Studio.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local GOLD = Color3.fromRGB(198, 160, 74)
local DARK = Color3.fromRGB(14, 14, 16)

local boardPart = Instance.new("Part")
boardPart.Name = "LeaderboardBoard"
boardPart.Size = Vector3.new(11, 7, 0.6)
boardPart.Position = Vector3.new(44, 9, -100)
boardPart.Anchored = true
boardPart.Color = DARK
boardPart.Material = Enum.Material.Marble
boardPart.CastShadow = false
boardPart.Locked = true
boardPart.Parent = workspace

task.wait()

local frame = Instance.new("Part")
frame.Name = "LeaderboardFrame"
frame.Size = Vector3.new(11.6, 7.6, 0.3)
frame.Position = boardPart.Position + Vector3.new(0, 0, 0.22)
frame.Anchored = true
frame.Color = GOLD
frame.Material = Enum.Material.Metal
frame.CanCollide = false
frame.CastShadow = false
frame.Locked = true
frame.Parent = workspace

for index, side in ipairs({ -6.05, 6.05 }) do
	local cabinet = Instance.new("Part")
	cabinet.Name = "LeaderboardPost" .. tostring(index)
	cabinet.Size = Vector3.new(0.5, 7.6, 0.5)
	cabinet.Position = boardPart.Position + Vector3.new(side, 0, 0.1)
	cabinet.Anchored = true
	cabinet.Color = GOLD
	cabinet.Material = Enum.Material.Metal
	cabinet.CastShadow = false
	cabinet.Locked = true
	cabinet.Parent = workspace
end

task.wait()

local gui = Instance.new("BillboardGui")
gui.Name = "BoardGui"
gui.Size = UDim2.fromOffset(420, 280)
gui.StudsOffsetWorldSpace = Vector3.new(0, 0.5, 0)
gui.AlwaysOnTop = false
gui.Parent = boardPart

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 44)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.TextSize = 26
title.TextColor3 = GOLD
title.Text = "TOP CASINOS"
title.Parent = gui

local listLabel = Instance.new("TextLabel")
listLabel.Position = UDim2.fromOffset(0, 52)
listLabel.Size = UDim2.new(1, 0, 1, -56)
listLabel.BackgroundTransparency = 1
listLabel.Font = Enum.Font.GothamMedium
listLabel.TextSize = 17
listLabel.TextXAlignment = Enum.TextXAlignment.Left
listLabel.TextYAlignment = Enum.TextYAlignment.Top
listLabel.TextColor3 = Color3.fromRGB(236, 233, 226)
listLabel.Text = "loading..."
listLabel.Parent = gui

local function getCash(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	local cash = leaderstats and leaderstats:FindFirstChild("Cash")
	return cash and cash.Value or 0
end

local function sessionTop()
	local list = {}
	for _, player in ipairs(Players:GetPlayers()) do
		table.insert(list, { n = player.DisplayName, c = getCash(player) })
	end
	table.sort(list, function(a, b)
		return a.c > b.c
	end)
	return list
end

local function render(list, subtitle)
	local lines = { subtitle, "" }
	for index = 1, 5 do
		local entry = list[index]
		if entry then
			table.insert(lines, string.format("%d.  %s   $%d", index, tostring(entry.n), tonumber(entry.c) or 0))
		else
			table.insert(lines, string.format("%d.  ---", index))
		end
	end
	listLabel.Text = table.concat(lines, "\n")
end

local store
local storeOk = pcall(function()
	store = DataStoreService:GetDataStore("CasinoTycoonBoard_v1")
end)
if not storeOk then
	store = nil
end

local function mergeAndPublish()
	local localTop = sessionTop()
	if not store then
		render(localTop, "SESSION RANKING")
		return
	end

	local stored = nil
	local okRead, readResult = pcall(function()
		return store:GetAsync("Top")
	end)
	if okRead and type(readResult) == "table" then
		stored = readResult
	end

	local byName = {}
	for _, entry in ipairs(stored or {}) do
		if type(entry) == "table" and entry.n then
			byName[entry.n] = math.max(tonumber(entry.c) or 0, byName[entry.n] or 0)
		end
	end
	for _, entry in ipairs(localTop) do
		byName[entry.n] = math.max(entry.c, byName[entry.n] or 0)
	end

	local merged = {}
	for name, cash in pairs(byName) do
		table.insert(merged, { n = name, c = cash })
	end
	table.sort(merged, function(a, b)
		return a.c > b.c
	end)
	while #merged > 5 do
		table.remove(merged)
	end

	pcall(function()
		store:SetAsync("Top", merged)
	end)
	render(merged, "ALL TIME")
end

task.spawn(function()
	task.wait(5)
	while true do
		local ok, err = pcall(mergeAndPublish)
		if not ok then
			warn("CasinoTycoonLeaderboard: " .. tostring(err))
			render(sessionTop(), "SESSION RANKING")
		end
		task.wait(120)
	end
end)
