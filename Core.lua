local addon = LibStub("AceAddon-3.0"):NewAddon("ItemAuditor", "AceConsole-3.0", "AceEvent-3.0", "AceBucket-3.0")

ItemAuditor = addon

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
	
	self:RegisterEvent("MAIL_SHOW")
	self:WatchBags()
end

local function IA_tcount(tab)
   local n = #tab
   if (n == 0) then
      for _ in pairs(tab) do
         n = n + 1
      end
   end
   return n
end


local options = {
	name = "ItemAuditor",
	handler = ItemAuditor,
	type = 'group',
	args = {
		debug = {
			type = "toggle",
			name = "Debug",
			desc = "Toggles debug messages in chat",
			get = "GetDebug",
			set = "SetDebug"
		},
		dump = {
			type = "execute",
			name = "dump",
			desc = "dumps IA database",
			func = "DumpInfo",
		},
		options = {
			type = "execute",
			name = "options",
			desc = "Show Blizzard's options GUI",
			func = "ShowOptionsGUI",
			guiHidden = true,
		},
	},
}


function addon:DumpInfo()
	self:Print("self.db.char")
	DevTools_Dump(self.db.char)
	self:Print("self.db.factionrealm")
	DevTools_Dump(self.db.factionrealm)
end

function addon:RegisterOptions()
	self.optionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("ItemAuditor", "ItemAuditor")
	
	LibStub("AceConfig-3.0"):RegisterOptionsTable("ItemAuditor", options, {"ia"})
end

function addon:GetMessage(info)
    return self.message
end

function addon:SetMessage(info, newValue)
    self.message = newValue
end


function addon:ShowOptionsGUI()
	InterfaceOptionsFrame_OpenToCategory(self.optionsFrame)
end

function addon:GetDebug(info)
	return self.db.char.debug
end

function addon:SetDebug(info, input)
	self.db.char.debug = input
	local value = "off"
	if input then
		value = "on"
	end
	self:Print("Debugging is now: " .. value)
end


-- ================  DEBUG ================
addon.OriginalRegisterEvent = addon.RegisterEvent 
addon.OriginalUnregisterEvent = addon.UnregisterEvent

function addon:RegisterEvent(event, callback, arg)
   self:Debug("RegisterEvent " .. event )
   if arg ~= nil then
      addon:OriginalRegisterEvent(event, callback, arg)
   elseif callback ~= nil then
      addon:OriginalRegisterEvent(event, callback)
   else
      addon:OriginalRegisterEvent(event)
   end
end

function addon:UnregisterEvent(event)
	self:Debug("UnregisterEvent " .. event )
	addon:OriginalUnregisterEvent (event)
end

-- ================  DEBUG ================

function addon:FormatMoney(money)
    return Altoholic:GetMoneyString(money, WHITE, false)
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

function addon:MAIL_SHOW()
	self:Debug("MAIL_SHOW")
	self.lastMailScan = self:ScanMail()
	self:UnregisterEvent("MAIL_SHOW")
	self:RegisterEvent("MAIL_CLOSED")
	self:RegisterEvent("MAIL_INBOX_UPDATE")
	self:Debug("MAIL_SHOW complete")
end

function addon:MAIL_CLOSED()
	addon:UnregisterEvent("MAIL_CLOSED")
	self:UnregisterEvent("MAIL_INBOX_UPDATE")
	self:RegisterEvent("MAIL_SHOW")
end

function addon:MAIL_INBOX_UPDATE()
	local newScan = addon:ScanMail()
	local diff
	for item, total in pairs(self.lastMailScan) do

		if newScan[item] == nil then
			newScan[item] = 0
		end
		diff = total - newScan[item]
		if diff ~= 0 then
			self:SaveValue(item, diff)
		end

	end

	self.lastMailScan = newScan
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

function addon:OnEnable()
	self:Debug("Hello, world! OnEnable")
end

function addon:Debug(msg)
	if self.db.char.debug then
		self:Print(msg)
	end
end

