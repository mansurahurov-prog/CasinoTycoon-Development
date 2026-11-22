-- Daily login bonus. Cash, plots and receipts are owned by CasinoTycoonData.
local Players = game:GetService("Players")
local Data = require(script.Parent:WaitForChild("CasinoTycoonData"))

local DAILY_BONUS = 250
local STREAK_STEP = 100
local MAX_STREAK = 5
local MAX_CASH = 1000000000

local function cashOf(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	local cash = leaderstats and leaderstats:FindFirstChild("Cash")
	if cash and cash:IsA("IntValue") then
		return cash
	end
	return nil
end

local function applyDaily(player)
	local profile = Data.WaitReady(player, 30)
	if not profile then
		return
	end

	local today = os.date("!%Y-%m-%d")
	local yesterday = os.date("!%Y-%m-%d", os.time() - 86400)
	local streak = tonumber(profile.StreakDays) or 0

	if profile.LastBonusDay == today then
		player:SetAttribute("DailyStreak", streak)
		return
	end

	if profile.LastBonusDay == yesterday then
		streak += 1
	else
		streak = 1
	end
	streak = math.clamp(streak, 1, MAX_STREAK)

	local reward = DAILY_BONUS + (streak - 1) * STREAK_STEP
	local cash = cashOf(player)
	if cash then
		cash.Value = math.min(MAX_CASH, cash.Value + reward)
	end

	profile.StreakDays = streak
	profile.LastBonusDay = today
	Data.MarkDirty(player)

	player:SetAttribute("DailyBonus", reward)
	player:SetAttribute("DailyStreak", streak)
end

Players.PlayerAdded:Connect(function(player)
	task.spawn(applyDaily, player)
end)

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(applyDaily, player)
end
