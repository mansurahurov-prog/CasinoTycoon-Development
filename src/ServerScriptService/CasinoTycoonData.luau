-- CasinoTycoonData: authoritative server-side player profile (cash, plots, receipts).
-- Schema v2 + session lock. All writes go through UpdateAsync.
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")

local STORE_NAME = "CasinoTycoonProfile_v2"
local LEGACY_STORE_NAME = "CasinoTycoonCash_v1"
local SCHEMA_VERSION = 2
local AUTOSAVE_INTERVAL = 45
local LOCK_TTL = 120
local MAX_RETRIES = 4
local STARTING_CASH = 1000
local MIN_CASH = 0
local MAX_CASH = 1000000000
local MAX_RECEIPTS = 60

local plotsFolder = workspace:WaitForChild("CasinoTycoon"):WaitForChild("Plots")

local store
local legacyStore
local storageOK = false
local warned = false

local function warnOnce(message)
	if warned then
		return
	end
	warned = true
	warn("CasinoTycoonData: " .. tostring(message) .. " - running with reduced persistence")
end

local okStore, resultStore = pcall(function()
	return DataStoreService:GetDataStore(STORE_NAME)
end)
if okStore and resultStore then
	store = resultStore
	storageOK = true
else
	warnOnce(resultStore)
end

local okLegacy, resultLegacy = pcall(function()
	return DataStoreService:GetDataStore(LEGACY_STORE_NAME)
end)
if okLegacy and resultLegacy then
	legacyStore = resultLegacy
end

-- Studio fallback: keep profiles in memory so save/restore can be exercised
-- before the place is published. Never used when DataStore is available.
local memoryData = {}
local memoryBackend = {}
function memoryBackend:GetAsync(key)
	return memoryData[key]
end
function memoryBackend:SetAsync(key, value)
	memoryData[key] = value
end
function memoryBackend:UpdateAsync(key, transform)
	local current = memoryData[key]
	local updated = transform(current)
	if updated ~= nil then
		memoryData[key] = updated
	end
	return memoryData[key]
end

local backend = store or memoryBackend

local function withRetry(label, callback)
	if not backend then
		return nil, "storage disabled"
	end
	local lastError = "unknown"
	for attempt = 1, MAX_RETRIES do
		local ok, result = pcall(callback)
		if ok and result ~= nil then
			return result
		end
		if ok then
			lastError = "cancelled"
		else
			lastError = result
		end
		if attempt < MAX_RETRIES then
			task.wait(0.5 * attempt)
		end
	end
	return nil, lastError
end

local function clampCash(value)
	local number = math.floor(tonumber(value) or STARTING_CASH)
	if number ~= number then
		number = STARTING_CASH
	end
	return math.clamp(number, MIN_CASH, MAX_CASH)
end

local function keyFor(player)
	return "Player_" .. tostring(player.UserId)
end

