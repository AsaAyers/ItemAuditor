local addonName, addonTable = ...; 
local ItemAuditor = _G[addonName]

local AceGUI = LibStub("AceGUI-3.0")
local ScrollingTable = LibStub("ScrollingTable")

local validateMoney = ItemAuditor.validateMoney
local parseMoney = ItemAuditor.parseMoney

local realData = {}

local function displayMoney(rowFrame, cellFrame, data, cols, row, realrow, column, fShow, table, ...)
	if fShow == true then
		local money = data[realrow][column]
		if money then
			cellFrame.text:SetText(ItemAuditor:FormatMoney(tonumber(money)))
		else
			cellFrame.text:SetText("")
		end
		
	end
end

local craftingCols = {
	{ name= "Item", width = 200, defaultsort = "desc",
		['DoCellUpdate'] = function(rowFrame, cellFrame, data, cols, row, realrow, column, fShow, table, ...)
			if fShow == true then
				local data = realData[realrow]
				cellFrame.text:SetText(data.link)
			end
		end,
	},
	{ name= "Cost Each", width = 100, align = "RIGHT", 
		['DoCellUpdate'] = displayMoney,
	},
	{ name= "Est Sale Each", width = 100, align = "RIGHT", 
		['DoCellUpdate'] = displayMoney,
	},
	{ name= "Decided By", width = 100, align = "RIGHT", 
		
	},
	{ name= "craft", width = 50, align = "RIGHT", 
		
	},
	{ name= "Total Profit", width = 100, align = "RIGHT", 
		['DoCellUpdate'] = displayMoney,
	},
}

local function ExportToSkillet()
	local index = 1
	local data = ItemAuditor:GetCraftingRow(index)
	while data do
		local skillString = select(3, string.find(data.recipeLink, "^|%x+|H(.+)|h%[.+%]"))
		local _, skillId = strsplit(":", skillString)
		
		ItemAuditor:AddToQueue(skillId,tradeSkillIndex, data.queue)
		index = index + 1
		data = ItemAuditor:GetCraftingRow(index)
		
	end
end

local craftingContent = false
local craftingTable = false
local btnProcess = false
local function ShowCrafting(container)
	if craftingContent == false then
		local window  = container.frame
		craftingContent = CreateFrame("Frame",nil,window)
		craftingContent:SetBackdropColor(0, 0, 1, 0.5) 
		craftingContent:SetBackdropBorderColor(1, 0, 0, 1)
		
		craftingContent:SetPoint("TOPLEFT", window, 10, -50)
		craftingContent:SetPoint("BOTTOMRIGHT",window, -10, 10)
		
		craftingTable = ScrollingTable:CreateST(craftingCols, 22, nil, nil, craftingContent )
		
		IAcc = craftingContent 
		IAccWindow = window
		craftingTable.frame:SetPoint("TOPLEFT",craftingContent, 0,0)
		craftingTable.frame:SetPoint("BOTTOMRIGHT", craftingContent, 0, 30)
		
		craftingTable:RegisterEvents({
			["OnEnter"] = function (rowFrame, cellFrame, data, cols, row, realrow, column, scrollingTable, ...)
				if realrow then
					local data = realData[realrow]
					
					GameTooltip:SetOwner(rowFrame, "ANCHOR_CURSOR")
					GameTooltip:SetHyperlink(data.link)
					GameTooltip:Show()
				end
			end,
			["OnLeave"] = function (rowFrame, cellFrame, data, cols, row, realrow, column, scrollingTable, ...)
				  GameTooltip:Hide()
			end,
		});
		
		
		btnProcess = CreateFrame("Button", nil, craftingContent, "UIPanelButtonTemplate")
		btnProcess:SetText("Process")
		btnProcess:SetSize(100, 25) 
		btnProcess:SetPoint("BOTTOMRIGHT", craftingContent, 0, 0)
		btnProcess:RegisterForClicks("LeftButtonUp");
		
		local function UpdateProcessTooltip(btn)
			local data = ItemAuditor:GetCraftingRow(1)
			if data then
				GameTooltip:SetOwner(this, "ANCHOR_CURSOR")
				GameTooltip:SetText(format('Create %sx%s', data.link, data.queue))
				GameTooltip:Show()
			end
		end
		btnProcess:SetScript("OnClick", function (self, button, down)
			local data = ItemAuditor:GetCraftingRow(1)
			if data then
				ItemAuditor:Print('Crafting %sx%s', data.link, data.queue)
				DoTradeSkill(data.tradeSkillIndex, data.queue)
				data.queue = 0
				ItemAuditor:RefreshCraftingTable()
				UpdateProcessTooltip()
			end
		end)

		btnProcess:SetScript("OnEnter", UpdateProcessTooltip)

		btnProcess:SetScript("OnLeave", function()
			GameTooltip:Hide()
		end)
	
		btnSkillet = CreateFrame("Button", nil, craftingContent, "UIPanelButtonTemplate")
		btnSkillet:SetText("Queue in Skillet")
		btnSkillet:SetSize(125, 25) 
		btnSkillet:SetPoint("BOTTOMRIGHT", btnProcess, 'BOTTOMLEFT', 0, 0)
		btnSkillet:RegisterForClicks("LeftButtonUp");
		btnSkillet:SetScript("OnClick", function (self, button, down)
			ExportToSkillet()
		end)
		
	end
	craftingContent:Show()
	
	if container.parent then
		local width = 80
		for i, data in pairs(craftingCols) do 
			width = width + data.width
		end
		container.parent:SetWidth(width);
	end
	
	ItemAuditor:RegisterEvent("TRADE_SKILL_SHOW", function()
		if craftingContent and craftingContent:IsVisible() then
			ItemAuditor:UpdateCraftingTable()
		end
	end)
	ItemAuditor:UpdateCraftingTable()
	
	return craftingContent
