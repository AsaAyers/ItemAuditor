local addonName, addonTable = ...; 
_G[addonName] = LibStub("AceAddon-3.0"):NewAddon(addonName, "AceConsole-3.0", "AceEvent-3.0", "AceBucket-3.0")
local addon = _G[addonName]
addonTable.ItemAuditor = addon

local utils = addonTable.utils


local WHITE		= "|cFFFFFFFF"
local RED		= "|cFFFF0000"
local GREEN		= "|cFF00FF00"
local YELLOW	= "|cFFFFFF00"
local ORANGE	= "|cFFFF7F00"
local TEAL		= "|cFF00FF9A"
local GOLD		= "|cFFFFD700"

function addon:OnInitialize()
	local DB_defaults = {
		char = {
			debug = false
		},
		factionrealm = {
			item_account = {},
			items = {},
			AHCut = 0.05,
		},
	}
	self.db = LibStub("AceDB-3.0"):New("ItemAuditorDB", DB_defaults, true)
	addonTable.db= self.db
	self.items = self.db.factionrealm.items
	
	self:RegisterOptions()
	
	self:RegisterEvent("PLAYER_ENTERING_WORLD")
end

function addon:ConvertItems()
	for itemName, value in pairs(self.db.factionrealm.item_account) do
		local itemID = utils:GetItemID(itemName)
		if itemID ~= nil then
			self:GetItem('item:' .. itemID)
		end
		if value == 0 then
			self.db.factionrealm.item_account[itemName] = nil
		end
	end
	
	for link, data in pairs(self.db.factionrealm.items) do
		if self:GetItem(link).count == 0 or self:GetItem(link).invested == 0 then
			self:RemoveItem(link)
		end
		-- addon:UpdateQAThreshold(link)
	end
	
	self:RefreshQAGroups()
end

function addon:RefreshQAGroups()
	for groupName in pairs(QAAPI:GetGroups()) do
		self:UpdateQAGroup(groupName)
	end
end

function addon:GetCurrentInventory()
	local i = {}
	local bagID
	local slotID
	
	for bagID = 0, NUM_BAG_SLOTS do
		bagSize=GetContainerNumSlots(bagID)
		for slotID = 0, bagSize do
			local link= GetContainerItemLink(bagID, slotID);
			link = link and self:GetSafeLink(link)

			if link ~= nil and i[link] == nil then
				i[link] = GetItemCount(link);
			end
		end

	end
	return {items = i, money = GetMoney()}
end

function addon:GetInventoryDiff(pastInventory, current)
	if current == nil then
		current = self:GetCurrentInventory()
	end
	local diff = {}

	for link, count in pairs(current.items) do
		if pastInventory.items[link] == nil then
			diff[link] = count
			-- self:Debug("1 diff[" .. name .. "]=" .. diff[name])
		elseif count - pastInventory.items[link] ~= 0 then
			diff[link] = count - pastInventory.items[link]
			-- self:Debug("2 diff[" .. name .. "]=" .. diff[name])        
		end    
	end

	for link, count in pairs(pastInventory.items) do
		if current.items[link] == nil then
			diff[link] = -count
			-- self:Debug("3 diff[" .. name .. "]=" .. diff[name])                
		elseif current.items[link] - count ~= 0 then
			diff[link] = current.items[link] - pastInventory.items[link]
			-- self:Debug("4 diff[" .. name .. "]=" .. diff[name])        
		end
	end

	local moneyDiff = current.money - pastInventory.money

	return {items = diff, money = moneyDiff}
end



