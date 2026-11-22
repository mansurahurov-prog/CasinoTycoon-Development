-- Casino Tycoon client HUD. Session-only, built entirely in code.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui", 20)
if not playerGui then
	return
end

local previous = playerGui:FindFirstChild("CasinoTycoonHUD")
if previous then
	previous:Destroy()
end

local GOLD = Color3.fromRGB(212, 175, 96)
local GOLD_SOFT = Color3.fromRGB(255, 218, 130)
local INK = Color3.fromRGB(12, 12, 14)
local IVORY = Color3.fromRGB(242, 240, 235)
local DIM = Color3.fromRGB(150, 150, 150)

local gui = Instance.new("ScreenGui")
gui.Name = "CasinoTycoonHUD"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 20
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local function makeLabel(parent, name, size, position, text, font, textSize, color)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Size = size
	label.Position = position
	label.BackgroundTransparency = 1
	label.Font = font or Enum.Font.GothamMedium
	label.Text = text or ""
	label.TextSize = textSize or 14
	label.TextColor3 = color or IVORY
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.Parent = parent
	return label
end

local function makeCard(name, position, size, anchor)
	local card = Instance.new("Frame")
	card.Name = name
	card.AnchorPoint = anchor or Vector2.new(0, 0)
	card.Position = position
	card.Size = size
	card.BackgroundColor3 = INK
	card.BackgroundTransparency = 0.18
	card.BorderSizePixel = 0
	card.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = card

	local stroke = Instance.new("UIStroke")
	stroke.Color = GOLD
	stroke.Transparency = 0.55
	stroke.Thickness = 1
	stroke.Parent = card
	return card
end

local cashCard = makeCard("CashCard", UDim2.fromOffset(24, 24), UDim2.fromOffset(240, 92))
makeLabel(cashCard, "Caption", UDim2.new(1, -28, 0, 18), UDim2.fromOffset(14, 8), "CASH", Enum.Font.GothamBold, 11, GOLD)
local cashLabel = makeLabel(cashCard, "Value", UDim2.new(1, -28, 0, 40), UDim2.fromOffset(14, 26), "$0", Enum.Font.GothamBold, 28, IVORY)
local cashMode = makeLabel(cashCard, "Mode", UDim2.new(1, -28, 0, 16), UDim2.fromOffset(14, 66), "", Enum.Font.GothamMedium, 11, DIM)

local statusCard = makeCard("StatusCard", UDim2.new(1, -24, 0, 24), UDim2.fromOffset(300, 96), Vector2.new(1, 0))
local plotTitle = makeLabel(statusCard, "PlotTitle", UDim2.new(1, -28, 0, 20), UDim2.fromOffset(14, 8), "PLOT", Enum.Font.GothamBold, 12, GOLD)
local plotOwner = makeLabel(statusCard, "PlotOwner", UDim2.new(1, -28, 0, 20), UDim2.fromOffset(14, 28), "", Enum.Font.GothamMedium, 15, IVORY)
local plotSuite = makeLabel(statusCard, "PlotSuite", UDim2.new(1, -28, 0, 20), UDim2.fromOffset(14, 50), "", Enum.Font.GothamMedium, 13, DIM)
local plotNote = makeLabel(statusCard, "PlotNote", UDim2.new(1, -28, 0, 16), UDim2.fromOffset(14, 72), "", Enum.Font.GothamMedium, 11, GOLD_SOFT)

local hintBar = makeCard("HintBar", UDim2.new(0.5, 0, 1, -28), UDim2.fromOffset(560, 42), Vector2.new(0.5, 1))
hintBar.BackgroundTransparency = 0.25
local hintLabel = makeLabel(hintBar, "Hint", UDim2.new(1, -24, 1, 0), UDim2.fromOffset(12, 0), "", Enum.Font.GothamMedium, 15, GOLD_SOFT)
hintLabel.TextXAlignment = Enum.TextXAlignment.Center
hintBar.Visible = false

