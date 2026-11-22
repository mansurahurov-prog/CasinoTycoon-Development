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

local function createGuestAvatar(modelName)
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
	guest.Name = modelName
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

	return guest, humanoid, root, head
end

local function addGuestBadge(head, text, maxDistance)
	local badge = Instance.new("BillboardGui")
	badge.Name = "GuestBillboard"
	badge.Size = UDim2.fromOffset(176, 34)
	badge.StudsOffset = Vector3.new(0, 2.25, 0)
	badge.MaxDistance = maxDistance
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
	label.Text = text
	label.Parent = badge

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = label
	local outline = Instance.new("UIStroke")
	outline.Color = Color3.fromRGB(191, 151, 75)
	outline.Thickness = 1
	outline.Parent = label

	return label
end

local function makeGuest(ownerId, plot, service)
	local guest, humanoid, root, head = createGuestAvatar("HotelGuest")
	guest:SetAttribute("VisitorForUserId", ownerId)
	guest:SetAttribute("VisitorForPlot", plot.Name)
	guest:SetAttribute("ServiceType", service.title)
	addGuestBadge(head, service.title .. " GUEST", 60)

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

-- Front desk: interactive one-shot check-in cycle.
-- One reception guest walks into the lobby and waits at the counter. Any player
-- with loaded cash can serve the guest once through a ProximityPrompt. The guest
-- is never re-servable: the prompt is destroyed and the served flag is latched
-- before the reward is applied.
local RECEPTION_FIRST_DELAY = 14
local RECEPTION_INTERVAL = 35
local RECEPTION_JITTER = 10
local RECEPTION_REWARD = 60
local RECEPTION_COOLDOWN = 30
local RECEPTION_PATIENCE = 90
local RECEPTION_MAX_DISTANCE = 18
local RECEPTION_AWARD_CAP = 1000000000

local receptionCooldown = {}
local receptionBusy = false
local receptionGeometry
local receptionWarned = false

local function warnReceptionOnce(message)
	if receptionWarned then
		return
	end
	receptionWarned = true
	warn("CasinoTycoonGuests: " .. message)
end

local function getReceptionGeometry()
	if receptionGeometry then
		return receptionGeometry
	end
	local district = casino:FindFirstChild("CentralDistrict")
	local hotel = district and district:FindFirstChild("GrandCasinoHotel")
	local lobby = hotel and hotel:FindFirstChild("GrandLobby")
	local floor = lobby and lobby:FindFirstChild("LobbyMarbleFloor", true)
	local desk = lobby and lobby:FindFirstChild("DeskBody", true)
	if not (floor and desk and floor:IsA("BasePart") and desk:IsA("BasePart")) then
		warnReceptionOnce("reception floor or desk missing, front desk cycle disabled")
		return nil
	end

	local floorY = floor.Position.Y + floor.Size.Y / 2
	local x = desk.Position.X
	local standZ = desk.Position.Z - desk.Size.Z / 2 - 2.2
	local spawnZ = floor.Position.Z - floor.Size.Z / 2 + 3
	receptionGeometry = {
		floorY = floorY,
		standPoint = Vector3.new(x, floorY, standZ),
		midPoint = Vector3.new(x, floorY, spawnZ + (standZ - spawnZ) * 0.45),
		spawnPoint = Vector3.new(x, floorY + 3.1, spawnZ),
		exitPoint = Vector3.new(x, floorY, spawnZ - 1.5),
	}
	return receptionGeometry
end

local function resetReceptionLabel(state)
	state.label.Text = "HOTEL GUEST"
	state.label.TextColor3 = Color3.fromRGB(235, 197, 111)
end

local function flashReceptionLabel(state, text, color, seconds)
	if state.served or state.leaving then
		return
	end
	state.label.Text = text
	state.label.TextColor3 = color
	local token = {}
	state.token = token
	task.delay(seconds, function()
		if state.token == token and not state.served and not state.leaving
			and state.label.Parent then
			resetReceptionLabel(state)
		end
	end)
end

