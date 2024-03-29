local ItemAuditor = select(2, ...)
local Utils = ItemAuditor:NewModule("Utils")

function Utils.FormatMoney(copper, color, textOnly)
	color = color or "|cFFFFFFFF"
	local prefix = ""
	copper = copper or 0
	if copper < 0 then
		prefix = "-"
		copper = abs(copper)
	end
	
	local copperTexture = COPPER_AMOUNT_TEXTURE
	local silverTexture = SILVER_AMOUNT_TEXTURE
	local goldTexture = GOLD_AMOUNT_TEXTURE
	if textOnly then
		copperTexture = '%dc'
		silverTexture = '%ds'
		goldTexture = '%dg'
	end

	local gold = floor( copper / 10000 );
	copper = mod(copper, 10000)
	local silver = floor( copper / 100 );
	copper = mod(copper, 100)
	
	
	copper = color .. format(copperTexture, copper, 13, 13)
	if silver > 0 or gold > 0 then
		silver = color.. format(silverTexture, silver, 13, 13) .. ' '
	else
		silver = ""
	end
	if gold > 0 then
		gold = color.. format(goldTexture, gold, 13, 13) .. ' '
	else
		gold = ""
	end
	
	return format("%s%s%s%s", prefix, gold, silver, copper)
end

-- Copied from QuickAuctions
function Utils.validateMoney(value)
	local gold = tonumber(string.match(value, "([0-9]+)|c([0-9a-fA-F]+)g|r") or string.match(value, "([0-9]+)g"))
	local silver = tonumber(string.match(value, "([0-9]+)|c([0-9a-fA-F]+)s|r") or string.match(value, "([0-9]+)s"))
	local copper = tonumber(string.match(value, "([0-9]+)|c([0-9a-fA-F]+)c|r") or string.match(value, "([0-9]+)c"))
	
	if( not gold and not silver and not copper ) then
		return false;
		-- return L["Invalid monney format entered, should be \"#g#s#c\", \"25g4s50c\" is 25 gold, 4 silver, 50 copper."]
	end
	
	return true
end

-- Copied from QuickAuctions
function Utils.parseMoney(value)
	local gold = tonumber(string.match(value, "([0-9]+)|c([0-9a-fA-F]+)g|r") or string.match(value, "([0-9]+)g"))
	local silver = tonumber(string.match(value, "([0-9]+)|c([0-9a-fA-F]+)s|r") or string.match(value, "([0-9]+)s"))
	local copper = tonumber(string.match(value, "([0-9]+)|c([0-9a-fA-F]+)c|r") or string.match(value, "([0-9]+)c"))
		
	-- Convert it all into copper
	return (copper or 0) + ((gold or 0) * COPPER_PER_GOLD) + ((silver or 0) * COPPER_PER_SILVER)
end


local tmp_item_cache = {}
function Utils.GetItemID(item)
	if not item then
		return nil
	end

	if tmp_item_cache[item] == nil then
		-- Whether item is a link or a name, both should return the full link
		local _, itemLink = GetItemInfo (item);
		if itemLink ~= nil then
			local _, _, _, _, itemID = string.find(itemLink, "|?c?f?f?(%x*)|?H?([^:]*):?(%d+):?(%d*):?(%d*):?(%d*):?(%d*):?(%d*):?(%-?%d*):?(%-?%d*):?(%d*)|?h?%[?([^%[%]]*)%]?|?h?|?r?")
			tmp_item_cache[item] = tonumber(itemID)
		else
			local _, _, _, _, itemID = string.find(item, "|?c?f?f?(%x*)|?H?([^:]*):?(%d+):?(%d*):?(%d*):?(%d*):?(%d*):?(%d*):?(%-?%d*):?(%-?%d*):?(%d*)|?h?%[?([^%[%]]*)%]?|?h?|?r?")
			tmp_item_cache[item] = tonumber(itemID)
		end
	end
	
	if tmp_item_cache[item] == nil then
		for link, data in pairs(ItemAuditor.db.factionrealm.items) do
			local name, itemLink = GetItemInfo (link);
			if name == item then
				local _, _, _, _, itemID = string.find(itemLink, "|?c?f?f?(%x*)|?H?([^:]*):?(%d+):?(%d*):?(%d*):?(%d*):?(%d*):?(%d*):?(%-?%d*):?(%-?%d*):?(%d*)|?h?%[?([^%[%]]*)%]?|?h?|?r?")
				tmp_item_cache[item] = tonumber(itemID)
			end
		end
	end
	return tmp_item_cache[item]
end


function ItemAuditor:GetLinkFromName(itemName)
	local itemID = self:GetItemID(itemName)
	local itemLink
	if itemID ~= nil then
		_, itemLink = GetItemInfo(itemID)
	end
	
	return itemLink
end

local SubjectPatterns = {
	AHCancelled = gsub(AUCTION_REMOVED_MAIL_SUBJECT, "%%s", ".*"),
	AHExpired = gsub(AUCTION_EXPIRED_MAIL_SUBJECT, "%%s", ".*"),
	AHOutbid = gsub(AUCTION_OUTBID_MAIL_SUBJECT, "%%s", ".*"),
	AHSuccess = gsub(AUCTION_SOLD_MAIL_SUBJECT, "%%s", ".*"),
	AHWon = gsub(AUCTION_WON_MAIL_SUBJECT, "%%s", ".*"),
	CODPayment = gsub(COD_PAYMENT, "%%s", "(.*)"),
}

function Utils.GetMailType(msgSubject)
	if msgSubject then
		for k, v in pairs(SubjectPatterns) do
			if msgSubject:find(v) then return k end
		end
	end
	return "NonAHMail"
end

function ItemAuditor:tcount(tab)
   local n = #tab
   if (n == 0) then
      for _ in pairs(tab) do
         n = n + 1
      end
   end
   return n
end

function ItemAuditor:GetDebug(info)
	return self.db.char.debug
end

function ItemAuditor:SetDebug(info, input)
	
	ItemAuditor.db.char.debug = input
	local value = "off"
	if input then
		value = "on"
	end
	self:Print("Debugging is now: " .. value)
end

-- TODO: Once everything points to the correct Utils method, all of these should be removed

function ItemAuditor:FormatMoney(copper, color, textOnly)
	return Utils.FormatMoney(copper, color, textOnly)
end


function ItemAuditor:GetMailType(msgSubject)
	return Utils.GetMailType(msgSubject)
end

function ItemAuditor:GetItemID(itemName)
	return Utils.GetItemID(itemName)
end

ItemAuditor.parseMoney = Utils.parseMoney
ItemAuditor.validateMoney = Utils.validateMoney