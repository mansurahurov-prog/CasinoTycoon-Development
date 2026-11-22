local Players = game:GetService("Players")
local Data = require(script.Parent:WaitForChild("CasinoTycoonData"))

local plotsFolder = workspace:WaitForChild("CasinoTycoon"):WaitForChild("Plots")
local plots = plotsFolder:GetChildren()
table.sort(plots, function(a, b)
	return a.Name < b.Name
end)

local owners = {}

local QUEUE_ENABLED_DEFAULT = false
local waiting = {}
local claiming = {}

local function queueEnabled()
	return plotsFolder:GetAttribute("PlotQueueEnabled") == true or QUEUE_ENABLED_DEFAULT
end

local function dropFromQueue(player)
	for index = #waiting, 1, -1 do
		if waiting[index] == player then
			table.remove(waiting, index)
		end
	end
	player:SetAttribute("PlotQueuePosition", nil)
end

local function refreshQueuePositions()
	for index, queued in ipairs(waiting) do
		if queued.Parent then
			queued:SetAttribute("PlotQueuePosition", index)
		end
	end
end

local function updateSign(plot, playerName)
	local sign = plot:FindFirstChild("NameSign")
	if not sign then
		return
	end

	local board = sign:FindFirstChild("OwnerBoard")
	if not board then
		board = Instance.new("BillboardGui")
		board.Name = "OwnerBoard"
		board.Size = UDim2.fromOffset(250, 72)
		board.StudsOffset = Vector3.new(0, 6, 0)
		board.AlwaysOnTop = true
		board.Parent = sign

		local label = Instance.new("TextLabel")
		label.Name = "OwnerName"
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundColor3 = Color3.fromRGB(13, 13, 16)
		label.BackgroundTransparency = 0.12
		label.BorderSizePixel = 0
		label.Font = Enum.Font.GothamBold
		label.TextColor3 = Color3.fromRGB(255, 218, 130)
		label.TextScaled = true
		label.TextStrokeTransparency = 0.7
		label.Parent = board
	end

	local label = board:FindFirstChild("OwnerName")
	if label then
		label.Text = playerName and (playerName .. "'s PLOT") or "AVAILABLE"
	end
end

local function plotById(plotId)
	local wanted = tostring(plotId)
	for _, plot in ipairs(plots) do
		if tostring(plot:GetAttribute("PlotId")) == wanted then
			return plot
		end
	end
	return nil
end

local function ownedPlotOf(player)
	local plot = plotById(player:GetAttribute("PlotId"))
	if plot and owners[plot] == player then
		return plot
	end
	for candidate, owner in pairs(owners) do
		if owner == player then
			return candidate
		end
	end
	return nil
end

local function bindPlot(player, plot)
	if not player.Parent then
		return nil
	end
	owners[plot] = player
	plot:SetAttribute("OwnerUserId", player.UserId)
	plot:SetAttribute("OwnerName", player.Name)
	player:SetAttribute("PlotId", plot:GetAttribute("PlotId"))
	player:SetAttribute("PlotName", plot.Name)
	updateSign(plot, player.Name)
	dropFromQueue(player)

	local profile = Data.Get(player)
	local plotId = tostring(plot:GetAttribute("PlotId"))
	local snapshot = profile and profile.Plots and profile.Plots[plotId]
	if snapshot then
		Data.ApplyPlot(player, plot, snapshot)
	end
	return plot
end

local function assignPlot(player, fromQueue)
	if not player.Parent or owners[plotById(player:GetAttribute("PlotId"))] == player then
		return nil
	end
	claiming[player] = claiming[player] or 0
	if claiming[player] > 0 then
		return nil
	end
	claiming[player] = 1

	local profile = Data.WaitReady(player, 25)
	if profile and type(profile.Plots) == "table" then
		local savedIds = {}
		for plotId in pairs(profile.Plots) do
			table.insert(savedIds, tostring(plotId))
		end
		table.sort(savedIds)
		for _, plotId in ipairs(savedIds) do
			local plot = plotById(plotId)
			if plot and owners[plot] == nil then
				claiming[player] = 0
				return bindPlot(player, plot)
			end
		end
	end

	for _, plot in ipairs(plots) do
		if owners[plot] == nil then
			claiming[player] = 0
			return bindPlot(player, plot)
		end
	end
	claiming[player] = 0

	if not fromQueue and queueEnabled() and not table.find(waiting, player) then
		table.insert(waiting, player)
		refreshQueuePositions()
	end
	warn("No available casino construction plot for " .. player.Name)
	return nil
end

local function offerNextPlot()
	if not queueEnabled() then
		return
	end
	while #waiting > 0 do
		local nextPlayer = table.remove(waiting, 1)
		if nextPlayer.Parent then
			if assignPlot(nextPlayer, true) then
				refreshQueuePositions()
				return
			end
		end
	end
	refreshQueuePositions()
end

local function clearPlotDecor(plot)
	local decor = plot:FindFirstChild("PlotDecor_Upgrade")
	if decor then
		decor:Destroy()
	end
	if plot:GetAttribute("DecorTier") ~= nil then
		plot:SetAttribute("DecorTier", 0)
	end
end
local function releasePlot(player)
	local plot = ownedPlotOf(player)
	if plot then
		owners[plot] = nil
		plot:SetAttribute("OwnerUserId", 0)
		plot:SetAttribute("OwnerName", "")
		updateSign(plot, nil)
		clearPlotDecor(plot)
	end
	player:SetAttribute("PlotId", nil)
	player:SetAttribute("PlotName", nil)
end

for _, plot in ipairs(plots) do
	plot:SetAttribute("OwnerUserId", 0)
	plot:SetAttribute("OwnerName", "")
	updateSign(plot, nil)
	clearPlotDecor(plot)
end

Players.PlayerAdded:Connect(function(player)
	task.spawn(assignPlot, player, false)
end)

Players.PlayerRemoving:Connect(function(player)
	dropFromQueue(player)
	local plot = ownedPlotOf(player)
	if plot then
		local ok, err = pcall(function()
			Data.SetPlotSnapshot(player, plot:GetAttribute("PlotId"), Data.SnapshotPlot(plot))
		end)
		if not ok then
			warn("PlotOwnership: snapshot failed for " .. player.Name .. ": " .. tostring(err))
		end
	end
	releasePlot(player)
	task.spawn(function()
		local saved, err = pcall(Data.SaveAndRelease, player)
		if not saved then
			warn("PlotOwnership: save failed for " .. player.Name .. ": " .. tostring(err))
		end
	end)
	offerNextPlot()
end)

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(assignPlot, player, false)
end
