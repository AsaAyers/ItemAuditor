local addonName, addonTable = ...; 
local addon = _G[addonName]

function addon:OnEnable()
	self:RegisterEvent("MAIL_SHOW")
	self:RegisterEvent("UNIT_SPELLCAST_START")
	addon:UpdateCurrentInventory()
	self:WatchBags()
	
	self:SetEnabled(nil, self.db.profile.addon_enabled)
end

function addon:OnDisable()
	self:UnwatchBags()
	self:UnregisterAllEvents()
	addon:HideAllFrames()
end
 
 function addon:MAIL_SHOW()
	self:Debug("MAIL_SHOW")
	self:UnwatchBags()
	addon:UpdateCurrentInventory()
	self.lastMailScan = self:ScanMail()
	
	self:UnregisterEvent("MAIL_SHOW")
	self:RegisterEvent("MAIL_CLOSED")
	self:RegisterEvent("MAIL_INBOX_UPDATE")
	
	self:GenerateBlankOutbox()
	
	self:RegisterEvent("MAIL_SUCCESS")
end

function addon:GenerateBlankOutbox()
	self.mailOutbox = {
		from = UnitName("player"),
		to = "",
		subject = "",
		link = '',
		count = 0,
		COD = 0,
		key = random(10000),
		sent = 0,
	}
	
	if self.db.factionrealm.outbound_cod[self.mailOutbox.key] ~= nil then
		return self:GenerateBlankOutbox()
	end
end

local Orig_SendMail = SendMail

function SendMail(recipient, subject, body, ...)
	local self = ItemAuditor
	self:GenerateBlankOutbox()

	self:Debug(format("[To: %s] [Subject: %s]", recipient, subject))
	
	self.mailOutbox.COD = GetSendMailCOD()
	
	if self.mailOutbox.COD == 0 then
		self:Debug("Non-COD mail")
		return Orig_SendMail(recipient, subject, body, ...)
	end
	
	subject = format("[IA: %s] %s", self.mailOutbox.key, subject)
	self.mailOutbox.subject = subject
	self.mailOutbox.to = recipient
	
	self.mailOutbox.count  = 0
	local link
	for index = 1, 12 do
		local itemName, _, itemCount = GetSendMailItem(index)
		local newLink = GetSendMailItemLink(index)
		
		if link == nil then
			link = newLink
		end
		
		if newLink ~= nil and self:GetIDFromLink(newLink) ~= self:GetIDFromLink(link) then
			self:Print(self:GetIDFromLink(newLink))
			self:Print(self:GetIDFromLink(link))
			
			self:Print("WARNING: ItemAuditor can't track COD mail with more than one item type.")
			self:GenerateBlankOutbox()
			return
		end
		self.mailOutbox.link = link 
		self.mailOutbox.count = self.mailOutbox.count + itemCount
		
	end
	
	-- self:MAIL_SUCCESS("Mock Success")
	return Orig_SendMail(recipient, subject, body, ...)
end

function addon:MAIL_SUCCESS(event)

	if self.mailOutbox.COD > 0 then
		self:Debug(format("MAIL_SUCCESS %d [To: %s] [Subject: %s] [COD: %s]", self.mailOutbox.key, self.mailOutbox.to, self.mailOutbox.subject, self.mailOutbox.COD))
		
		self.mailOutbox.sent = time()
		self.db.factionrealm.outbound_cod[self.mailOutbox.key] = self.mailOutbox
	end
	
	self.mailOutbox = {
		to = "",
		subject = "",
		items = {},
		COD = 0,
	}
end

function addon:MAIL_CLOSED()
	self:Debug("MAIL_CLOSED")
	addon:UnregisterEvent("MAIL_CLOSED")
	self:MAIL_INBOX_UPDATE()
	self:UnregisterEvent("MAIL_INBOX_UPDATE")
	self:RegisterEvent("MAIL_SHOW")
	self:WatchBags()
end

