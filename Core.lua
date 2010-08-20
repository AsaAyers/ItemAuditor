local ItemAuditor = select(2, ...)
ItemAuditor = LibStub("AceAddon-3.0"):NewAddon(ItemAuditor, "ItemAuditor", "AceEvent-3.0", "AceBucket-3.0")
--@debug@
	_G['ItemAuditor'] = ItemAuditor
--@end-debug@

if not DevTools_Dump then
	function DevTools_Dump()
	end
end

local allMailboxes = {}
local myMailbox = {}

ItemAuditor.Options = {
	handler = ItemAuditor,
	name = "ItemAuditor @project-version@",
	type = 'group',
	args = {
		options = {
			type = "execute",
			name = "options",
			desc = "Show Blizzard's options GUI",
			func = "ShowOptionsGUI",
			guiHidden = true,
		},
		debug = {
			type = "execute",
			name = "debug",
			desc = "Shows the debug frame",
			func = function() ItemAuditor_DebugFrame:Show() end,
			guiHidden = true,
		},
		suspend = {
			type = "toggle",
			name = "suspend",
			desc = "Suspends ItemAuditor",
			get = "IsEnabled",
			set = "SetEnabled",
			guiHidden = true,
		},
	},
}

ItemAuditor.DB_defaults = {
	char = {
		ah = 1,
		use_quick_auctions = false,
		profitable_threshold = 10000,
		auction_threshold = 0.15,
		qa_extra = 0,
		output_chat_frame = nil,
	},
	profile = {
		messages = {
			cost_updates = true,
			queue_skip = false,
		},
		ItemAuditor_enabled = true,
		queue_destination = nil,
		disabled_deciders = {},
		pricing_method = 'low',
	},
	factionrealm = {
		item_account = {},
		items = {},
		outbound_cod = {},
		mailbox = {},
	},
}

function ItemAuditor:OnInitialize()
	self.db = LibStub("AceDB-3.0"):New("ItemAuditorDB", ItemAuditor.DB_defaults, true)

	allMailboxes = self.db.factionrealm.mailbox
	if not allMailboxes[UnitName("player")] then
		allMailboxes[UnitName("player")] = {}
	end
	myMailbox = allMailboxes[UnitName("player")]

	self.optionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("ItemAuditor", "ItemAuditor")
	
	LibStub("AceConfig-3.0"):RegisterOptionsTable("ItemAuditor", ItemAuditor.Options, {"ia"})
	ItemAuditor:RegisterFrame(ItemAuditor_DebugFrame)
	
	LibStub("AceConsole-3.0"):RegisterChatCommand('rl', ReloadUI)

	if self.db.char.crafting_threshold then
		local threshold = self.db.char.crafting_threshold
		if threshold == 1 then
			self.db.char.profitable_threshold = 5000
		elseif threshold == 2 then
			self.db.char.profitable_threshold = 10000
		elseif threshold == 3 then
			self.db.char.profitable_threshold = 50000
		end
	
		self.db.char.crafting_threshold = nil
	end

	--@debug@
		-- ItemAuditor_DebugFrame:Show()
		-- self:CreateFrame('tab_crafting')
		self:RegisterEvent("TRADE_SKILL_SHOW", function()
			ItemAuditor:DisplayCrafting()
		end)
	--@end-debug@
end



local registeredEvents = {}
local originalRegisterEvent = ItemAuditor.RegisterEvent 
function ItemAuditor:RegisterEvent(event, callback, arg)
	registeredEvents[event] = true
	if arg ~= nil then
		return originalRegisterEvent(self, event, callback, arg)
	elseif callback ~= nil then
		return originalRegisterEvent(self, event, callback)
	else
		return originalRegisterEvent(self, event)
	end
end

local originalUnregisterEvent = ItemAuditor.UnregisterEvent
function ItemAuditor:UnregisterEvent(event)
	registeredEvents[event] = nil
        return originalUnregisterEvent(self, event)
end

function ItemAuditor:UnregisterAllEvents()
	for event in pairs(registeredEvents) do
		self:UnregisterEvent(event)
	end
end

local registeredFrames = {}
function ItemAuditor:RegisterFrame(frame)
	tinsert(registeredFrames, frame)
end

function ItemAuditor:HideAllFrames()
	for key, frame in pairs(registeredFrames) do
		if frame then
			frame:Hide()
		end
	end
end

function ItemAuditor:ConvertItems()
	for itemName, value in pairs(self.db.factionrealm.item_account) do
		local itemID = self:GetItemID(itemName)
		if itemID ~= nil then
			self:GetItem('item:' .. itemID)
		end
		if value == 0 then
			self.db.factionrealm.item_account[itemName] = nil
		end
	end
	
	for link, data in pairs(self.db.factionrealm.items) do
		if self:GetItem(link).count == 0 or self:GetItem(link).invested == 0 then
			self:RemoveItem(link)
		end
	end
	
	self:RefreshQAGroups()
