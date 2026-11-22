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
-- Desk upgrade ceiling for the hotel reception desk (kept in sync with
-- CasinoTycoonGuests DESK_MAX_LEVEL).
local MAX_DESK_LEVEL = 3

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

local function deepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, entry in pairs(value) do
		copy[key] = deepCopy(entry)
	end
	return copy
end

-- One writer per profile. Two overlapping UpdateAsync calls would share the
-- live session table and could serialise a half-updated payload, so every
-- write for a player is queued behind the previous one.
local function newMutex()
	return { locked = false, waiters = {} }
end

local function acquireMutex(mutex)
	if not mutex.locked then
		mutex.locked = true
		return
	end
	table.insert(mutex.waiters, coroutine.running())
	coroutine.yield()
end

local function releaseMutex(mutex)
	local nextThread = table.remove(mutex.waiters, 1)
	if nextThread then
		task.defer(nextThread)
	else
		mutex.locked = false
	end
end

local function withMutex(mutex, callback)
	acquireMutex(mutex)
	local ok, result, extra = pcall(callback)
	releaseMutex(mutex)
	if not ok then
		return false, result
	end
	return result, extra
end

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
		DeskLevel = 0,
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
	local deskLevel = math.floor(tonumber(raw.DeskLevel) or 0)
	if deskLevel ~= deskLevel then
		deskLevel = 0
	end
	profile.DeskLevel = math.clamp(deskLevel, 0, MAX_DESK_LEVEL)
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
	-- Older profiles have no DeskLevel: backfill it once so the field is written.
	local needsBackfill = type(raw.DeskLevel) ~= "number"
	return profile, version ~= SCHEMA_VERSION or needsBackfill
end

local sessions = {}

-- Dirty tracking carries a monotonic revision so a save that started before a
-- newer change cannot clear the flag for that change.
local function markDirty(session)
	if not session then
		return
	end
	session.dirty = true
	session.revision = (session.revision or 0) + 1
