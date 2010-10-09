local ItemAuditor = select(2, ...)
local Events = ItemAuditor:NewModule("Events", "AceEvent-3.0")

local Utils = ItemAuditor:GetModule("Utils")

function ItemAuditor:OnEnable()
	self:RegisterEvent("MAIL_SHOW")
	self:RegisterEvent("UNIT_SPELLCAST_START")
	
	self:RegisterEvent("BANKFRAME_OPENED", 'BankFrameChanged')
	self:RegisterEvent("BANKFRAME_CLOSED", 'BankFrameChanged')

	ItemAuditor:UpdateCurrentInventory()
	self:WatchBags()
	
	self:SetEnabled(nil, self.db.profile.ItemAuditor_enabled)
end

function ItemAuditor:OnDisable()
	self:UnwatchBags()
	self:UnregisterAllEvents()
	ItemAuditor:HideAllFrames()
end
 
 function ItemAuditor:MAIL_SHOW()
	self:Debug("MAIL_SHOW")
	self.mailOpen = true
	ItemAuditor:UpdateCurrentInventory()
	self.lastMailScan = self:ScanMail()
	
	self:UnregisterEvent("MAIL_SHOW")
	self:RegisterEvent("MAIL_CLOSED")
	self:RegisterEvent("MAIL_INBOX_UPDATE")
	
	self:GenerateBlankOutbox()
	
	self:RegisterEvent("MAIL_SUCCESS")
end

function ItemAuditor:GenerateBlankOutbox()
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
local skipCODCheck = false

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

