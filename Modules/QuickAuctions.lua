local addonName, addonTable = ...; 
local addon = _G[addonName]

function addon:IsQACompatible()
	return (QAAPI ~= nil and QAAPI.GetGroups ~= nil)
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
addon.minimum_profit = 50000

local function calculateQAThreshold(copper)
	if copper == 0 then
		copper = 1
	end
	
	-- add my minimum profit margin
	copper = copper * addon.profit_margin 
	
	-- Adding the cost of mailing every item once.
	copper = copper + 30
	
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
		
		QAAPI:SetGroupThreshold(groupName, ceil(threshold))
	end
end

--[[
	This is based on KTQ
]]
function addon:Queue()
	if not addon.IsQAEnabled() then
		self:Debug("Refusing to run :Queue() QA is disabled")
		return
	end
	if LSW == nil then
		self:Print("This feature requires LilSparky's Workshop.")
		return
	end
	
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
			local QAGroup = QAAPI:GetItemGroup(itemLink)
			if QAGroup ~= nil then
				stackSize = QAAPI:GetGroupPostCap(QAGroup) * QAAPI:GetGroupPerAuction(QAGroup)
				stackSize = stackSize / GetTradeSkillNumMade(i)
				
				-- bonus
				stackSize = ceil(stackSize *1.25)
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
				
				
				newThreshold = calculateQAThreshold(newThreshold)
				local currentPrice = GetAuctionBuyout(itemLink) or 0
				
				
				-- bonus?
				
				if newThreshold < currentPrice and (currentPrice - newThreshold) > addon.minimum_profit then
					self:Debug(format("Adding %s x%s to skillet queue. Profit: %s", 
						itemLink, 
						toQueue, 
						addon:FormatMoney(currentPrice - newThreshold)
					))
					self:AddToQueue(skillId,i, toQueue)
				else
					self:Debug(format("Skipping %s x%s. Would lose %s ", itemLink, toQueue, addon:FormatMoney(currentPrice - newThreshold)))
				end
			end
		  end
	end
	
	
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
	local ahPrice = (GetAuctionBuyout(link) or 99990000)
	
	return totalCost + (ahPrice * total)
end

function addon:AddToQueue(skillId,skillIndex, toQueue)
	if Skillet == nil then
		self:Print("Skillet not loaded")
	end
	if Skillet.QueueCommandIterate ~= nil then
		local queueCommand = Skillet:QueueCommandIterate(tonumber(skillId), toQueue)
		Skillet:AddToQueue(queueCommand)
	else
		Skillet.stitch:AddToQueue(skillIndex, toQueue)
	end
end
