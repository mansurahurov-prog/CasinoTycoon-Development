-- Plot decor upgrades: money sink that also raises passive income by 10% per tier.
local Players = game:GetService("Players")
local plotsFolder = workspace:WaitForChild("CasinoTycoon"):WaitForChild("Plots")

local COSTS = { 250, 750, 2000 }
local MAX_TIER = #COSTS
local GOLD = Color3.fromRGB(198, 160, 74)
local DARK = Color3.fromRGB(20, 20, 22)
local PLANT = Color3.fromRGB(34, 74, 44)
local WARM = Color3.fromRGB(255, 226, 176)

local function getCash(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	local cash = leaderstats and leaderstats:FindFirstChild("Cash")
	if cash and cash:IsA("IntValue") then
		return cash
	end
	return nil
end

local function part(parent, name, size, cf, color, material, collide)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.CanCollide = collide
	p.CastShadow = false
	p.Locked = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function buildTier(plot, tier)
	local pad = plot:FindFirstChild("BuildablePad")
	if not pad then
		return
	end
	local decor = plot:FindFirstChild("PlotDecor_Upgrade")
	if not decor then
		decor = Instance.new("Model")
		decor.Name = "PlotDecor_Upgrade"
		decor.Parent = plot
	end
	local o = pad.CFrame
	local base = pad.Size.Y / 2

	if tier >= 1 and not decor:FindFirstChild("DecorTier1") then
		local g = Instance.new("Folder")
	
g.Name = "DecorTier1"
		g.Parent = decor
		for i, off in ipairs({ { 36, 36 }, { 36, -36 }, { -36, 36 }, { -36, -36 } }) do
			part(g, "Planter" .. i, Vector3.new(3, 1.8, 3), o * CFrame.new(off[1], base + 0.9, off[2]), DARK, Enum.Material.Marble, true)
			part(g, "PlanterRim" .. i, Vector3.new(3.2, 0.2, 3.2), o * CFrame.new(off[1], base + 1.85, off[2]), GOLD, Enum.Material.Metal, false)
			part(g, "PlanterBush" .. i, Vector3.new(2.6, 2.2, 2.6), o * CFrame.new(off[1], base + 2.9, off[2]), PLANT, Enum.Material.Grass, true)
		end
	end

	if tier >= 2 and not decor:FindFirstChild("DecorTier2") then
		local g = Instance.new("Folder")
		g.Name = "DecorTier2"
		g.Parent = decor
		part(g, "CarpetRunner", Vector3.new(10, 0.1, 34), o * CFrame.new(0, base + 0.06, 18), Color3.fromRGB(96, 20, 26), Enum.Material.Fabric, false)
		part(g, "CarpetInlayL", Vector3.new(0.4, 0.12, 34), o * CFrame.new(-5, base + 0.07, 18), GOLD, Enum.Material.Fabric, false)
		part(g, "CarpetInlayR", Vector3.new(0.4, 0.12, 34), o * CFrame.new(5, base + 0.07, 18), GOLD, Enum.Material.Fabric, false)
		for i, off in ipairs({ { 24, 40 }, { -24, 40 }, { 24, -40 }, { -24, -40 } }) do
			part(g, "LanternPost" .. i, Vector3.new(0.6, 5, 0.6), o * CFrame.new(off[1], base + 2.5, off[2]), GOLD, Enum.Material.Metal, true)
			part(g, "LanternGlow" .. i, Vector3.new(1.1, 1.1, 1.1), o * CFrame.new(off[1], base + 5.3, off[2]), WARM, Enum.Material.Neon, false)
		end
	end

	if tier >= 3 and not decor:FindFirstChild("DecorTier3") then
		local g = Instance.new("Folder")
		g.Name = "DecorTier3"
		g.Parent = decor
		part(g, "GoldRailFront", Vector3.new(62, 0.35, 0.5), o * CFrame.new(0, base + 1.5, 43), GOLD, Enum.Material.Metal, false)
		for i = 1, 6 do
			local x = -30 + (i - 1) * 12
			part(g, "RailPost" .. i, Vector3.new(0.6, 1.6, 0.6), o * CFrame.new(x, base + 0.8, 43), GOLD, Enum.Material.Metal, true)
		end
		part(g, "MarbleMedallion", Vector3.new(8, 0.12, 8), o * CFrame.new(0, base + 0.08, 18), Color3.fromRGB(236, 233, 226), Enum.Material.Marble, false)
	end
end

local function refreshStation(station, plot)
	local tier = tonumber(plot:GetAttribute("DecorTier")) or 0
	local prompt = station.ButtonPart:FindFirstChildOfClass("ProximityPrompt")
	local board = station:FindFirstChild("DecorBoard")
	if tier >= MAX_TIER then
		prompt.Enabled = false
		prompt.ActionText = "Decor maxed"
	else
		prompt.Enabled = true
		prompt.ActionText = "Upgrade decor " .. tostring(COSTS[tier + 1])
	end
	if board and board:FindFirstChildOfClass("BillboardGui") then
		board:FindFirstChildOfClass("BillboardGui").Tier.Text = "DECOR TIER " .. tostring(tier) .. " / " .. tostring(MAX_TIER)
	end
end

local function setupPlot(plot)
	if plot:GetAttribute("DecorTier") == nil then
		plot:SetAttribute("DecorTier", 0)
	end
	if plot:FindFirstChild("CasinoTycoonDecorStation") then
		return
	end
	local pad = plot:FindFirstChild("BuildablePad")
	if not pad then
		return
	end
	local station = Instance.new("Model")
	station.Name = "CasinoTycoonDecorStation"
	part(station, "ButtonPart", Vector3.new(5, 0.5, 5), pad.CFrame * CFrame.new(22, pad.Size.Y / 2 + 0.25, 36), DARK, Enum.Material.Marble, true)
	part(station, "GoldButtonTrim", Vector3.new(4.8, 0.12, 0.12), pad.CFrame * CFrame.new(22, pad.Size.Y / 2 + 0.55, 33.6), GOLD, Enum.Material.Metal, false)
	local board = part(station, "DecorBoard", Vector3.new(0.2, 1.4, 5), pad.CFrame * CFrame.new(22, pad.Size.Y / 2 + 3.2, 36), DARK, Enum.Material.SmoothPlastic, false)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(240, 60)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 1.4, 0)
	gui.AlwaysOnTop = false
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.Name = "Tier"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = GOLD
	label.Text = "DECOR TIER 0 / " .. tostring(MAX_TIER)
	label.Parent = gui
	station.Parent = plot

	local prompt = Instance.new("ProximityPrompt")
	prompt.ObjectText = "Decor Upgrades"
	prompt.ActionText = "Upgrade decor " .. tostring(COSTS[1])
	prompt.HoldDuration = 0.4
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = station.ButtonPart

	local building = false
	prompt.Triggered:Connect(function(player)
		if player:GetAttribute("CashLoaded") ~= true then
			return
		end
		if building then
			return
		end
		if tonumber(plot:GetAttribute("OwnerUserId")) ~= player.UserId then
			return
		end
		local tier = tonumber(plot:GetAttribute("DecorTier")) or 0
		if tier >= MAX_TIER then
			return
		end
		local cost = COSTS[tier + 1]
		local cash = getCash(player)
		if not cash or cash.Value < cost then
			return
		end
		building = true
		cash.Value -= cost
		local ok, err = pcall(buildTier, plot, tier + 1)
		if not ok then
			cash.Value += cost
			warn("CasinoTycoonDecorUpgrades: build failed for " .. plot.Name .. ": " .. tostring(err))
		else
			plot:SetAttribute("DecorTier", tier + 1)
			player:SetAttribute("DecorTierUp", tier + 1)
		end
		building = false
		refreshStation(station, plot)
	end)

	refreshStation(station, plot)

	plot:GetAttributeChangedSignal("DecorTier"):Connect(function()
		local tier = tonumber(plot:GetAttribute("DecorTier")) or 0
		if tier > 0 then
			pcall(buildTier, plot, tier)
		end
		refreshStation(station, plot)
	end)
end

for i = 1, 4 do
	local plot = plotsFolder:FindFirstChild("Plot_" .. i)
	if plot then
		setupPlot(plot)
	end
end

plotsFolder.ChildAdded:Connect(function(plot)
	if plot:IsA("Model") then
		task.defer(setupPlot, plot)
	end
end)
