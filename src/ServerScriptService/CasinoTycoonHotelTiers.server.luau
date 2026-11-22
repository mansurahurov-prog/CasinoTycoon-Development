-- Follow-up hotel tiers for Casino Tycoon. Session-only; no DataStore or remotes.
local Players = game:GetService("Players")
local plotsFolder = game.Workspace.CasinoTycoon:WaitForChild("Plots")

local SYSTEM_TAG = "CasinoTycoonHotelTiers"
local PAYOUT_INTERVAL = 5
local tiers = {
	{
		key = "Restaurant",
		stationName = "CasinoTycoonPurchaseStation_Restaurant",
		modelName = "CasinoTycoonRestaurant",
		purchasedAttr = "HotelRestaurantPurchased",
		ownerAttr = "HotelRestaurantOwnerUserId",
		prerequisiteAttr = "HotelSuitePurchased",
		cost = 1500,
		payout = 75,
		centerX = 10,
		centerZ = -16,
	},
	{
		key = "Spa",
		stationName = "CasinoTycoonPurchaseStation_Spa",
		modelName = "CasinoTycoonSpa",
		purchasedAttr = "HotelSpaPurchased",
		ownerAttr = "HotelSpaOwnerUserId",
		prerequisiteAttr = "HotelRestaurantPurchased",
		cost = 3000,
		payout = 150,
		centerX = -14,
		centerZ = 12,
	},
}

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

local function getLabel(station)
	local button = station and station:FindFirstChild("ButtonPart")
	local billboard = button and button:FindFirstChild("PurchaseLabel")
	return billboard and billboard:FindFirstChild("Text")
end

local function setLabel(station, text)
	local label = getLabel(station)
	if label then
		label.Text = text
	end
end

local function makePart(parent, name, size, cframe, material, color, canCollide, transparency)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Anchored = true
	part.Material = material
	part.Color = color
	part.Transparency = transparency or 0
	part.CanCollide = canCollide
	part.CanTouch = false
	part.CanQuery = canCollide
	part.Parent = parent
	return part
end

local function buildPurchasedRoom(plot, tier, ownerId)
	if plot:FindFirstChild(tier.modelName) then
		return nil, "upgrade already exists"
	end

	local pad = plot:FindFirstChild("BuildablePad")
	if not pad or not pad:IsA("BasePart") then
		return nil, "BuildablePad missing"
	end

	local room = Instance.new("Model")
	room.Name = tier.modelName
	room:SetAttribute("CreatedBy", SYSTEM_TAG)
	room:SetAttribute("PurchasedByUserId", ownerId)
	room:SetAttribute("UpgradeType", tier.key)
	room.Parent = plot

	local origin = pad.CFrame
	local cx, cz = tier.centerX, tier.centerZ
	local floorTop = pad.Size.Y / 2 + 0.3
	local wallY = floorTop + 4
	local pale = Color3.fromRGB(224, 222, 216)
	local glass = Color3.fromRGB(185, 218, 226)
	local gold = Color3.fromRGB(212, 175, 96)
	local dark = Color3.fromRGB(31, 34, 39)
	local floorColor = Color3.fromRGB(55, 54, 52)

	local floor = makePart(room, tier.key .. "Floor", Vector3.new(18, 0.3, 16),
		origin * CFrame.new(cx, pad.Size.Y / 2 + 0.15, cz),
		Enum.Material.Marble, floorColor, true)
	room.PrimaryPart = floor

	makePart(room, "RearWall", Vector3.new(18, 8, 0.4),
		origin * CFrame.new(cx, wallY, cz + 7.8), Enum.Material.Marble, pale, true)
	makePart(room, "SideWallLeft", Vector3.new(0.4, 8, 16),
		origin * CFrame.new(cx - 8.8, wallY, cz), Enum.Material.Marble, pale, true)
	makePart(room, "SideWallRight", Vector3.new(0.4, 8, 16),
		origin * CFrame.new(cx + 8.8, wallY, cz), Enum.Material.Marble, pale, true)
	makePart(room, "FrontGlassLeft", Vector3.new(6, 8, 0.4),
		origin * CFrame.new(cx - 6, wallY, cz - 7.8), Enum.Material.Glass, glass, true, 0.4)
	makePart(room, "FrontGlassRight", Vector3.new(6, 8, 0.4),
		origin * CFrame.new(cx + 6, wallY, cz - 7.8), Enum.Material.Glass, glass, true, 0.4)
	makePart(room, "Roof", Vector3.new(18, 0.3, 16),
		origin * CFrame.new(cx, floorTop + 8.15, cz), Enum.Material.Glass, glass, true, 0.55)

	if tier.key == "Restaurant" then
		makePart(room, "ServiceCounter", Vector3.new(10, 1.4, 1.5),
			origin * CFrame.new(cx, floorTop + 0.7, cz + 5.5), Enum.Material.Marble, dark, true)
		makePart(room, "GoldCounterEdge", Vector3.new(10, 0.12, 0.12),
			origin * CFrame.new(cx, floorTop + 1.35, cz + 4.7), Enum.Material.Metal, gold, false)
		for _, dx in ipairs({-5, 5}) do
			local tableCenter = origin * CFrame.new(cx + dx, floorTop + 0.5, cz - 1.5)
			makePart(room, "DiningTable", Vector3.new(2.8, 0.8, 2.4),
				tableCenter, Enum.Material.Marble, pale, true)
			for _, sx in ipairs({-1.7, 1.7}) do
				makePart(room, "DiningChair", Vector3.new(0.8, 1.2, 0.8),
					origin * CFrame.new(cx + dx + sx, floorTop + 0.6, cz - 1.5),
					Enum.Material.SmoothPlastic, dark, true)
			end
		end
	elseif tier.key == "Spa" then
		for _, dx in ipairs({-4.5, 4.5}) do
			makePart(room, "TreatmentBedBase", Vector3.new(3.4, 0.65, 7),
				origin * CFrame.new(cx + dx, floorTop + 0.325, cz), Enum.Material.SmoothPlastic, dark, true)
			makePart(room, "TreatmentCushion", Vector3.new(3.1, 0.25, 6.7),
				origin * CFrame.new(cx + dx, floorTop + 0.775, cz), Enum.Material.Fabric, pale, false)
		end
		makePart(room, "SpaPlungePool", Vector3.new(4.5, 0.45, 3),
			origin * CFrame.new(cx, floorTop + 0.225, cz + 5.3), Enum.Material.Glass, glass, true, 0.3)
		makePart(room, "GoldSpaTrim", Vector3.new(4.7, 0.08, 3.2),
			origin * CFrame.new(cx, floorTop + 0.46, cz + 5.3), Enum.Material.Metal, gold, false)
	end

	return room
