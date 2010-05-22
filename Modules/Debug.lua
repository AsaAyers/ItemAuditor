local addonName, addonTable = ...; 
local addon = _G[addonName]

local utils = addonTable.utils


function addon:Debug(msg)
	if self.db.char.debug then
		self:Print(msg)
	end
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





DebugEventRegistration()