local storedCountDiff
function addon:MAIL_INBOX_UPDATE()
	self:Debug("MAIL_INBOX_UPDATE")
	local newScan = addon:ScanMail()
	local diff
	
	for mailType, collection in pairs(self.lastMailScan) do
		newScan[mailType] = (newScan[mailType] or {})
		for itemName, data in pairs(collection) do
			newScan[mailType][itemName] = (newScan[mailType][itemName] or {total=0,count=0})
			local totalDiff = data.total - newScan[mailType][itemName].total
			local countDiff = data.count - newScan[mailType][itemName].count
			--[[
				In one update the item will be taken and in the following update the invoice
				will be gone. I need to store the item difference in order ot pass it into
				SaveValue.
			]]
			if countDiff ~= 0 then
				storedCountDiff = countDiff
			end
			
			if totalDiff ~= 0 then
				if mailType == "CODPayment" then
					local trackID
					trackID, itemName= strsplit("|", itemName, 2)
					self.db.factionrealm.outbound_cod[tonumber(trackID)] = nil
					self:Debug("Removing COD Tracker: " .. trackID)
				end
				self:SaveValue(itemName, totalDiff, storedCountDiff)
				storedCountDiff = 0
			end

		end
	end

	self.lastMailScan = newScan
end

function addon:UNIT_SPELLCAST_START(event, target, spell)
	if target == "player" and spell == "Milling" or spell == "Prospecting" or spell == "Disenchanting" then
		self:Debug(event .. " " .. spell)
		self:UnwatchBags()
		self:UpdateCurrentInventory()
		self:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
		self:RegisterEvent("LOOT_CLOSED")
	end
end

--[[ 
	The item should be destroyed before this point, so the last inventory check
	needs to be kept so it can be combined with the up coming loot.
 ]]
function addon:LOOT_CLOSED()
	self:Debug("LOOT_CLOSED")
	self:UnregisterEvent("LOOT_CLOSED")
	self:UnregisterEvent("UNIT_SPELLCAST_INTERRUPTED")
	local inventory = self.lastInventory
	self:WatchBags()
	self.lastInventory = inventory 
end

function addon:UNIT_SPELLCAST_INTERRUPTED(event, target, spell)
	if target == "player" and spell == "Milling" or spell == "Prospecting" or spell == "Disenchanting" then
		self:Debug(event .. " " .. spell)
		self:UnregisterEvent("UNIT_SPELLCAST_INTERRUPTED")
		self:UnregisterEvent("LOOT_CLOSED")
		self:WatchBags()
	end
end

function addon:UpdateCurrentInventory()
	self.lastInventory = self:GetCurrentInventory()
end

function addon:UpdateAudit()
	-- self:Debug("UpdateAudit " .. event)
	local currentInventory = self:GetCurrentInventory()
	local diff =  addon:GetInventoryDiff(self.lastInventory, currentInventory)
	
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
	
	if positiveCount + negativeCount == 0 then
		--[[
			Nothing needs to be done, but this will prevent mistakenly attributing
			the cost of flights to the first item you pick up.
		]]
	elseif diff.money > 0 and self:tcount(positive) > 0 and self:tcount(negative) == 0 then
		self:Debug("loot")
	elseif abs(diff.money) > 0 and self:tcount(diff.items) == 1 then
		self:Debug("purchase or sale")
		
		for link, count in pairs(diff.items) do
			self:SaveValue(link, 0 - diff.money, count)
		end
	elseif self:tcount(diff.items) > 1 and self:tcount(positive) > 0 and self:tcount(negative) > 0 then
		-- we must have created/converted something
		self:Debug("conversion")
		
		local totalChange = 0
		for link, change in pairs(negative) do
			local _, itemCost, count = self:GetItemCost(link, change)
			self:SaveValue(link, itemCost * change, change)
			
			totalChange = totalChange + (itemCost * abs(change))
		end
		
		local valuePerItem = totalChange / positiveCount
		
		for link, change in pairs(positive) do
			self:SaveValue(link, valuePerItem * change, change)
		end
	else
		self:Debug("No match in UpdateAudit.")
	end
	
	self.lastInventory = currentInventory
	addon:WatchBags()
end