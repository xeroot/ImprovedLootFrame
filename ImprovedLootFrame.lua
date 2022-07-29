-- ///
-- ImprovedLootFrame stand-alone
-- ///

local folder, core = ...
core.title = GetAddOnMetadata(folder, "Title")
core.version = GetAddOnMetadata(folder, "Version")
core.name = UnitName("player")
core.race = select(2, UnitRace("player"))
core.faction = UnitFactionGroup("player")
core.class = select(2, UnitClass("player"))
_G.KPack = core

local L = core.L

-------------------------------------------------------------------------------
-- Weak Table
--

local wipe = wipe or table.wipe

local weaktable = {__mode = "v"}
function WeakTable(t)
	return setmetatable(wipe(t or {}), weaktable)
end

-- Shamelessly copied from Omen - thanks!
local tablePool = setmetatable({}, {__mode = "kv"})

-- get a new table
function newTable()
	local t = next(tablePool) or {}
	tablePool[t] = nil
	return t
end

-- delete table and return to pool
function delTable(t)
	if type(t) == "table" then
		wipe(t)
		t[true] = true
		t[true] = nil
		tablePool[t] = true
	end
	return nil
end

-------------------------------------------------------------------------------

-- automatic garbage collection
local collectgarbage = collectgarbage
local UnitIsAFK = UnitIsAFK
local InCombatLockdown = InCombatLockdown
local eventcount = 0

local f = CreateFrame("Frame")
f:SetScript("OnEvent", function(self, event, arg1)
	if event == "PLAYER_LOGIN" then
		core.guid = UnitGUID("player")
	elseif (InCombatLockdown() and eventcount > 25000) or (not InCombatLockdown() and eventcount > 10000) or event == "PLAYER_ENTERING_WORLD" then
		collectgarbage("collect")
		eventcount = 0
		self:UnregisterEvent(event)
	elseif event == "PLAYER_REGEN_ENABLED" then
		core.InCombat = false
	elseif event == "PLAYER_REGEN_DISABLED" then
		core.InCombat = true
	else
		if arg1 ~= "player" then
			return
		end
		if UnitIsAFK(arg1) then
			collectgarbage("collect")
		end
	end
	eventcount = eventcount + 1
end)
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("PLAYER_FLAGS_CHANGED")
f:RegisterEvent("PLAYER_REGEN_ENABLED")
f:RegisterEvent("PLAYER_REGEN_DISABLED")

function RegisterForEvent(event, callback, ...)
	frame = CreateFrame("Frame")
	frame:SetScript("OnEvent", function(f, event, ...)
		for func, args in next, f.events[event] do
			func(unpack(args), ...)
		end
	end)
	frame.events = frame.events or {}
	frame.events[event] = frame.events[event] or {}
	frame.events[event][callback] = {...}
	frame:RegisterEvent(event)
end


print("ImprovedLootFrame is enabled.")

local mod = {}

local hasAddon

-- cache frequently used globals
local CreateFrame = CreateFrame
local GetNumLootItems = GetNumLootItems
local select, pairs = select, pairs
local format = string.format
local random = math.random
-- ///////////////////////////////////////////////////////
-- replace default functions
-- ///////////////////////////////////////////////////////

local RAID_CLASS_COLORS = RAID_CLASS_COLORS
local hexColors = {}
for k, v in pairs(RAID_CLASS_COLORS) do
	hexColors[k] = format("|cff%02x%02x%02x", v.r * 255, v.g * 255, v.b * 255)
end
hexColors.UNKNOWN = format("|cff%02x%02x%02x", 0.6 * 255, 0.6 * 255, 0.6 * 255)

if CUSTOM_CLASS_COLORS then
	local function update()
		for k, v in pairs(CUSTOM_CLASS_COLORS) do
			hexColors[k] = ("|cff%02x%02x%02x"):format(v.r * 255, v.g * 255, v.b * 255)
		end
	end
	CUSTOM_CLASS_COLORS:RegisterCallback(update)
	update()
end

local unknownColor = {r = 0.6, g = 0.6, b = 0.6}
local classesInRaid, randoms

local function CandidateUnitClass(unit)
	local class, filename = UnitClass(unit)
	if class then
		return class, filename
	end
	return UNKNOWN, "UNKNOWN"
end