local toast = makeCard("RewardToast", UDim2.new(0.5, 0, 1, -84), UDim2.fromOffset(320, 40), Vector2.new(0.5, 1))
toast.Visible = false
local toastLabel = makeLabel(toast, "Text", UDim2.new(1, -20, 1, 0), UDim2.fromOffset(10, 0), "", Enum.Font.GothamBold, 16, GOLD_SOFT)
toastLabel.TextXAlignment = Enum.TextXAlignment.Center

local modal = makeCard("PurchaseModal", UDim2.new(0.5, 0, 0.5, 0), UDim2.fromOffset(380, 200), Vector2.new(0.5, 0.5))
modal.ZIndex = 10
modal.Visible = false
local modalTitle = makeLabel(modal, "Title", UDim2.new(1, -32, 0, 22), UDim2.fromOffset(16, 14), "BUILD HOTEL SUITE", Enum.Font.GothamBold, 15, GOLD)
local modalLine = makeLabel(modal, "Line", UDim2.new(1, -32, 0, 18), UDim2.fromOffset(16, 40), "", Enum.Font.GothamMedium, 12, DIM)
local modalCost = makeLabel(modal, "Cost", UDim2.new(1, -32, 0, 38), UDim2.fromOffset(16, 62), "", Enum.Font.GothamBold, 26, IVORY)

local function makeButton(name, text, position, isPrimary)
	local button = Instance.new("TextButton")
	button.Name = name
	button.Size = UDim2.fromOffset(164, 42)
	button.Position = position
	button.BackgroundColor3 = isPrimary and GOLD or INK
	button.BackgroundTransparency = isPrimary and 0 or 0.25
	button.BorderSizePixel = 0
	button.Font = Enum.Font.GothamBold
	button.Text = text
	button.TextSize = 14
	button.TextColor3 = isPrimary and INK or IVORY
	button.AutoButtonColor = true
	button.Parent = modal

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = button

	if not isPrimary then
		local stroke = Instance.new("UIStroke")
		stroke.Color = GOLD
		stroke.Transparency = 0.5
		stroke.Parent = button
	end
	return button
end

local confirmButton = makeButton("Confirm", "CONFIRM  \u{00B7}  PAY", UDim2.fromOffset(16, 140), true)
local cancelButton = makeButton("Cancel", "CANCEL", UDim2.fromOffset(200, 140), false)

local welcome = makeCard("WelcomeCard", UDim2.new(0.5, 0, 0, 88), UDim2.fromOffset(520, 252), Vector2.new(0.5, 0))
welcome.ZIndex = 9
local welcomeTitle = makeLabel(welcome, "Title", UDim2.new(1, -40, 0, 28), UDim2.fromOffset(20, 18), "WELCOME TO CASINO TYCOON", Enum.Font.GothamBold, 17, GOLD)
welcomeTitle.TextXAlignment = Enum.TextXAlignment.Center

local welcomeSteps = {
	"1  ·  Walk to your lot and build the hotel suite ($500).",
	"2  ·  The suite pays $25 every 5 seconds, forever.",
	"3  ·  Upgrade with Restaurant ($1,500) and Spa ($3,000) for bigger income.",
}
for index, text in ipairs(welcomeSteps) do
	local label = makeLabel(welcome, "Step" .. index, UDim2.new(1, -40, 0, 26), UDim2.fromOffset(20, 58 + (index - 1) * 30), text, Enum.Font.GothamMedium, 14, IVORY)
	label.TextXAlignment = Enum.TextXAlignment.Left
end

local welcomeButton = makeButton("Dismiss", "LET'S PLAY", UDim2.fromOffset(180, 40), true)
welcomeButton.Parent = welcome
welcomeButton.Position = UDim2.new(0.5, -90, 0, 190)

local function formatMoney(value)
	local text = tostring(math.floor(tonumber(value) or 0))
	local sign = ""
	if text:sub(1, 1) == "-" then
		sign = "-"
		text = text:sub(2)
	end
	local out = ""
	local count = 0
	for index = #text, 1, -1 do
		out = text:sub(index, index) .. out
		count += 1
		if count % 3 == 0 and index > 1 then
			out = "," .. out
		end
	end
	return sign .. "$" .. out