StaticPopupDialogs["ItemAuditor_Insufficient_COD"] = {
	text = "The COD on this mail is less than the value of items attached. Are you sure you want to send this?|nTotal value (including postage): %s",
	button1 = "Yes",
	button2 = "No",
	OnAccept = function()
		skipCODCheck = true
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
	
	wipe(attachedItems)
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
			attachedItems[newLink].costEach = select(2, ItemAuditor:GetItemCost(newLink))
		end
	end
	local attachedValue = 0
	for link, data in pairs(attachedItems) do
		data.price = 30 * data.stacks
		attachedValue = attachedValue + data.price + (data.costEach * data.count)
	end

	local destinationType = 'unknown'
	local realm = GetRealmName()
	for account in pairs(DataStore:GetAccounts()) do
		for character in pairs(DataStore:GetCharacters(realm, account)) do
			if strlower(recipient) == strlower(character) then
				destinationType = (account == 'Default') and 'same_account' or 'owned_account'
				destinationType = 'owned_account'
				break
			end
		end
	end
	self.mailOutbox.destinationType = destinationType
	if destinationType == 'unknown' and attachedValue > self.mailOutbox.COD and not skipCODCheck and ItemAuditor.db.char.cod_warnings then
		self:GenerateBlankOutbox()
		skipCODCheck = false;
		local vararg = ...
		StaticPopupDialogs["ItemAuditor_Insufficient_COD"].OnAccept = function()
			skipCODCheck = true
			SendMail(recipient, subject, body, vararg)
			skipCODCheck = false
		end
		StaticPopup_Show ("ItemAuditor_Insufficient_COD", Utils.FormatMoney(attachedValue));
		return
	elseif destinationType == 'owned_account' then
		-- If we are mailing to an alt on a different account, a uniqueue tracking number
		-- is generated and all of the needed data is attached to the message.
		-- The tracking number is only used to make sure the other character doesn't count the
		-- mail more than once.
		local key = time()..":"..random(10000)
		self.mailOutbox.attachedItems = attachedItems
		body = body .. ItemAuditor.TRACKING_DATA_DIVIDER .. ItemAuditor:Serialize(key, attachedItems)
	elseif self.mailOutbox.COD > 0 and skipCODTracking then
		
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

function ItemAuditor:MAIL_SUCCESS(event)
	skipCODTracking = false
	skipCODCheck = false

	for link, data in pairs(attachedItems) do
		-- When mailing to an alt on a different account, we still
		-- should add the price of postage, but need to subtract the
		-- cost of the items. This will simulate CODing the mail and
		-- getting the money back, except that postage is paid by the
		-- sender
		if self.mailOutbox.destinationType == 'owned_account' then
			data.price = data.price - (data.costEach * data.count)
		end
		self:SaveValue(link, data.price, data.count)
	end
	if self.mailOutbox.COD > 0 then
		self:Debug(format("MAIL_SUCCESS %d [To: %s] [Subject: %s] [COD: %s]", self.mailOutbox.key, self.mailOutbox.to, self.mailOutbox.subject, self.mailOutbox.COD))
		
		self.mailOutbox.sent = time()
		self.db.factionrealm.outbound_cod[self.mailOutbox.key] = self.mailOutbox
	end

	wipe(attachedItems)
	self:GenerateBlankOutbox()
end

function ItemAuditor:MAIL_CLOSED()
	self:Debug("MAIL_CLOSED")
	ItemAuditor:UnregisterEvent("MAIL_CLOSED")
	self:MAIL_INBOX_UPDATE()
	self:UnregisterEvent("MAIL_INBOX_UPDATE")
	self:RegisterEvent("MAIL_SHOW")
	self.mailOpen = nil
end

local function CanMailBeDeleted(mailIndex)
	local msgMoney, _, _, msgItem = select(5, GetInboxHeaderInfo(mailIndex))
	local body = GetInboxText(mailIndex)
	if msgMoney == 0 and msgItem == nil and body and body:find(ItemAuditor.TRACKING_DATA_DIVIDER) then
		local serialized = body:gsub('.*'..ItemAuditor.TRACKING_DATA_DIVIDER, '')
		local body = body:gsub(ItemAuditor.TRACKING_DATA_DIVIDER..'.*', '')
		local success, trackingID, data = ItemAuditor:Deserialize(serialized)
		if success and body == '' then
			return true
		end
	end
	return false
end

local Postal_L
local function blockMailOperations()
	if MailAddonBusy == 'ItemAuditor' then
		return false
	end
	if Postal_L == nil then
		local locale = LibStub("AceLocale-3.0", true)
		Postal_L = locale and locale:GetLocale("Postal", true)
	end
	return MailAddonBusy or PostalOpenAllButton and Postal_L and PostalOpenAllButton:GetText() == Postal_L["In Progress"]
end

local storedCountDiff
function ItemAuditor:MAIL_INBOX_UPDATE()
	self:Debug("MAIL_INBOX_UPDATE")
	self.deleteQueue = nil
	local newScan = self:ScanMail()
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

	if self.deleteQueue and not self.deleteScheduled then
		-- For some reason DeleteInboxItem will not trigger a MAIL_INBOX_UPDATE
		-- if it is called from here, so I have to use a timer to get it
		-- to run outside of this function.

		-- If the mailbox is full of items to be deleted, this will speed up because
		-- postal shouldn't be running at this point. Keeping at 0.1 breaks postal.
		local delay = (GetInboxNumItems() > #(self.deleteQueue)) and 1 or 0.1
		self:ScheduleTimer("ProcessDeleteQueue", delay)
		self.deleteScheduled = true
	elseif MailAddonBusy == 'ItemAuditor' then
		MailAddonBusy = nil
	end
end

function ItemAuditor:ProcessDeleteQueue()
	if blockMailOperations() then
		self:ScheduleTimer("ProcessDeleteQueue", 1)
		return
	end
	self.deleteScheduled = false
	if self.deleteQueue then
		MailAddonBusy = 'ItemAuditor'
		while  #(self.deleteQueue) > 0 do
			local mailIndex = table.remove(self.deleteQueue)
			if CanMailBeDeleted(mailIndex) then
				DeleteInboxItem(mailIndex)
				-- This returns after the first item because you can't delete
				-- all mail at once and this is in a loop so that if for some
				-- reason CanMailBeDeleted returns false, we can delete the next
				-- mail in the queue instead.
				return
			end
		end
	else
		MailAddonBusy = nil
	end
end

function ItemAuditor:UNIT_SPELLCAST_START(event, target, spell)
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
function ItemAuditor:LOOT_CLOSED()
	self:Debug("LOOT_CLOSED")
	self:UnregisterEvent("LOOT_CLOSED")
	self:UnregisterEvent("UNIT_SPELLCAST_INTERRUPTED")
	local inventory = self.lastInventory
	self:WatchBags()
	self.lastInventory = inventory 
end

function ItemAuditor:UNIT_SPELLCAST_INTERRUPTED(event, target, spell)
	if target == "player" and spell == "Milling" or spell == "Prospecting" or spell == "Disenchanting" then
		self:Debug(event .. " " .. spell)
		self:UnregisterEvent("UNIT_SPELLCAST_INTERRUPTED")
		self:UnregisterEvent("LOOT_CLOSED")
		self:WatchBags()
	end
end

function ItemAuditor:UpdateCurrentInventory()
	self.lastInventory = self:GetCurrentInventory()
end

local function distributeValue(self, totalValue, targetItems)
	
	local weights = {}
	local totalWeight = 0
	for itemID, change in pairs(targetItems) do
		--[[ 
			If something has never been seen on the AH, it must not be very valuable.
			I'm using 1c so it doesn't have much weight and I can't get a devided by zero error.
			The only time I know that this is a problem is when crafting a BOP item, and it 
			is always crafted 1 at a time, so a weight of 1 will work.
		]]
		local ap = (ItemAuditor:GetAuctionPrice(itemID) or 1) * change
		totalWeight = totalWeight + ap
		weights[itemID] = ap
	end
	
	for itemID, change in pairs(targetItems) do
		local value = totalValue * (weights[itemID]/totalWeight)
		self:SaveValue(itemID, value, change)
	end
end

function ItemAuditor:UpdateAudit()
	-- self:Debug("UpdateAudit " .. event)
	local currentInventory = self:GetCurrentInventory()
	local diff =  ItemAuditor:GetInventoryDiff(self.lastInventory, currentInventory)
	
	local positive, negative = {}, {}
	local positiveCount, negativeCount = 0, 0
	for itemID, count in pairs(diff.items) do
		if count > 0 then
			positive[itemID] = count
			positiveCount = positiveCount + count
		elseif count < 0 then
			negative[itemID] = count
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
	elseif abs(diff.money) > 0 and self:tcount(diff.items) == 1 and not self.mailOpen then
		self:Debug("purchase or sale")
		
		for itemID, count in pairs(diff.items) do
			self:SaveValue(itemID, 0 - diff.money, itemID)
		end
	elseif self:tcount(diff.items) > 1 and self:tcount(positive) > 0 and self:tcount(negative) > 0 then
		-- we must have created/converted something
		self:Debug("conversion")
		
		local totalChange = 0
		for itemID, change in pairs(negative) do
			local _, itemCost, count = self:GetItemCost(itemID, change)
			self:SaveValue(itemID, itemCost * change, change)
			
			totalChange = totalChange + (itemCost * abs(change))
		end
		totalChange = totalChange - diff.money
		
		distributeValue(self, totalChange, positive)
	else
		self:Debug("No match in UpdateAudit.")
	end
	
	self.lastInventory = currentInventory
	ItemAuditor:WatchBags()
end