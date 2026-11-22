-- Developer Product fulfillment for chip packs.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local config = require(ReplicatedStorage:WaitForChild("CasinoTycoonShopConfig"))

local grants = {}
for _, product in ipairs(config.Products or {}) do
	local id = tonumber(product.id)
	if id and id > 0 then
		grants[id] = tonumber(product.cash) or 0
	end
end

local processed = {}

local function getCash(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	local cash = leaderstats and leaderstats:FindFirstChild("Cash")
	if cash and cash:IsA("IntValue") then
		return cash
	end
	return nil
end

MarketplaceService.ProcessReceipt = function(receiptInfo)
	local purchaseId = tostring(receiptInfo.PurchaseId)
	if processed[purchaseId] then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	local amount = grants[receiptInfo.ProductId]
	if not amount then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local cash = getCash(player)
	if not cash then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	cash.Value += amount
	processed[purchaseId] = true
	player:SetAttribute("ChipPackPurchased", amount)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end
