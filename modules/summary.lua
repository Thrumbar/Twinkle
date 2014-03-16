local addonName, ns, _ = ...
local summary = {}
ns.summary = summary

-- GLOBALS: TwinkleUI
-- GLOBALS: OptionsList_ClearSelection, GetItemInfo
-- GLOBALS: string, table, pairs, ipairs, wipe, select, type, tonumber, print

-- used as fallback if no data returned
local empty = {}
local characters = ns.data.GetCharacters()

function summary.Update(self)
	local view = ns.GetCurrentView()
	if not view or view.name == 'search' or not view.Summary then
		return
	end

	local scrollFrame = _G[addonName.."UI"].sidebar.scrollFrame
	OptionsList_ClearSelection(scrollFrame, scrollFrame.buttons)
	view.Summary()
end