end

local leaderstats = player:WaitForChild("leaderstats", 30)

local function refreshCashMode()
	if player:GetAttribute("CashLoaded") == true then
		cashMode.Text = "SAVED PROGRESS"
		cashMode.TextColor3 = GOLD_SOFT
	else
		cashMode.Text = "SESSION ONLY"
		cashMode.TextColor3 = DIM
	end
end
player:GetAttributeChangedSignal("CashLoaded"):Connect(refreshCashMode)
refreshCashMode()
if leaderstats then
	local cash = leaderstats:WaitForChild("Cash", 20)
	if cash then
		local function refreshCash()
			cashLabel.Text = formatMoney(cash.Value)
		end
		cash:GetPropertyChangedSignal("Value"):Connect(refreshCash)
		refreshCash()
	end
end

local plotsFolder = workspace:WaitForChild("CasinoTycoon", 30)
plotsFolder = plotsFolder and plotsFolder:WaitForChild("Plots", 30)

local currentPlot = nil
local plotConnections = {}
local promptConnection = nil

local function clearPlotBindings()
	for _, connection in ipairs(plotConnections) do
		connection:Disconnect()
	end
	table.clear(plotConnections)
	if promptConnection then
		promptConnection:Disconnect()
		promptConnection = nil
	end
	currentPlot = nil
end

local function setHint(text)
	if text and text ~= "" then
		hintLabel.Text = text
		hintBar.Visible = true
	else
		hintBar.Visible = false
	end
end

local function findPrompt(plot)
	local station = plot:FindFirstChild("CasinoTycoonPurchaseStation")
	local button = station and station:FindFirstChild("ButtonPart")
	return button and button:FindFirstChildOfClass("ProximityPrompt")
end

local observerMode = false

local function refreshPlot()
	local plot = currentPlot
	if not plot then
		local queuePosition = player:GetAttribute("PlotQueuePosition")
		if queuePosition then
			plotTitle.Text = "WAITING"
			plotOwner.Text = "Queue position " .. tostring(queuePosition)
			plotNote.Text = "Next free lot is yours"
		else
			plotTitle.Text = "NO PLOT"
			if observerMode then
				plotOwner.Text = "Lobby is open to everyone"
				plotNote.Text = "ALL PLOTS TAKEN \u{00B7} SPECTATOR MODE"
			else
				plotOwner.Text = "Waiting for an available plot"
				plotNote.Text = ""
			end
		end
		plotSuite.Text = ""
		setHint("")
		return
	end

	local ownerId = tonumber(plot:GetAttribute("OwnerUserId")) or 0
	local ownerName = plot:GetAttribute("OwnerName")
	local plotId = plot:GetAttribute("PlotId")
	local purchased = plot:GetAttribute("HotelSuitePurchased") == true
	local suiteOwner = tonumber(plot:GetAttribute("HotelSuiteOwnerUserId")) or 0

	plotTitle.Text = "LOT " .. tostring(plotId or "?") .. "  \u{00B7}  " .. plot.Name
	if ownerId == player.UserId then
		plotOwner.Text = "YOUR CASINO"
	elseif ownerId > 0 then
		plotOwner.Text = (ownerName ~= nil and ownerName ~= "" and ownerName) or "Occupied"
	else
		plotOwner.Text = "UNCLAIMED"
	end

	if purchased then
		local mine = suiteOwner == player.UserId
		plotSuite.Text = mine and "Hotel suite: built" or "Hotel suite: owned by another player"
	else
		plotSuite.Text = "Hotel suite: not built"
	end

	plotNote.Text = ""
	local prompt = findPrompt(plot)
	if prompt then
		if promptConnection then
			promptConnection:Disconnect()
		end
		local function refreshHint()
			if prompt.Enabled and ownerId == player.UserId and not purchased then
				local action = prompt.ActionText
				if action == nil or action == "" then
					action = "Build Hotel Suite   " .. formatMoney(500)
				end
				setHint("E  \u{00B7}  " .. action)
			else
				setHint("")
			end
		end
		promptConnection = prompt:GetPropertyChangedSignal("Enabled"):Connect(refreshHint)
		refreshHint()
	end
