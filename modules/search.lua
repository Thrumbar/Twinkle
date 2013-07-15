local addonName, ns, _ = ...
local search = {}
ns.search = search

function search.Update(self)
	local oldText, text = self.searchString, self:GetText()
	if text == "" or text == SEARCH then self.searchString = nil
	else self.searchString = string.lower(text) end

	if oldText ~= self.searchString then
		-- TODO: search
	end
end

function search.Reset(self)
	print('reset search')
end
