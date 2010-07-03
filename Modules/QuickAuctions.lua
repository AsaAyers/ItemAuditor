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
		
		if threshold == 0 then
			threshold = 1
		end
		
		-- add my minimum profit margin
		threshold = threshold * 1.10
		
		-- Adding the cost of mailing every item once.
		threshold = threshold + 30
		
		-- add AH Cut
		local keep = 1 - addon:GetAHCut()
		threshold = threshold/keep
		
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
		local stackSize  = 0
		if recipeLink ~= nil then
			_, itemLink= GetItemInfo(itemId)
			local QAGroup = QAAPI:GetItemGroup(itemLink)
			if QAGroup ~= nil then
				stackSize = QAAPI:GetGroupPostCap(QAGroup) * QAAPI:GetGroupPerAuction(QAGroup)
				stackSize = stackSize / GetTradeSkillNumMade(i)
			end

			local count = Altoholic:GetItemCount(itemId)
			
			if count < stackSize then
				local found, _, skillString = string.find(recipeLink, "^|%x+|H(.+)|h%[.+%]")
				local _, skillId = strsplit(":", skillString )
				
				
				local totalCost = 0
				for reagentId = 1, GetTradeSkillNumReagents(i) do
					_, _, reagentCount = GetTradeSkillReagentInfo(i, reagentId);
					reagentLink = GetTradeSkillReagentItemLink(i, reagentId)
					
					totalCost = totalCost + addon:GetReagentCost(reagentLink, reagentCount)  
				end
				
				local currentPrice = GetAuctionBuyout(itemLink) or 0
				
				local toQueue = stackSize - count
				-- bonus?
				
				if totalCost < currentPrice then
					self:Debug(format("Adding %s x%s to skillet queue.", itemLink, toQueue))
					self:AddToQueue(skillId,i, toQueue)
				else
					self:Debug(format("Skipping %s. Would cost %s to craft and sell for %s", itemLink, addon:FormatMoney(totalCost), addon:FormatMoney(currentPrice)))
				end
			end
		  end
	end
	
	
end

function addon:GetReagentCost(link, total)
	local totalCost = 0
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