end

local function bindPlot(plot)
	clearPlotBindings()
	currentPlot = plot
	for _, attribute in ipairs({ "OwnerUserId", "OwnerName", "HotelSuitePurchased", "HotelSuiteOwnerUserId" }) do
		table.insert(plotConnections, plot:GetAttributeChangedSignal(attribute):Connect(refreshPlot))
	end
	local suiteToastShown = plot:GetAttribute("HotelSuitePurchased") == true
	table.insert(plotConnections, plot:GetAttributeChangedSignal("HotelSuitePurchased"):Connect(function()
		if suiteToastShown or plot:GetAttribute("HotelSuitePurchased") ~= true then
			return
		end
		suiteToastShown = true
		toastLabel.Text = "SUITE BUILT  \u{00B7}  NEXT: RESTAURANT ($1,500)"
		toast.Visible = true
		task.delay(4, function()
			toast.Visible = false
		end)
	end))
	refreshPlot()
end

local function refreshBinding()
	local plotName = player:GetAttribute("PlotName")
	if plotName and plotsFolder then
		local plot = plotsFolder:FindFirstChild(plotName)
		if plot then
			if plot ~= currentPlot then
				bindPlot(plot)
			else
				refreshPlot()
			end
			return
		end
	end

	if currentPlot then
		clearPlotBindings()
	end
	refreshPlot()

	if not observerShown and plotsFolder then
		local owned, total = 0, 0
		for _, child in ipairs(plotsFolder:GetChildren()) do
			total += 1
			if (tonumber(child:GetAttribute("OwnerUserId")) or 0) > 0 then
				owned += 1
			end
		end
		if total > 0 and owned >= total then
			observerMode = true
			refreshPlot()
		end
	end
end

player:GetAttributeChangedSignal("PlotName"):Connect(refreshBinding)
player:GetAttributeChangedSignal("PlotId"):Connect(refreshBinding)
player:GetAttributeChangedSignal("PlotQueuePosition"):Connect(refreshBinding)
refreshBinding()

local toastToken = 0
player:GetAttributeChangedSignal("LastGuestReward"):Connect(function()
	local reward = tonumber(player:GetAttribute("LastGuestReward"))
	if not reward or reward <= 0 then
		return
	end
	toastToken += 1
	local token = toastToken
	toastLabel.Text = "GUEST PAYOUT  +" .. formatMoney(reward)
	toast.Visible = true
	task.delay(2.5, function()
		if token == toastToken then
			toast.Visible = false
		end
	end)
end)

local function showBonusToast(text)
	toastToken += 1
	local token = toastToken
	toastLabel.Text = text
	toast.Visible = true
	task.delay(4, function()
		if token == toastToken then
			toast.Visible = false
		end
	end)
end

player:GetAttributeChangedSignal("LastBonusAmount"):Connect(function()
	local amount = tonumber(player:GetAttribute("LastBonusAmount"))
	if not amount or amount <= 0 then
		return
	end
	local label = tostring(player:GetAttribute("LastBonusLabel") or "MILESTONE")
	showBonusToast(label .. " BONUS  +" .. formatMoney(amount))
end)

player:GetAttributeChangedSignal("DailyBonus"):Connect(function()
	local amount = tonumber(player:GetAttribute("DailyBonus"))
	if not amount or amount <= 0 then
		return
	end
	showBonusToast("DAILY BONUS  +" .. formatMoney(amount))
end)

player:GetAttributeChangedSignal("FountainTipCount"):Connect(function()
	showBonusToast("FOUNTAIN TIP  +" .. formatMoney(25))
end)

task.spawn(function()
	while gui.Parent do
		task.wait(2)
		refreshBinding()
	end
end)

local requestRemote = ReplicatedStorage:WaitForChild("CasinoTycoonPurchaseRequest", 20)
local confirmRemote = ReplicatedStorage:WaitForChild("CasinoTycoonPurchaseConfirm", 20)
local pendingPlotId = nil

