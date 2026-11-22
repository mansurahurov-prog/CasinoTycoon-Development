-- VIP game pass: refreshes ownership and exposes it as a player attribute.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local config = require(ReplicatedStorage:WaitForChild("CasinoTycoonShopConfig"))
local vipId = tonumber((config.GamePasses or {}).vip) or 0

local function refresh(player)
	if vipId <= 0 then
		player:SetAttribute("VipActive", false)
		return
	end
	local ok, owns = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, vipId)
	end)
	if ok then
		player:SetAttribute("VipActive", owns == true)
	end
end

Players.PlayerAdded:Connect(function(player)
	task.delay(3, refresh, player)
end)

for _, player in ipairs(Players:GetPlayers()) do
	task.delay(3, refresh, player)
end

task.spawn(function()
	while true do
		task.wait(300)
		for _, player in ipairs(Players:GetPlayers()) do
			refresh(player)
		end
	end
end)
