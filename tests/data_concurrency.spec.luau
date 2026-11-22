--!nolint
-- Unit tests for CasinoTycoonData save/purchase concurrency.
-- Runs the real module against a fake Roblox environment and a scriptable
-- DataStore, so races (autosave vs purchase, PlayerRemoving vs save, lost
-- reply on UpdateAsync) are reproduced deterministically.
-- Usage: luau tests/data_concurrency.spec.luau

-- ---------------------------------------------------------------- scheduler
local clock = 0
local ready = {}
local sleepers = {}

local function enqueue(thread)
	table.insert(ready, thread)
end

local function promoteDue()
	local promoted = false
	for index = #sleepers, 1, -1 do
		local sleeper = sleepers[index]
		if sleeper.at <= clock then
			table.remove(sleepers, index)
			table.insert(ready, sleeper.thread)
			promoted = true
		end
	end
	return promoted
end

local function step()
	local guard = 0
	while true do
		if #ready > 0 then
			local thread = table.remove(ready, 1)
			local ok, err = coroutine.resume(thread)
			if not ok then
				error("thread failed: " .. tostring(err), 0)
			end
		elseif not promoteDue() then
			break
		end
		guard += 1
		if guard > 200000 then
			error("scheduler spin", 0)
		end
	end
end

local function settle(maxAdvance)
	maxAdvance = maxAdvance or 0
	step()
	while true do
		local nextAt
		for _, sleeper in ipairs(sleepers) do
			if not nextAt or sleeper.at < nextAt then
				nextAt = sleeper.at
			end
		end
		if not nextAt or nextAt > clock + maxAdvance then
			break
		end
		if nextAt > clock then
			clock = nextAt
		end
		step()
	end
end

task = {
	wait = function(seconds)
		table.insert(sleepers, { thread = coroutine.running(), at = clock + (seconds or 0) })
		coroutine.yield()
	end,
	waitn = function() end,
	spawn = function(fn, ...)
		if type(fn) == "thread" then
			enqueue(fn)
			return fn
		end
		local thread = coroutine.create(fn)
		local ok, err = coroutine.resume(thread, ...)
		if not ok then
			error("task.spawn failed: " .. tostring(err), 0)
		end
		return thread
	end,
	defer = function(fn)
		if type(fn) == "thread" then
			enqueue(fn)
		else
			enqueue(coroutine.create(fn))
		end
	end,
}

-- ---------------------------------------------------------------- signals
local Signal = {}
Signal.__index = Signal

local function newSignal()
	return setmetatable({ handlers = {} }, Signal)
end

function Signal:Connect(handler)
	table.insert(self.handlers, handler)
	return { Disconnect = function() end }
end

function Signal:Fire(...)
	for _, handler in ipairs(self.handlers) do
		local ok, err = pcall(handler, ...)
		if not ok then
			error("signal handler failed: " .. tostring(err), 0)
		end
	end
end

-- ---------------------------------------------------------------- instances
local function newFolder(name)
	return {
		Name = name,
		ClassName = "Folder",
		children = {},
		attributes = {},
		IsA = function(self, class)
			return class == "Folder" or class == "Instance"
		end,
		FindFirstChild = function(self, childName)
			for _, child in ipairs(self.children) do
				if child.Name == childName then
					return child
				end
			end
			return nil
		end,
		WaitForChild = function(self, childName)
			return self:FindFirstChild(childName)
		end,
		GetChildren = function(self)
			return self.children
		end,
	}
end

local function newNumberValue(name, initial)
	local state = { value = initial, changed = newSignal() }
	local proxy = {}
	local methods = {
		IsA = function(_, class)
			return class == "IntValue" or class == "ValueBase" or class == "Instance"
		end,
		GetPropertyChangedSignal = function(_, property)
			assert(property == "Value", "unexpected property")
			return state.changed
		end,
	}
	return setmetatable(proxy, {
		__index = function(_, key)
			if key == "Value" then
				return state.value
			elseif key == "Name" then
				return name
			end
			return methods[key]
		end,
		__newindex = function(_, key, value)
			if key == "Value" then
				state.value = value
				state.changed:Fire()
			else
				rawset(proxy, key, value)
			end
		end,
	})
