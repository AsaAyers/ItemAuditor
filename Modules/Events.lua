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

local attachedItems = {}
local Orig_SendMail = SendMail
local skipCODTracking = false

StaticPopupDialogs["ItemAuditor_Send_COD_without_tracking_number"] = {
	text = "ItemAuditor cannot track COD mail with multiple item types attached. Do you want to send this mail without tracking?",
	button1 = "Yes",
	button2 = "No",
	OnAccept = function()
		skipCODTracking = true
	end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
}

function SendMail(recipient, subject, body, ...)
	local self = ItemAuditor
	self:GenerateBlankOutbox()

	self:Debug(format("[To: %s] [Subject: %s]", recipient, subject))
	
	self.mailOutbox.COD = GetSendMailCOD()
	
	attachedItems = {}
	local totalStacks = 0
	local link
	for index = 1, ATTACHMENTS_MAX_SEND do
		local itemName, _, itemCount = GetSendMailItem(index)
		local newLink = GetSendMailItemLink(index)
		
		if newLink ~= nil then
			newLink = self:GetSafeLink(newLink)
			totalStacks = totalStacks + 1
			attachedItems[newLink] = (attachedItems[newLink] or {stacks = 0, count = 0})
			attachedItems[newLink].stacks = attachedItems[newLink].stacks + 1
			attachedItems[newLink].count = attachedItems[newLink].count + itemCount
			attachedItems[newLink].price = 0 -- This is a placeholder for below.
		end
	end
	local pricePerStack = GetSendMailPrice() / totalStacks
	for link, data in pairs(attachedItems) do
		data.price = pricePerStack * data.stacks
	end
	
	if self.mailOutbox.COD > 0 and skipCODTracking then
		
	elseif self.mailOutbox.COD > 0 then
		if self:tcount(attachedItems) > 1 then
			self:GenerateBlankOutbox()
			local vararg = ...
			StaticPopupDialogs["ItemAuditor_Send_COD_without_tracking_number"].OnAccept = function()
				skipCODTracking = true
				SendMail(recipient, subject, body, vararg)
				skipCODTracking = false
			end
			StaticPopup_Show ("ItemAuditor_Send_COD_without_tracking_number");
			return
		end
		self:Debug("COD mail")
		
		subject = format("[IA: %s] %s", self.mailOutbox.key, subject)
		self.mailOutbox.subject = subject
		self.mailOutbox.to = recipient
		
		-- At this point we know there is only one item
		for link, data in pairs(attachedItems) do
			self.mailOutbox.link = link 
			self.mailOutbox.count = data.count
		end
	else
		self:Debug("Non-COD mail")
	end

	return Orig_SendMail(recipient, subject, body, ...)
end

function addon:MAIL_SUCCESS(event)
	skipCODTracking = false
	for link, data in pairs(attachedItems) do
		self:SaveValue(link, data.price, data.count)
	end
	if self.mailOutbox.COD > 0 then
		self:Debug(format("MAIL_SUCCESS %d [To: %s] [Subject: %s] [COD: %s]", self.mailOutbox.key, self.mailOutbox.to, self.mailOutbox.subject, self.mailOutbox.COD))
		
		self.mailOutbox.sent = time()
		self.db.factionrealm.outbound_cod[self.mailOutbox.key] = self.mailOutbox
	end
	
	
	self:GenerateBlankOutbox()
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

local function distributeValueByAHValue(self, totalValue, targetItems)
	
	local weights = {}
	local totalWeight = 0
	for link, change in pairs(targetItems) do
		--[[ 
			If something has never been seen on the AH, it must not be very valuable.
			I'm using 1c so it doesn't have much weight and I can't get a devided by zero error.
			The only time I know that this is a problem is when crafting a BOP item, and it 
			is always crafted 1 at a time, so a weight of 1 will work.
		]]
		local ap = (addon:GetAuctionPrice(link) or 1)
		totalWeight = totalWeight + ap
		weights[link] = ap
	end
	
	local valuePerPoint = totalValue / totalWeight
	
	for link, change in pairs(targetItems) do
		self:SaveValue(link, weights[link] * valuePerPoint, change)
	end
end

local function distributeValue(self, totalValue, targetItems)
	if true then
		return distributeValueByAHValue(self, totalValue, targetItems)
	else
		local valuePerItem = totalChange / positiveCount
			
		for link, change in pairs(targetItems) do
			self:SaveValue(link, valuePerItem * change, change)
		end
	end
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
		
		distributeValue(self, totalChange, positive)
	else
		self:Debug("No match in UpdateAudit.")
	end
	
	self.lastInventory = currentInventory
	addon:WatchBags()
end