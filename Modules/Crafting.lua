local ItemAuditor = select(2, ...)
local Crafting = ItemAuditor:NewModule("Crafting", 'AceEvent-3.0')

local Utils = ItemAuditor:GetModule("Utils")

local AceGUI = LibStub("AceGUI-3.0")
local ScrollingTable = LibStub("ScrollingTable")

local validateMoney = ItemAuditor.validateMoney
local parseMoney = ItemAuditor.parseMoney

local realData = {}
local nameMap = nil

function Crafting:OnInitialize()
	self:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
	self:RegisterEvent("UNIT_SPELLCAST_FAILED")
end

local function getQueueLocation(name)
	-- this is supposed to cache, but it isn't working. its easier to just
	-- disable the cache for now.
	nameMap = nil
	if not nameMap then
		nameMap = {}
		for key, data in pairs(realData) do
			-- TODO: Fix the cache and remove this.
			if data.skillName == name then
				return key
			end
			nameMap[data.skillName] = key
		end
	end
	return nameMap[name]
end

--@debug@
Crafting.getQueueLocation = getQueueLocation
function Crafting.getNameMap()
	return nameMap
end

function Crafting.getRealData()
	return realData
end
--@end-debug@

function Crafting:UNIT_SPELLCAST_SUCCEEDED(event, unit, spell)
	if unit == "player" and getQueueLocation(spell) then
		local data = realData[getQueueLocation(spell)]
		data.queue = data.queue - 1
		ItemAuditor:RefreshCraftingTable()
	end
end

--[[
	If the craft failed, probably because you're missing an item, remove it and move on.
]]
function Crafting:UNIT_SPELLCAST_FAILED(event, unit, spell)
	if unit == "player" and getQueueLocation(spell) then
		local data = realData[getQueueLocation(spell)]
		data.queue = 0
		ItemAuditor:RefreshCraftingTable()
	end
end

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

function ItemAuditor:GetCraftingThreshold()
	return self.db.char.profitable_threshold
end