end

local function newPlayer(name, cash)
	local leaderstats = newFolder("leaderstats")
	leaderstats.children = { newNumberValue("Cash", cash) }
	local player = {
		Name = name,
		UserId = 100 + math.random(1, 100000),
		attributes = {},
		children = { leaderstats },
		IsA = function(self, class)
			return class == "Player" or class == "Instance"
		end,
		FindFirstChild = function(self, childName)
			for _, child in ipairs(self.children) do
				if child.Name == childName then
					return child
				end
			end
			return nil
		end,
		WaitForChild = function(self, childName)
			return self:FindFirstChild(childName)
		end,
		SetAttribute = function(self, key, value)
			self.attributes[key] = value
		end,
		GetAttribute = function(self, key)
			return self.attributes[key]
		end,
	}
	return player
end

-- ---------------------------------------------------------------- datastore
local function newStore()
	local store = { data = {}, behavior = "ok", latency = 1, calls = 0, active = 0, maxActive = 0 }

	function store:reset(behavior, latency)
		self.data = {}
		self.behavior = behavior or "ok"
		self.latency = latency or 1
		self.calls = 0
		self.active = 0
		self.maxActive = 0
	end

	function store:GetAsync(key)
		self.calls += 1
		for _ = 1, self.latency do
			task.wait(0)
		end
		if self.behavior == "failReads" then
			error("GetAsync request failed")
		end
		return self.data[key]
	end

	function store:UpdateAsync(key, transform)
		self.calls += 1
		self.active += 1
		if self.active > self.maxActive then
			self.maxActive = self.active
		end
		for _ = 1, self.latency do
			task.wait(0)
		end
		local updated = transform(self.data[key])
		for _ = 1, self.latency do
			task.wait(0)
		end
		self.active -= 1
		if updated == nil then
			return nil
		end
		if self.behavior == "failBeforeCommit" then
			error("UpdateAsync request failed")
		end
		self.data[key] = updated
		if self.behavior == "failAfterCommit" then
			error("UpdateAsync timed out after write")
		end
		return updated
	end

	return store
end

-- ---------------------------------------------------------------- roblox env
local store = newStore()
local playersList = {}
local Players = {
	PlayerAdded = newSignal(),
	PlayerRemoving = newSignal(),
	GetPlayers = function()
		local copy = {}
		for _, player in ipairs(playersList) do
			table.insert(copy, player)
		end
		return copy
	end,
}

local plotsFolder = newFolder("Plots")
local casinoFolder = newFolder("CasinoTycoon")
casinoFolder.children = { plotsFolder }

game = {
	JobId = "test-server",
	GetService = function(_, service)
		if service == "Players" then
			return Players
		elseif service == "DataStoreService" then
			return {
				GetDataStore = function(_, dataStoreName)
					if dataStoreName == "CasinoTycoonCash_v1" then
						return { GetAsync = function() return nil end }
					end
					return store
				end,
			}
		end
		error("unexpected service " .. tostring(service))
	end,
	BindToClose = function() end,
}

workspace = {
	WaitForChild = function(_, name)
		if name == "CasinoTycoon" then
			return casinoFolder
		end
		return newFolder(name)
	end,
}

warn = function(message)
	print("[warn] " .. tostring(message))
end

-- ---------------------------------------------------------------- module
-- Injected by tests/run-tests.ps1: the real module source, loaded into this
-- environment so the module sees the fake Roblox globals defined above.
local Data = assert(loadstring(_MODULE_SOURCE, "CasinoTycoonData"))()

local failures = 0
local checks = 0
local currentTest = "?"

local function expect(condition, message)
	checks += 1
	if not condition then
		failures += 1
		print(("FAIL [%s] %s"):format(currentTest, message))
	end
end

local function expectEqual(actual, expected, message)
	checks += 1
	if actual ~= expected then
		failures += 1
		print(("FAIL [%s] %s (expected %s, got %s)"):format(currentTest, message, tostring(expected), tostring(actual)))
	end
end

local function keyFor(player)
	return "Player_" .. tostring(player.UserId)
