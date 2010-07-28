local addonName, addonTable = ...; 
local addon = _G[addonName]

--[[
	This is simply for compatibility while I change the QA API. Once
	my changes get merged into the main project, this can go away.
]]
if QAAPI ~= nil and QAAPI.GetGroupThreshold ~= nil and QAAPI.GetGroupConfig == nil then
	function QAAPI:GetGroupConfig(groupName)
		return QAAPI:GetGroupThreshold(groupName),
			QAAPI:GetGroupPostCap(groupName),
			QAAPI:GetGroupPerAuction(groupName)
	end
	
	function QAAPI:SetGroupConfig(groupName, key, value)
		if key == 'threshold' then
			return QAAPI:SetGroupThreshold(groupName, value)
		end
	end
end



function addon:IsQACompatible()
	return (QAAPI ~= nil and QAAPI.GetGroupConfig ~= nil)
end

function addon:IsQAEnabled()
	return addon:IsQACompatible() and ItemAuditor.db.char.use_quick_auctions
end

function addon:IsQADisabled()
	return not self:IsQAEnabled()
end

function addon:SetQAEnabled(info, value)
	ItemAuditor.db.char.use_quick_auctions = value
end

function addon:RefreshQAGroups()
	if not addon.IsQAEnabled() then
		return
	end
	for groupName in pairs(QAAPI:GetGroups()) do
		self:UpdateQAGroup(groupName)
	end
end

function addon:UpdateQAThreshold(link)
	if not addon.IsQAEnabled() then
		return
	end
	_, link= GetItemInfo(link)
	
	self:UpdateQAGroup(QAAPI:GetItemGroup(link))
end

addon.profit_margin = 1.15

local function calculateQAThreshold(copper)
	if copper == 0 then
		copper = 1
	end
	
	-- add my minimum profit margin
	-- GetAuctionThreshold returns a percent as a whole number. This will convert 25 to 1.25
	copper = copper *  (1+addon:GetAuctionThreshold())
	
	-- add AH Cut
	local keep = 1 - addon:GetAHCut()
	return copper/keep
end

function addon:UpdateQAGroup(groupName)
	if not addon.IsQAEnabled() then
		return
	end
	if groupName then
		local threshold = 0
		
		for link in pairs(QAAPI:GetItemsInGroup(groupName)) do
			local _, itemCost= ItemAuditor:GetItemCost(link, 0)
			
			threshold = max(threshold, itemCost)
		end
		
		threshold = calculateQAThreshold(threshold)
		
		QAAPI:SetGroupConfig(groupName, 'threshold', ceil(threshold))
	end
end

local function isProfitable(data)
	if addon.IsQAEnabled() then
		local QAGroup = QAAPI:GetItemGroup(data.link)
		if QAGroup ~= nil then
			local currentInvested, _, currentCount = addon:GetItemCost(data.link)
			local threshold, postCap, perAuction = QAAPI:GetGroupConfig(QAGroup)
			local stackSize = postCap * perAuction
			
			stackSize = stackSize / GetTradeSkillNumMade(data.tradeSkillIndex)
			
			-- bonus
			stackSize = ceil(stackSize *1.25)
			
			local newThreshold = ((data.cost*stackSize) + currentInvested) / (currentCount + stackSize)
			newThreshold = calculateQAThreshold(newThreshold)
			
			if  newThreshold < data.price then
				return stackSize
			end
			
			return -1
		end
	end
	return 0
end
ItemAuditor:RegisterCraftingDecider('IA QuickAuctions', isProfitable)

