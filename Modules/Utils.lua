local addonName, addonTable = ...; 
local addon = {}

local AceConsole = LibStub("AceConsole-3.0")
AceConsole:Embed(addon)

addonTable.utils = addon

function addon:FormatMoney(money)
    return Altoholic:GetMoneyString(money, WHITE, false)
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
