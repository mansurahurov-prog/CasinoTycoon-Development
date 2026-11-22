-- Global Lucky Hour event: doubles all passive payouts for a short window.
local ct = workspace:WaitForChild("CasinoTycoon")

local IDLE_TIME = 480
local ACTIVE_TIME = 180
local MULTIPLIER = 2

if ct:GetAttribute("LuckyHourMultiplier") == nil then
	ct:SetAttribute("LuckyHourMultiplier", 1)
end
ct:SetAttribute("LuckyHourActive", false)

local function setActive(on)
	ct:SetAttribute("LuckyHourMultiplier", on and MULTIPLIER or 1)
	ct:SetAttribute("LuckyHourActive", on)
end

task.wait(90)

while true do
	setActive(true)
	task.wait(ACTIVE_TIME)
	setActive(false)
	task.wait(IDLE_TIME)
end