local function closeModal()
	modal.Visible = false
	pendingPlotId = nil
end

if requestRemote then
	requestRemote.OnClientEvent:Connect(function(data)
		if type(data) ~= "table" then
			return
		end
		pendingPlotId = data.plotId
		local action = tostring(data.actionText or "")
		modalTitle.Text = action ~= "" and string.upper(action) or "BUILD HOTEL SUITE"
		modalLine.Text = "Lot " .. tostring(data.plotId) .. "  \u{00B7}  " .. tostring(data.plotName)
		modalCost.Text = formatMoney(data.cost)
		modal.Visible = true
	end)
end

confirmButton.MouseButton1Click:Connect(function()
	if confirmRemote and pendingPlotId ~= nil then
		confirmRemote:FireServer(pendingPlotId, true)
	end
	closeModal()
end)

cancelButton.MouseButton1Click:Connect(function()
	if confirmRemote and pendingPlotId ~= nil then
		confirmRemote:FireServer(pendingPlotId, false)
	end
	closeModal()
end)

welcomeButton.MouseButton1Click:Connect(function()
	welcome.Visible = false
end)

task.delay(20, function()
	welcome.Visible = false
end)

-- Lucky Hour banner
local luckyBanner = Instance.new("Frame")
luckyBanner.Name = "LuckyHourBanner"
luckyBanner.AnchorPoint = Vector2.new(0.5, 0)
luckyBanner.Position = UDim2.new(0.5, 0, 0, 128)
luckyBanner.Size = UDim2.fromOffset(430, 48)
luckyBanner.BackgroundColor3 = Color3.fromRGB(12, 12, 14)
luckyBanner.BackgroundTransparency = 0.08
luckyBanner.BorderSizePixel = 0
luckyBanner.Visible = false
luckyBanner.Parent = gui

local luckyCorner = Instance.new("UICorner")
luckyCorner.CornerRadius = UDim.new(0, 6)
luckyCorner.Parent = luckyBanner

local luckyStroke = Instance.new("UIStroke")
luckyStroke.Color = GOLD
luckyStroke.Thickness = 1.6
luckyStroke.Transparency = 0.15
luckyStroke.Parent = luckyBanner

local luckyLabel = Instance.new("TextLabel")
luckyLabel.Name = "Title"
luckyLabel.BackgroundTransparency = 1
luckyLabel.AnchorPoint = Vector2.new(0.5, 0.5)
luckyLabel.Position = UDim2.fromScale(0.5, 0.5)
luckyLabel.Size = UDim2.fromScale(1, 1)
luckyLabel.Font = Enum.Font.GothamBold
luckyLabel.TextSize = 18
luckyLabel.TextColor3 = GOLD
luckyLabel.Text = "LUCKY HOUR  \u{00B7}  x2 PAYOUTS"
luckyLabel.Parent = luckyBanner

local casinoTycoonFolder = workspace:WaitForChild("CasinoTycoon")

local function refreshLuckyHour()
	luckyBanner.Visible = casinoTycoonFolder:GetAttribute("LuckyHourActive") == true
end

casinoTycoonFolder:GetAttributeChangedSignal("LuckyHourActive"):Connect(function()
	refreshLuckyHour()
	if casinoTycoonFolder:GetAttribute("LuckyHourActive") == true then
		showBonusToast("LUCKY HOUR  x2 PAYOUTS")
	end
end)

refreshLuckyHour()

task.spawn(function()
	while gui.Parent do
		task.wait(1)
		if luckyBanner.Visible then
			luckyStroke.Transparency = 0.1 + 0.35 * (0.5 + 0.5 * math.sin(os.clock() * 3))
		end
	end
end)

-- Cash shop (Developer Products)
local MarketplaceService = game:GetService("MarketplaceService")
local SHOP_GOLD = Color3.fromRGB(198, 160, 74)
local SHOP_IVORY = Color3.fromRGB(236, 233, 226)
local SHOP_DIM = Color3.fromRGB(150, 148, 142)