ItemAuditor.Options.args.crafting_options = {
	name = "Crafting",
	type = 'group',
	args = {
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
	{ name= "Decided By", width = 125, align = "RIGHT",

	},
	{ name= "craft", width = 50, align = "RIGHT",

	},
	{ name= "Have Mats", width = 60, align = "RIGHT",

	},
	{ name= "Profit Each", width = 100, align = "RIGHT",
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

-- ItemAuditor:GetModule('Crafting').filter_queued = false
Crafting.filter_have_mats = false
Crafting.filter_show_all = false
local function tableFilter(self, row, ...)
	if Crafting.nameFilter then
		return string.find(row[1], Crafting.nameFilter) ~= nil
	end

	if Crafting.filter_show_all then
		return true
	end

	-- column 5 is how many should be crafted
	if Crafting.filter_have_mats and row[6] == 0 then
		return false
	end
	if (row[4] and strfind(row[4], 'VETO: .*')) or row[5] == 0 then
		return false
	end
	return true
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

		local craftingView = CreateFrame("Button", nil, craftingContent, "UIPanelButtonTemplate")
		craftingView:SetText("View")
		craftingView:SetSize(50, 25)
		craftingView:SetPoint("BOTTOMLEFT", craftingContent, 0, 0)

		local menu = {
			{ text = "View", isTitle = true},
			{ text = "To be crafted", func = function()
				Crafting.filter_have_mats = false
				Crafting.filter_show_all = false
				ItemAuditor:RefreshCraftingTable()
			end },
			{ text = "Have Mats", func = function()
				Crafting.filter_have_mats = true
				Crafting.filter_show_all = false
				ItemAuditor:RefreshCraftingTable()
			end },
			{ text = "All", func = function()
				Crafting.filter_have_mats = false
				Crafting.filter_show_all = true
				ItemAuditor:RefreshCraftingTable()
			end },
		}
		local menuFrame = CreateFrame("Frame", "ExampleMenuFrame", UIParent, "UIDropDownMenuTemplate")
		craftingView:SetScript("OnClick", function (self, button, down)
			EasyMenu(menu, menuFrame, "cursor", 0 , 0, "MENU");
		end)


		btnProcess = CreateFrame("Button", nil, craftingContent, "UIPanelButtonTemplate")
		btnProcess:SetText("Process")
		btnProcess:SetSize(100, 25)
		btnProcess:SetPoint("BOTTOMRIGHT", craftingContent, 0, 0)
		btnProcess:RegisterForClicks("LeftButtonUp");

		local function UpdateProcessTooltip()
			local data = ItemAuditor:GetCraftingRow(1)
			if data then
				GameTooltip:SetOwner(btnProcess, "ANCHOR_CURSOR")
				GameTooltip:SetText(format('Create %sx%s', data.link, data.queue))
				GameTooltip:Show()
			end
		end

		--[[
			When enchanting UseContainerItem seems to be protected, so the enchants
			have to be done one at a time.
		]]
		local function useVellum(vellumID)
			for bagID = 0, NUM_BAG_SLOTS do
				for slotID = 0, GetContainerNumSlots(bagID) do
					local link = GetContainerItemLink(bagID, slotID)
					local id = Utils.GetItemID(link);
					if id == vellumID then
						UseContainerItem(bagID, slotID)
						return
					end
				end
			end
		end

		btnProcess:SetScript("OnClick", function (self, button, down)
			local data = ItemAuditor:GetCraftingRow(1)
			if data then
				-- This will make sure the correct tradeskill window is open.
				local tradeskillName = GetTradeSkillLine()
				if data.tradeskillName ~= tradeskillName then
					CastSpellByName(data.tradeskillName)
				end

				local queue = data.queue
				local vellumID = nil
				local altVerb = select(5, GetTradeSkillInfo(data.tradeSkillIndex))
				if altVerb == 'Enchant' then
					vellumID = 38682
					queue = 1
				end
				ItemAuditor:Print('Crafting %sx%s', data.link, queue)
				DoTradeSkill(data.tradeSkillIndex, queue)
				if vellumID then
					useVellum(vellumID)
				end

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
	local reason = ""
	for name, decider in pairs(craftingDeciders) do
		if not ItemAuditor.db.profile.disabled_deciders[name] and name ~= lastWinner then
			newDecision, reason = decider(data)

			if newDecision > data.queue then
				data.queue = newDecision
				lastWinner = (reason or name)
				return Decide(data)
			elseif newDecision < 0 then
				lastWinner = ""
				return 'VETO: '..(reason or name), -1
			end
		end
	end

	winner = lastWinner
	lastWinner = ""

	data.queue = ceil(data.queue / GetTradeSkillNumMade(data.tradeSkillIndex))

	return winner, data.queue
end

local function isProfitable(data)
	if data.profit > 0 and data.profit > ItemAuditor:GetCraftingThreshold() then
		return 1
	end
	return -1, 'Not Profitable'
end

local isProfitableOptions = {
	profitable_threshold = {
		type = "input",
		name = "Crafting Threshold",
		desc = "Don't create items that will make less than this amount of profit",
		get = function() return
			Utils.FormatMoney(ItemAuditor:GetCraftingThreshold(), '', true)
		end,
		validate = function(info, value)
			if not Utils.validateMoney(value) then
				return "Invalid money format"
			end
			return true
		end,
		set = function(info, value)
			ItemAuditor.db.char.profitable_threshold = Utils.parseMoney(value)
		end,
		usage = "###g ##s ##c",
		order = 0,
	},
}

Crafting.RegisterCraftingDecider('Is Profitable', isProfitable, isProfitableOptions)



local tableData = {}
function ItemAuditor:UpdateCraftingTable()
	if GetAuctionBuyout ~= nil then
	elseif AucAdvanced and AucAdvanced.Version then
	else
		self:Print("This feature requires Auctionator, Auctioneer, AuctionLite, or AuctionMaster.")
		return
	end
	local tradeskillName = GetTradeSkillLine()

	wipe(tableData)

	local profitableItems = {}
	local profitableIndex = 1
	local numChecked = 0
	local numTradeSkills = GetNumTradeSkills()
	if tradeskillName == 'UNKNOWN' then
		numTradeSkills  = 0
	end

	local row = 1
	getQueueLocation()
	
	for i = 1, numTradeSkills do
		local itemLink = GetTradeSkillItemLink(i)
		local itemId = Utils.GetItemID(itemLink)
		local vellumID = nil

		--Figure out if its an enchant or not
		local altVerb = select(5, GetTradeSkillInfo(i))
		if LSW and LSW.scrollData[itemId] ~= nil and altVerb == 'Enchant' then
			-- Ask LSW for the correct scroll
			itemId = LSW.scrollData[itemId]
			vellumID = 38682
		end

		local recipeLink = GetTradeSkillRecipeLink(i)
		local stackSize  = 1
		if recipeLink ~= nil and itemId ~= nil then
			local skillName, skillType, numAvailable, isExpanded, altVerb = GetTradeSkillInfo(i)
			local itemName, itemLink= GetItemInfo(itemId)

			-- This check has to be here for things like Inscription Research that don't produce an item.
			if itemLink then
				local count = ItemAuditor:GetItemCount(itemId)
				local reagents = {}
				local totalCost = 0
				for reagentId = 1, GetTradeSkillNumReagents(i) do
					local reagentName, _, reagentCount = GetTradeSkillReagentInfo(i, reagentId);
					local reagentLink = GetTradeSkillReagentItemLink(i, reagentId)
					local reagentTotalCost = self:GetReagentCost(reagentLink, reagentCount)
					if not reagentLink then
						-- we can't continue without a link, but sometimes blizzard just fails to return one.z
						self:Print("GetItemInfo failed to return an item link for %s. Retrying in 1 second.", tostring(reagentName))
						return self:ScheduleTimer("UpdateCraftingTable", 1)
					end

					assert(reagentLink, format("GetItemInfo failed to return an item link for %s (skill: %s) (ReagentID: %s)", tostring(reagentName), tostring(i), tostring(reagentId)))

					reagents[reagentId] = {
						link = reagentLink,
						itemID = Utils.GetItemID(reagentLink),
						name = reagentName,
						count = reagentCount,
						price = reagentTotalCost / reagentCount,
						need = 0, -- This will get populated after the decisions have been made. it can't
						-- be done before that because highest profit items get priority on materials.
					}
					totalCost  = totalCost + reagentTotalCost
				end
				if vellumID then
					reagentId = GetTradeSkillNumReagents(i) + 1
					local reagentName, reagentLink = GetItemInfo(vellumID)
					assert(reagentLink, format("GetItemInfo failed to return an item link %s:%s", tostring(vellumID), tostring(reagentName)))
					reagents[reagentId] = {
						link = reagentLink,
						itemID = vellumID,
						name = reagentName,
						count = 1,
						price = self:GetReagentCost(reagentLink, 1),
						need = 0, -- This will get populated after the decisions have been made. it can't
						-- be done before that because highest profit items get priority on materials.
					}
					totalCost  = totalCost + self:GetReagentCost(reagentLink, 1)
				end

				local price = (self:GetAuctionPrice(itemLink) or 0)
				totalCost  = totalCost + (price * ItemAuditor:GetAHCut())
				local data = {
					recipeLink = recipeLink,
					recipeID = Utils.GetItemID(recipeLink),
					link = itemLink,
					name = itemName,
					skillName = skillName,
					count = count,
					price = price,
					cost = totalCost,
					profit = price - totalCost,
					reagents = reagents,
					count = count,
					tradeSkillIndex = i,
					queue = 0,
					winner = "",
					tradeskillName = tradeskillName,
				}

				data.winner, data.queue = Decide(data)
				--[[
					If it wasn't vetoed we need to reduce the number by how many are owned
					but this should not go below 0
				]]
				if data.queue > 0 then
					data.queue = max(0, data.queue - count)
				end

				-- If a tradeskill makes 5 at a time and something asks for 9, we should only
				-- craft twice to get 10.
				data.queue = ceil(data.queue / GetTradeSkillNumMade(i))

				realData[row] = data
				nameMap[skillName] = row
				row = row + 1
			end
		end
	end
	table.sort(realData, function(a, b) return a.profit*max(1, a.queue) > b.profit*max(1, b.queue) end)

	local numOwned = {}

	for key, data in pairs(realData) do
		data.haveMaterials = data.queue
		for id, reagent in pairs(data.reagents) do
			local needEach = reagent.count
			reagent.count = reagent.count * data.queue

			if not numOwned[reagent.link] then
				numOwned[reagent.link] = ItemAuditor:GetItemCount(ItemAuditor:GetIDFromLink(reagent.link))
			end
			data.haveMaterials = min(data.haveMaterials, floor(numOwned[reagent.link] / needEach))
			numOwned[reagent.link] = numOwned[reagent.link] - reagent.count

			if numOwned[reagent.link] < 0 then
				reagent.need = min(reagent.count, abs(numOwned[reagent.link]))
			end
		end
		data.haveMaterials = max(0, data.haveMaterials)
	end

	if craftingTable then
		craftingTable:SetFilter(tableFilter)
		self:RefreshCraftingTable()
	end
end

function ItemAuditor:RefreshCraftingTable()
	-- If the crafting table hasn't been created/displayed, there is no
	-- reason to try to update it.
	if not craftingTable then
		return
	end
	tableData = {}
	nameMap = {}
	for key, data in pairs(realData) do
		nameMap[data.name] = key

		tableData[key] = {
			data.name,
			data.cost,
			data.price,
			data.winner,
			abs(data.queue),
			data.haveMaterials,
			data.profit,
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