end

local function cashOf(player)
	return player:FindFirstChild("leaderstats"):FindFirstChild("Cash")
end

local function profileKey(player)
	return keyFor(player)
end

local function join(name, cash)
	local player = newPlayer(name, cash or 1000)
	table.insert(playersList, player)
	Players.PlayerAdded:Fire(player)
	settle(0)
	return player
end

local function removePlayer(player)
	for index = #playersList, 1, -1 do
		if playersList[index] == player then
			table.remove(playersList, index)
		end
	end
	Players.PlayerRemoving:Fire(player)
end

-- ------------------------------------------------------------------ tests
local tests = {}
local function test(name, fn)
	table.insert(tests, { name = name, fn = fn })
end

test("purchase upgrades desk and stores cash atomically", function()
	store:reset("ok", 1)
	local player = join("Buyer", 1000)
	local ok, level, persisted = Data.PurchaseDeskUpgrade(player, 400, 3)
	settle(0)
	expectEqual(ok, true, "purchase accepted")
	expectEqual(level, 1, "new desk level")
	expectEqual(persisted, true, "write confirmed")
	expectEqual(cashOf(player).Value, 600, "cash charged once")
	local stored = store.data[profileKey(player)]
	expectEqual(stored.Cash, 600, "stored cash")
	expectEqual(stored.DeskLevel, 1, "stored desk level")
	expectEqual(stored.Lock ~= nil, true, "lock re-armed while playing")
end)

test("autosave and purchase never interleave on one profile", function()
	store:reset("ok", 3)
	local player = join("Racer", 1000)
	Data.MarkDirty(player)
	local saveThread = task.spawn(function()
		Data.Save(player)
	end)
	local ok = Data.PurchaseDeskUpgrade(player, 400, 3)
	settle(0)
	settle(10)
	expectEqual(ok, true, "purchase accepted")
	expectEqual(cashOf(player).Value, 600, "cash charged once")
	local stored = store.data[profileKey(player)]
	expectEqual(stored.Cash, 600, "stored cash after both writes")
	expectEqual(stored.DeskLevel, 1, "stored desk level")
	expectEqual(store.maxActive, 1, "writes for one profile never overlap")
end)

test("overlapping writes serialise instead of sharing the payload", function()
	store:reset("ok", 2)
	local player = join("Parallel", 1000)
	Data.MarkDirty(player)
	local first = task.spawn(function()
		Data.Save(player)
	end)
	local second = task.spawn(function()
		Data.Save(player)
	end)
	settle(0)
	settle(10)
	local stored = store.data[profileKey(player)]
	expectEqual(type(stored), "table", "profile stored")
	expectEqual(cashOf(player).Value, 1000, "cash untouched")
	expectEqual(store.maxActive, 1, "parallel saves are serialised")
end)

test("definite save failure refunds exactly the price", function()
	store:reset("ok", 1)
	local player = join("Refund", 1000)
	-- Only the purchase write fails; the load and the verify read still work.
	store.behavior = "failBeforeCommit"
	local ok, reason = Data.PurchaseDeskUpgrade(player, 400, 3)
	settle(10)
	expectEqual(ok, false, "purchase rejected")
	expectEqual(reason, "SaveFailed", "reason")
	expectEqual(cashOf(player).Value, 1000, "cash restored")
	expectEqual(Data.GetDeskLevel(player), 0, "level not granted")
end)

test("refund preserves cash earned during the failed write", function()
	store:reset("ok", 2)
	local player = join("Earner", 1000)
	store.behavior = "failBeforeCommit"
	local purchase = task.spawn(function()
		local ok = Data.PurchaseDeskUpgrade(player, 400, 3)
		return ok
	end)
	-- A guest pays out while the purchase write is failing.
	task.wait(0)
	settle(0)
	cashOf(player).Value = 660
	settle(20)
	expectEqual(cashOf(player).Value, 1060, "refund added back, concurrent gain kept")
	expectEqual(Data.GetDeskLevel(player), 0, "level not granted")
end)

