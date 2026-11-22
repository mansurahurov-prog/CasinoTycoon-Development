-- Developer Product fulfillment for chip packs.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local config = require(ReplicatedStorage:WaitForChild("CasinoTycoonShopConfig"))

-- Must match MAX_CASH in CasinoTycoonData.
local MAX_CASH = 1000000000

local grants = {}
for _, product in ipairs(config.Products or {}) do
	local id = tonumber(product.id)
	if id and id > 0 then
		grants[id] = tonumber(product.cash) or 0
	end
end

local okData, resultData = pcall(function()
	return require(script.Parent:WaitForChild("CasinoTycoonData"))
end)
local Data = okData and resultData or nil
if not Data then
	warn("CasinoTycoonMonetization: CasinoTycoonData unavailable - receipts stay pending")
end

-- Receipts granted in memory but not yet confirmed by a durable save.
local pending = {}
local saving = {}

local function getCash(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	local cash = leaderstats and leaderstats:FindFirstChild("Cash")
	if cash and cash:IsA("IntValue") then
		return cash
	end
	return nil
end

local function saveNow(player, purchaseId)
	local savingSet = saving[player]
	if savingSet and savingSet[purchaseId] then
		return false
	end
	if not savingSet then
		savingSet = {}
		saving[player] = savingSet
	end
	savingSet[purchaseId] = true
	local ok, saved = pcall(Data.Save, player)
	savingSet[purchaseId] = nil
	if not ok then
		warn("CasinoTycoonMonetization: save failed for " .. purchaseId .. ": " .. tostring(saved))
		return false
	end
	return saved == true
end

MarketplaceService.ProcessReceipt = function(receiptInfo)
	local purchaseId = tostring(receiptInfo.PurchaseId)
	local amount = grants[receiptInfo.ProductId]
	if not amount or amount <= 0 then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	if not Data or not Data.IsReady(player) or not Data.IsPersistent() then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if player:GetAttribute("DataReadOnly") == true then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local receipts = Data.GetReceipts(player)
	if not receipts then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	-- An unconfirmed grant must never be acknowledged, even though the
	-- in-memory receipt table already contains the id.
	local pendingSet = pending[player]
	if pendingSet and pendingSet[purchaseId] then
		if saveNow(player, purchaseId) then
			pendingSet[purchaseId] = nil
			player:SetAttribute("ChipPackPurchased", amount)
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	if receipts[purchaseId] ~= nil then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	local cash = getCash(player)
	if not cash then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	-- Mark before yielding so a duplicate delivery cannot grant twice.
	if not pendingSet then
		pendingSet = {}
		pending[player] = pendingSet
	end
	pendingSet[purchaseId] = true
	local before = cash.Value
	cash.Value = math.clamp(before + amount, 0, MAX_CASH)
	if not Data.AddReceipt(player, purchaseId) then
		cash.Value = before
		pendingSet[purchaseId] = nil
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if not saveNow(player, purchaseId) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	pendingSet[purchaseId] = nil
	player:SetAttribute("ChipPackPurchased", amount)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

Players.PlayerRemoving:Connect(function(player)
	pending[player] = nil
	saving[player] = nil
end)
