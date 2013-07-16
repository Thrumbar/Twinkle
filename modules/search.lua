local addonName, ns, _ = ...
local search = {}
ns.search = search

function search.Init()
	print('search init')
	local scrollFrame = _G[addonName.."UI"].sidebar.scrollFrame
	OptionsList_ClearSelection(scrollFrame, scrollFrame.buttons)
	ns.DisplayPanel("search")
end

function search.Update(self)
	local oldText, text = self.searchString, self:GetText()
	if text == "" or text == SEARCH then self.searchString = nil
	else self.searchString = string.lower(text) end

	if oldText ~= self.searchString then
		if self.searchString then search.Init() end
		-- TODO: search
	end
end

function search.Reset(self)
	print('reset search')
	ns.DisplayPanel("default")
	ns.Update()
end
