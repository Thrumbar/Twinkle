local addonName, ns, _ = ...
local search = {}
ns.search = search

function search.Init()
	local view = ns.GetCurrentView()
	if view.Search then return end

	print('search init')
	local scrollFrame = _G[addonName.."UI"].sidebar.scrollFrame
	OptionsList_ClearSelection(scrollFrame, scrollFrame.buttons)
	ns.DisplayPanel("search")
end

function search.Update(self)
	local oldText, text = self.searchString, self:GetText()
	if not text or text == "" or text == SEARCH then
		self.searchString = nil
	else
		self.searchString = string.lower(text)
	end

	if oldText == self.searchString then
		return
	end

	local view = ns.GetCurrentView()
	if view.Search then
		view.Search(self.searchString)

		--[[ local current, currentButton = TwinkleUI.sidebar.scrollFrame.selection, nil
		for i, button in ipairs(TwinkleUI.sidebar.scrollFrame.buttons) do
			local characterKey = button.element
			if characterKey ~= current then
				local numHits = view.Search(self.searchString, characterKey)
				if numHits then
					button:SetAlpha(1)
				else
					button:SetAlpha(0.4)
				end
			else
				currentButton = button
			end
		end
		currentButton:SetAlpha(1)
		view.Search(self.searchString, current) --]]
	else
		search.Init()
		-- TODO: search
	end
end

function search.Reset(self)
	--[[ for i, button in ipairs(TwinkleUI.sidebar.scrollFrame.buttons) do
		button:SetAlpha(1)
	end --]]

	local view = ns.GetCurrentView()
	if view.name ~= "search" and view.Search then
		ns.Update()
	else
		ns.DisplayPanel("default")
	end
end
