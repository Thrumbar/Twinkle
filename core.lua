local addonName, ns, _ = ...

-- GLOBALS:

ns.views = {}
function ns:GetName() return addonName end

-- settings
local globalDefaults = {}
local localDefaults = {}

local function UpdateDatabase()
	--[[ if MidgetDB == nil then
		MidgetDB = globalDefaults
	else
		for key,value in pairs(globalDefaults) do
			if MidgetDB[key] == nil then MidgetDB[key] = value end
		end
	end

	if MidgetLocalDB == nil then
		MidgetLocalDB = localDefaults
	else
		for key,value in pairs(localDefaults) do
			if MidgetLocalDB[key] == nil then MidgetLocalDB[key] = value end
		end
	end--]]
end

local function InitializeLDB()
	ns.ldb = LibStub:GetLibrary("LibDataBroker-1.1"):NewDataObject(addonName, {
		type  = "launcher",
		icon  = "Interface\\Icons\\ACHIEVEMENT_GUILDPERK_MRPOPULARITY_RANK2",
		label = addonName,

		OnClick = function(self, button)
			if button == "RightButton" then
				-- open config
				-- InterfaceOptionsFrame_OpenToCategory(Viewda.options)
			else
				ns.ToggleUI()
			end
		end,
	})
end

local frame, eventHooks = CreateFrame("Frame", "MidgetEventHandler"), {}
local function eventHandler(frame, event, arg1, ...)
	if event == 'ADDON_LOADED' and arg1 == addonName then
		-- make sure we always init before any other module
		ns.Initialize()
		if not eventHooks[event] or ns.Count(eventHooks[event]) < 1 then
			frame:UnregisterEvent(event)
		end
	end

	if eventHooks[event] then
		for id, listener in pairs(eventHooks[event]) do
			listener(frame, event, arg1, ...)
		end
	end
end
frame:SetScript("OnEvent", eventHandler)
frame:RegisterEvent("ADDON_LOADED")

function ns.RegisterEvent(event, callback, id, silentFail)
	assert(callback and event and id, format("Usage: RegisterEvent(event, callback, id[, silentFail])"))
	if not eventHooks[event] then
		eventHooks[event] = {}
		frame:RegisterEvent(event)
	end
	assert(silentFail or not eventHooks[event][id], format("Event %s already registered by id %s.", event, id))

	eventHooks[event][id] = callback
end
function ns.UnregisterEvent(event, id)
	if not eventHooks[event] or not eventHooks[event][id] then return end
	eventHooks[event][id] = nil
	if ns.Count(eventHooks[event]) < 1 then
		eventHooks[event] = nil
		frame:UnregisterEvent(event)
	end
end

-- ================================================
-- Little Helpers
-- ================================================
function ns.Print(text, ...)
	if ... and text:find("%%") then
		text = format(text, ...)
	elseif ... then
		text = join(", ", tostringall(text, ...))
	end
	DEFAULT_CHAT_FRAME:AddMessage("|cffE01B5DTwinkle|r "..text)
end

function ns.Debug(...)
  if true then
	ns.Print("! "..join(", ", tostringall(...)))
  end
end

function ns.ShowTooltip(self)
	if not self.tiptext and not self.link then return end
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	GameTooltip:ClearLines()

	if self.link then
		GameTooltip:SetHyperlink(self.link)
	elseif type(self.tiptext) == "string" and self.tiptext ~= "" then
		GameTooltip:SetText(self.tiptext, nil, nil, nil, nil, true)
	elseif type(self.tiptext) == "function" then
		self.tiptext(self, GameTooltip)
	end
	GameTooltip:Show()
end
function ns.HideTooltip() GameTooltip:Hide() end
function ns.GetLinkID(link)
	if not link or type(link) ~= "string" then return end
	local linkType, id = link:match("\124H([^:]+):([^:]+)")
	return linkType, tonumber(id)
end
-- counts table entries. for numerically indexed tables, use #table
function ns.Count(table)
	if not table or type(table) ~= "table" then return 0 end
	local i = 0
	for _ in pairs(table) do
		i = i + 1
	end
	return i
end

function ns.Find(where, what)
	for k, v in pairs(where) do
		if v == what then
			return k
		end
	end
end

local function ViewShow(self)
	if not self.panel then
		self.Init()
	end
	self.Update()
end
function ns.CreateView(name)
	local view = {}
	view.name = name
	view.Show = ViewShow
	table.insert(ns.views, view)

	return view
end

-- ================================================
function ns.Initialize()
	UpdateDatabase()
	InitializeLDB()

	-- expose us
	Twinkle = ns
end
