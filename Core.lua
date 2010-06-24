local addonName, addonTable = ...; 
_G[addonName] = LibStub("AceAddon-3.0"):NewAddon(addonName, "AceConsole-3.0", "AceEvent-3.0", "AceBucket-3.0")
local addon = _G[addonName]

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
		
		if mailType == "NonAHMail" and msgCOD > 0 then
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
		elseif mailType == "CODPayment" then	
			itemName = msgSubject:gsub(utils.SubjectPatterns[mailType], function(item) return item end)
			
			results[mailType][itemName] = (results[mailType][itemName] or 0) + msgMoney
			
		elseif mailType == "AHSuccess" then
			local invoiceType, itemName, playerName, bid, buyout, deposit, consignment = GetInboxInvoiceInfo(mailIndex);
			results[mailType][itemName] = (results[mailType][itemName] or 0) + deposit + buyout - consignment

		elseif mailType == "AHWon" then
			local invoiceType, itemName, playerName, bid, buyout, deposit, consignment = GetInboxInvoiceInfo(mailIndex);
			results[mailType][itemName] = (results[mailType][itemName] or 0) - bid
		elseif mailType == "AHExpired" or mailType == "AHCancelled" or mailType == "AHOutbid" then
			-- These should be handled when you pay the deposit at the AH
		else
			self:Debug("Unhandled mail type: " .. mailType)
			self:Debug(msgSubject)
		end

	end
	return results   
end

function addon:GetItem(link)
	link = utils:GetSafeLink(link)
	DevTools_Dump(link)
	if self.items[link] == nil then
		local itemName = GetItemInfo(link)
	
		self.items[link] = {
			count = Altoholic:GetItemCount(utils:GetIDFromLink(link)),
			invested = abs(self.db.factionrealm.item_account[itemName] or 0),
		}
		self.db.factionrealm.item_account[itemName] = nil
	end
	
	return self.items[link]
end

function addon:RemoveItem(link)
	link = utils:GetSafeLink(link)
	self.items[link] = nil
end

function addon:SaveValue(link, value)
	local item_account = self.db.factionrealm.item_account
	
	local item = self:GetItem(link)
	
	item.invested = item.invested + value
	
	local itemName = GetItemInfo(link)
	if abs(value) > 0 then
		self:Debug("Updated price of " .. itemName .. " to " .. utils:FormatMoney(item.invested) .. "(change: " .. utils:FormatMoney(value) .. ")")
	end
	
	if item.invested > 0 then
		self:Debug("Updated price of " .. itemName .. " to " .. utils:FormatMoney(0))
		self:RemoveItem(link)
	end
	
	if item.count == 0 then 
		self:Print("You ran out of " .. itemName .. " and never recovered " .. utils:FormatMoney(item.invested))
		self:RemoveItem(link)
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

function addon:GetItemCost(link, countModifier)
	local item = self:GetItem(link)

	local invested = item.invested
	
	if invested > 0 then
		local ItemID = utils:GetIDFromLink(link)
		if ItemID ~= nil then
			local count = self:GetItem(link).count
			
			if countModifier ~= nil then
				count = count - countModifier
			end
			if count > 0 then 
				return ceil(invested), ceil(invested/count), count
			end
		end
	end
	return 0, 0, 0
end
