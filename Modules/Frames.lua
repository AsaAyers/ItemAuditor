local addonName, addonTable = ...; 
local addon = _G[addonName]

local AceGUI = LibStub("AceGUI-3.0")

local tabs = {}

function addon:RegisterTab(text, value, callback)
	tabs[value] = {text=text, callback=callback}
end

local displayFrame = false
local currentContent = false
local function switchTab(container, event, group)
	if tabs[group] == nil then
		error(format("Invaid tab name: %s", tostring(group)))
	end
	local cb = tabs[group].callback

	container:ReleaseChildren()
	
	if currentContent then
		currentContent:Hide()
		if displayFrame then
			displayFrame:SetStatusText('')
		end
	end
	
	currentContent = cb(container)
end


function addon:CreateFrame(selectedTab)
	
	if not displayFrame then
		-- Create the frame container
		displayFrame = AceGUI:Create("Frame")
		ItemAuditor:RegisterFrame(displayFrame)
		local window = displayFrame.frame;
		-- I have no idea why AceGUI insists on using FULLSCREEN_DIALOG by default.
		window:SetFrameStrata("MEDIUM")
		displayFrame:SetTitle("ItemAuditor")
		displayFrame:SetStatusText("")

		displayFrame:SetLayout("Fill")
	
		window:SetHeight(500);
	
		local tabSet = {}
		for key, data in pairs(tabs) do 
			tinsert(tabSet, {text=data['text'], value=key})
			-- Default to the first tab.
			if not selectedTab then
				selectedTab = key
			end
		end
		-- Each tab can adjust the width as needed.
		window:SetWidth(300);

		displayFrame.tab =  AceGUI:Create("TabGroup")
		displayFrame.tab:SetLayout("Flow")
		displayFrame.tab:SetTabs(tabSet)
		displayFrame.tab:SetCallback("OnGroupSelected", switchTab)
		
		
		displayFrame:AddChild(displayFrame.tab)
	end
	
	if not selectedTab then
		for key in pairs(tabs) do 
			selectedTab = key
			break
		end
	end
	
	displayFrame.tab:SelectTab(selectedTab)
	displayFrame:Show()
end

function addon:UpdateStatusText(message)
	if displayFrame then
		displayFrame:SetStatusText(message)
	end
end