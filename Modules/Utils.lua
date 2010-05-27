local addonName, addonTable = ...; 
local addon = {}

local AceConsole = LibStub("AceConsole-3.0")
AceConsole:Embed(addon)

addonTable.utils = addon

function addon:FormatMoney(money)
	local prefix = ""
	if money < 0 then
		prefix = "-"
	end
	return prefix .. Altoholic:GetMoneyString(abs(money), WHITE, false)
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