end



ItemAuditor:RegisterTab('Crafting', 'tab_crafting', ShowCrafting)
function ItemAuditor:DisplayCrafting()
	self:CreateFrame('tab_crafting')
end

local craftingDeciders = {}

function ItemAuditor:RegisterCraftingDecider(name, decider)
	craftingDeciders[name] = decider
end

local lastWinnder = ""
local function Decide(data)
	local newDecision = 0
	for name, decider in pairs(craftingDeciders) do
		if name ~= lastWinner then
			newDecision = decider(data)
			if newDecision > data.queue then
				data.queue = newDecision
				lastWinner = name
				return Decide(data)
			elseif newDecision < 0 then
				lastWinner = ""
				return 'VETO: '..name, 0
			end
		end
	end
	
	winner = lastWinner
	lastWinner = ""
	
	return winner, data.queue
end

local function isProfitable(data)
	if data.profit > 0 and data.profit > ItemAuditor:GetCraftingThreshold() then
		return 1
	end
	return -1
end
ItemAuditor:RegisterCraftingDecider('Is Profitable', isProfitable)

local function tableFilter(self, row, ...)
	-- column 5 is how many should be crafted
	return row[5] > 0
end

local tableData = {}
function ItemAuditor:UpdateCraftingTable()
	if LSW == nil then
		self:Print("This feature requires LilSparky's Workshop.")
		return
	end
	if Skillet == nil then
		self:Print("This feature requires Skillet.")
		return
	end
	if GetAuctionBuyout ~= nil then
	elseif AucAdvanced and AucAdvanced.Version then
	else
		self:Print("This feature requires Auctionator, Auctioneer, AuctionLite, or AuctionMaster.")
		return
	end
	wipe(realData)
	wipe(tableData)
	
	local profitableItems = {}
	local profitableIndex = 1
	local numChecked = 0
	local row = 1
	
	for i = 1, GetNumTradeSkills() do
		local itemLink = GetTradeSkillItemLink(i)
		local itemId = Skillet:GetItemIDFromLink(itemLink)

		--Figure out if its an enchant or not
		_, _, _, _, altVerb = GetTradeSkillInfo(i)
		if LSW.scrollData[itemId] ~= nil and altVerb == 'Enchant' then
			-- Ask LSW for the correct scroll
			itemId = LSW.scrollData[itemId]["scrollID"]
		end

		local recipeLink = GetTradeSkillRecipeLink(i)
		local stackSize  = 1
		if recipeLink ~= nil and itemId ~= nil then
			local skillName, skillType, numAvailable, isExpanded, altVerb = GetTradeSkillInfo(i)
			local itemName, itemLink= GetItemInfo(itemId)
		
			local count = Altoholic:GetItemCount(itemId)
			local reagents = {}
			local totalCost = 0
			for reagentId = 1, GetTradeSkillNumReagents(i) do
				local reagentName, _, reagentCount = GetTradeSkillReagentInfo(i, reagentId);
				local reagentLink = GetTradeSkillReagentItemLink(i, reagentId)
				
				reagents[reagentId] = {
					name = reagentName,
					count = reagentCount,
					price = self:GetReagentCost(reagentLink, reagentCount),
				}
				totalCost  = totalCost + self:GetReagentCost(reagentLink, reagentCount)
			end
			
			local data = {
				recipeLink = recipeLink,
				link = itemLink,
				name = itemName,
				count = count,
				price = (self:GetAuctionPrice(itemLink) or 0),
				cost = totalCost,
				profit = (self:GetAuctionPrice(itemLink) or 0) - totalCost,
				reagents = reagents,
				count = count,
				tradeSkillIndex = i,
				queue = 0,
				winner = "",
			}
			
			data.winner, data.queue = Decide(data)
			data.queue = data.queue - count
			
			-- If a tradeskill makes 5 at a time and something asks for 9, we should only 
			-- craft twice to get 10.
			data.queue = ceil(data.queue / GetTradeSkillNumMade(i))
			
			realData[row] = data
			row = row + 1
		end
	end
	table.sort(realData, function(a, b) return a.profit*a.queue > b.profit*b.queue end)
	craftingTable:SetFilter(tableFilter)
	self:RefreshCraftingTable()
end

function ItemAuditor:RefreshCraftingTable()
	for key, data in pairs(realData) do
		tableData[key] = {
			data.name,
			data.cost,
			data.price,
			data.winner,
			data.queue,
			data.profit*data.queue,
		}
	end
	craftingTable:SetData(tableData, true)
	
	if self:GetCraftingRow(1) then
		btnProcess:Enable()
	else
		btnProcess:Disable()
	end
end

function ItemAuditor:GetCraftingRow(row)
	if craftingTable then
		for _, index in pairs(craftingTable.sorttable) do
			local tableRow = tableData[index]
			if tableFilter(nil, tableRow) then
				row = row - 1
				if row == 0 then
					return realData[index]
				end
			end
		end
	elseif realData then
		return realData[row]
	end
	return nil
end
