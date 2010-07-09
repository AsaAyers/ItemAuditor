local addonName, addonTable = ...; 
local addon = _G[addonName]

local utils = addonTable.utils


function addon:Debug(msg)
	self:Log(msg, " |cffffff00DEBUG")
end

function addon:Log(message, prefix)
	prefix = prefix or ""
	ItemAuditor_DebugFrameTxt:AddMessage(format("%d%s|r: %s", time(), prefix, tostring(message)))
end

function addon:GetDebug(info)
       return self.db.profile.messages.debug
end

function addon:SetDebug(info, input)
       self.db.profile.messages.debug = input
       local value = "off"
       if input then
               value = "on"
       end
       self:Print("Debugging is now: " .. value)
end

local function DebugEventRegistration()
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

end





-- DebugEventRegistration()