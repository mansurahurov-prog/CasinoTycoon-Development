-- Session-only Casino Tycoon economy. This system does not save player data.
local Players = game:GetService("Players")
local plotsFolder = game.Workspace.CasinoTycoon:WaitForChild("Plots")

local STARTING_CASH = 1000
local SUITE_COST = 500
local PAYOUT_AMOUNT = 25
local PAYOUT_INTERVAL = 5
local STATION_NAME = "CasinoTycoonPurchaseStation"
local SUITE_NAME = "CasinoTycoonHotelSuite"
local SYSTEM_TAG = "CasinoTycoonEconomy"

local function getOwnerId(plot)
	return tonumber(plot:GetAttribute("OwnerUserId")) or 0
end

local function getCash(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	local cash = leaderstats and leaderstats:FindFirstChild("Cash")
	if cash and cash:IsA("IntValue") then
		return cash
	end
	return nil
end

local function ensureCash(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		leaderstats.Parent = player
	end

	local cash = leaderstats:FindFirstChild("Cash")
	if cash then
		if cash:IsA("IntValue") then
			return cash
		end
		warn("CasinoTycoonEconomy: Cash exists but is not an IntValue for " .. player.Name)
		return nil
	end

	cash = Instance.new("IntValue")
	cash.Name = "Cash"
	cash.Value = STARTING_CASH
	cash.Parent = leaderstats
	return cash
end

Players.PlayerAdded:Connect(ensureCash)
for _, player in ipairs(Players:GetPlayers()) do
	ensureCash(player)
end

local function makePart(parent, name, size, cframe, material, color, canCollide)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Anchored = true
	part.Material = material
	part.Color = color
	part.CanCollide = canCollide
	part.CanTouch = false
	part.CanQuery = canCollide
	part.Parent = parent
	return part
end

local function buildHotelSuite(plot, ownerId)
	local existing = plot:FindFirstChild(SUITE_NAME)
	if existing then
		return nil, "suite already exists"
	end

	local pad = plot:FindFirstChild("BuildablePad")
	if not pad or not pad:IsA("BasePart") then
		return nil, "BuildablePad missing"
	end

	local suite = Instance.new("Model")
	suite.Name = SUITE_NAME
	suite:SetAttribute("CreatedBy", SYSTEM_TAG)
	suite:SetAttribute("PurchasedByUserId", ownerId)
	suite.Parent = plot

	local origin = pad.CFrame
	local floorTop = pad.Size.Y / 2 + 0.3
	local dark = Color3.fromRGB(31, 34, 39)
	local wallColor = Color3.fromRGB(224, 222, 216)
	local glassColor = Color3.fromRGB(185, 218, 226)
	local gold = Color3.fromRGB(212, 175, 96)

	local floor = makePart(
		suite, "SuiteFloor", Vector3.new(18, 0.3, 16),
		origin * CFrame.new(10, pad.Size.Y / 2 + 0.15, 12),
		Enum.Material.Marble, dark, true
	)
	suite.PrimaryPart = floor

	local wallY = floorTop + 4
	makePart(suite, "SuiteBackWall", Vector3.new(18, 8, 0.4),
		origin * CFrame.new(10, wallY, 19.8), Enum.Material.Marble, wallColor, true)
	makePart(suite, "SuiteSideWallLeft", Vector3.new(0.4, 8, 16),
		origin * CFrame.new(1.2, wallY, 12), Enum.Material.Marble, wallColor, true)
	makePart(suite, "SuiteSideWallRight", Vector3.new(0.4, 8, 16),
		origin * CFrame.new(18.8, wallY, 12), Enum.Material.Marble, wallColor, true)
	makePart(suite, "SuiteFrontLeft", Vector3.new(6, 8, 0.4),
		origin * CFrame.new(4, wallY, 4.2), Enum.Material.Glass, glassColor, true).Transparency = 0.4
	makePart(suite, "SuiteFrontRight", Vector3.new(6, 8, 0.4),
		origin * CFrame.new(16, wallY, 4.2), Enum.Material.Glass, glassColor, true).Transparency = 0.4
	makePart(suite, "SuiteRoof", Vector3.new(18, 0.3, 16),
		origin * CFrame.new(10, floorTop + 8.15, 12), Enum.Material.Glass, glassColor, true).Transparency = 0.55

	makePart(suite, "BedBase", Vector3.new(7, 0.8, 6),
		origin * CFrame.new(10, floorTop + 0.4, 11), Enum.Material.SmoothPlastic, dark, true)
	makePart(suite, "BedTopper", Vector3.new(6.5, 0.5, 5.5),
		origin * CFrame.new(10, floorTop + 1.05, 11), Enum.Material.Fabric, wallColor, false)
	makePart(suite, "Headboard", Vector3.new(7, 2, 0.3),
		origin * CFrame.new(10, floorTop + 1.9, 14), Enum.Material.SmoothPlastic, dark, true)
	makePart(suite, "GoldBedTrim", Vector3.new(6.8, 0.08, 0.08),
		origin * CFrame.new(10, floorTop + 0.15, 7.95), Enum.Material.Metal, gold, false)
	makePart(suite, "Nightstand", Vector3.new(2, 2, 2),
		origin * CFrame.new(5, floorTop + 1, 16), Enum.Material.Marble, dark, true)
	makePart(suite, "GoldNightstandTop", Vector3.new(2.1, 0.08, 2.1),
		origin * CFrame.new(5, floorTop + 2.04, 16), Enum.Material.Metal, gold, false)

	-- Luxury interior finish (visual only)
	local ivory = Color3.fromRGB(238, 236, 230)
	local charcoal = Color3.fromRGB(26, 26, 28)
	local velvet = Color3.fromRGB(58, 26, 30)

	local function restyle(name, material, color, transparency)
		local part = suite:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			part.Material = material
			part.Color = color
			if transparency then
				part.Transparency = transparency
			end
		end
	end

	restyle("SuiteFloor", Enum.Material.Marble, charcoal)
	restyle("SuiteBackWall", Enum.Material.Marble, ivory)
	restyle("SuiteSideWallLeft", Enum.Material.Marble, ivory)
	restyle("SuiteSideWallRight", Enum.Material.Marble, ivory)
	restyle("Headboard", Enum.Material.Marble, charcoal)
	restyle("BedTopper", Enum.Material.Fabric, Color3.fromRGB(246, 244, 238))
	restyle("SuiteRoof", Enum.Material.Glass, glassColor, 0.62)

	local inlayY = floorTop + 0.02
	makePart(suite, "FloorInlayFront", Vector3.new(16.6, 0.04, 0.3), origin * CFrame.new(10, inlayY, 4.9), Enum.Material.Metal, gold, false)
	makePart(suite, "FloorInlayBack", Vector3.new(16.6, 0.04, 0.3), origin * CFrame.new(10, inlayY, 19.1), Enum.Material.Metal, gold, false)
	makePart(suite, "FloorInlayLeft", Vector3.new(0.3, 0.04, 15), origin * CFrame.new(1.9, inlayY, 12), Enum.Material.Metal, gold, false)
	makePart(suite, "FloorInlayRight", Vector3.new(0.3, 0.04, 15), origin * CFrame.new(18.1, inlayY, 12), Enum.Material.Metal, gold, false)
	makePart(suite, "VelvetRug", Vector3.new(7, 0.06, 5), origin * CFrame.new(10, inlayY, 8.5), Enum.Material.Fabric, velvet, false)

	makePart(suite, "ChandelierStem", Vector3.new(0.3, 0.7, 0.3), origin * CFrame.new(10, floorTop + 7.55, 12), Enum.Material.Metal, gold, false)
	makePart(suite, "ChandelierRing", Vector3.new(3.6, 0.28, 3.6), origin * CFrame.new(10, floorTop + 7.1, 12), Enum.Material.Metal, gold, false)
	makePart(suite, "ChandelierInner", Vector3.new(2.2, 0.2, 2.2), origin * CFrame.new(10, floorTop + 6.85, 12), Enum.Material.Metal, gold, false)
	local bulb = makePart(suite, "ChandelierBulb", Vector3.new(0.7, 0.32, 0.7), origin * CFrame.new(10, floorTop + 7.0, 12), Enum.Material.Neon, Color3.fromRGB(255, 226, 178), false)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 218, 164)
	light.Range = 24
	light.Brightness = 1.1
	light.Shadows = false
	light.Parent = bulb

	makePart(suite, "WallRailLeft", Vector3.new(0.12, 0.16, 15.4), origin * CFrame.new(1.45, floorTop + 3.2, 12), Enum.Material.Metal, gold, false)
	makePart(suite, "WallRailRight", Vector3.new(0.12, 0.16, 15.4), origin * CFrame.new(18.55, floorTop + 3.2, 12), Enum.Material.Metal, gold, false)
	makePart(suite, "WallRailBack", Vector3.new(17.1, 0.16, 0.12), origin * CFrame.new(10, floorTop + 3.2, 19.52), Enum.Material.Metal, gold, false)

	makePart(suite, "Console", Vector3.new(5, 2.6, 0.25), origin * CFrame.new(15, floorTop + 1.75, 19.4), Enum.Material.Glass, Color3.fromRGB(24, 30, 34), false).Transparency = 0.15
	makePart(suite, "ConsoleShelf", Vector3.new(5.4, 0.12, 0.6), origin * CFrame.new(15, floorTop + 3.2, 19.2), Enum.Material.Metal, gold, false)

	makePart(suite, "NightstandRight", Vector3.new(2, 2, 2), origin * CFrame.new(15, floorTop + 1, 16), Enum.Material.Marble, charcoal, true)
	makePart(suite, "GoldNightstandTopRight", Vector3.new(2.1, 0.08, 2.1), origin * CFrame.new(15, floorTop + 2.04, 16), Enum.Material.Metal, gold, false)
	makePart(suite, "ArmchairSeat", Vector3.new(2.2, 0.8, 2.2), origin * CFrame.new(14.2, floorTop + 0.4, 6.4), Enum.Material.Fabric, velvet, true)
	makePart(suite, "ArmchairBack", Vector3.new(2.2, 1.5, 0.4), origin * CFrame.new(14.2, floorTop + 1.2, 7.3), Enum.Material.Fabric, velvet, true)

	makePart(suite, "NightstandLampLeft", Vector3.new(0.9, 0.9, 0.9), origin * CFrame.new(5, floorTop + 2.55, 16), Enum.Material.Neon, Color3.fromRGB(255, 228, 186), false)
	makePart(suite, "NightstandLampRight", Vector3.new(0.9, 0.9, 0.9), origin * CFrame.new(15, floorTop + 2.55, 16), Enum.Material.Neon, Color3.fromRGB(255, 228, 186), false)

	return suite
end

local function clearPurchasedSuite(plot)
	local suite = plot:FindFirstChild(SUITE_NAME)
	if suite and suite:GetAttribute("CreatedBy") == SYSTEM_TAG then
		suite:Destroy()
	end
	plot:SetAttribute("HotelSuitePurchased", false)
	plot:SetAttribute("HotelSuiteOwnerUserId", nil)
end

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function ensureRemote(name)
	local event = ReplicatedStorage:FindFirstChild(name)
	if not event then
		event = Instance.new("RemoteEvent")
		event.Name = name
		event.Parent = ReplicatedStorage
	end
	return event
end

local requestEvent = ensureRemote("CasinoTycoonPurchaseRequest")
local confirmEvent = ensureRemote("CasinoTycoonPurchaseConfirm")
local pending = {}

local function findPrompt(plot)
	local station = plot:FindFirstChild(STATION_NAME)
	local button = station and station:FindFirstChild("ButtonPart")
	return button and button:FindFirstChildOfClass("ProximityPrompt")
end

local function purchaseSuite(player, plot)
	if getOwnerId(plot) ~= player.UserId then
		return false
	end
	if plot:GetAttribute("HotelSuitePurchased") == true then
		return false
	end

	local cash = getCash(player)
	if not cash or cash.Value < SUITE_COST then
		return false
	end

	cash.Value -= SUITE_COST
	local suite, err = buildHotelSuite(plot, player.UserId)
	if not suite then
		cash.Value += SUITE_COST
		warn("CasinoTycoonEconomy: purchase failed for " .. plot.Name .. ": " .. tostring(err))
		return false
	end

	plot:SetAttribute("HotelSuitePurchased", true)
	plot:SetAttribute("HotelSuiteOwnerUserId", player.UserId)
	local prompt = findPrompt(plot)
	if prompt then
		prompt.Enabled = false
	end
	return true
end

local function configurePlot(plot)
	local station = plot:FindFirstChild(STATION_NAME)
	local button = station and station:FindFirstChild("ButtonPart")
	local prompt = button and button:FindFirstChildOfClass("ProximityPrompt")
	if not prompt then
		warn("CasinoTycoonEconomy: purchase prompt missing for " .. plot.Name)
		return
	end

	local function refresh()
		local ownerId = getOwnerId(plot)
		local purchasedOwnerId = tonumber(plot:GetAttribute("HotelSuiteOwnerUserId"))
		if purchasedOwnerId and ownerId ~= purchasedOwnerId then
			clearPurchasedSuite(plot)
		end
		if ownerId > 0 and ownerId == purchasedOwnerId
			and plot:GetAttribute("HotelSuitePurchased") == true
			and not plot:FindFirstChild(SUITE_NAME) then
			local ok, err = pcall(buildHotelSuite, plot, ownerId)
			if not ok or not err then
				warn("CasinoTycoonEconomy: suite restore failed for " .. plot.Name .. ": " .. tostring(err))
			end
		end
		prompt.Enabled = ownerId > 0 and plot:GetAttribute("HotelSuitePurchased") ~= true
	end

	plot:GetAttributeChangedSignal("OwnerUserId"):Connect(refresh)
	plot:GetAttributeChangedSignal("HotelSuitePurchased"):Connect(refresh)
	plot:GetAttributeChangedSignal("HotelSuiteOwnerUserId"):Connect(refresh)
	refresh()

	prompt.Triggered:Connect(function(player)
		if player:GetAttribute("CashLoaded") ~= true then
			return
		end
		if getOwnerId(plot) ~= player.UserId then
			return
		end
		if plot:GetAttribute("HotelSuitePurchased") == true then
			return
		end

		local cash = getCash(player)
		if not cash or cash.Value < SUITE_COST then
			return
		end

		pending[player] = { plot = plot, stamp = os.clock() }
		requestEvent:FireClient(player, {
			plotId = plot:GetAttribute("PlotId"),
			plotName = plot.Name,
			cost = SUITE_COST,
			actionText = prompt.ActionText,
		})
	end)
end

confirmEvent.OnServerEvent:Connect(function(player, plotId, accepted)
	local entry = pending[player]
	pending[player] = nil
	if not entry or accepted == false then
		return
	end
	if os.clock() - entry.stamp > 25 then
		return
	end
	if entry.plot.Parent == nil then
		return
	end
	if plotId ~= nil and entry.plot:GetAttribute("PlotId") ~= plotId then
		return
	end
	purchaseSuite(player, entry.plot)
end)

Players.PlayerRemoving:Connect(function(player)
	pending[player] = nil
end)

for plotId = 1, 4 do
	local plot = plotsFolder:FindFirstChild("Plot_" .. plotId)
	if plot then
		configurePlot(plot)
	else
		warn("CasinoTycoonEconomy: Plot_" .. plotId .. " missing")
	end
end

task.spawn(function()
	while true do
		task.wait(PAYOUT_INTERVAL)
		for plotId = 1, 4 do
			local plot = plotsFolder:FindFirstChild("Plot_" .. plotId)
			if plot and plot:GetAttribute("HotelSuitePurchased") == true then
				local ownerId = getOwnerId(plot)
				local purchasedOwnerId = tonumber(plot:GetAttribute("HotelSuiteOwnerUserId"))
				if ownerId > 0 and ownerId == purchasedOwnerId then
					local player = Players:GetPlayerByUserId(ownerId)
					local cash = player and getCash(player)
					if cash then
						local lucky = tonumber(workspace.CasinoTycoon:GetAttribute("LuckyHourMultiplier")) or 1
						local decor = 1 + 0.1 * (tonumber(plot:GetAttribute("DecorTier")) or 0)
						local vip = player:GetAttribute("VipActive") == true and 1.5 or 1
						cash.Value += math.floor(PAYOUT_AMOUNT * lucky * decor * vip)
					end
				end
			end
		end
	end
end)