end

-- Options doesn't exist when this file is created the first time, so getOptions will 
-- make one call to :GetModule and return the result and replace itself with a 
-- function that simply returns the same object. The permanent solution will probably be
-- to move :Print to a different module.
local function getOptions()
	local Options = ItemAuditor:GetModule("Options")
	getOptions = function() return Options end
	return Options
end

local printPrefix = "|cFFA3CEFFItemAuditor|r: "
function ItemAuditor:Print(message, ...)
	message = format(message, ...)
	getOptions().GetSelectedChatWindow():AddMessage( printPrefix .. tostring(message))
end

local bankOpen = false

function ItemAuditor:BankFrameChanged(event)
	bankOpen = (event == 'BANKFRAME_OPENED')
	ItemAuditor:UpdateCurrentInventory()
end

local function scanBag(bagID, i)
	bagSize=GetContainerNumSlots(bagID)
	for slotID = 0, bagSize do
		local link= GetContainerItemLink(bagID, slotID);
		link = link and ItemAuditor:GetSafeLink(link)

		if link ~= nil and i[link] == nil then
			i[link] = GetItemCount(link, bankOpen);
		end
	end
end

function ItemAuditor:GetCurrentInventory()
	local i = {}
	local bagID
	local slotID
	
	for bagID = 0, NUM_BAG_SLOTS do
		scanBag(bagID, i)
	end
	
	if bankOpen then
		scanBag(BANK_CONTAINER, i)
		for bagID = NUM_BAG_SLOTS+1, NUM_BANKBAGSLOTS do
			scanBag(bagID, i)
		end
	end
	
	return {items = i, money = GetMoney()}
end

function ItemAuditor:GetInventoryDiff(pastInventory, current)
	if current == nil then
		current = self:GetCurrentInventory()
	end
	local diff = {}

	for link, count in pairs(current.items) do
		if pastInventory.items[link] == nil then
			diff[link] = count
			self:Debug("1 diff[" .. link .. "]=" .. diff[link])
		elseif count - pastInventory.items[link] ~= 0 then
			diff[link] = count - pastInventory.items[link]
			self:Debug("2 diff[" .. link .. "]=" .. diff[link])        
		end    
	end

	for link, count in pairs(pastInventory.items) do
		if current.items[link] == nil then
			diff[link] = -count
			self:Debug("3 diff[" .. link .. "]=" .. diff[link])                
		elseif current.items[link] - count ~= 0 then
			diff[link] = current.items[link] - pastInventory.items[link]
			self:Debug("4 diff[" .. link .. "]=" .. diff[link])        
		end
	end

	local moneyDiff = current.money - pastInventory.money
	if abs(moneyDiff) > 0 then
		self:Debug("moneyDiff: " .. moneyDiff)
	end

	return {items = diff, money = moneyDiff}
end