function addon:ScanMail()
	local results = {}
	for mailIndex = 1, GetInboxNumItems() or 0 do
		local sender, msgSubject, msgMoney, msgCOD, _, msgItem, _, _, msgText, _, isGM = select(3, GetInboxHeaderInfo(mailIndex))
		local mailType = utils:GetMailType(msgSubject)
		
		results[mailType] = (results[mailType] or {})
		
		if mailType == "NonAHMail" then
			--[[
			and msgCOD > 0 
			
			mailType = 'COD'
			results[mailType] = (results[mailType] or {})
			
			local itemTypes = {}
			for itemIndex = 1, ATTACHMENTS_MAX_RECEIVE do
				local itemName, _, count, _, _= GetInboxItem(mailIndex, itemIndex)
				if itemName ~= nil then
					itemTypdes[itemName] = (itemTypes[itemName] or 0) + count
				end
			end
			
			if utils:tcount(itemTypes) == 1 then
				for itemName, count in pairs(itemTypes) do
					results[mailType][itemName] = (results[mailType][itemName] or 0) - msgCOD
				end
			else
				self:Debug("Don't know what to do with more than one item type on COD mail.")
			end
			]]
		elseif mailType == "CODPayment" then	
			itemName = msgSubject:gsub(utils.SubjectPatterns[mailType], function(item) return item end)
			
			results[mailType][itemName] = (results[mailType][itemName] or 0) - msgMoney
			
		elseif mailType == "AHSuccess" then
			local invoiceType, itemName, playerName, bid, buyout, deposit, consignment = GetInboxInvoiceInfo(mailIndex);
			results[mailType][itemName] = (results[mailType][itemName] or 0) - deposit - buyout + consignment

		elseif mailType == "AHWon" then
			local invoiceType, itemName, playerName, bid, buyout, deposit, consignment = GetInboxInvoiceInfo(mailIndex);
			results[mailType][itemName] = (results[mailType][itemName] or 0) + bid
		elseif mailType == "AHExpired" or mailType == "AHCancelled" or mailType == "AHOutbid" then
			-- These should be handled when you pay the deposit at the AH
		else
			self:Debug("Unhandled mail type: " .. mailType)
			self:Debug(msgSubject)
		end

	end
	return results   
end

function addon:GetItem(link, viewOnly)
	if viewOnly == nil then
		viewOnly = false
	end
	
	local itemName = nil
	if self:GetSafeLink(link) == nil then
		itemName = link
		link = self:GetSafeLink(link)
	else
		link = self:GetSafeLink(link)
		itemName = GetItemInfo(link)
	end
	
	
	if self.db.factionrealm.item_account[itemName] ~= nil then
		self.items[link] = {
			count = Altoholic:GetItemCount(self:GetIDFromLink(link)),
			invested = abs(self.db.factionrealm.item_account[itemName] or 0),
		}
		self.db.factionrealm.item_account[itemName] = nil
	end
	
	if viewOnly == false and self.items[link] == nil then
		local itemName = GetItemInfo(link)
	
		self.items[link] = {
			count =  Altoholic:GetItemCount(self:GetIDFromLink(link)),
			invested = abs(self.db.factionrealm.item_account[itemName] or 0),
		}
		
	end
	
	
	
	if viewOnly == true and self.items[link] == nil then
		return {count = 0, invested = 0}
	elseif viewOnly == true then
		return {count = self.items[link].count, invested = self.items[link].invested}
	end
	self.items[link].count =  Altoholic:GetItemCount(self:GetIDFromLink(link))
	return self.items[link]
end

function addon:RemoveItem(link)
	self.db.factionrealm.item_account[link] = nil
	link = self:GetSafeLink(link)
	if link ~= nil then
		self.items[link] = nil
	end
end

