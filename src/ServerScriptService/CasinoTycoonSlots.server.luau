-- Playable slot machines on the existing lobby cabinets.
local Players = game:GetService("Players")
local lobby = workspace.CasinoTycoon.CentralDistrict.GrandCasinoHotel.GrandLobby.LuxuryPass_2026_11_19
local slots = lobby:WaitForChild("Slots")

local COST = 50
local JACKPOT = 500
local PAIR = 50
local SYMBOLS = { "7", "$", "*", "o", "#", "+" }
local GOLD = Color3.fromRGB(198, 160, 74)
local GREEN = Color3.fromRGB(120, 226, 140)
local RED = Color3.fromRGB(226, 96, 96)

local cooldowns = {}

local function getCash(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	local cash = leaderstats and leaderstats:FindFirstChild("Cash")
	if cash and cash:IsA("IntValue") then
		return cash
	end
	return nil
end

local function symbol()
	return SYMBOLS[math.random(#SYMBOLS)]
end

local function attach(cabinet)
	local topName = string.gsub(cabinet.Name, "Cabinet$", "TopBar")
	local top = cabinet.Parent and cabinet.Parent:FindFirstChild(topName) or cabinet

	local gui = Instance.new("BillboardGui")
	gui.Name = "SlotResult"
	gui.Size = UDim2.fromOffset(210, 62)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 1.7, 0)
	gui.AlwaysOnTop = false
	gui.Parent = top

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = GOLD
	label.Text = "PLAY " .. tostring(COST)
	label.Parent = gui

	local prompt = Instance.new("ProximityPrompt")
	prompt.ObjectText = "Slot Machine"
	prompt.ActionText = "Play " .. tostring(COST)
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = cabinet

	prompt.Triggered:Connect(function(player)
		if player:GetAttribute("CashLoaded") ~= true then
			return
		end
		local readyAt = cooldowns[player] or 0
		if readyAt > os.clock() then
			return
		end
		local cash = getCash(player)
		if not cash or cash.Value < COST then
			label.TextColor3 = RED
			label.Text = "NEED $" .. tostring(COST)
			task.delay(2, function()
				label.TextColor3 = GOLD
				label.Text = "PLAY " .. tostring(COST)
			end)
			return
		end

		cooldowns[player] = os.clock() + 2
		cash.Value -= COST

		task.spawn(function()
			for _ = 1, 9 do
				label.TextColor3 = GOLD
				label.Text = string.format("%s  %s  %s", symbol(), symbol(), symbol())
				task.wait(0.07)
			end
			local a, b, c = symbol(), symbol(), symbol()
			label.Text = string.format("%s  %s  %s", a, b, c)

			local win = 0
			if a == b and b == c then
				win = JACKPOT
			elseif a == b or b == c or a == c then
				win = PAIR
			end

			if win > 0 then
				cash.Value += win
				label.TextColor3 = GREEN
				label.Text = string.format("%s %s %s  +$%d", a, b, c, win)
				player:SetAttribute("SlotWin", win)
			else
				label.TextColor3 = RED
				label.Text = "NO WIN"
			end

			task.wait(2.5)
			label.TextColor3 = GOLD
			label.Text = "PLAY " .. tostring(COST)
		end)
	end)
end

for _, item in ipairs(slots:GetChildren()) do
	if item:IsA("BasePart") and string.find(item.Name, "Cabinet", 1, true) then
		attach(item)
	end
end

Players.PlayerRemoving:Connect(function(player)
	cooldowns[player] = nil
end)
