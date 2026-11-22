-- Milestone bonuses: one-time cash reward when a plot reaches a new tier.
local Players = game:GetService("Players")
local Data = require(script.Parent:WaitForChild("CasinoTycoonData"))
local plotsFolder = workspace:WaitForChild("CasinoTycoon"):WaitForChild("Plots")

local BONUSES = {
	{ attr = "HotelSuitePurchased", amount = 150, label = "SUITE" },
	{ attr = "HotelRestaurantPurchased", amount = 400, label = "RESTAURANT" },
	{ attr = "HotelSpaPurchased", amount = 1000, label = "SPA" },
}

local function getCash(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	local cash = leaderstats and leaderstats:FindFirstChild("Cash")
	if cash and cash:IsA("IntValue") then
		return cash
	end
	return nil
end

local function award(plot, bonus)
	local ownerId = tonumber(plot:GetAttribute("OwnerUserId")) or 0
	if ownerId <= 0 then
		return
	end
	local player = Players:GetPlayerByUserId(ownerId)
	local cash = player and getCash(player)
	if not cash then
		return
	end
	cash.Value += bonus.amount
	player:SetAttribute("LastBonusLabel", bonus.label)
	player:SetAttribute("LastBonusAmount", bonus.amount)
	print("CasinoTycoonMilestones: " .. player.Name .. " +$" .. bonus.amount .. " for " .. bonus.label)
end

local function watchPlot(plot)
	for _, bonus in ipairs(BONUSES) do
		local alreadyReached = plot:GetAttribute(bonus.attr) == true
		plot:GetAttributeChangedSignal(bonus.attr):Connect(function()
			if alreadyReached then
				return
			end
			if plot:GetAttribute(bonus.attr) ~= true then
				return
			end
			alreadyReached = true
			local ownerId = tonumber(plot:GetAttribute("OwnerUserId")) or 0
			local owner = ownerId > 0 and Players:GetPlayerByUserId(ownerId) or nil
			if owner and owner:GetAttribute("RestoringPlot") == true then
				Data.SetMilestone(owner, bonus.attr)
				return
			end
			if owner and not Data.ClaimMilestone(owner, bonus.attr) then
				return
			end
			award(plot, bonus)
		end)
	end
end

for plotId = 1, 4 do
	local plot = plotsFolder:FindFirstChild("Plot_" .. plotId)
	if plot then
		watchPlot(plot)
	else
		warn("CasinoTycoonMilestones: Plot_" .. plotId .. " missing")
	end
end