local function runReceptionVisit()
	local geometry = getReceptionGeometry()
	if not geometry then
		return
	end

	local guest, humanoid, root, head = createGuestAvatar("HotelReceptionGuest")
	guest:SetAttribute("GuestKind", "Reception")
	guest:SetAttribute("Served", false)
	local label = addGuestBadge(head, "HOTEL GUEST", 70)
	guest:PivotTo(CFrame.lookAt(geometry.spawnPoint, geometry.spawnPoint + Vector3.new(0, 0, 1)))
	guest.Parent = guestsFolder

	local state = { served = false, leaving = false, label = label }
	local prompt

	local function openPrompt()
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = "ReceptionPrompt"
		prompt.ObjectText = "Hotel Guest"
		prompt.ActionText = "Check in guest"
		prompt.HoldDuration = 0.8
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt.Exclusivity = Enum.ProximityPromptExclusivity.OneGlobal
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.GamepadKeyCode = Enum.KeyCode.ButtonX

		prompt.Triggered:Connect(function(player)
			if state.served or state.leaving or not guest.Parent then
				return
			end
			if player.Parent ~= Players then
				return
			end
			if player:GetAttribute("CashLoaded") ~= true then
				flashReceptionLabel(state, "PROFILE LOADING - TRY AGAIN", Color3.fromRGB(240, 190, 120), 2)
				return
			end
			local stats = player:FindFirstChild("leaderstats")
			local cash = stats and stats:FindFirstChild("Cash")
			if not cash or not cash:IsA("IntValue") then
				return
			end
			local character = player.Character
			local playerRoot = character and character:FindFirstChild("HumanoidRootPart")
			local playerHumanoid = character and character:FindFirstChildOfClass("Humanoid")
			if not playerRoot or not playerHumanoid or playerHumanoid.Health <= 0 then
				return
			end
			if (playerRoot.Position - root.Position).Magnitude > RECEPTION_MAX_DISTANCE then
				return
			end
			if (receptionCooldown[player] or 0) > os.clock() then
				flashReceptionLabel(state, "DESK BUSY - TRY AGAIN", Color3.fromRGB(240, 190, 120), 2)
				return
			end

			-- Latch first: a second trigger (or a duplicated signal) must never pay twice.
			state.served = true
			guest:SetAttribute("Served", true)
			prompt:Destroy()
			cash.Value = math.min(RECEPTION_AWARD_CAP, cash.Value + RECEPTION_REWARD)
			receptionCooldown[player] = os.clock() + RECEPTION_COOLDOWN
			-- Same-frame attribute writes can be coalesced before replication, so the
			-- HUD toast would not fire on a repeat check-in. Reset now, raise later.
			player:SetAttribute("LastGuestReward", 0)
			player:SetAttribute("LastGuestService", "HOTEL CHECK-IN")
			task.delay(0.1, function()
				if player.Parent == Players then
					player:SetAttribute("LastGuestReward", RECEPTION_REWARD)
				end
			end)
			state.label.Text = "+$" .. tostring(RECEPTION_REWARD) .. " | CHECK-IN COMPLETE"
			state.label.TextColor3 = Color3.fromRGB(154, 226, 177)
		end)

		prompt.Parent = root
	end

	local arrived = walkRoute(guest, humanoid, { geometry.midPoint, geometry.standPoint })
	if arrived and guest.Parent then
		local faceAt = geometry.standPoint + Vector3.new(0, 3.1, 0)
		humanoid.AutoRotate = false
		guest:PivotTo(CFrame.lookAt(faceAt, faceAt + Vector3.new(0, 0, 1)))
		openPrompt()
		local deadline = os.clock() + RECEPTION_PATIENCE
		while not state.served and guest.Parent and os.clock() < deadline do
			task.wait(0.25)
		end
		if state.served then
			task.wait(1.5)
		end
	end

	if guest.Parent then
		state.leaving = true
		if not state.served then
			state.label.Text = "NO CHECK-IN TODAY"
			state.label.TextColor3 = Color3.fromRGB(220, 170, 160)
		end
		if prompt then
			prompt:Destroy()
		end
		humanoid.AutoRotate = true
		walkRoute(guest, humanoid, { geometry.exitPoint })
	end
	guest:Destroy()
end

task.spawn(function()
	task.wait(RECEPTION_FIRST_DELAY)
	while true do
		if not receptionBusy then
			receptionBusy = true
			task.spawn(function()
				local ok, err = pcall(runReceptionVisit)
				receptionBusy = false
				if not ok then
					warn("CasinoTycoonGuests: reception visit failed: " .. tostring(err))
					for _, child in ipairs(guestsFolder:GetChildren()) do
						if child:GetAttribute("GuestKind") == "Reception" then
							child:Destroy()
						end
					end
				end
			end)
		end
		task.wait(RECEPTION_INTERVAL + Random.new():NextNumber(0, RECEPTION_JITTER))
	end
end)

Players.PlayerRemoving:Connect(function(player)
	receptionCooldown[player] = nil
end)
