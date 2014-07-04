local addonName, addon, _ = ...

-- GLOBALS: _G
-- GLOBALS: CreateFrame, FauxScrollFrame_Update, FauxScrollFrame_GetOffset, FauxScrollFrame_OnVerticalScroll
-- GLOBALS: hooksecurefunc, ipairs

local summary = addon:NewModule('summary')

function summary.OnEnable()
	local views = addon:GetModule('views', true)
	if not views then return end

	-- add summary button to frame sidebar
	local frame = addon.frame
	local button = CreateFrame('Button', '$parentSummaryButton', frame.sidebar, 'UIPanelButtonTemplate')
	      button:SetPoint('TOPRIGHT', -10, -10)
	      button:SetWidth(100)

	button:SetText('Summary')
	button:SetScript('OnClick', function(self, btn, up)
		summary.show = not summary.show
		summary.Update()
	end)
	frame.summary = button

	-- add a unified panel that will hold all info
	local panel = CreateFrame('Frame', '$parentPanelSummary', addon.frame)
	      panel:Hide()
	summary.panel = panel

	panel:SetParent(frame.content)
	panel:ClearAllPoints()
	panel:SetAllPoints()

	local scrollFrame = CreateFrame('ScrollFrame', '$parentTable', panel, 'FauxScrollFrameTemplate')
	panel.scrollFrame = scrollFrame

	scrollFrame:SetPoint('TOPLEFT', 4, -40)
	scrollFrame:SetPoint('BOTTOMRIGHT', -24, 2) -- -4, 2)

	-- build our data table
	scrollFrame.scrollBarHideable = true
	scrollFrame.table = {
		headers = {},
	}

	local numRows, numColumns = #(frame.sidebar.scrollFrame.buttons), 5
	for row, characterButton in ipairs(frame.sidebar.scrollFrame.buttons) do
		scrollFrame.table[row] = {}

		for col = 1, numColumns do
			local cell = CreateFrame('Frame', '$parentRow'..row..'Col'..col, panel, nil, col)
			      cell:SetBackdrop(_G.GameTooltip:GetBackdrop())
			      cell:SetPoint('TOP', characterButton, 'TOP')
			      cell:SetPoint('BOTTOM', characterButton, 'BOTTOM')
			      cell:SetWidth(70)

			if col == 1 then
				cell:SetPoint('LEFT', 10, 0)
			else
				cell:SetPoint('TOPLEFT', scrollFrame.table[row][col-1], 'TOPRIGHT', 0, 0)
			end

			if row == 1 then
				-- add column header
				local header = panel:CreateFontString(nil, nil, 'GameFontNormal')
				      header:SetPoint('TOP')
				      header:SetPoint('BOTTOM', cell, 'TOP', -4, 0)
				      header:SetPoint('LEFT', cell, 'LEFT')
				      header:SetPoint('RIGHT', cell, 'RIGHT')

				scrollFrame.table.headers[col] = header
			end
			scrollFrame.table[row][col] = cell
		end
	end

	scrollFrame:SetScript('OnVerticalScroll', function(self, offset)
		local stepSize = scrollFrame.table[1][1]:GetWidth()
		FauxScrollFrame_OnVerticalScroll(self, offset, stepSize, summary.UpdateTable)
	end)

	-- make sure all views are always up to date & filtered properly
	local function OnViewUpdate()
		-- summary.updating = true
		summary.Update()
		-- summary.updating = nil
	end
	-- hook into existing views
	for name, view in views:IterateModules() do
		hooksecurefunc(view, 'Update', OnViewUpdate)
	end
	-- also, mind future views!
	hooksecurefunc(views, 'NewModule', function(viewName)
		hooksecurefunc(views:GetModule(viewName), 'Update', OnViewUpdate)
	end)
end

function summary.UpdateTable(...)
	summary.UpdateHeaders(...)
	summary.UpdateRows(...)
end

-- TODO: how can views supply header labels and table data???
function summary.UpdateHeaders(scrollFrame)
	local views = addon:GetModule('views')
	local view  = views.GetActiveView()

	local offset = FauxScrollFrame_GetOffset(scrollFrame)
	for column, header in ipairs(scrollFrame.table.headers) do
		local label = view.SummaryColumn and view:SummaryColumn(column + offset) or 'Column '..(column + offset)
		header:SetText(label)
	end
end

function summary.UpdateRows(scrollFrame)
	-- print('UpdateRows', scrollFrame, self)
	-- local scrollFrame = summary.panel.scrollFrame
	local offset = FauxScrollFrame_GetOffset(scrollFrame)

	for row = 1, #scrollFrame.table do
		for column = 1, #scrollFrame.table[row] do
			local button = scrollFrame.table[row][column]
			local index = column + offset

			local character = true -- characters[index]
			if character then
				button:Show()
			else
				button:Hide()
			end
		end
	end

	local numItems, numToDisplay = 10, #scrollFrame.table[1]
	local buttonSize = scrollFrame.table[1][1]:GetWidth() -- first row, first column
	local needsScrollBar = FauxScrollFrame_Update(scrollFrame, numItems, numToDisplay, buttonSize)
end

function summary:Update()
	local views = addon:GetModule('views')
	local view  = views.GetActiveView()

	if self.show then
		view.panel:Hide()
		self.panel:Show()

		if true or view.Summary then
			local scrollFrame = self.panel.scrollFrame
			local offset = FauxScrollFrame_GetOffset(scrollFrame)
			self.UpdateTable(scrollFrame)
			-- TODO: Summary(characterKey) should return data for one row in our table
			-- view.Summary(characterKey, offset)
		end
	else
		self.panel:Hide()
		view.panel:Show()
	end
end