test("lost reply after commit keeps the upgrade instead of refunding", function()
	store:reset("ok", 1)
	local player = join("Timeout", 1000)
	store.behavior = "failAfterCommit"
	local ok, level, persisted = Data.PurchaseDeskUpgrade(player, 400, 3)
	settle(20)
	expectEqual(ok, true, "committed write accepted")
	expectEqual(persisted, true, "re-read confirmed the write")
	expectEqual(level, 1, "level granted")
	expectEqual(cashOf(player).Value, 600, "charged once")
	expectEqual(store.data[profileKey(player)].DeskLevel, 1, "stored level")
end)

test("repeat purchase after a failed save charges exactly once", function()
	store:reset("ok", 1)
	local player = join("Retry", 1000)
	store.behavior = "failBeforeCommit"
	local ok = Data.PurchaseDeskUpgrade(player, 400, 3)
	settle(10)
	expectEqual(ok, false, "first attempt fails")
	store:reset("ok", 1)
	store.data[profileKey(player)] = nil
	local ok2, level = Data.PurchaseDeskUpgrade(player, 400, 3)
	settle(0)
	expectEqual(ok2, true, "retry succeeds")
	expectEqual(level, 1, "level one")
	expectEqual(cashOf(player).Value, 600, "charged once")
end)

test("second concurrent purchase is rejected while the first is writing", function()
	store:reset("ok", 4)
	local player = join("Double", 1000)
	local results = {}
	task.spawn(function()
		table.insert(results, { Data.PurchaseDeskUpgrade(player, 400, 3) })
	end)
	Data.PurchaseDeskUpgrade(player, 400, 3)
	settle(0)
	settle(10)
	expectEqual(cashOf(player).Value, 600, "only one charge")
	expectEqual(Data.GetDeskLevel(player), 1, "only one level")
	expectEqual(#results, 1, "first call finished")
end)

test("SaveAndRelease during a purchase keeps state consistent and drops the lock", function()
	store:reset("ok", 3)
	local player = join("Leaver", 1000)
	task.spawn(function()
		Data.PurchaseDeskUpgrade(player, 400, 3)
	end)
	task.wait(0)
	settle(0)
	task.spawn(function()
		Data.SaveAndRelease(player)
	end)
	settle(0)
	settle(20)
	local stored = store.data[profileKey(player)]
	expectEqual(stored.Cash, 600, "stored cash")
	expectEqual(stored.DeskLevel, 1, "stored level")
	expectEqual(stored.Lock, nil, "lock released")
	expectEqual(Data.IsReady(player), false, "session released")
end)

test("purchase preserves plots, milestones and receipts", function()
	store:reset("ok", 1)
	local player = join("Keeper", 1000)
	local profile = Data.Get(player)
	profile.Milestones.SlotsUnlocked = true
	profile.Plots.Plot_1 = { Slot1Purchased = true }
	Data.AddReceipt(player, "receipt-1")
	local ok = Data.PurchaseDeskUpgrade(player, 400, 3)
	settle(0)
	expectEqual(ok, true, "purchase accepted")
	local stored = store.data[profileKey(player)]
	expectEqual(stored.Milestones.SlotsUnlocked, true, "milestones kept")
	expectEqual(stored.Plots.Plot_1.Slot1Purchased, true, "plots kept")
	expectEqual(stored.PurchaseIds["receipt-1"] ~= nil, true, "receipts kept")
	expectEqual(stored.Cash, 600, "cash stored")
end)

-- ---------------------------------------------------------------- runner
for _, entry in ipairs(tests) do
	currentTest = entry.name
	local before = failures
	local thread = coroutine.create(entry.fn)
	enqueue(thread)
	local guard = 0
	while coroutine.status(thread) ~= "dead" and guard < 40 do
		guard += 1
		settle(20)
	end
	if coroutine.status(thread) ~= "dead" then
		failures += 1
		print(("FAIL [%s] did not finish"):format(entry.name))
	elseif failures == before then
		print(("PASS  %s"):format(entry.name))
	end
end

print(("%d checks, %d failures"):format(checks, failures))
if failures > 0 then
	error(("%d test failures"):format(failures), 0)
end
print("ALL TESTS PASSED")
