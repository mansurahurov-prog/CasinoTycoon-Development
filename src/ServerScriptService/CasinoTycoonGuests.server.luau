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

-- Front desk: hotel service queue (v1).
-- Three guest types, four request types, a three-slot queue in front of the
-- lobby desk, a patience timer with live visual feedback, type/quality-scaled
-- rewards and a per-player desk upgrade (DeskLevel 0-3) persisted through
-- CasinoTycoonData. Every payout is latched before it is credited, so a guest
-- can never be served twice. The plot guest loop above is untouched.
local ServerScriptService = game:GetService("ServerScriptService")

local RECEPTION_FIRST_DELAY = 14
local RECEPTION_INTERVAL = 16
local RECEPTION_JITTER = 8
local RECEPTION_RETRY = 6
local RECEPTION_MAX_DISTANCE = 18
local RECEPTION_AWARD_CAP = 1000000000
local RECEPTION_TRIGGER_COOLDOWN = 1
local QUEUE_TICK = 0.25

local QUEUE_OFFSETS = { -6, 0, 6 }
local QUEUE_SIZE = #QUEUE_OFFSETS

local GUEST_TYPES = {
	{
		id = "Regular",
		label = "GUEST",
		hold = 0.8,
		patience = 45,
		multiplier = 1,
		color = Color3.fromRGB(235, 197, 111),
	},
	{
		id = "VIP",
		label = "VIP GUEST",
		hold = 1,
		patience = 32,
		multiplier = 1.35,
		color = Color3.fromRGB(246, 214, 120),
	},
	{
		id = "Demanding",
		label = "DEMANDING",
		hold = 1.4,
		patience = 22,
		multiplier = 1.2,
		color = Color3.fromRGB(238, 150, 120),
	},
}

local REQUESTS = {
	{ id = "CHECK_IN", text = "CHECK IN", base = 60 },
	{ id = "RESTAURANT", text = "RESTAURANT", base = 80 },
	{ id = "SPA", text = "SPA", base = 110 },
	{ id = "VIP_CONCIERGE", text = "VIP CONCIERGE", base = 150 },
}

local DESK_MAX_LEVEL = 3
local DESK_COSTS = { 400, 1200, 3000 }
local DESK_INCOME_PER_LEVEL = 0.15
local DESK_SPEED_PER_LEVEL = 0.15
local DESK_MAX_DISTANCE = 14

local receptionGeometry
local receptionWarned = false

-- CasinoTycoonData owns persistence; the guest script only reads/writes the
-- DeskLevel field through it. If the module is unavailable (partial place
-- load) the desk falls back to the player attribute for the current session.
local Data
do
	local dataModule = ServerScriptService:FindFirstChild("CasinoTycoonData")
	if dataModule and dataModule:IsA("ModuleScript") then
		local ok, result = pcall(require, dataModule)
		if ok and type(result) == "table" then
			Data = result
		else
			warn("CasinoTycoonGuests: CasinoTycoonData unavailable - desk level is session-only")
		end
	end
end

local function deskLevelOf(player)
	if Data and Data.GetDeskLevel then
		local level = Data.GetDeskLevel(player)
		if level then
			return level
		end
	end
	return math.clamp(tonumber(player:GetAttribute("DeskLevel")) or 0, 0, DESK_MAX_LEVEL)
end

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
		lobby = lobby,
	}
	return receptionGeometry
end

local receptionQueue = {}
local receptionPending = 0
local serveCooldown = {}
local upgradeCooldown = {}
local purchasing = {}
local deskStation
local stationToken

local function queueIndexIn(queue, state)
	for index, candidate in ipairs(queue) do
		if candidate == state then
			return index
		end
	end
	return nil
end

local function queueIndexOf(state)
	return queueIndexIn(receptionQueue, state)
end

-- Capacity counts guests that already hold a slot and guests still being built
-- (avatar creation yields), so the spawner can never overshoot QUEUE_SIZE.
local function hasQueueCapacity(queueLength, pending, size)
	return queueLength + pending < size
end

-- Remove one guest without touching the others; survivors keep their relative
-- order and simply re-derive their index on the next tick.
local function queueRemove(queue, state)
	local index = queueIndexIn(queue, state)
	if index then
		table.remove(queue, index)
	end
	return index