local shopProducts = {}
local shopConfigModule = ReplicatedStorage:WaitForChild("CasinoTycoonShopConfig", 20)
if shopConfigModule then
	local ok, result = pcall(require, shopConfigModule)
	if ok and type(result) == "table" and type(result.Products) == "table" then
		shopProducts = result.Products
	end
end

local shopButton = Instance.new("TextButton")
shopButton.Name = "ShopButton"
shopButton.Position = UDim2.fromOffset(24, 126)
shopButton.Size = UDim2.fromOffset(240, 38)
shopButton.BackgroundColor3 = Color3.fromRGB(14, 14, 16)
shopButton.BackgroundTransparency = 0.1
shopButton.BorderSizePixel = 0
shopButton.Font = Enum.Font.GothamBold
shopButton.TextSize = 15
shopButton.TextColor3 = SHOP_GOLD
shopButton.Text = "CASH SHOP"
shopButton.Parent = gui

local shopButtonCorner = Instance.new("UICorner")
shopButtonCorner.CornerRadius = UDim.new(0, 6)
shopButtonCorner.Parent = shopButton

local shopButtonStroke = Instance.new("UIStroke")
shopButtonStroke.Color = SHOP_GOLD
shopButtonStroke.Thickness = 1.2
shopButtonStroke.Transparency = 0.25
shopButtonStroke.Parent = shopButton