function addon:WatchBags()
   if self.watch_handle == nil then
	self.lastInventory = self:GetCurrentInventory()
	self.watch_handle = self:RegisterBucketEvent({"BAG_UPDATE", "PLAYER_MONEY"}, 0.2, "UpdateAudit")
   end
end

function addon:UnwatchBags()
   if self.watch_handle ~= nil then
      self:UnregisterBucket(self.watch_handle)
      self.watch_handle = nil
   end
end

function addon:UpdateAudit()
	self:Debug("UpdateAudit")
	local currentInventory = self:GetCurrentInventory()
	local diff =  addon:GetInventoryDiff(self.lastInventory, currentInventory)
	-- this is only here for debugging
	self.lastdiff = diff
	
	if abs(diff.money) > 0 and IA_tcount(diff.items) == 1 then
		self:Debug("purchase or sale")
		
		for itemName, count in pairs(diff.items) do
			self:SaveValue(itemName, diff.money)
		end
	elseif IA_tcount(diff.items) > 1 then
		local positive, negative = {}, {}
		local positiveCount, negativeCount = 0, 0
		for item, count in pairs(diff.items) do
			if count > 0 then
				positive[item] = count
				positiveCount = positiveCount + count
			elseif count < 0 then
				negative[item] = count
				negativeCount = negativeCount + abs(count)
			end
		end
		
		if IA_tcount(positive) > 0 and IA_tcount(negative) > 0 then
			-- we must have created/converted something
			self:Debug("conversion")
			local totalChange = 0
			for itemName, change in pairs(negative) do
				local _, itemCost, count = self:GetItemCost(itemName, change)
				self:SaveValue(itemName, abs(itemCost * change))
				
				totalChange = totalChange + abs(itemCost * change)
			end
			
			self:Debug("totalChange")
			self:Debug(totalChange)
			
			local valuePerItem = totalChange / positiveCount
			self:Debug(valuePerItem )
			for itemName, change in pairs(positive) do
				self:Debug(itemName)
				self:Debug(0-abs(valuePerItem * change))
				self:SaveValue(itemName, 0-abs(valuePerItem * change))
			end
		end
	end
	
	self.lastInventory = currentInventory
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
			self:Print("You ran out of " .. itemName .. "and never recovered " .. self:FormatMoney(invested))
			return 0, 0, 0
		end
		return ceil(invested), ceil(invested/count), count
	end
	return 0, 0, 0
end

function addon:ShowTooltip(tip, link, num)
   if (link == nil) then
      return;
   end
   
   local itemName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType, _, _, _, _, itemVendorPrice = GetItemInfo (link);
   -- local _, _, Color, Ltype, Id, Enchant, Gem1, Gem2, Gem3, Gem4, Suffix, Unique, LinkLvl, Name = string.find(link, "|?c?f?f?(%x*)|?H?([^:]*):?(%d+):?(%d*):?(%d*):?(%d*):?(%d*):?(%d*):?(%-?%d*):?(%-?%d*):?(%d*)|?h?%[?([^%[%]]*)%]?|?h?|?r?")
   
   local investedTotal, investedPerItem, count = self:GetItemCost(itemName)
   
   local AHCut = 0.05
   local keep = 1 - AHCut
   
   if investedTotal > 0 then
      tip:AddDoubleLine("\124cffffffffIA: Total Invested", self:FormatMoney(investedTotal));
      tip:AddDoubleLine("\124cffffffffIA: Invested/Item (" .. count .. ")", self:FormatMoney(ceil(investedPerItem)));
      tip:AddDoubleLine("\124cffffffffIA: Minimum faction AH Price: ", self:FormatMoney(ceil(investedPerItem/keep)))
      tip:Show()
   end
end

local function ShowTipWithPricing(tip, link, num)
	addon:ShowTooltip(tip, link, num)
end

hooksecurefunc (GameTooltip, "SetBagItem",
	function(tip, bag, slot)
		local _, num = GetContainerItemInfo(bag, slot);
		ShowTipWithPricing (tip, GetContainerItemLink(bag, slot), num);
	end
);


