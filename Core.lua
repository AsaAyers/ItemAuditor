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
			item_account = {}
		},
	}
	self.db = LibStub("AceDB-3.0"):New("ItemAuditorDB", DB_defaults, true)
	
	self.db.char.debug = true
	
	self:RegisterOptions()
	
	self:RegisterEvent("PLAYER_ENTERING_WORLD")
end

function addon:GetCurrentInventory()
   local i = {}
   local link
   
   for bagID = 0, NUM_BAG_SLOTS do
      bagSize=GetContainerNumSlots(bagID)
      for slotID = 0, bagSize do
         itemID = GetContainerItemID(bagID, slotID);
         
         if itemID ~= nil then
            _, itemCount, _, _, _= GetContainerItemInfo(bagID, slotID);
            name = GetItemInfo(itemID)
            if i[name] == nil then
               i[name] = 0
            end
            i[name] = i[name] + (itemCount or 0)
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
   
   for name, count in pairs(current.items) do
      if pastInventory.items[name] == nil then
         diff[name] = count
         self:Debug("1 diff[" .. name .. "]=" .. diff[name])
      elseif count - pastInventory.items[name] ~= 0 then
         diff[name] = count - pastInventory.items[name]
         self:Debug("2 diff[" .. name .. "]=" .. diff[name])        
      end    
   end
   
   for name, count in pairs(pastInventory.items) do
      if current.items[name] == nil then
         diff[name] = -count
         self:Debug("3 diff[" .. name .. "]=" .. diff[name])                
      elseif current.items[name] - count ~= 0 then
         diff[name] = current.items[name] - pastInventory.items[name]
         self:Debug("4 diff[" .. name .. "]=" .. diff[name])        
      end
   end
   
   local moneyDiff = current.money - pastInventory.money
   
   return {items = diff, money = moneyDiff}
end


function addon:ScanMail()
	local results = {}
	for mailIndex = 1, GetInboxNumItems() or 0 do
		local sender, msgSubject, msgMoney, msgCOD, _, msgItem, _, _, msgText, _, isGM = select(3, GetInboxHeaderInfo(mailIndex))
		local mailType = Postal:GetMailType(msgSubject)

		if mailType == "NonAHMail" then
			-- Don't know how to handle these yet
		elseif mailType == "AHSuccess" then
			local invoiceType, itemName, playerName, bid, buyout, deposit, consignment = GetInboxInvoiceInfo(mailIndex);
			if results[itemName] == nil then
				results[itemName] = 0
			end
			results[itemName] = results[itemName] + deposit + buyout - consignment

		elseif mailType == "AHWon" then
			local invoiceType, itemName, playerName, bid, buyout, deposit, consignment = GetInboxInvoiceInfo(mailIndex);
			if results[itemName] == nil then
				results[itemName] = 0
			end
			results[itemName] = results[itemName] - bid
		elseif mailType == "AHExpired" or mailType == "AHCancelled" then
			-- These should be handled when you pay the deposit at the AH
		else
			self:Debug("Unhandled mail type: " .. mailType)
			self:Debug(msgSubject)
		end

	end
	return results   
end

function addon:SaveValue(item, value)
	local item_account = self.db.factionrealm.item_account
	if item_account[item] == nil then
		item_account[item] = 0
	end
	item_account[item] = item_account[item] + value
	
	if item_account[item] >= 0 then
		item_account[item] = nil
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

function addon:GetItemCost(itemName, countModifier)
	local invested = abs(self.db.factionrealm.item_account[itemName] or 0)
	
	if invested > 0 then
		local _, itemLink = GetItemInfo (itemName);
		local _, _, _, _, Id = string.find(itemLink, "|?c?f?f?(%x*)|?H?([^:]*):?(%d+):?(%d*):?(%d*):?(%d*):?(%d*):?(%d*):?(%-?%d*):?(%-?%d*):?(%d*)|?h?%[?([^%[%]]*)%]?|?h?|?r?")
		local count = Altoholic:GetItemCount(tonumber(Id))
		if countModifier ~= nil then
			count = count - countModifier
		end
		if count == 0 then 
			self.db.factionrealm.item_account[itemName] = nil
			self:Print("You ran out of " .. itemName .. "and never recovered " .. utils:FormatMoney(invested))
			return 0, 0, 0
		end
		return ceil(invested), ceil(invested/count), count
	end
	return 0, 0, 0
end
