-- Server-side hotel guest visits. Session-only: no persistence, remotes, or gambling.
local Players = game:GetService("Players")

local casino = workspace:WaitForChild("CasinoTycoon")
local plotsFolder = casino:WaitForChild("Plots")
local guestsFolder = casino:FindFirstChild("GuestVisitors")
if not guestsFolder then
	guestsFolder = Instance.new("Folder")
	guestsFolder.Name = "GuestVisitors"
	guestsFolder.Parent = casino
end

local SPAWN_INTERVAL = 18
local SERVICE_SECONDS = 3
local MAX_ACTIVE_PER_PLOT = 1
local activeByPlot = {}

local services = {
	{
		attr = "HotelSpaPurchased",
		ownerAttr = "HotelSpaOwnerUserId",
		model = "CasinoTycoonSpa",
		title = "SPA",
		offset = Vector3.new(-14, 0, 12),
		reward = 125,
	},
	{
		attr = "HotelRestaurantPurchased",
		ownerAttr = "HotelRestaurantOwnerUserId",
		model = "CasinoTycoonRestaurant",
		title = "RESTAURANT",
		offset = Vector3.new(10, 0, -16),
		reward = 80,
	},
	{
		attr = "HotelSuitePurchased",
		ownerAttr = "HotelSuiteOwnerUserId",
		model = "CasinoTycoonHotelSuite",
		title = "HOTEL",
		offset = Vector3.new(10, 0, 12),
		reward = 45,
	},
}

local function getActiveService(plot, ownerId)
	for _, service in ipairs(services) do
		local room = plot:FindFirstChild(service.model)
		if room and plot:GetAttribute(service.attr) == true
			and tonumber(plot:GetAttribute(service.ownerAttr)) == ownerId then
			return service, room
		end
	end
	return nil
end

