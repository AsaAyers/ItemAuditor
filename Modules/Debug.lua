local ItemAuditor = select(2, ...)
local Debug = ItemAuditor:NewModule("Debug")
local ItemAuditor = ItemAuditor

function ItemAuditor:Debug(msg, ...)
	msg = format(msg, ...)
	self:Log(msg, " |cffffff00DEBUG")
end

function ItemAuditor:Log(message, prefix)
	prefix = prefix or ""
	ItemAuditor_DebugFrameTxt:AddMessage(format("%d%s|r: %s", time(), prefix, tostring(message)))
end

function ItemAuditor:GetDebug(info)
       return self.db.profile.messages.debug
end

function ItemAuditor:SetDebug(info, input)
       self.db.profile.messages.debug = input
       local value = "off"
       if input then
               value = "on"
       end
       self:Print("Debugging is now: " .. value)
end

local function DebugEventRegistration()
	ItemAuditor.OriginalRegisterEvent = ItemAuditor.RegisterEvent 
	ItemAuditor.OriginalUnregisterEvent = ItemAuditor.UnregisterEvent

	function ItemAuditor:RegisterEvent(event, callback, arg)
	   self:Debug("RegisterEvent " .. event )
	   if arg ~= nil then
	      ItemAuditor:OriginalRegisterEvent(event, callback, arg)
	   elseif callback ~= nil then
	      ItemAuditor:OriginalRegisterEvent(event, callback)
	   else
	      ItemAuditor:OriginalRegisterEvent(event)
	   end
	end

	function ItemAuditor:UnregisterEvent(event)
		self:Debug("UnregisterEvent " .. event )
		ItemAuditor:OriginalUnregisterEvent (event)
	end

end





-- DebugEventRegistration()