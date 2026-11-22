-- Fountain wish: touching the fountain pays a small tip with a per-player cooldown.
local Players = game:GetService("Players")
local district = workspace:WaitForChild("CasinoTycoon"):WaitForChild("CentralDistrict")
local fountain = district:WaitForChild("FountainTipTrigger", 20)
if not fountain then
	warn("CasinoTycoonFountainTip: trigger volume missing")
	return
end

local TIP_AMOUNT = 25
local COOLDOWN = 60
local cooldowns = {}

local function getCash(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	local cash = leaderstats and leaderstats:FindFirstChild("Cash")
	if cash and cash:IsA("IntValue") then
		return cash
	end
	return nil
end

fountain.Touched:Connect(function(hit)
	local character = hit:FindFirstAncestorOfClass("Model")
	local player = character and Players:GetPlayerFromCharacter(character)
	if not player then
		return
	end

	local now = os.clock()
	local last = cooldowns[player]
	if last and now - last < COOLDOWN then
		return
	end

	local cash = getCash(player)
	if not cash then
		return
	end

	cooldowns[player] = now
	cash.Value += TIP_AMOUNT
	player:SetAttribute("FountainTipCount", (tonumber(player:GetAttribute("FountainTipCount")) or 0) + 1)
end)

Players.PlayerRemoving:Connect(function(player)
	cooldowns[player] = nil
end)