local function makeGuest(ownerId, plot, service)
	local description = Instance.new("HumanoidDescription")
	local skin = Color3.fromRGB(199, 153, 122)
	local jacketColors = {
		Color3.fromRGB(29, 32, 38),
		Color3.fromRGB(43, 54, 68),
		Color3.fromRGB(82, 35, 40),
		Color3.fromRGB(235, 231, 221),
	}
	local jacket = jacketColors[Random.new():NextInteger(1, #jacketColors)]
	description.HeadColor = skin
	description.LeftArmColor = skin
	description.RightArmColor = skin
	description.TorsoColor = jacket
	description.LeftLegColor = Color3.fromRGB(35, 36, 40)
	description.RightLegColor = Color3.fromRGB(35, 36, 40)

	local ok, guestOrError = pcall(function()
		return Players:CreateHumanoidModelFromDescriptionAsync(description, Enum.HumanoidRigType.R15)
	end)
	description:Destroy()
	if not ok then
		error("avatar creation failed: " .. tostring(guestOrError))
	end

	local guest = guestOrError
	guest.Name = "HotelGuest"
	guest:SetAttribute("VisitorForUserId", ownerId)
	guest:SetAttribute("VisitorForPlot", plot.Name)
	guest:SetAttribute("ServiceType", service.title)
	local humanoid = guest:FindFirstChildOfClass("Humanoid")
	local root = guest:FindFirstChild("HumanoidRootPart")
	local head = guest:FindFirstChild("Head")
	if not humanoid or not root or not head then
		guest:Destroy()
		error("generated guest is missing Humanoid, HumanoidRootPart, or Head")
	end
	humanoid.DisplayName = "Hotel Guest"
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.WalkSpeed = 10
	humanoid.JumpPower = 0
	humanoid.AutoRotate = true

	local badge = Instance.new("BillboardGui")
	badge.Name = "GuestBillboard"
	badge.Size = UDim2.fromOffset(176, 34)
	badge.StudsOffset = Vector3.new(0, 2.25, 0)
	badge.MaxDistance = 60
	badge.AlwaysOnTop = true
	badge.Parent = head

	local label = Instance.new("TextLabel")
	label.Name = "GuestMessage"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(22, 25, 31)
	label.BackgroundTransparency = 0.12
	label.TextColor3 = Color3.fromRGB(235, 197, 111)
	label.Font = Enum.Font.GothamSemibold
	label.TextScaled = true
	label.Text = service.title .. " GUEST"
	label.Parent = badge

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = label
	local outline = Instance.new("UIStroke")
	outline.Color = Color3.fromRGB(191, 151, 75)
	outline.Thickness = 1
	outline.Parent = label

	guest.Parent = guestsFolder
	return guest, humanoid, root
end

local function walkRoute(guest, humanoid, waypoints)
	for _, destination in ipairs(waypoints) do
		if not guest.Parent or humanoid.Health <= 0 then
			return false
		end
		local reached = false
		local connection = humanoid.MoveToFinished:Connect(function(success)
			reached = success
		end)
		humanoid:MoveTo(destination)
		local deadline = os.clock() + 9
		while not reached and os.clock() < deadline and guest.Parent do
			task.wait(0.15)
		end
		connection:Disconnect()
		if not reached then
			warn("CasinoTycoonGuests: guest route blocked near " .. tostring(destination))
			return false
		end
	end
	return true
end

local function runVisit(plot, ownerId, player, pad, service, room)
	local guest, humanoid, root = makeGuest(ownerId, plot, service)
	local spawnPosition = pad.CFrame:PointToWorldSpace(Vector3.new(0, pad.Size.Y / 2 + 3.2, -40))
	guest:PivotTo(CFrame.new(spawnPosition))

	local targetPosition = pad.CFrame:PointToWorldSpace(Vector3.new(
		service.offset.X,
		pad.Size.Y / 2 + 3.2,
		service.offset.Z - 6.5
	))
	local approachPosition = pad.CFrame:PointToWorldSpace(Vector3.new(
		service.offset.X,
		pad.Size.Y / 2 + 3.2,
		service.offset.Z - 10
	))
	if walkRoute(guest, humanoid, {approachPosition, targetPosition}) then
		task.wait(SERVICE_SECONDS)
		if player.Parent == Players
			and tonumber(plot:GetAttribute("OwnerUserId")) == ownerId
			and plot:GetAttribute(service.attr) == true
			and tonumber(plot:GetAttribute(service.ownerAttr)) == ownerId
			and room.Parent == plot then
			local stats = player:FindFirstChild("leaderstats")
			local cash = stats and stats:FindFirstChild("Cash")
			if cash and cash:IsA("IntValue") then
				cash.Value += service.reward
				player:SetAttribute("LastGuestService", service.title)
				player:SetAttribute("LastGuestReward", service.reward)
				guest:SetAttribute("ServiceCompleted", true)
				local message = guest:FindFirstChild("GuestMessage", true)
				if message and message:IsA("TextLabel") then
					message.Text = "+$" .. tostring(service.reward) .. " | " .. service.title .. " SERVED"
					message.TextColor3 = Color3.fromRGB(154, 226, 177)
				end
				task.wait(2)
			end
		end
	end
	guest:Destroy()
end

task.spawn(function()
	while true do
		task.wait(SPAWN_INTERVAL)
		for plotId = 1, 4 do
			local plot = plotsFolder:FindFirstChild("Plot_" .. plotId)
			local ownerId = plot and (tonumber(plot:GetAttribute("OwnerUserId")) or 0) or 0
			local player = ownerId > 0 and Players:GetPlayerByUserId(ownerId) or nil
			local pad = plot and plot:FindFirstChild("BuildablePad")
			local service, room
			if plot and ownerId > 0 then
				service, room = getActiveService(plot, ownerId)
			end
			if player and pad and pad:IsA("BasePart") and service and room
				and (activeByPlot[plot] or 0) < MAX_ACTIVE_PER_PLOT then
				activeByPlot[plot] = (activeByPlot[plot] or 0) + 1
				task.spawn(function()
					local ok, err = pcall(runVisit, plot, ownerId, player, pad, service, room)
					activeByPlot[plot] -= 1
					if not ok then
						warn("CasinoTycoonGuests: visit failed for " .. plot.Name .. ": " .. tostring(err))
					end
				end)
			end
		end
	end
end)
