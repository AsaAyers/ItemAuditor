local addonName, addonTable = ...; 
local ItemAuditor = _G[addonName]

local AceGUI = LibStub("AceGUI-3.0")
local ScrollingTable = LibStub("ScrollingTable")

local priceTypeEach = 1
local priceTypeTotal = 2

local promptFrame = false

-- Copied from QuickAuctions
local function validateMoney(value)
	local gold = tonumber(string.match(value, "([0-9]+)|c([0-9a-fA-F]+)g|r") or string.match(value, "([0-9]+)g"))
	local silver = tonumber(string.match(value, "([0-9]+)|c([0-9a-fA-F]+)s|r") or string.match(value, "([0-9]+)s"))
	local copper = tonumber(string.match(value, "([0-9]+)|c([0-9a-fA-F]+)c|r") or string.match(value, "([0-9]+)c"))
	
	if( not gold and not silver and not copper ) then
		return false;
		-- return L["Invalid monney format entered, should be \"#g#s#c\", \"25g4s50c\" is 25 gold, 4 silver, 50 copper."]
	end
	
	return true
end

-- Copied from QuickAuctions
local function parseMoney(value)
	local gold = tonumber(string.match(value, "([0-9]+)|c([0-9a-fA-F]+)g|r") or string.match(value, "([0-9]+)g"))
	local silver = tonumber(string.match(value, "([0-9]+)|c([0-9a-fA-F]+)s|r") or string.match(value, "([0-9]+)s"))
	local copper = tonumber(string.match(value, "([0-9]+)|c([0-9a-fA-F]+)c|r") or string.match(value, "([0-9]+)c"))
		
	-- Convert it all into copper
	return (copper or 0) + ((gold or 0) * COPPER_PER_GOLD) + ((silver or 0) * COPPER_PER_SILVER)
	
end

local function SaveNewValue(link, type, text)
	if not validateMoney(text) then
		error("Invalid value")
	end
	local investedTotal, investedPerItem, numOwned = ItemAuditor:GetItemCost(link)
	local newValue=parseMoney(text)
	
	if type == priceTypeEach then
		newValue = newValue * numOwned
	end
	
	ItemAuditor:SaveValue(link, newValue-investedTotal, 0)
	-- ItemAuditor:SaveValue(link, newValue, 0)
	
	promptFrame:Hide()
end


local function PromptForNewPrice(link, type)
	local investedTotal, investedPerItem, count = ItemAuditor:GetItemCost(link)
	local itemName, displayLink = GetItemInfo(link)
	local priceDesc = " Invested Each:"
	local price = investedPerItem
	
	if type == priceTypeTotal then
		priceDesc = " Invested Total:"
		price = investedTotal
	end

	if not promptFrame then
		promptFrame = AceGUI:Create("Frame")
		ItemAuditor:RegisterFrame(promptFrame)

		local window = promptFrame.frame;
		local width = 345
		local height = 115
		window:SetWidth(width )
		window:SetHeight(height )
		window:SetMinResize(width, height)
		window:SetMaxResize(width, height)
		
		promptFrame:SetTitle("ItemAuditor")
		promptFrame:SetStatusText("Status Here")
		promptFrame:SetCallback("OnClose", function(widget) AceGUI:Release(widget); promptFrame = false end)
		promptFrame:SetLayout("Flow")

		promptFrame.editbox = AceGUI:Create("EditBox")
		promptFrame.editbox:SetWidth(300)
		promptFrame:AddChild(promptFrame.editbox)
	end
	promptFrame.editbox:SetCallback("OnEnterPressed", function(widget, event, text) SaveNewValue(link, type, text) end)
	promptFrame:SetStatusText("Current Price: "..ItemAuditor:FormatMoney(price))
	promptFrame.editbox:SetLabel(displayLink..priceDesc)
	promptFrame.editbox:SetText(ItemAuditor:FormatMoney(price, "", true))
	
	promptFrame:Show()
	editBox = promptFrame.editbox
end

local function displayMoney(rowFrame, cellFrame, data, cols, row, realrow, column, fShow, table, ...)
	if fShow == true then
		local money = data[realrow][column]
		if money == nil then
			cellFrame.text:SetText("None")
		else
			cellFrame.text:SetText(ItemAuditor:FormatMoney(data[realrow][column]))
		end
	end
end

local investedCols = {
	{ name= "Item", width = 200, 
		['DoCellUpdate'] = function(rowFrame, cellFrame, data, cols, row, realrow, column, fShow, table, ...)
			if fShow == true then
				local _, link= strsplit("|", data[realrow][column], 2)
				cellFrame.text:SetText(link)
			end
		end,
	},
	{ name= "Invested Total", width = 100, align = "RIGHT", 
		['DoCellUpdate'] = displayMoney,
	},
	{ name= "Invested Each", width = 100, align = "RIGHT", 
		['DoCellUpdate'] = displayMoney,
	},
	{ name= "# Owned", width = 50, align = "RIGHT", defaultsort = "asc", },
}

