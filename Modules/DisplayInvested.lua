local addonName, addonTable = ...; 
local ItemAuditor = _G[addonName]

local AceGUI = LibStub("AceGUI-3.0")
local ScrollingTable = LibStub("ScrollingTable")

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
		['DoCellUpdate'] = function(rowFrame, cellFrame, data, cols, row, realrow, column, fShow, table, ...)
			if fShow == true then
				cellFrame.text:SetText(ItemAuditor:FormatMoney(data[realrow][column]))
			end
		end,
	},
	{ name= "Invested each", width = 100, align = "RIGHT", 
		['DoCellUpdate'] = function(rowFrame, cellFrame, data, cols, row, realrow, column, fShow, table, ...)
			if fShow == true then
				cellFrame.text:SetText(ItemAuditor:FormatMoney(data[realrow][column]))
			end
		end,
	},
	{ name= "# owned", width = 50, align = "RIGHT", defaultsort = "asc", },
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
				  if column == 3 then
					GameTooltip:Hide()
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
		for link in pairs(ItemAuditor.db.factionrealm.items) do
			local investedTotal, investedPerItem, count = ItemAuditor:GetItemCost(link)
			local itemName, link = GetItemInfo(link)
			if investedTotal > 0 then
				tableData[i] = {
					itemName.."|"..link,
					investedTotal,
					investedPerItem,
					count,
				}
				
				totalInvested = totalInvested + investedTotal
				
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