hooksecurefunc (GameTooltip, "SetAuctionItem",
	function (tip, type, index)
		ShowTipWithPricing (tip, GetAuctionItemLink(type, index));
	end
);

hooksecurefunc (GameTooltip, "SetAuctionSellItem",
	function (tip)
		local name, _, count = GetAuctionSellItemInfo();
		local __, link = GetItemInfo(name);
		ShowTipWithPricing (tip, link, num);
	end
);


hooksecurefunc (GameTooltip, "SetLootItem",
	function (tip, slot)
		if LootSlotIsItem(slot) then
			local link, _, num = GetLootSlotLink(slot);
			ShowTipWithPricing (tip, link, num);
		end
	end
);

hooksecurefunc (GameTooltip, "SetLootRollItem",
	function (tip, slot)
		local _, _, num = GetLootRollItemInfo(slot);
		ShowTipWithPricing (tip, GetLootRollItemLink(slot), num);
	end
);


hooksecurefunc (GameTooltip, "SetInventoryItem",
	function (tip, unit, slot)
		ShowTipWithPricing (tip, GetInventoryItemLink(unit, slot), GetInventoryItemCount(unit, slot));
	end
);

hooksecurefunc (GameTooltip, "SetGuildBankItem",
	function (tip, tab, slot)
		local _, num = GetGuildBankItemInfo(tab, slot);
		ShowTipWithPricing (tip, GetGuildBankItemLink(tab, slot), num);
	end
);

hooksecurefunc (GameTooltip, "SetTradeSkillItem",
	function (tip, skill, id)
		local link = GetTradeSkillItemLink(skill);
		local num  = GetTradeSkillNumMade(skill);
		if id then
			link = GetTradeSkillReagentItemLink(skill, id);
			num = select (3, GetTradeSkillReagentInfo(skill, id));
		end

		ShowTipWithPricing (tip, link, num);
	end
);

hooksecurefunc (GameTooltip, "SetTradePlayerItem",
	function (tip, id)
		local _, _, num = GetTradePlayerItemInfo(id);
		ShowTipWithPricing (tip, GetTradePlayerItemLink(id), num);
	end
);

hooksecurefunc (GameTooltip, "SetTradeTargetItem",
	function (tip, id)
		local _, _, num = GetTradeTargetItemInfo(id);
		ShowTipWithPricing (tip, GetTradeTargetItemLink(id), num);
	end
);

hooksecurefunc (GameTooltip, "SetQuestItem",
	function (tip, type, index)
		local _, _, num = GetQuestItemInfo(type, index);
		ShowTipWithPricing (tip, GetQuestItemLink(type, index), num);
	end
);

hooksecurefunc (GameTooltip, "SetQuestLogItem",
	function (tip, type, index)
		local num, _;
		if type == "choice" then
			_, _, num = GetQuestLogChoiceInfo(index);
		else
			_, _, num = GetQuestLogRewardInfo(index)
		end

		ShowTipWithPricing (tip, GetQuestLogItemLink(type, index), num);
	end
);

hooksecurefunc (GameTooltip, "SetInboxItem",
	function (tip, index, attachIndex)
		local _, _, num = GetInboxItem(index, attachIndex);
		ShowTipWithPricing (tip, GetInboxItemLink(index, attachIndex), num);
	end
);

hooksecurefunc (GameTooltip, "SetSendMailItem",
	function (tip, id)
		local name, _, num = GetSendMailItem(id)
		local name, link = GetItemInfo(name);
		ShowTipWithPricing (tip, link, num);
	end
);

hooksecurefunc (GameTooltip, "SetHyperlink",
	function (tip, itemstring, num)
		local name, link = GetItemInfo (itemstring);
		ShowTipWithPricing (tip, link, num);
	end
);

hooksecurefunc (ItemRefTooltip, "SetHyperlink",
	function (tip, itemstring)
		local name, link = GetItemInfo (itemstring);
		ShowTipWithPricing (tip, link);
	end
);
