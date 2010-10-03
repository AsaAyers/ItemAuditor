local ItemAuditor = select(2, ...)
local DisplayInvested = ItemAuditor:NewModule("DisplayInvested")


local AceGUI = LibStub("AceGUI-3.0")
local ScrollingTable = LibStub("ScrollingTable")

local priceTypeEach = 1
local priceTypeTotal = 2

local promptFrame = false

local validateMoney = ItemAuditor.validateMoney
local parseMoney = ItemAuditor.parseMoney


StaticPopupDialogs["ItemAuditor_NewPrice"] = {
	text = "New price %s %s",
	button1 = SAVE,
	button2 = CANCEL,
	hasEditBox = 1,
	showAlert = 1,
	OnAccept = function()
		skipCODTracking = true
	end,
	EditBoxOnEnterPressed = function()
		if ( getglobal(this:GetParent():GetName().."Button1"):IsEnabled() == 1 ) then
			getglobal(this:GetParent():GetName().."Button1"):Click()
		end
	end,
	EditBoxOnTextChanged = function ()
		local parentName = this:GetParent():GetName()
		local editBox = getglobal( parentName.."EditBox");
		local value = editBox:GetText()
		if validateMoney(value) then
			getglobal(parentName.."Button1"):Enable();
		else
			getglobal(parentName.."Button1"):Disable();
		end
	end,
	EditBoxOnEscapePressed = function()
		this:GetParent():Hide();
		ClearCursor();
	end,
	timeout = 0,
	hideOnEscape = 1,
	exclusive = true,
}

local function PromptForNewPrice(link, type)
	local investedTotal, investedPerItem, count = ItemAuditor:GetItemCost(link)

	local typeText = "Invested Each"
	local price = investedPerItem
	if type == priceTypeTotal then
		typeText = "Invested Total"
		price = investedTotal

	end
	
	StaticPopupDialogs["ItemAuditor_NewPrice"].text = format("Update %s: %s|nThe current value is %s", typeText, link, ItemAuditor:FormatMoney(price))
	
	StaticPopupDialogs["ItemAuditor_NewPrice"].OnShow = function (self, data)
		self.editBox:SetText(ItemAuditor:FormatMoney(price, '', true))
	end
	
	StaticPopupDialogs["ItemAuditor_NewPrice"].OnAccept = function()
		local name = this:GetParent():GetName().."EditBox"
		local button = getglobal(name)
		local newValue = button:GetText()
		newValue = parseMoney(newValue)
		
		local investedTotal, investedPerItem, numOwned = ItemAuditor:GetItemCost(link)
		
		if type == priceTypeEach then
			newValue = newValue * numOwned
		end
		
		ItemAuditor:SaveValue(link, newValue-investedTotal, 0)
	end
	StaticPopup_Show ("ItemAuditor_NewPrice");
end

local function displayMoney(rowFrame, cellFrame, data, cols, row, realrow, column, fShow, table, ...)
	if fShow == true then
		local money = data[realrow][column]
		cellFrame.text:SetText(ItemAuditor:FormatMoney(data[realrow][column]))
	end
end

local investedCols = {
	{ name= "Item", width = 200, defaultsort = "desc",
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
	{ name= "# Owned", width = 50, align = "RIGHT", },
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
	
	return investedTable
end

ItemAuditor:RegisterTab("Invested", 'tab_invested', ShowInvested)
function ItemAuditor:DisplayInvested()
	self:CreateFrame('tab_invested')
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
				includedItems[ItemAuditor:GetIDFromLink(safeLink)] = true
			end
		end
		
		local inventory = ItemAuditor:GetCurrentInventory()
		
		for itemID, count in pairs(inventory.items) do
			if includedItems[itemID] == nil then
				local itemName, link = GetItemInfo(itemID)
				local count = ItemAuditor:GetItemCount(itemID)
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
			ItemAuditor:UpdateStatusText("Total Invested: "..ItemAuditor:FormatMoney(totalInvested))
		end
		
		investedTable:SetData(tableData, true)
	end
end


ItemAuditor.Options.args.invested = {
	type = "execute",
	name = "invested",
	desc = "Shows what you have invested in",
	func = "DisplayInvested",
	guiHidden = false,
}