local inboundCOD = {}
local skipMail = {}
function ItemAuditor:ScanMail()
	local results = {}
	local CODPaymentRegex = gsub(COD_PAYMENT, "%%s", "(.*)")
	
	for mailIndex = 1, GetInboxNumItems() or 0 do
		local sender, msgSubject, msgMoney, msgCOD, daysLeft, msgItem, _, _, msgText, _, isGM = select(3, GetInboxHeaderInfo(mailIndex))
		local mailType = self:GetMailType(msgSubject)
		
		local mailSignature = msgSubject .. '-' .. msgMoney .. '-' .. msgCOD .. '-' .. daysLeft
		
		results[mailType] = (results[mailType] or {})
		
		if skipMail[mailSignature] ~= nil then
			-- do nothing
		elseif mailType == "NonAHMail" and msgCOD > 0 then
			mailType = 'COD'
			results[mailType] = (results[mailType] or {})
			
			local itemTypes = {}
			for itemIndex = 1, ATTACHMENTS_MAX_RECEIVE do
				local itemName, _, count, _, _= GetInboxItem(mailIndex, itemIndex)
				if itemName ~= nil then
					itemTypes[itemName] = (itemTypes[itemName] or 0) + count
				end
			end
			
			if self:tcount(itemTypes) == 1 then
				for itemName, count in pairs(itemTypes) do
					results[mailType][itemName] = (results[mailType][itemName] or {total=0,count=0})
					results[mailType][itemName].total = results[mailType][itemName].total + msgCOD
					
					if inboundCOD[mailSignature] == nil then
						results[mailType][itemName].count = results[mailType][itemName].count + count
						inboundCOD[mailSignature] = (inboundCOD[mailSignature] or 0) + count
					else
						results[mailType][itemName].count = inboundCOD[mailSignature]
					end
					
					
				end
			else
				self:Debug("Don't know what to do with more than one item type on COD mail.")
			end
		elseif mailType == "CODPayment" then	
			-- /dump ItemAuditor.db.factionrealm.outbound_cod
			self:Debug(msgSubject)
			self:Debug(CODPaymentRegex)
			local outboundSubject = select(3, msgSubject:find(CODPaymentRegex))
			local trackID
			if outboundSubject ~= nil then
				self:Debug(outboundSubject)
				trackID = select(3, outboundSubject:find('[[]IA: (%d*)[]]'))
				
				if trackID ~= nil then
					trackID = tonumber(trackID)
					self:Debug('COD ID: %s', trackID)
					local cod = self.db.factionrealm.outbound_cod[trackID]
					if cod == nil then
						skipMail[mailSignature] = true
						self:Print("WARNING: {%s} has an invalid ItemAuditor tracking number.", msgSubject)
					else
						itemName = trackID .. "|" .. cod['link']
						
						
						results[mailType][itemName] = (results[mailType][itemName] or {total=0,count=0})
						results[mailType][itemName].total = results[mailType][itemName].total - msgMoney
						results[mailType][itemName].count = results[mailType][itemName].count - cod.count
					end
				end
			end
			
			if trackID == nil then
				skipMail[mailSignature] = true
				self:Print("WARNING: {%s} is a COD payment but doesn't have an ItemAuditor tracking number.", msgSubject)
			end
			
		elseif mailType == "AHSuccess" then
			local invoiceType, itemName, playerName, bid, buyout, deposit, consignment = GetInboxInvoiceInfo(mailIndex);
			results[mailType][itemName] = (results[mailType][itemName] or {total=0,count=0})
			results[mailType][itemName].total = results[mailType][itemName].total - deposit - buyout + consignment
			

		elseif mailType == "AHWon" then
			local invoiceType, itemName, playerName, bid, buyout, deposit, consignment = GetInboxInvoiceInfo(mailIndex);
			results[mailType][itemName] = (results[mailType][itemName] or {total=0,count=0})
			results[mailType][itemName].total = results[mailType][itemName].total + bid
			
			local count = select(3, GetInboxItem(mailIndex,1))
			results[mailType][itemName].count = results[mailType][itemName].count + count
		elseif mailType == "AHExpired" or mailType == "AHCancelled" or mailType == "AHOutbid" then
			-- These should be handled when you pay the deposit at the AH
		else
			-- self:Debug("Unhandled mail type: " .. mailType)
			-- self:Debug(msgSubject)
		end

	end

	wipe(myMailbox)
	for mailType, collection in pairs(results) do
		myMailbox[mailType] = {}
		for item, data in pairs(collection) do
			myMailbox[mailType][item] = {
				total = data.total,
				count = data.count,
			}
			-- self:Print(format("|cFF00FF00MailScan|r: %s - %s - %s x %s", mailType, item, data.total, data.count))
		end
	end
	return results   
end

function ItemAuditor:GetItemCount(searchID)
	local count = Altoholic:GetItemCount(searchID)
	local itemName = GetItemInfo(searchID)
	for character, mailbox in pairs(allMailboxes) do
		for type, items in pairs(mailbox) do
			if type == 'AHWon' or type == 'COD' then
				for name, data in pairs(items) do
					if name == itemName then
						count = count - data.count

					end
				end
			end
		end
	end
	return count
end

function ItemAuditor:GetItem(link, viewOnly)
	if viewOnly == nil then
		viewOnly = false
	end
	
	local itemName = nil
	if self:GetSafeLink(link) == nil then
		itemName = link
	else
		link = self:GetSafeLink(link)
		itemName = GetItemInfo(link)
	end
	
	
	if self.db.factionrealm.item_account[itemName] ~= nil then
		self.db.factionrealm.items[link] = {
			count = ItemAuditor:GetItemCount(self:GetIDFromLink(link)),
			invested = abs(self.db.factionrealm.item_account[itemName] or 0),
		}
		self.db.factionrealm.item_account[itemName] = nil
	end
	
	if viewOnly == false and self.db.factionrealm.items[link] == nil then
		
		self.db.factionrealm.items[link] = {
			count =  ItemAuditor:GetItemCount(self:GetIDFromLink(link)),
			invested = abs(self.db.factionrealm.item_account[itemName] or 0),
		}
		
	end
	
	if self.db.factionrealm.items[link] ~= nil then
		self.db.factionrealm.items[link].count =  ItemAuditor:GetItemCount(self:GetIDFromLink(link))
		
		if self.db.factionrealm.items[link].invested == nil then
			self.db.factionrealm.items[link].invested = 0
		end
	end
	
	if viewOnly == true and self.db.factionrealm.items[link] == nil then
		return {count = 0, invested = 0}
	elseif viewOnly == true then
		
		return {count = self.db.factionrealm.items[link].count, invested = self.db.factionrealm.items[link].invested}
	end
	
	
	
	return self.db.factionrealm.items[link]