local shopPanel = Instance.new("Frame")
shopPanel.Name = "ShopPanel"
shopPanel.AnchorPoint = Vector2.new(0.5, 0.5)
shopPanel.Position = UDim2.fromScale(0.5, 0.5)
shopPanel.Size = UDim2.fromOffset(470, 96 + math.max(1, #shopProducts) * 70)
shopPanel.BackgroundColor3 = Color3.fromRGB(10, 10, 12)
shopPanel.BackgroundTransparency = 0.03
shopPanel.BorderSizePixel = 0
shopPanel.Visible = false
shopPanel.Parent = gui

local shopPanelCorner = Instance.new("UICorner")
shopPanelCorner.CornerRadius = UDim.new(0, 8)
shopPanelCorner.Parent = shopPanel

local shopPanelStroke = Instance.new("UIStroke")
shopPanelStroke.Color = SHOP_GOLD
shopPanelStroke.Thickness = 1.5
shopPanelStroke.Transparency = 0.2
shopPanelStroke.Parent = shopPanel

local shopTitle = Instance.new("TextLabel")
shopTitle.Size = UDim2.new(1, -32, 0, 30)
shopTitle.Position = UDim2.fromOffset(20, 16)
shopTitle.BackgroundTransparency = 1
shopTitle.Font = Enum.Font.GothamBold
shopTitle.TextSize = 20
shopTitle.TextColor3 = SHOP_GOLD
shopTitle.TextXAlignment = Enum.TextXAlignment.Left
shopTitle.Text = "CHIP SHOP"
shopTitle.Parent = shopPanel

local shopClose = Instance.new("TextButton")
shopClose.Size = UDim2.fromOffset(30, 30)
shopClose.Position = UDim2.new(1, -42, 0, 14)
shopClose.BackgroundTransparency = 1
shopClose.Font = Enum.Font.GothamBold
shopClose.TextSize = 20
shopClose.TextColor3 = SHOP_DIM
shopClose.Text = "X"
shopClose.Parent = shopPanel

for index, product in ipairs(shopProducts) do
	local row = Instance.new("Frame")
	row.Name = "Pack" .. tostring(index)
	row.Size = UDim2.new(1, -40, 0, 60)
	row.Position = UDim2.fromOffset(20, 56 + (index - 1) * 70)
	row.BackgroundColor3 = Color3.fromRGB(20, 20, 22)
	row.BackgroundTransparency = 0.05
	row.BorderSizePixel = 0
	row.Parent = shopPanel

	local rowCorner = Instance.new("UICorner")
	rowCorner.CornerRadius = UDim.new(0, 6)
	rowCorner.Parent = row

	local packName = Instance.new("TextLabel")
	packName.Size = UDim2.new(0.5, -12, 0, 20)
	packName.Position = UDim2.fromOffset(14, 9)
	packName.BackgroundTransparency = 1
	packName.Font = Enum.Font.GothamBold
	packName.TextSize = 15
	packName.TextColor3 = SHOP_IVORY
	packName.TextXAlignment = Enum.TextXAlignment.Left
	packName.Text = tostring(product.name)
	packName.Parent = row

	local packCash = Instance.new("TextLabel")
	packCash.Size = UDim2.new(0.5, -12, 0, 20)
	packCash.Position = UDim2.fromOffset(14, 30)
	packCash.BackgroundTransparency = 1
	packCash.Font = Enum.Font.GothamMedium
	packCash.TextSize = 13
	packCash.TextColor3 = SHOP_GOLD
	packCash.TextXAlignment = Enum.TextXAlignment.Left
	packCash.Text = "+" .. tostring(product.cash) .. " CHIPS"
	packCash.Parent = row

	local buyButton = Instance.new("TextButton")
	buyButton.Size = UDim2.fromOffset(140, 40)
	buyButton.Position = UDim2.new(1, -154, 0.5, -20)
	buyButton.BackgroundColor3 = Color3.fromRGB(28, 24, 14)
	buyButton.BorderSizePixel = 0
	buyButton.Font = Enum.Font.GothamBold
	buyButton.TextSize = 15
	buyButton.TextColor3 = SHOP_GOLD
	buyButton.Text = tostring(product.price)
	buyButton.Parent = row

	local buyCorner = Instance.new("UICorner")
	buyCorner.CornerRadius = UDim.new(0, 5)
	buyCorner.Parent = buyButton

	local buyStroke = Instance.new("UIStroke")
	buyStroke.Color = SHOP_GOLD
	buyStroke.Thickness = 1
	buyStroke.Transparency = 0.3
	buyStroke.Parent = buyButton

	local productId = tonumber(product.id)
	if not productId or productId <= 0 then
		buyButton.Text = "NOT IN STORE"
		buyButton.TextColor3 = SHOP_DIM
		buyStroke.Transparency = 0.6
	end

	buyButton.MouseButton1Click:Connect(function()
		if productId and productId > 0 then
			MarketplaceService:PromptProductPurchase(player, productId)
		else
			packName.Text = "AVAILABLE AFTER RELEASE"
		end
	end)
end

shopButton.MouseButton1Click:Connect(function()
	shopPanel.Visible = not shopPanel.Visible
end)

shopClose.MouseButton1Click:Connect(function()
	shopPanel.Visible = false
end)

player:GetAttributeChangedSignal("SlotWin"):Connect(function()
	local win = tonumber(player:GetAttribute("SlotWin"))
	if win and win > 0 then
		showBonusToast("SLOT WIN  +" .. formatMoney(win))
	end
end)

player:GetAttributeChangedSignal("ChipPackPurchased"):Connect(function()
	local amount = tonumber(player:GetAttribute("ChipPackPurchased"))
	if amount and amount > 0 then
		showBonusToast("CHIPS ADDED  +" .. formatMoney(amount))
	end
end)

-- VIP badge next to the cash card
local vipBadge = Instance.new("TextLabel")
vipBadge.Name = "VipBadge"
vipBadge.Position = UDim2.fromOffset(24, 170)
vipBadge.Size = UDim2.fromOffset(240, 28)
vipBadge.BackgroundColor3 = Color3.fromRGB(24, 20, 12)
vipBadge.BackgroundTransparency = 0.15
vipBadge.BorderSizePixel = 0
vipBadge.Font = Enum.Font.GothamBold
vipBadge.TextSize = 13
vipBadge.TextColor3 = GOLD
vipBadge.Text = "VIP  +50% INCOME"
vipBadge.Visible = false
vipBadge.Parent = gui

local vipCorner = Instance.new("UICorner")
vipCorner.CornerRadius = UDim.new(0, 5)
vipCorner.Parent = vipBadge

local function refreshVipBadge()
	vipBadge.Visible = player:GetAttribute("VipActive") == true
end

player:GetAttributeChangedSignal("VipActive"):Connect(refreshVipBadge)
refreshVipBadge()