local function cashValue(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	local cash = leaderstats and leaderstats:FindFirstChild("Cash")
	if cash and cash:IsA("IntValue") then
		return cash
	end
	return nil
end

local function waitForCash(player)
	local leaderstats = player:WaitForChild("leaderstats", 20)
	local cash = leaderstats and leaderstats:WaitForChild("Cash", 15)
	if cash and cash:IsA("IntValue") then
		return cash
	end
	return nil
end

local OWNER_SUFFIX = "OwnerUserId"
local PURCHASED_SUFFIX = "Purchased"

local function isOwnAttr(name)
	return name == "PlotId" or name == "OwnerUserId" or name == "OwnerName" or name == "OwnerDisplayName"
end

local function snapshotPlot(plot)
	local snapshot = {}
	for name, value in pairs(plot:GetAttributes()) do
		local kind = typeof(value)
		if not isOwnAttr(name) and (kind == "number" or kind == "boolean" or kind == "string") then
			snapshot[name] = value
		end
	end
	return snapshot
end

local function applyPlot(plot, snapshot, player)
	if type(snapshot) ~= "table" then
		return
	end
	for name, value in pairs(snapshot) do
		if not isOwnAttr(name) then
			local current = plot:GetAttribute(name)
			if current ~= value then
				plot:SetAttribute(name, value)
			end
		end
	end
	-- ownership markers of purchased sub-areas must point at the current owner
	for name, value in pairs(snapshot) do
		if typeof(value) == "number" and string.sub(name, -#OWNER_SUFFIX) == OWNER_SUFFIX then
			plot:SetAttribute(name, player.UserId)
		elseif typeof(value) == "boolean" and value and string.sub(name, -#PURCHASED_SUFFIX) == PURCHASED_SUFFIX then
			local ownerName = string.sub(name, 1, #name - #PURCHASED_SUFFIX) .. OWNER_SUFFIX
			if snapshot[ownerName] == nil then
				plot:SetAttribute(ownerName, player.UserId)
			end
		end
	end
end

local function blankProfile()
	return {
		Version = SCHEMA_VERSION,
		Cash = STARTING_CASH,
		Plots = {},
		StreakDays = 0,
		LastBonusDay = nil,
		PurchaseIds = {},
		Milestones = {},
	}
end

local function migrate(raw, player)
	local profile = blankProfile()
	if type(raw) ~= "table" then
		return profile, true
	end
	local version = tonumber(raw.Version) or 1
	profile.Cash = clampCash(raw.Cash)
	profile.StreakDays = tonumber(raw.StreakDays) or 0
	profile.LastBonusDay = type(raw.LastBonusDay) == "string" and raw.LastBonusDay or nil
	profile.PurchaseIds = type(raw.PurchaseIds) == "table" and raw.PurchaseIds or {}
	profile.Milestones = type(raw.Milestones) == "table" and raw.Milestones or {}
	if version >= SCHEMA_VERSION and type(raw.Plots) == "table" then
		for plotId, snapshot in pairs(raw.Plots) do
			if type(snapshot) == "table" then
				profile.Plots[tostring(plotId)] = snapshot
			end
		end
	elseif type(raw.Plots) == "table" then
		-- v1 keyed plots by name; remap to PlotId
		for plotName, snapshot in pairs(raw.Plots) do
			local plot = plotsFolder:FindFirstChild(tostring(plotName))
			if plot and type(snapshot) == "table" then
				profile.Plots[tostring(plot:GetAttribute("PlotId"))] = snapshot
			end
		end
	end
	return profile, version ~= SCHEMA_VERSION
end

local sessions = {}

local function acquireLock(player, key)
	local now = os.time()
	local payload = backend:UpdateAsync(key, function(current)
		if type(current) ~= "table" then
			current = { Version = SCHEMA_VERSION, Cash = STARTING_CASH, Plots = {} }
		end
		local lock = current.Lock
		if type(lock) == "table" then
			local holder = tostring(lock.Server or "")
			local age = now - (tonumber(lock.At) or 0)
			if holder ~= "" and holder ~= game.JobId and age < LOCK_TTL then
				return nil
			end
		end
		current.Lock = { At = now, Server = game.JobId, UserId = player.UserId }
		return current
	end)
	if type(payload) == "table" and type(payload.Lock) == "table" and tostring(payload.Lock.Server) == game.JobId then
		return payload
	end
	return nil
end

local function publishCash(player, value)
	local cash = waitForCash(player)
	if not cash then
		return nil
	end
	cash.Value = clampCash(value)
	return cash
end

local function loadPlayer(player)
	if sessions[player] then
		return
	end
	local session = { ready = false, dirty = false, readOnly = false, lockHeld = false, data = blankProfile() }
	sessions[player] = session
	local key = keyFor(player)
	local raw

	if backend then
		local before = os.clock()
		local locked
		repeat
			locked = withRetry("lock " .. player.Name, function()
				return acquireLock(player, key)
			end)
			if locked then
				break
			end
			task.wait(1)
		until os.clock() - before > 12

		if locked then
			session.lockHeld = true
			raw = locked
		else
			session.readOnly = true
			raw = withRetry("GetAsync " .. player.Name, function()
				return backend:GetAsync(key)
			end)
		end
	end

	if type(raw) ~= "table" and legacyStore then
		local legacy, err = withRetry("legacy " .. player.Name, function()
			return legacyStore:GetAsync(key)
		end)
		if err == nil and type(legacy) == "table" then
			raw = legacy
		end
	end

	local profile, migrated = migrate(raw, player)
	session.data = profile
	if migrated then
		session.dirty = true
	end

	local cash = publishCash(player, profile.Cash)
	if cash then
		cash:GetPropertyChangedSignal("Value"):Connect(function()
			if sessions[player] == session then
				session.dirty = true
			end
		end)
	end

	session.ready = true
	player:SetAttribute("CashLoaded", true)
	player:SetAttribute("DataReadOnly", session.readOnly)
end

local function releaseLock(player)
	local session = sessions[player]
	if not session or not session.lockHeld or not backend then
		return
	end
	session.lockHeld = false
	withRetry("unlock " .. player.Name, function()
		return backend:UpdateAsync(keyFor(player), function(current)
			if type(current) ~= "table" then
				return nil
			end
			if type(current.Lock) == "table" and tostring(current.Lock.Server) == game.JobId then
				current.Lock = nil
				return current
			end
			return nil
		end)
	end)
end

local function writeProfile(player, releaseAfter)
	local session = sessions[player]
	if not session or not session.ready then
		return false
	end
	if session.readOnly or not session.lockHeld then
		return false
	end
	if not backend then
		return false
	end
	if not session.dirty and not releaseAfter then
		return true
	end
	local cash = cashValue(player)
	if cash then
		session.data.Cash = clampCash(cash.Value)
	end
	session.data.Version = SCHEMA_VERSION
	session.data.SavedAt = os.time()

	local payload = session.data
	local saved = withRetry("save " .. player.Name, function()
		return backend:UpdateAsync(keyFor(player), function(current)
			if type(current) == "table" and type(current.Lock) == "table" then
				local holder = tostring(current.Lock.Server)
				if holder ~= "" and holder ~= game.JobId then
					return nil
				end
			end
			if releaseAfter then
				payload.Lock = nil
			else
				payload.Lock = { At = os.time(), Server = game.JobId, UserId = player.UserId }
			end
			return payload
		end)
	end)
	if saved then
		session.dirty = false
		if releaseAfter then
			session.lockHeld = false
		end
		return true
	end
	return false
end

local Data = {}

function Data.WaitReady(player, timeout)
	local session = sessions[player]
	if not session then
		task.spawn(loadPlayer, player)
		session = sessions[player]
	end
	local deadline = os.clock() + (timeout or 20)
	while session and not session.ready and os.clock() < deadline do
		task.wait(0.1)
	end
	return session and session.ready and session.data or nil
end

function Data.Get(player)
	local session = sessions[player]
	return session and session.data or nil
end

function Data.IsReady(player)
	local session = sessions[player]
	return session ~= nil and session.ready
end

function Data.IsPersistent()
	return store ~= nil
end

function Data.MarkDirty(player)
	local session = sessions[player]
	if session then
		session.dirty = true
	end
end

function Data.GetPlotSnapshot(player, plotId)
	local session = sessions[player]
	local profile = session and session.data
	if not profile then
		return nil
	end
	return profile.Plots[tostring(plotId)]
end

function Data.SetPlotSnapshot(player, plotId, snapshot)
	local session = sessions[player]
	local profile = session and session.data
	if not profile then
		return
	end
	profile.Plots[tostring(plotId)] = snapshot
	session.dirty = true
end

function Data.ApplyPlot(player, plot, snapshot)
	-- Restored purchases must never re-trigger one-time bonuses.
	if type(snapshot) == "table" then
		local profile = Data.Get(player)
		if profile then
			profile.Milestones = profile.Milestones or {}
			for name, value in pairs(snapshot) do
				if value == true and string.sub(name, -#PURCHASED_SUFFIX) == PURCHASED_SUFFIX then
					profile.Milestones[name] = true
				end
			end
		end
	end
	player:SetAttribute("RestoringPlot", true)
	local ok, err = pcall(applyPlot, plot, snapshot, player)
	player:SetAttribute("RestoringPlot", nil)
	if not ok then
		warn("CasinoTycoonData: apply failed for " .. player.Name .. ": " .. tostring(err))
	end
end

function Data.HasMilestone(player, key)
	local profile = Data.Get(player)
	return profile ~= nil and type(profile.Milestones) == "table" and profile.Milestones[key] == true
end

function Data.SetMilestone(player, key)
	local profile = Data.Get(player)
	if not profile then
		return
	end
	profile.Milestones = profile.Milestones or {}
	profile.Milestones[key] = true
	Data.MarkDirty(player)
end

function Data.ClaimMilestone(player, key)
	if Data.HasMilestone(player, key) then
		return false
	end
	Data.SetMilestone(player, key)
	return true
end

function Data.SnapshotPlot(plot)
	return snapshotPlot(plot)
end

function Data.Save(player)
	return writeProfile(player, false)
end

function Data.SaveAndRelease(player)
	local ok = writeProfile(player, true)
	local session = sessions[player]
	if session and not session.lockHeld then
		sessions[player] = nil
	end
	return ok
end

function Data.GetReceipts(player)
	local profile = Data.Get(player)
	return profile and profile.PurchaseIds or nil
end

function Data.AddReceipt(player, purchaseId)
	local profile = Data.Get(player)
	if not profile then
		return false
	end
	profile.PurchaseIds = profile.PurchaseIds or {}
	profile.PurchaseIds[tostring(purchaseId)] = os.time()
	local count = 0
	for id in pairs(profile.PurchaseIds) do
		count += 1
	end
	while count > MAX_RECEIPTS do
		local oldestId, oldestAt
		for id, at in pairs(profile.PurchaseIds) do
			if not oldestAt or (tonumber(at) or 0) < oldestAt then
				oldestId, oldestAt = id, tonumber(at) or 0
			end
		end
		if not oldestId then
			break
		end
		profile.PurchaseIds[oldestId] = nil
		count -= 1
	end
	Data.MarkDirty(player)
	return true
end

Players.PlayerAdded:Connect(function(player)
	task.spawn(loadPlayer, player)
end)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(loadPlayer, player)
end

task.spawn(function()
	while true do
		task.wait(AUTOSAVE_INTERVAL)
		for _, player in ipairs(Players:GetPlayers()) do
			local session = sessions[player]
			if session and session.ready and session.dirty and not session.readOnly then
				task.spawn(writeProfile, player, false)
			end
		end
	end
end)

game:BindToClose(function()
	local pending = 0
	for _, player in ipairs(Players:GetPlayers()) do
		if sessions[player] then
			pending += 1
			task.spawn(function()
				writeProfile(player, true)
				pending -= 1
			end)
		end
	end
	local deadline = os.clock() + 25
	while pending > 0 and os.clock() < deadline do
		task.wait(0.2)
	end
end)

return Data