function addon:SaveValue(link, value)
	local item = nil
	local realLink = self:GetSafeLink(link)
	local itemName = nil
	if realLink == nil then
		itemName = link
		self.db.factionrealm.item_account[itemName] = (self.db.factionrealm.item_account[itemName] or 0) + value
		item = {invested = self.db.factionrealm.item_account[itemName], count = 1}
	else
		item = self:GetItem(realLink)
		item.invested = item.invested + value
		itemName = GetItemInfo(realLink)
	end
	
	if abs(value) > 0 then
		self:Debug("Updated price of " .. itemName .. " to " .. utils:FormatMoney(item.invested) .. "(change: " .. utils:FormatMoney(value) .. ")")
		
		if item.invested <= 0 then
			self:Debug("Updated price of " .. itemName .. " to " .. utils:FormatMoney(0))
			self:RemoveItem(link)
		-- This doesn't work when you mail the only copy of an item you have to another character.
		--[[
		elseif item.count == 0 and realLink and Altoholic:GetItemCount(self:GetIDFromLink(realLink)) then 
			self:Print("You ran out of " .. itemName .. " and never recovered " .. utils:FormatMoney(item.invested))
			self:RemoveItem(link)
		]]
		end
	end
	
	if realLink ~= nil then
		addon:UpdateQAThreshold(realLink)
	end
end

function addon:UpdateQAThreshold(link)
	_, link= GetItemInfo(link)
	
	self:UpdateQAGroup(QAAPI:GetItemGroup(link))
end

function addon:UpdateQAGroup(groupName)
	if groupName then
		local threshold = 0
		
		for link in pairs(QAAPI:GetItemsInGroup(groupName)) do
			local _, itemCost= ItemAuditor:GetItemCost(link, 0)
			
			threshold = max(threshold, itemCost)
		end
		
		if threshold == 0 then
			threshold = 10000
		end
		
		-- add my minimum profit margin
		threshold = threshold * 1.10
		
		-- Adding the cost of mailing every item once.
		threshold = threshold + 30
		
		-- add AH Cut
		local keep = 1 - self.db.factionrealm.AHCut
		threshold = threshold/keep
		
		QAAPI:SetGroupThreshold(groupName, ceil(threshold))
	end
end

local defaultBagDelay = 0.2

function addon:WatchBags(delay)
	delay = delay or defaultBagDelay
	if delay ~= self.currentBagDelay  then
		self:UnwatchBags()
	end

	if self.watch_handle == nil then
		self.currentBagDelay = delay
		self:Debug("currentBagDelay = " .. delay)
		addon:UpdateCurrentInventory()
		self.watch_handle = self:RegisterBucketEvent({"BAG_UPDATE", "PLAYER_MONEY"}, self.currentBagDelay, "UpdateAudit")
	end
end

function addon:UnwatchBags()
	if self.watch_handle ~= nil then
		self:UnregisterBucket(self.watch_handle)
		self.watch_handle = nil
	end
end

function addon:GetItemID(itemName)
	return utils:GetItemID(itemName)
end

function addon:GetSafeLink(link)
	local newLink = nil

	if link and link ~= string.match(link, '.-:[-0-9]+[:0-9]*') then
		newLink = link and string.match(link, "|H(.-):([-0-9]+):([0-9]+)|h")
	end
	if newLink == nil then
		local itemID = self:GetItemID(link)
		if itemID ~= nil then
			_, newLink = GetItemInfo(itemID)
			return self:GetSafeLink(newLink)
		end
	end
	return newLink and string.gsub(newLink, ":0:0:0:0:0:0", "")
end

function addon:GetIDFromLink(link)
	local _, _, _, _, Id = string.find(link, "|?c?f?f?(%x*)|?H?([^:]*):?(%d+):?(%d*):?(%d*):?(%d*):?(%d*):?(%d*):?(%-?%d*):?(%-?%d*):?(%d*)|?h?%[?([^%[%]]*)%]?|?h?|?r?")
	return tonumber(Id)
end

function addon:GetItemCost(link, countModifier)
	local item = self:GetItem(link, true)

	if item.invested > 0 then
		local count = item.count
		
		if countModifier ~= nil then
			count = count - countModifier
		end
		if count > 0 then 
			return ceil(item.invested), ceil(item.invested/item.count), count
		end
		
	end
	return 0, 0, 0
end