end

-- Patience is measured from the first slot the guest takes. Walking forward in
-- the queue must never restart the clock.
local function ensureArrivalTime(state, now)
	if state.arrivedAt == nil then
		state.arrivedAt = now
	end
	return state.arrivedAt
end

local function queueSlotPoint(geometry, index)
	local offset = QUEUE_OFFSETS[math.clamp(index, 1, QUEUE_SIZE)] or 0
	return Vector3.new(geometry.standPoint.X + offset, geometry.floorY, geometry.standPoint.Z)
end

local function createServiceBadge(head, guestType)
	local badge = Instance.new("BillboardGui")
	badge.Name = "GuestBillboard"
	badge.Size = UDim2.fromOffset(228, 64)
	badge.StudsOffset = Vector3.new(0, 2.6, 0)
	badge.MaxDistance = 80
	badge.AlwaysOnTop = true

	local title = Instance.new("TextLabel")
	title.Name = "GuestTitle"
	title.Size = UDim2.new(1, 0, 0.46, 0)
	title.BackgroundColor3 = Color3.fromRGB(22, 25, 31)
	title.BackgroundTransparency = 0.12
	title.TextColor3 = guestType.color
	title.Font = Enum.Font.GothamSemibold
	title.TextScaled = true
	title.Text = guestType.label
	title.Parent = badge

	local titleCorner = Instance.new("UICorner")
	titleCorner.CornerRadius = UDim.new(0, 6)
	titleCorner.Parent = title
	local titleStroke = Instance.new("UIStroke")
	titleStroke.Color = Color3.fromRGB(191, 151, 75)
	titleStroke.Thickness = 1
	titleStroke.Parent = title

	local status = Instance.new("TextLabel")
	status.Name = "GuestStatus"
	status.Position = UDim2.new(0, 0, 0.5, 0)
	status.Size = UDim2.new(1, 0, 0.28, 0)
	status.BackgroundTransparency = 1
	status.TextColor3 = Color3.fromRGB(226, 226, 226)
	status.Font = Enum.Font.Gotham
	status.TextScaled = true
	status.Text = "WALKING IN"
	status.Parent = badge

	local barBack = Instance.new("Frame")
	barBack.Name = "PatienceBack"
	barBack.Position = UDim2.new(0, 8, 1, -12)
	barBack.Size = UDim2.new(1, -16, 0, 6)
	barBack.BackgroundColor3 = Color3.fromRGB(40, 44, 52)
	barBack.BorderSizePixel = 0
	barBack.Parent = badge

	local bar = Instance.new("Frame")
	bar.Name = "Patience"
	bar.Size = UDim2.fromScale(1, 1)
	bar.BackgroundColor3 = Color3.fromRGB(120, 210, 140)
	bar.BorderSizePixel = 0
	bar.Parent = barBack

	local barCorner = Instance.new("UICorner")
	barCorner.CornerRadius = UDim.new(0, 3)
	barCorner.Parent = barBack

	badge.Parent = head
	return { badge = badge, title = title, status = status, bar = bar }
end

local guestRng = Random.new()

local function pickGuestType()
	local roll = guestRng:NextNumber()
	if roll < 0.18 then
		return GUEST_TYPES[2]
	elseif roll < 0.42 then
		return GUEST_TYPES[3]
	end
	return GUEST_TYPES[1]
end