local function ILF_InitializeMenu()
	local candidate, color
	local info

	if UIDROPDOWNMENU_MENU_LEVEL == 2 then
		for i = 1, 40 do
			candidate = GetMasterLootCandidate(i)
			if candidate then
				local class = select(2, CandidateUnitClass(candidate))
				if class == UIDROPDOWNMENU_MENU_VALUE then
					info = UIDropDownMenu_CreateInfo()
					info.text = candidate
					info.colorCode = hexColors[class] or hexColors.UNKNOWN
					info.textHeight = 12
					info.value = i
					info.func = GroupLootDropDown_GiveLoot
					UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL)
				end
			end
		end
		return
	end

	info = UIDropDownMenu_CreateInfo()
	info.isTitle = true
	info.text = GIVE_LOOT
	info.textHeight = 12
	info.notCheckable = true
	UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL)

	if GetNumRaidMembers() > 0 then
		classesInRaid = WeakTable(classesInRaid)

		for i = 1, 40 do
			candidate = GetMasterLootCandidate(i)
			if candidate then
				local cname, class = CandidateUnitClass(candidate)
				classesInRaid[class] = cname
			end
		end

		for k, v in pairs(classesInRaid) do
			info = UIDropDownMenu_CreateInfo()
			info.text = v
			info.colorCode = hexColors[k] or hexColors.UNKOWN
			info.textHeight = 12
			info.hasArrow = true
			info.notCheckable = true
			info.value = k
			UIDropDownMenu_AddButton(info)
		end
	else
		for i = 1, MAX_PARTY_MEMBERS + 1, 1 do
			candidate = GetMasterLootCandidate(i)
			if candidate then
				info = UIDropDownMenu_CreateInfo()
				info.text = candidate
				info.colorCode = hexColors[select(2, CandidateUnitClass(candidate))] or hexColors.UNKOWN
				info.textHeight = 12
				info.value = i
				info.notCheckable = true
				info.func = GroupLootDropDown_GiveLoot
				UIDropDownMenu_AddButton(info)
			end
		end
	end

	randoms = newTable()
	for i = 1, 40 do
		candidate = GetMasterLootCandidate(i)
		if candidate then
			tinsert(randoms, i)
		end
	end
	if #randoms > 0 then
		info.colorCode = "|cffffffff"
		info.textHeight = 12
		info.value = randoms[random(1, #randoms)]
		info.notCheckable = 1
		info.text = L["Random"]
		info.func = GroupLootDropDown_GiveLoot
		info.hasArrow = nil
		UIDropDownMenu_AddButton(info)
	end
	delTable(randoms)

	for i = 1, 40 do
		candidate = GetMasterLootCandidate(i)
		if candidate and candidate == core.name then
			info.colorCode = hexColors[core.class] or hexColors["UNKOWN"]
			info.textHeight = 12
			info.value = i
			info.notCheckable = 1
			info.text = L["Self Loot"]
			info.func = GroupLootDropDown_GiveLoot
			UIDropDownMenu_AddButton(info)
			break
		end
	end
end

-- replacing LootFrame_Show
local ILF_LootFrame_Show
do
	local p, r, x, y = "TOP", "BOTTOM", 0, -4
	local buttonHeight = LootButton1:GetHeight() + abs(y)
	local baseHeight = LootFrame:GetHeight() - (buttonHeight * LOOTFRAME_NUMBUTTONS)

	local Old_LootFrame_Show = LootFrame_Show
	function ILF_LootFrame_Show(self, ...)
		LootFrame:SetHeight(baseHeight + (GetNumLootItems() * buttonHeight))
		local num = GetNumLootItems()
		for i = 1, GetNumLootItems() do
			if i > LOOTFRAME_NUMBUTTONS then
				local button = _G["LootButton" .. i]
				if not button then
					button = CreateFrame("Button", "LootButton" .. i, LootFrame, "LootButtonTemplate", i)
				end
				LOOTFRAME_NUMBUTTONS = i
			end

			if i > 1 then
				local button = _G["LootButton" .. i]
				button:ClearAllPoints()
				button:SetPoint(p, "LootButton" .. (i - 1), r, x, y)
			end
		end
		return Old_LootFrame_Show(self, ...)
	end
end

-- replacing LootButton_OnClick
local ILF_LootButton_OnClick
do
	-- list of registered frames.
	local frames = {}

	-- populates the frames table.
	local function PopulateFrames(...)
		frames = wipe(frames or {})
		for i = 1, select("#", ...) do
			frames[i] = select(i, ...)
		end
	end

	local Old_LootButton_OnClick = LootButton_OnClick
	function ILF_LootButton_OnClick(self, ...)
		PopulateFrames(GetFramesRegisteredForEvent("ADDON_ACTION_BLOCKED"))

		for i, frame in pairs(frames) do
			frame:UnregisterEvent("ADDON_ACTION_BLOCKED")
		end

		Old_LootButton_OnClick(self, ...)
		for i, frame in pairs(frames) do
			frame:RegisterEvent("ADDON_ACTION_BLOCKED")
		end
	end
end

-- initializes the module
local function ILF_Initialize()
	local i, t = 1, "Interface\\LootFrame\\UI-LootPanel"

	while true do
		local r = select(i, LootFrame:GetRegions())
		if not r then
			break
		end

		if r.GetText and r:GetText() == ITEMS then
			r:ClearAllPoints()
			r:SetPoint("TOP", -12, -19.5)
		elseif r.GetTexture and r:GetTexture() == t then
			r:Hide()
		end
		i = i + 1
	end

	-- frame top
	local top = LootFrame:CreateTexture("LootFrameBackdropTop")
	top:SetTexture(t)
	top:SetTexCoord(0, 1, 0, 0.3046875)
	top:SetPoint("TOP")
	top:SetHeight(78)

	-- frame bottom
	local bottom = LootFrame:CreateTexture("LootFrameBackdropBottom")
	bottom:SetTexture(t)
	bottom:SetTexCoord(0, 1, 0.9296875, 1)
	bottom:SetPoint("BOTTOM")
	bottom:SetHeight(18)

	-- frame middle
	local mid = LootFrame:CreateTexture("LootFrameBackdropMiddle")
	mid:SetTexture(t)
	mid:SetTexCoord(0, 1, 0.3046875, 0.9296875)
	mid:SetPoint("TOP", top, "BOTTOM")
	mid:SetPoint("BOTTOM", bottom, "TOP")
end

RegisterForEvent("PLAYER_LOGIN", function()
	hasAddon = IsAddOnLoaded("LovelyLoot")
	if hasAddon then return end
	ILF_Initialize()
	_G.LootFrame_Show = ILF_LootFrame_Show
	_G.LootButton_OnClick = ILF_LootButton_OnClick
	UIDropDownMenu_Initialize(GroupLootDropDown, ILF_InitializeMenu)
end)