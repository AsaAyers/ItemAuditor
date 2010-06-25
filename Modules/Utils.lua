local addonName, addonTable = ...; 
local addon = {}

local AceConsole = LibStub("AceConsole-3.0")
AceConsole:Embed(addon)

addonTable.utils = addon
IAUtils = addon

function addon:FormatMoney(money)
	local prefix = ""
	if money < 0 then
		prefix = "-"
	end
	return prefix .. Altoholic:GetMoneyString(abs(money), WHITE, false)
end

-- This is only here to make sure this doesn't blow up if ReplaceItemCache is never called
local item_db = {}

function addon:ReplaceItemCache(new_cache)
	item_db  = new_cache
end

-- This will be reset every session
local tmp_item_cache = {}
function addon:GetItemID(itemName)
	if item_db[itemName] ~= nil then
		return item_db[itemName]
	end
	
	if tmp_item_cache[itemName] == nil then
		local _, itemLink = GetItemInfo (itemName);
		if itemLink ~= nil then
			local _, _, _, _, itemID = string.find(itemLink, "|?c?f?f?(%x*)|?H?([^:]*):?(%d+):?(%d*):?(%d*):?(%d*):?(%d*):?(%d*):?(%-?%d*):?(%-?%d*):?(%d*)|?h?%[?([^%[%]]*)%]?|?h?|?r?")
			tmp_item_cache[itemName] = tonumber(itemID)
		end
	end
	
	if tmp_item_cache[itemName] == nil then
		for link, data in pairs(ItemAuditor.db.factionrealm.items) do
			local name, itemLink = GetItemInfo (link);
			if name == itemName then
				local _, _, _, _, itemID = string.find(itemLink, "|?c?f?f?(%x*)|?H?([^:]*):?(%d+):?(%d*):?(%d*):?(%d*):?(%d*):?(%d*):?(%-?%d*):?(%-?%d*):?(%d*)|?h?%[?([^%[%]]*)%]?|?h?|?r?")
				tmp_item_cache[itemName] = tonumber(itemID)
			end
		end
		
	end
	
	return tmp_item_cache[itemName]
end

function addon:GetLinkFromName(itemName)
	local itemID = self:GetItemID(itemName)
	local itemLink
	if itemID ~= nil then
		_, itemLink = GetItemInfo(itemID)
	end
	
	return itemLink
end

function addon:SaveItemID(itemName, id)
	item_db[itemName] = tonumber(id)
end

local SubjectPatterns = {
	AHCancelled = gsub(AUCTION_REMOVED_MAIL_SUBJECT, "%%s", ".*"),
	AHExpired = gsub(AUCTION_EXPIRED_MAIL_SUBJECT, "%%s", ".*"),
	AHOutbid = gsub(AUCTION_OUTBID_MAIL_SUBJECT, "%%s", ".*"),
	AHSuccess = gsub(AUCTION_SOLD_MAIL_SUBJECT, "%%s", ".*"),
	AHWon = gsub(AUCTION_WON_MAIL_SUBJECT, "%%s", ".*"),
	CODPayment = gsub(COD_PAYMENT, "%%s", "(.*)"),
}

function addon:GetMailType(msgSubject)
	if msgSubject then
		for k, v in pairs(SubjectPatterns) do
			if msgSubject:find(v) then return k end
		end
	end
	return "NonAHMail"
end

function addon:tcount(tab)
   local n = #tab
   if (n == 0) then
      for _ in pairs(tab) do
         n = n + 1
      end
   end
   return n
end



function addon:GetDebug(info)
	return true
	-- return self.db.char.debug
end

function addon:SetDebug(info, input)
	self:Print("Debugging is now: " .. value)
	self.db.char.debug = input
	local value = "off"
	if input then
		value = "on"
	end
	
end