end

local refreshing = {}
local function clearTier(plot, tier)
	local room = plot:FindFirstChild(tier.modelName)
	if room and room:GetAttribute("CreatedBy") == SYSTEM_TAG then
		room:Destroy()
	end
	plot:SetAttribute(tier.purchasedAttr, false)
	plot:SetAttribute(tier.ownerAttr, nil)
end

local function refreshPlot(plot, stations)
	if refreshing[plot] then
		return
	end
	refreshing[plot] = true

	local ownerId = getOwnerId(plot)
	for _, tier in ipairs(tiers) do
		local purchaseOwnerId = tonumber(plot:GetAttribute(tier.ownerAttr))
		if purchaseOwnerId and purchaseOwnerId ~= ownerId then
			clearTier(plot, tier)
		end
	end
	for _, tier in ipairs(tiers) do
		if ownerId > 0
			and tonumber(plot:GetAttribute(tier.ownerAttr)) == ownerId
			and plot:GetAttribute(tier.purchasedAttr) == true
			and not plot:FindFirstChild(tier.modelName) then
			local ok, room = pcall(buildPurchasedRoom, plot, tier, ownerId)
			if not ok or not room then
				warn("CasinoTycoonHotelTiers: restore failed for " .. tier.key .. " on " .. plot.Name .. ": " .. tostring(room))
			end
		end
	end

	local suiteBought = plot:GetAttribute("HotelSuitePurchased") == true
	local restaurantBought = plot:GetAttribute("HotelRestaurantPurchased") == true
	local spaBought = plot:GetAttribute("HotelSpaPurchased") == true

	local restaurantPrompt = stations.Restaurant:FindFirstChild("ButtonPart"):FindFirstChildOfClass("ProximityPrompt")
	local spaPrompt = stations.Spa:FindFirstChild("ButtonPart"):FindFirstChildOfClass("ProximityPrompt")
	restaurantPrompt.Enabled = ownerId > 0 and suiteBought and not restaurantBought
	spaPrompt.Enabled = ownerId > 0 and restaurantBought and not spaBought

	local suiteStation = plot:FindFirstChild("CasinoTycoonPurchaseStation")
	setLabel(suiteStation, suiteBought and "GUEST SUITE BUILT | +$25 / 5s" or "GUEST SUITE | $500")
	setLabel(stations.Restaurant, restaurantBought and "RESTAURANT BUILT | +$75 / 5s"
		or (suiteBought and "RESTAURANT | $1500" or "LOCKED | BUILD GUEST SUITE"))
	setLabel(stations.Spa, spaBought and "SPA BUILT | +$150 / 5s"
		or (restaurantBought and "SPA | $3000" or "LOCKED | BUILD RESTAURANT"))

	refreshing[plot] = nil