end

function ItemAuditor:RemoveItem(link)
	self.db.factionrealm.item_account[link] = nil
	link = self:GetSafeLink(link)
	if link ~= nil then
		local item = ItemAuditor:GetItem(link)
		item.invested = 0
	else
		self:Debug('Failed to convert link' .. tostring(link))
	end
end

function ItemAuditor:SaveValue(link, value, countChange)
	self:Debug("SaveValue(%s, %s, %s)", tostring(link), value, (countChange or 'default'))
	countChange = countChange or 0
	local item = nil
	local realLink = self:GetSafeLink(link)
	local itemName = nil
	if realLink == nil then
		itemName = link
		self:Debug('SaveValue: GetSafeLink failed, falling back to storing by name: ' .. tostring(itemName))
		self.db.factionrealm.item_account[itemName] = (self.db.factionrealm.item_account[itemName] or 0) + value
		item = {invested = self.db.factionrealm.item_account[itemName], count = 1}
	else
		
		item = self:GetItem(realLink)
		item.invested = item.invested + value
		itemName = GetItemInfo(realLink)
	end
	
	if value > 0 and countChange > 0 and item.invested == value and item.count ~= countChange then
		local costPerItem = value / countChange
		value = costPerItem * item.count
		item.invested = value
		self:Print("You already owned %s %s with an unknown price, so they have also been updated to %s each", (item.count - countChange), itemName, self:FormatMoney(costPerItem))
	end
	
	if abs(value) > 0 then
		if  item.invested < 0 then
			if self.db.profile.messages.cost_updates then
				self:Print(format("Updated price of %s from %s to %s. |cFF00FF00You just made a profit of %s.", itemName, self:FormatMoney(item.invested - value), self:FormatMoney(0), self:FormatMoney(abs(item.invested))))
			end
			self:RemoveItem(link)
		-- This doesn't work when you mail the only copy of an item you have to another character.
		--[[
		elseif item.count == 0 and realLink and ItemAuditor:GetItemCount(self:GetIDFromLink(realLink)) then 
			self:Print("You ran out of " .. itemName .. " and never recovered " .. self:FormatMoney(item.invested))
			self:RemoveItem(link)
		]]
		else
			if self.db.profile.messages.cost_updates then
				self:Print(format("Updated price of %s from %s to %s. (total change:%s)", itemName, self:FormatMoney(item.invested - value), self:FormatMoney(item.invested), self:FormatMoney(value)))
			end
		end
	end
	
	if realLink ~= nil then
		ItemAuditor:UpdateQAThreshold(realLink)
	end
	UpdateInvestedData()
end


function ItemAuditor:WatchBags()
	if self.watch_handle == nil then
		ItemAuditor:UpdateCurrentInventory()
		self.watch_handle = self:RegisterBucketEvent({"BAG_UPDATE", "PLAYER_MONEY"}, 0.3, "UpdateAudit")
	end
end

function ItemAuditor:UnwatchBags()
	if self.watch_handle ~= nil then
		self:UnregisterBucket(self.watch_handle)
		self.watch_handle = nil
	end
end


function ItemAuditor:GetSafeLink(link)
	local newLink = nil

	if link and link == string.match(link, '.-:[-0-9]+[:0-9]*') then
		newLink = link
	elseif link then
		newLink = link and string.match(link, "|H(.-):([-0-9]+):([0-9]+)|h")
	end
	if newLink == nil then
		local itemID = self:GetItemID(link)
		if itemID ~= nil then
			_, newLink = GetItemInfo(itemID)
			return self:GetSafeLink(newLink)
		end
	end
	return newLink and string.gsub(newLink, ":0:0:0:0:0:0", "")
end

function ItemAuditor:GetIDFromLink(link)
	local _, _, _, _, Id = string.find(link, "|?c?f?f?(%x*)|?H?([^:]*):?(%d+):?(%d*):?(%d*):?(%d*):?(%d*):?(%d*):?(%-?%d*):?(%-?%d*):?(%d*)|?h?%[?([^%[%]]*)%]?|?h?|?r?")
	return tonumber(Id)
end

function ItemAuditor:GetItemCost(link, countModifier)
	local item = self:GetItem(link, true)

	if item.invested > 0 then
		local count = item.count
		
		if countModifier ~= nil then
			count = count - countModifier
		end
		if count > 0 then 
			return ceil(item.invested), ceil(item.invested/count), count
		end
		
	end
	return 0, 0, ItemAuditor:GetItemCount(ItemAuditor:GetIDFromLink(link))
end