--[[
	This is based on KTQ
]]
function addon:Queue()
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
	
	
	if addon.IsQAEnabled() then
		self:Debug("Auction Threshold: %d%%", self:GetAuctionThreshold()*100 )
	end
	self:Debug(format("Crafting Threshold: %s", self:FormatMoney(self:GetCraftingThreshold())))
	local profitableItems = {}
	local profitableIndex = 1
	local numChecked = 0
	
	for i = 1, GetNumTradeSkills() do
		local itemLink = GetTradeSkillItemLink(i)
		local itemId = Skillet:GetItemIDFromLink(itemLink)

		--Figure out if its an enchant or not
		_, _, _, _, altVerb = GetTradeSkillInfo(i)
		if LSW.scrollData[itemId] ~= nil and altVerb == 'Enchant' then
			-- Ask LSW for the correct scroll
			itemId = LSW.scrollData[itemId]["scrollID"]
		end

		local skillName, skillType, numAvailable, isExpanded, altVerb = GetTradeSkillInfo(i)
		local recipeLink = GetTradeSkillRecipeLink(i)
		local stackSize  = 1
		if recipeLink ~= nil then
			_, itemLink= GetItemInfo(itemId)
			
			
			-- if QA isn't enabled, this will just return nil
			local QAGroup = nil
			if addon.IsQAEnabled() then
				QAGroup = QAAPI:GetItemGroup(itemLink)
				if QAGroup ~= nil then
					local threshold, postCap, perAuction = QAAPI:GetGroupConfig(QAGroup)
					stackSize = postCap * perAuction
					stackSize = stackSize / GetTradeSkillNumMade(i)
					
					-- bonus
					stackSize = ceil(stackSize *1.25)
				end
			end
			
			local count = Altoholic:GetItemCount(itemId)
			
			if count < stackSize and itemLink ~= nil then
				local found, _, skillString = string.find(recipeLink, "^|%x+|H(.+)|h%[.+%]")
				local _, skillId = strsplit(":", skillString )
				
				local toQueue = stackSize - count
				local newCost = 0
				for reagentId = 1, GetTradeSkillNumReagents(i) do
					_, _, reagentCount = GetTradeSkillReagentInfo(i, reagentId);
					reagentLink = GetTradeSkillReagentItemLink(i, reagentId)
					newCost = newCost + addon:GetReagentCost(reagentLink, reagentCount)  
				end
				
				local currentInvested, _, currentCount = addon:GetItemCost(itemLink)
				local newThreshold = (newCost + currentInvested) / (currentCount + toQueue)
				
				if addon.IsQAEnabled() then
					newThreshold = calculateQAThreshold(newThreshold)
				else
					-- if quick auctions isn't enabled, this will cause the decision to rely
					-- completly on the crafting threshold
					newThreshold = 0
				end
				local currentPrice = addon:GetAuctionPrice(itemLink) or 0
				numChecked = numChecked  + 1
				
				if newThreshold < currentPrice and (currentPrice - newCost) > self:GetCraftingThreshold() then
					
					profitableItems[profitableIndex] = {
						itemLink = itemLink,
						SkillID = skillId,
						Index = i,
						toQueue = toQueue,
						profit = (currentPrice - newCost) * toQueue
					}
					profitableIndex = profitableIndex + 1
				else
					local skipMessage = format("Skipping %s x%s. Profit: %s ", itemLink, toQueue, addon:FormatMoney(currentPrice - newCost))
					if ItemAuditor.db.profile.messages.queue_skip then
						self:Print(skipMessage)
					else
						self:Debug(format("Skipping %s x%s. Profit: %s ", itemLink, toQueue, addon:FormatMoney(currentPrice - newCost)))
					end
				end
			end
		end
	end
	local numAdded = 0
	table.sort(profitableItems, function(a, b) return a.profit > b.profit end)
	for key, data in pairs(profitableItems) do
		self:Print(format("Adding %s x%s to skillet queue. Profit: %s", 
			data.itemLink, 
			data.toQueue, 
			self:FormatMoney(data.profit)
		))
		self:AddToQueue(data.SkillID, data.Index, data.toQueue)
		numAdded = numAdded +1
	end
	self:Print(format("%d items checked", numChecked))
	self:Print(format("%d queued", numAdded))
end

function addon:GetReagentCost(link, total)
	local totalCost = 0
	
	if Skillet:VendorSellsReagent(link) then
		local _, _, _, _, _, _, _, _, _, _, itemVendorPrice = GetItemInfo (link);
		totalCost = itemVendorPrice * total
		total = 0
	end

	
	local investedTotal, investedPerItem, count = addon:GetItemCost(link)
	
	if count > 0 then
		if total <= count then
			totalCost = investedPerItem * total
			total = 0
		else
			totalCost = investedTotal
			total = total - count
		end
	end
	
	-- If there is none on the auction house, this uses a large enough number
	-- to prevent us from trying to make the item.
	local ahPrice = (self:GetAuctionPrice(link) or 99990000)
	-- local itemName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType, _, _, _, _, itemVendorPrice = GetItemInfo (link);
	
	return totalCost + (ahPrice * total)
end

function addon:GetAuctionPrice(itemLink)
	if GetAuctionBuyout ~= nil then
		return GetAuctionBuyout(itemLink)
	elseif AucAdvanced and AucAdvanced.Version then
		local _, _, _, _, _, lowBuy= AucAdvanced.Modules.Util.SimpleAuction.Private.GetItems(itemLink)
		return lowBuy
	end
	return nil
end

function addon:AddToQueue(skillId,skillIndex, toQueue)
	if Skillet == nil then
		self:Print("Skillet not loaded")
		return
	end
	if Skillet.QueueCommandIterate ~= nil then
		local queueCommand = Skillet:QueueCommandIterate(tonumber(skillId), toQueue)
		Skillet:AddToQueue(queueCommand)
	else
		Skillet.stitch:AddToQueue(skillIndex, toQueue)
	end
end