local function pickRequest(guestType)
	if guestType.id == "VIP" and guestRng:NextNumber() < 0.6 then
		return REQUESTS[4]
	end
	return REQUESTS[guestRng:NextInteger(1, #REQUESTS)]
end

local function qualityFor(elapsed, patience)
	local ratio = elapsed / math.max(patience, 1)
	if ratio <= 0.4 then
		return 1, "PERFECT"
	elseif ratio <= 0.7 then
		return 0.75, "GOOD"
	elseif ratio < 1 then
		return 0.5, "LATE"
	end
	return 0, nil
end

local function rewardFor(state, quality, deskLevel)
	local value = state.request.base * state.guestType.multiplier * quality
		* (1 + DESK_INCOME_PER_LEVEL * deskLevel)
	return math.clamp(math.floor(value + 0.5), 0, RECEPTION_AWARD_CAP)
end

-- Hold time is a property of the guest, not of whoever stands nearby, so it is
-- identical for every player at the counter. The desk speed bonus is applied to
-- the serving player's own timing instead (see effectiveWait).
local function holdDurationFor(guestType)
	return math.max(0.25, guestType.hold)
end

-- Desk speed (DeskLevel) shortens the service time of the player who owns that
-- level: the guest is processed faster, so less of its patience is consumed.
-- Called only with the level of the player who is serving and being paid.
local function effectiveWait(elapsed, deskLevel)
	if elapsed <= 0 then
		return 0
	end
	return elapsed / (1 + DESK_SPEED_PER_LEVEL * deskLevel)
end

local function flashStatus(state, text, color)
	if state.served or state.leaving then
		return
	end
	state.flashUntil = os.clock() + 2
	state.ui.status.Text = text
	state.ui.status.TextColor3 = color
end

local function updateGuestVisual(state, elapsed)
	if state.served or state.leaving then
		return
	end
	local patience = state.guestType.patience
	local remaining = math.max(0, patience - elapsed)
	local ratio = math.clamp(remaining / patience, 0, 1)
	state.ui.bar.Size = UDim2.fromScale(ratio, 1)
	if ratio > 0.7 then
		state.ui.bar.BackgroundColor3 = Color3.fromRGB(120, 210, 140)
	elseif ratio > 0.4 then
		state.ui.bar.BackgroundColor3 = Color3.fromRGB(240, 196, 110)
	else
		state.ui.bar.BackgroundColor3 = Color3.fromRGB(226, 110, 100)
	end

	local index = queueIndexOf(state) or 0
	local prefix
	if index == 1 then
		prefix = "HOLD E TO SERVE"
	elseif index > 1 then
		prefix = "WAITING #" .. tostring(index)
	else
		prefix = "LEAVING"
	end
	if (state.flashUntil or 0) > os.clock() then
		return
	end
	state.ui.status.Text = string.format("%s - %ds", prefix, math.ceil(remaining))
	if index == 1 then
		state.ui.status.TextColor3 = Color3.fromRGB(154, 226, 177)
	else
		state.ui.status.TextColor3 = Color3.fromRGB(212, 212, 212)
	end
end

local function openPromptFor(state)
	if state.prompt or state.served or state.leaving or not state.guest.Parent then
		return
	end
	if queueIndexOf(state) ~= 1 then
		return
	end

	local guestType = state.guestType
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ReceptionPrompt"
	prompt.ObjectText = guestType.label .. " - " .. state.request.text
	prompt.ActionText = "Serve guest"
	prompt.HoldDuration = holdDurationFor(guestType)
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	state.prompt = prompt

	prompt.Triggered:Connect(function(player)
		if state.served or state.leaving or not state.guest.Parent then
			return
		end
		if queueIndexOf(state) ~= 1 then
			return
		end
		if player.Parent ~= Players then
			return
		end
		if player:GetAttribute("CashLoaded") ~= true then
			flashStatus(state, "PROFILE LOADING - TRY AGAIN", Color3.fromRGB(240, 190, 120))
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
		if (playerRoot.Position - state.root.Position).Magnitude > RECEPTION_MAX_DISTANCE then
			return
		end
		if (serveCooldown[player] or 0) > os.clock() then
			flashStatus(state, "DESK BUSY - TRY AGAIN", Color3.fromRGB(240, 190, 120))
			return
		end

		local deskLevel = deskLevelOf(player)
		local elapsed = os.clock() - (state.arrivedAt or os.clock())
		-- Both the speed bonus and the income bonus come from this same player.
		local quality, rating = qualityFor(effectiveWait(elapsed, deskLevel), guestType.patience)
		if quality <= 0 then
			return
		end
		local reward = rewardFor(state, quality, deskLevel)

		-- Latch first: a duplicated signal, a second player or a replayed
		-- trigger must never pay the same guest twice.
		state.served = true
		state.rating = rating
		state.reward = reward
		serveCooldown[player] = os.clock() + RECEPTION_TRIGGER_COOLDOWN
		state.guest:SetAttribute("Served", true)
		state.guest:SetAttribute("ServedByUserId", player.UserId)
		state.guest:SetAttribute("ServedReward", reward)
		if state.prompt then
			state.prompt:Destroy()
			state.prompt = nil
		end
		state.ui.title.Text = "+$" .. tostring(reward) .. " | " .. tostring(rating)
		state.ui.title.TextColor3 = Color3.fromRGB(154, 226, 177)
		state.ui.status.Text = guestType.label .. " SERVED - DESK LV " .. tostring(deskLevel)
		state.ui.status.TextColor3 = Color3.fromRGB(154, 226, 177)
		state.ui.bar.Size = UDim2.fromScale(0, 1)

		cash.Value = math.min(RECEPTION_AWARD_CAP, cash.Value + reward)
		player:SetAttribute("LastGuestService", state.request.text .. " " .. tostring(rating))
		-- Same-frame attribute writes can be coalesced before replication, so
		-- the HUD toast would not fire on a repeat payout. Reset now, raise later.
		player:SetAttribute("LastGuestReward", 0)
		task.delay(0.1, function()
			if player.Parent == Players then
				player:SetAttribute("LastGuestReward", reward)
			end
		end)
	end)

	prompt.Parent = state.root
end

local function buildServiceGuest(geometry)
	local guestType = pickGuestType()
	local request = pickRequest(guestType)
	local guest, humanoid, root, head = createGuestAvatar("HotelReceptionGuest")
	guest:SetAttribute("GuestKind", "Reception")
	guest:SetAttribute("GuestType", guestType.id)
	guest:SetAttribute("GuestRequest", request.id)
	guest:SetAttribute("Served", false)

	local ui = createServiceBadge(head, guestType)
	ui.title.Text = guestType.label .. " | " .. request.text

	local state = {
		guest = guest,
		humanoid = humanoid,
		root = root,
		ui = ui,
		guestType = guestType,
		request = request,
		geometry = geometry,
		slot = 0,
		served = false,
		leaving = false,
		arrivedAt = nil,
		rating = nil,
		reward = 0,
	}

	guest:PivotTo(CFrame.lookAt(geometry.spawnPoint, geometry.spawnPoint + Vector3.new(0, 0, 1)))
	guest.Parent = guestsFolder
	receptionQueue[#receptionQueue + 1] = state
	return state
end

local function serveServiceGuest(state)
	local geometry = state.geometry
	local guest, humanoid, root = state.guest, state.humanoid, state.root

	if not walkRoute(guest, humanoid, { geometry.midPoint }) then
		error("guest could not reach the lobby")
	end

	while guest.Parent do
		if state.served then
			break
		end
		local index = queueIndexOf(state)
		if not index then
			break
		end
		if state.slot ~= index then
			state.slot = index
			if not walkRoute(guest, humanoid, { queueSlotPoint(geometry, index) }) then
				error("queue slot " .. tostring(index) .. " is blocked")
			end
			ensureArrivalTime(state, os.clock())
		end
		if state.leaving then
			break
		end
		local elapsed = state.arrivedAt and (os.clock() - state.arrivedAt) or 0
		if state.arrivedAt and elapsed >= state.guestType.patience then
			-- Checked before the prompt opens: a guest that ran out of patience
			-- while walking forward must never be offered to a player.
			break
		end
		if index == 1 and not state.faced and not state.served then
			-- Face the desk once; repeated pivots would restart walk animations.
			state.faced = true
			humanoid.AutoRotate = false
			local position = root.Position
			guest:PivotTo(CFrame.lookAt(position, position + Vector3.new(0, 0, 1)))
		end
		openPromptFor(state)
		updateGuestVisual(state, elapsed)
		task.wait(QUEUE_TICK)
	end

	state.leaving = true
	queueRemove(receptionQueue, state)
	if state.prompt then
		state.prompt:Destroy()
		state.prompt = nil
	end
	if state.served then
		task.wait(1.2)
	end

	if guest.Parent then
		humanoid.AutoRotate = true
		if not state.served then
			state.ui.title.Text = state.guestType.label .. " | NO SERVICE"
			state.ui.title.TextColor3 = Color3.fromRGB(220, 170, 160)
			state.ui.status.Text = "LEFT THE QUEUE"
			state.ui.status.TextColor3 = Color3.fromRGB(220, 170, 160)
			state.ui.bar.Size = UDim2.fromScale(0, 1)
		end
		walkRoute(guest, humanoid, {
			Vector3.new(root.Position.X, geometry.floorY, geometry.standPoint.Z - 5),
			geometry.midPoint,
			geometry.exitPoint,
		})
	end
	guest:Destroy()
end

local function cleanupServiceGuest(state)
	if not state then
		return
	end
	state.leaving = true
	queueRemove(receptionQueue, state)
	if state.prompt then
		state.prompt:Destroy()
		state.prompt = nil
	end
	if state.guest and state.guest.Parent then
		state.guest:Destroy()
	end
end

-- Capacity is reserved *before* the avatar is created: createGuestAvatar yields
-- (Players:CreateHumanoidModelFromDescriptionAsync), so without the reservation
-- a slow avatar service would let the spawner start more than three guests.
local function startServiceGuest(geometry)
	receptionPending += 1
	local built, state = pcall(buildServiceGuest, geometry)
	receptionPending -= 1
	if not built then
		warn("CasinoTycoonGuests: reception guest failed: " .. tostring(state))
		return
	end
	local served, err = pcall(serveServiceGuest, state)
	if not served then
		warn("CasinoTycoonGuests: reception service failed: " .. tostring(err))
	end
	cleanupServiceGuest(state)
end

local STATION_TEXT = "RECEPTION DESK\nUPGRADE +15% INCOME"
local STATION_COLOR = Color3.fromRGB(235, 197, 111)

local function ensureDeskStation(geometry)
	if deskStation and deskStation.Parent then
		return deskStation
	end
	local station = Instance.new("Model")
	station.Name = "ReceptionDeskUpgrade"

	local body = Instance.new("Part")
	body.Name = "ButtonPart"
	body.Size = Vector3.new(3, 3, 3)
	body.Position = Vector3.new(
		geometry.standPoint.X + 16,
		geometry.floorY + 1.5,
		geometry.standPoint.Z + 1
	)
	body.Anchored = true
	body.CanCollide = true
	body.Material = Enum.Material.Metal
	body.Color = Color3.fromRGB(124, 96, 56)
	body.TopSurface = Enum.SurfaceType.Smooth
	body.Parent = station

	local badge = Instance.new("BillboardGui")
	badge.Name = "DeskSign"
	badge.Size = UDim2.fromOffset(210, 52)
	badge.StudsOffset = Vector3.new(0, 2.6, 0)
	badge.MaxDistance = 60
	badge.AlwaysOnTop = true
	badge.Parent = body

	local label = Instance.new("TextLabel")
	label.Name = "DeskLabel"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(22, 25, 31)
	label.BackgroundTransparency = 0.15
	label.TextColor3 = STATION_COLOR
	label.Font = Enum.Font.GothamSemibold
	label.TextScaled = true
	label.Text = STATION_TEXT
	label.Parent = badge

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = label

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "DeskUpgradePrompt"
	prompt.ObjectText = "Reception Desk"
	prompt.ActionText = "Upgrade desk"
	prompt.HoldDuration = 0.4
	prompt.MaxActivationDistance = DESK_MAX_DISTANCE
	prompt.RequiresLineOfSight = false
	prompt.Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.Parent = body

	local function flash(text, color, seconds)
		label.Text = text
		label.TextColor3 = color or STATION_COLOR
		local token = {}
		stationToken = token
		task.delay(seconds or 2, function()
			if stationToken == token and label.Parent then
				label.Text = STATION_TEXT
				label.TextColor3 = STATION_COLOR
			end
		end)
	end

	prompt.Triggered:Connect(function(player)
		if player.Parent ~= Players then
			return
		end
		if player:GetAttribute("CashLoaded") ~= true then
			flash("PROFILE LOADING - TRY AGAIN", Color3.fromRGB(240, 190, 120), 2)
			return
		end
		if player:GetAttribute("DataReadOnly") == true then
			-- A read-only profile could take cash that can never be stored.
			flash("PROFILE READ-ONLY - DESK LOCKED", Color3.fromRGB(240, 190, 120), 2.5)
			return
		end
		local character = player.Character
		local playerRoot = character and character:FindFirstChild("HumanoidRootPart")
		if not playerRoot or (playerRoot.Position - body.Position).Magnitude > DESK_MAX_DISTANCE + 2 then
			return
		end
		if (upgradeCooldown[player] or 0) > os.clock() or purchasing[player] then
			return
		end
		local stats = player:FindFirstChild("leaderstats")
		local cash = stats and stats:FindFirstChild("Cash")
		if not cash or not cash:IsA("IntValue") then
			return
		end
		local level = deskLevelOf(player)
		if level >= DESK_MAX_LEVEL then
			flash("DESK LEVEL MAX", Color3.fromRGB(154, 226, 177), 2)
			return
		end
		local cost = DESK_COSTS[level + 1]
		if cash.Value < cost then
			flash("NEED $" .. tostring(cost) .. " FOR DESK " .. tostring(level + 1), Color3.fromRGB(240, 190, 120), 2.5)
			return
		end
		if not (Data and Data.PurchaseDeskUpgrade) then
			-- Without the profile module the money could not be tracked at all.
			flash("PROFILE UNAVAILABLE - DESK LOCKED", Color3.fromRGB(240, 190, 120), 2.5)
			return
		end

		upgradeCooldown[player] = os.clock() + 2
		purchasing[player] = true
		-- Charge and write happen inside the data module: cash and DeskLevel go
		-- out in one payload and the level is granted only after that write is
		-- confirmed. On failure both the profile field and leaderstats cash are
		-- restored, so no money is kept without a stored upgrade.
		local ok, result, persisted = Data.PurchaseDeskUpgrade(player, cost, DESK_MAX_LEVEL)
		purchasing[player] = nil
		if not ok then
			if result == "SaveFailed" then
				flash("SAVE FAILED - NOT CHARGED", Color3.fromRGB(240, 190, 120), 3)
			elseif result == "NotEnoughCash" then
				flash("NEED $" .. tostring(cost), Color3.fromRGB(240, 190, 120), 2.5)
			elseif result == "MaxLevel" then
				flash("DESK LEVEL MAX", Color3.fromRGB(154, 226, 177), 2)
			else
				flash("UPGRADE UNAVAILABLE - TRY AGAIN", Color3.fromRGB(240, 190, 120), 2.5)
			end
			return
		end
		player:SetAttribute("DeskLevel", result)
		local persistent = Data.IsPersistent and Data.IsPersistent()
		if not persisted then
			-- The write reply was lost: the level is already applied locally and
			-- the next autosave stores it, so never call this refunded.
			flash("DESK LV " .. tostring(result) .. " - SAVING...", Color3.fromRGB(240, 190, 120), 3)
		elseif persistent then
			flash("DESK LV " .. tostring(result) .. " SAVED", Color3.fromRGB(154, 226, 177), 2.5)
		else
			flash("DESK LV " .. tostring(result) .. " (SESSION ONLY)", Color3.fromRGB(154, 226, 177), 2.5)
		end
	end)

	station.PrimaryPart = body
	station.Parent = geometry.lobby or casino
	deskStation = station
	return station
end

-- Drop guests left over from an earlier server (or a previous run in Studio).
for _, child in ipairs(guestsFolder:GetChildren()) do
	if child:GetAttribute("GuestKind") == "Reception" then
		child:Destroy()
	end
end

task.spawn(function()
	local geometry = getReceptionGeometry()
	if geometry then
		ensureDeskStation(geometry)
	end
end)

task.spawn(function()
	task.wait(RECEPTION_FIRST_DELAY)
	while true do
		local geometry = getReceptionGeometry()
		if not geometry then
			task.wait(RECEPTION_RETRY)
		else
			ensureDeskStation(geometry)
			if #Players:GetPlayers() > 0 and hasQueueCapacity(#receptionQueue, receptionPending, QUEUE_SIZE) then
				task.spawn(startServiceGuest, geometry)
				task.wait(RECEPTION_INTERVAL + Random.new():NextNumber(0, RECEPTION_JITTER))
			else
				task.wait(RECEPTION_RETRY)
			end
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	serveCooldown[player] = nil
	upgradeCooldown[player] = nil
	purchasing[player] = nil
end)
