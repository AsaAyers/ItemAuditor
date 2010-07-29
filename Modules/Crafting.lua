local ItemAuditor = select(2, ...)
local Crafting = ItemAuditor:NewModule("Crafting")

local AceGUI = LibStub("AceGUI-3.0")
local ScrollingTable = LibStub("ScrollingTable")

local validateMoney = ItemAuditor.validateMoney
local parseMoney = ItemAuditor.parseMoney

local realData = {}


local queueDestinations = {}
local displayCraftingDestinations = {}
function Crafting.RegisterQueueDestination(name, destination)
	queueDestinations[name] = destination
	displayCraftingDestinations[name] = name
end

function Crafting.UnRegisterQueueDestination(name)
	queueDestinations[name] = nil
	displayCraftingDestinations[name] = nil
end

function Crafting.GetQueueDestination()
	local dest = ItemAuditor.db.profile.queue_destination
	if dest and queueDestinations[dest] then
		return queueDestinations[dest], dest
	end
	-- If there is none selected or the selected option has 
	-- dissapeared, choose the first one in the list
	for name, func in pairs(queueDestinations) do
		if dest then
			ItemAuditor:Print("%s is no longer available as a queue destination. %s is the new default", dest, name)
		end
		ItemAuditor.db.profile.queue_destination = name
		return func, name
	end
	
	error('Unable to determine queue destination.')
end

-- TODO: Convert this to a text field.
local craftingThresholds = {5000, 10000, 50000}
local craftingThresholdsDisplay = {}

for key, value in pairs(craftingThresholds) do
	craftingThresholdsDisplay[key] = ItemAuditor:FormatMoney(value, '', true)
	-- craftingThresholdsDisplay[key] = value
end

function ItemAuditor:GetCraftingThreshold()
	local key = ItemAuditor.db.char.crafting_threshold
	return craftingThresholds[key]
end

ItemAuditor.Options.args.crafting_options = {
	name = "Crafting",
	type = 'group',
	args = {
		crafting_threshold = {
			type = "select",
			name = "Crafting Threshold",
			desc = "Don't create items that will make less than this amount of profit",
			values = craftingThresholdsDisplay,
			get = function() return ItemAuditor.db.char.crafting_threshold end,
			set = function(info, value) ItemAuditor.db.char.crafting_threshold = value end,
			order = 0,
		},
		queue_destination = {
			type = "select",
			name = "Queue Destination",
			desc = "Select the addon who's queue you would like ItemAuditor to post to.",
			values = displayCraftingDestinations,
			get = function() return select(2, Crafting.GetQueueDestination()) end,
			set = function(info, value) ItemAuditor.db.profile.queue_destination = value end,
			order = 1,
		},
		deciders = {
			type="header",
			name="Crafting Deciders",
			order = 10,
		},
		
	},
}

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

function Crafting.ExportToSkillet(data)
	local skillString = select(3, string.find(data.recipeLink, "^|%x+|H(.+)|h%[.+%]"))
	local _, skillId = strsplit(":", skillString)
	
	ItemAuditor:AddToQueue(skillId,tradeSkillIndex, data.queue)
end

Crafting.RegisterQueueDestination('Skillet', Crafting.ExportToSkillet)



function Crafting.Export(destination)
	if type(destination) == 'function' then
		-- do nothing
	elseif destination == nil then
		destination = Crafting.GetQueueDestination()
	elseif type(destination) == 'string' then
		destination = queueDestinations[destination]
	else
		error('destination must be a function or a string')
	end
	
	local index = 1
	local data = ItemAuditor:GetCraftingRow(index)
	while data do
		if data.queue > 0 then
			destination(data)
		end
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
		
		
		btnSkillet:SetSize(125, 25) 
		btnSkillet:SetPoint("BOTTOMRIGHT", btnProcess, 'BOTTOMLEFT', 0, 0)
		btnSkillet:RegisterForClicks("LeftButtonUp");
		btnSkillet:SetScript("OnClick", function (self, button, down)
			Crafting.Export()
		end)
		
	end
	local destination = select(2, Crafting.GetQueueDestination())
	btnSkillet:SetText("Export to "..destination)
	
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

function Crafting.RegisterCraftingDecider(name, decider, options)
	craftingDeciders[name] = decider
	
	ItemAuditor.Options.args.crafting_options.args['chk'..name] = {
		type = "toggle",
		name = "Enable "..name,
		get = function() return not ItemAuditor.db.profile.disabled_deciders[name] end,
		set = function(info, value) ItemAuditor.db.profile.disabled_deciders[name] = not value end,
		order = 11,
	}
	
	if options then
		ItemAuditor.Options.args.crafting_options.args['decider_'..name] = {
			handler = {},
			name = name,
			type = 'group',
			args = options,
		}
	end
end

local lastWinnder = ""
local function Decide(data)
	local newDecision = 0
	for name, decider in pairs(craftingDeciders) do
		if not ItemAuditor.db.profile.disabled_deciders[name] and name ~= lastWinner then
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

Crafting.RegisterCraftingDecider('Is Profitable', isProfitable)

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
	if craftingTable then
		craftingTable:SetFilter(tableFilter)
		self:RefreshCraftingTable()
	end
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
ItemAuditor.Options.args.crafting = {
	type = "execute",
	name = "crafting",
	desc = "This opens a window to configure a crafting queue.",
	func = "DisplayCrafting",
	guiHidden = false,
}