end

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
	local session = {
		ready = false,
		dirty = false,
		readOnly = false,
		lockHeld = false,
		released = false,
		purchasing = false,
		revision = 0,
		savedRevision = 0,
		writeMutex = newMutex(),
		data = blankProfile(),
	}
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
		markDirty(session)
	end

	local cash = publishCash(player, profile.Cash)
	if cash then
		cash:GetPropertyChangedSignal("Value"):Connect(function()
			if sessions[player] == session then
				markDirty(session)
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

local function performWrite(player, session, releaseAfter)
	if sessions[player] ~= session then
		return false
	end
	if session.readOnly or not session.lockHeld then
		return false
	end
	if not session.dirty and not releaseAfter and session.revision == session.savedRevision then
		return true
	end
	local cash = cashValue(player)
	if cash then
		session.data.Cash = clampCash(cash.Value)
	end
	session.data.Version = SCHEMA_VERSION
	session.data.SavedAt = os.time()

	-- Snapshot under the write lock. The payload must not alias session.data,
	-- otherwise a save still in flight is rewritten by later edits and two
	-- concurrent writes serialise the same shared table.
	local revision = session.revision
	local payload = deepCopy(session.data)
	local saved = withRetry("save " .. player.Name, function()
		return backend:UpdateAsync(keyFor(player), function(current)
			if type(current) == "table" and type(current.Lock) == "table" then
				local holder = tostring(current.Lock.Server)
				if holder ~= "" and holder ~= game.JobId then
					return nil
				end
			end
			if releaseAfter or session.released then
				payload.Lock = nil
			else
				payload.Lock = { At = os.time(), Server = game.JobId, UserId = player.UserId }
			end
			return payload
		end)
	end)
	if saved then
		session.savedRevision = revision
		if session.revision == revision then
			session.dirty = false
		end
		if releaseAfter then
			session.lockHeld = false
		end
		return true
	end
	return false
end

-- Every write for a profile goes through the session mutex, so autosave,
-- PlayerRemoving, BindToClose and a desk purchase can never overlap.
local function writeProfile(player, releaseAfter)
	local session = sessions[player]
	if not session or not session.ready then
		return false
	end
	-- A release started for this session: any late save must not re-arm the lock.
	if releaseAfter then
		session.released = true
	end
	if session.readOnly or not session.lockHeld then
		return false
	end
	if not backend then
		return false
	end
	local ok = withMutex(session.writeMutex, function()
		return performWrite(player, session, releaseAfter)
	end)
	return ok == true
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
	markDirty(sessions[player])
end

-- Desk upgrade level (0..MAX_DESK_LEVEL). Persisted inside the profile so a paid
-- upgrade survives a rejoin; the guest script marks the session dirty on change.
function Data.GetDeskLevel(player)
	local session = sessions[player]
	local profile = session and session.data
	if not profile then
		return nil
	end
	return math.clamp(tonumber(profile.DeskLevel) or 0, 0, MAX_DESK_LEVEL)
end

-- A failed write does not prove the payload was rejected: a timeout or a lost
-- reply may still have committed it. Re-read the key before refunding, and
-- refund as a delta so wins/losses that happened during the write survive.
local function reconcileDeskWrite(player, session, previousLevel, price)
	local stored = withRetry("verify " .. player.Name, function()
		return backend:GetAsync(keyFor(player))
	end)
	if type(stored) == "table" then
		local storedLevel = math.floor(tonumber(stored.DeskLevel) or 0)
		if storedLevel >= previousLevel + 1 then
			-- The write landed: keep the charge and the upgrade.
			session.data.DeskLevel = math.max(tonumber(session.data.DeskLevel) or 0, storedLevel)
			return "granted"
		end
		-- Definitively not stored: give the money back, as a delta.
		local cash = cashValue(player)
		if cash then
			cash.Value = clampCash(cash.Value + price)
		end
		if session.data.DeskLevel == previousLevel + 1 then
			session.data.DeskLevel = previousLevel
		end
		markDirty(session)
		return "refunded"
	end
	-- Undecidable: keeping the charge and the level locally means the next
	-- successful save persists exactly that state, so the player can never end
	-- up holding both the upgrade and the refunded money.
	markDirty(session)
	return "unknown"
end

-- Durable desk purchase. Cash and DeskLevel go out in one payload, and the
-- level is granted only after that write is confirmed. A failed write may
-- still have landed, so the stored profile is re-read before money is
-- refunded. Returns ok, newLevelOrReason, persisted.
function Data.PurchaseDeskUpgrade(player, cost, maxLevel)
	local session = sessions[player]
	if not session or not session.ready then
		return false, "NotReady"
	end
	if session.readOnly or not session.lockHeld then
		return false, "ReadOnly"
	end
	if session.purchasing then
		return false, "Busy"
	end

	local profile = session.data
	local ceiling = math.clamp(math.floor(tonumber(maxLevel) or MAX_DESK_LEVEL), 1, MAX_DESK_LEVEL)
	local level = math.clamp(tonumber(profile.DeskLevel) or 0, 0, ceiling)
	if level >= ceiling then
		return false, "MaxLevel"
	end
	local price = math.floor(tonumber(cost) or -1)
	if price < 0 then
		return false, "BadCost"
	end
	local cash = cashValue(player)
	if not cash then
		return false, "NoCash"
	end
	if cash.Value < price then
		return false, "NotEnoughCash"
	end

	session.purchasing = true
	cash.Value = clampCash(cash.Value - price)
	profile.DeskLevel = level + 1
	markDirty(session)

	local persisted = true
	if not writeProfile(player, false) then
		local outcome = reconcileDeskWrite(player, session, level, price)
		if outcome == "refunded" then
			session.purchasing = nil
			return false, "SaveFailed"
		end
		-- "granted" was confirmed by the re-read; only an unreadable store is
		-- still pending, and the next save persists the same state.
		persisted = outcome == "granted"
	end
	session.purchasing = nil
	return true, level + 1, persisted
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
	markDirty(session)
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
	local session = sessions[player]
	local ok = writeProfile(player, true)
	if session and not session.lockHeld then
		session.closed = true
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