end

for plotId = 1, 4 do
	local plot = plotsFolder:FindFirstChild("Plot_" .. plotId)
	if not plot then
		warn("CasinoTycoonHotelTiers: Plot_" .. plotId .. " missing")
		continue
	end

	assert(plot:FindFirstChild(tiers[1].stationName), "Restaurant station missing on " .. plot.Name)
	assert(plot:FindFirstChild(tiers[2].stationName), "Spa station missing on " .. plot.Name)

	local stations = {}
	for _, tier in ipairs(tiers) do
		local station = plot:FindFirstChild(tier.stationName)
		if not station then
			warn("CasinoTycoonHotelTiers: station " .. tier.stationName .. " missing on " .. plot.Name)
			break
		end
		stations[tier.key] = station
	end
	if not stations.Restaurant or not stations.Spa then
		continue
	end

	for _, tier in ipairs(tiers) do
		local station = stations[tier.key]
		local button = station:FindFirstChild("ButtonPart")
		local prompt = button and button:FindFirstChildOfClass("ProximityPrompt")
		if not prompt then
			warn("CasinoTycoonHotelTiers: prompt missing on " .. station:GetFullName())
			continue
		end

		prompt.Triggered:Connect(function(player)
			if player:GetAttribute("CashLoaded") ~= true then
				return
			end
			if getOwnerId(plot) ~= player.UserId then
				return
			end
			if plot:GetAttribute(tier.prerequisiteAttr) ~= true then
				return
			end
			if plot:GetAttribute(tier.purchasedAttr) == true then
				return
			end

			local cash = getCash(player)
			if not cash then
				return
			end
			if cash.Value < tier.cost then
				local label = getLabel(station)
				if label then
					label.Text = "NEED $" .. tostring(tier.cost)
					task.delay(2, function()
						refreshPlot(plot, stations)
					end)
				end
				return
			end

			cash.Value -= tier.cost
			local ok, result = pcall(buildPurchasedRoom, plot, tier, player.UserId)
			if not ok or not result then
				cash.Value += tier.cost
				local room = plot:FindFirstChild(tier.modelName)
				if room and room:GetAttribute("CreatedBy") == SYSTEM_TAG then
					room:Destroy()
				end
				warn("CasinoTycoonHotelTiers: purchase failed on " .. plot.Name .. ": " .. tostring(result))
				return
			end

			plot:SetAttribute(tier.purchasedAttr, true)
			plot:SetAttribute(tier.ownerAttr, player.UserId)
			refreshPlot(plot, stations)
		end)
	end

	for _, attribute in ipairs({
		"OwnerUserId",
		"HotelSuitePurchased",
		"HotelRestaurantPurchased",
		"HotelSpaPurchased",
	}) do
		plot:GetAttributeChangedSignal(attribute):Connect(function()
			refreshPlot(plot, stations)
		end)
	end
	refreshPlot(plot, stations)
end

task.spawn(function()
	while true do
		task.wait(PAYOUT_INTERVAL)
		for plotId = 1, 4 do
			local plot = plotsFolder:FindFirstChild("Plot_" .. plotId)
			local ownerId = plot and getOwnerId(plot) or 0
			local player = ownerId > 0 and Players:GetPlayerByUserId(ownerId) or nil
			local cash = player and getCash(player)
			if plot and cash then
				for _, tier in ipairs(tiers) do
					if plot:GetAttribute(tier.purchasedAttr) == true
						and tonumber(plot:GetAttribute(tier.ownerAttr)) == ownerId then
						local lucky = tonumber(workspace.CasinoTycoon:GetAttribute("LuckyHourMultiplier")) or 1
						local decor = 1 + 0.1 * (tonumber(plot:GetAttribute("DecorTier")) or 0)
						local vip = player:GetAttribute("VipActive") == true and 1.5 or 1
						cash.Value += math.floor(tier.payout * lucky * decor * vip)
					end
				end
			end
		end
	end
end)