local investedTable = false
local function ShowInvested(container)
	if investedTable == false then
		local window  = container.frame
		investedTable = ScrollingTable:CreateST(investedCols, 23, nil, nil, window)
		investedTable.frame:SetPoint("BOTTOMLEFT",window, 10,10)
		investedTable.frame:SetPoint("TOP", window, 0, -60)
		investedTable.frame:SetPoint("RIGHT", window, -10,0)
		investedTable:RegisterEvents({
			["OnEnter"] = function (rowFrame, cellFrame, data, cols, row, realrow, column, scrollingTable, ...)
				if realrow then
					local _, link= strsplit("|", data[realrow][1], 2)
					
					GameTooltip:SetOwner(rowFrame, "ANCHOR_CURSOR")
					GameTooltip:SetHyperlink(link)
					GameTooltip:Show()
				end
			end,
			["OnLeave"] = function (rowFrame, cellFrame, data, cols, row, realrow, column, scrollingTable, ...)
				  GameTooltip:Hide()
			end,
			["OnClick"] = function (rowFrame, cellFrame, data, cols, row, realrow, column, scrollingTable, ...)
				  if realrow ~= nil and (column == 2 or column == 3) then
					-- column.text = row:CreateFontString(col:GetName().."text", "OVERLAY", "GameFontHighlightSmall");
					local _, link= strsplit("|", data[realrow][1], 2)
					
					local type=priceTypeEach
					if column == 2 then
						type = priceTypeTotal
					end
					
					PromptForNewPrice(link, type)
				  end
			end,
		});
	end
	investedTable:Show()
	
	local width = 80
	for i, data in pairs(investedCols) do 
		width = width + data.width
	end
	if container.parent then
		container.parent:SetWidth(width);
	end

	
	UpdateInvestedData()
end


local function switchTab(container, event, group)
	container:ReleaseChildren()
	
	if investedTab then investedTab:Hide() end

	if group == "tab_invested" then
		ShowInvested(container)
	end
end



displayFrame = false
local function CreateFrames()
	if not displayFrame then
		-- Create the frame container
		displayFrame = AceGUI:Create("Frame")
		ItemAuditor:RegisterFrame(displayFrame)
		local window = displayFrame.frame;
		displayFrame:SetTitle("ItemAuditor")
		displayFrame:SetStatusText("")

		displayFrame:SetLayout("Fill")
	
		window:SetHeight(500);
	
		local width = 80
		for i, data in pairs(investedCols) do 
			width = width + data.width
		end
		window:SetWidth(width);

		local tab =  AceGUI:Create("TabGroup")
		tab:SetLayout("Flow")
		tab:SetTabs({{text="Invested", value="tab_invested"}})
		tab:SetCallback("OnGroupSelected", switchTab)
		tab:SelectTab("tab_invested")

		displayFrame:AddChild(tab)
	end
	displayFrame:Show()
end





function UpdateInvestedData()
	if investedTable then
		tableData = {} --reset
		local totalInvested = 0
		
		local i = 1
		local data
		local items = ItemAuditor.db.factionrealm.items
		local includedItems = {}
		for safeLink in pairs(items) do
			local investedTotal, investedPerItem, count = ItemAuditor:GetItemCost(safeLink)
			local itemName, link = GetItemInfo(safeLink)
			if investedTotal > 0 and link ~= nil then
				tableData[i] = {
					itemName.."|"..link,
					investedTotal,
					investedPerItem,
					count,
				}
				
				totalInvested = totalInvested + investedTotal
				
				i = i + 1
				includedItems[safeLink] = true
			end
		end
		
		local inventory = ItemAuditor:GetCurrentInventory()
		
		for link, count in pairs(inventory.items) do
			if includedItems[link] == nil then
				local count = Altoholic:GetItemCount(ItemAuditor:GetIDFromLink(link))
				local itemName, link = GetItemInfo(link)
				tableData[i] = {
					itemName.."|"..link,
					0,
					0,
					count,
				}
				
				-- totalInvested = totalInvested + investedTotal
				
				i = i + 1
			end
		end
		
		if investedTable.frame:IsShown() then
			displayFrame:SetStatusText("Total Invested: "..ItemAuditor:FormatMoney(totalInvested))
		end
		
		investedTable:SetData(tableData, true)
	end
end

function ItemAuditor:CreateFrames()
	CreateFrames()
end

