local addonName, addonTable = ...; 
local addon = _G[addonName]

local utils = addonTable.utils

function addon:PLAYER_ENTERING_WORLD()
	self:RegisterEvent("MAIL_SHOW")
	self:RegisterEvent("UNIT_SPELLCAST_START")
	self:WatchBags()
end
 
 function addon:MAIL_SHOW()
	self:Debug("MAIL_SHOW")
	self.lastMailScan = self:ScanMail()
	self:UnregisterEvent("MAIL_SHOW")
	self:RegisterEvent("MAIL_CLOSED")
	self:RegisterEvent("MAIL_INBOX_UPDATE")
	self:Debug("MAIL_SHOW complete")
end

function addon:MAIL_CLOSED()
	addon:UnregisterEvent("MAIL_CLOSED")
	self:UnregisterEvent("MAIL_INBOX_UPDATE")
	self:RegisterEvent("MAIL_SHOW")
end

function addon:MAIL_INBOX_UPDATE()
	local newScan = addon:ScanMail()
	local diff
	for mailType, collection in pairs(self.lastMailScan) do
		for item, total in pairs(collection) do

			diff = total - (newScan[mailType][item] or 0)
			if diff ~= 0 then
				self:SaveValue(item, diff)
			end

		end
	end

	self.lastMailScan = newScan
end

function addon:UNIT_SPELLCAST_START(event, target, spell)
	if target == "player" and spell == "Milling" or spell == "Prospecting" or spell == "Disenchanting" then
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
	self:UnregisterEvent("LOOT_CLOSED")
	self:UnregisterEvent("UNIT_SPELLCAST_INTERRUPTED")
	local inventory = self.lastInventory
	self:WatchBags()
	self.lastInventory = inventory 
end

function addon:UNIT_SPELLCAST_INTERRUPTED(event, target, spell)
	if target == "player" and spell == "Milling" or spell == "Prospecting" or spell == "Disenchanting" then
		self:UnregisterEvent("UNIT_SPELLCAST_INTERRUPTED")
		self:UnregisterEvent("LOOT_CLOSED")
		self:WatchBags()
	end
end

function addon:UpdateCurrentInventory()
	self.lastInventory = self:GetCurrentInventory()
end

function addon:UpdateAudit()
	self:Debug("UpdateAudit")
	local currentInventory = self:GetCurrentInventory()
	local diff =  addon:GetInventoryDiff(self.lastInventory, currentInventory)
	-- this is only here for debugging
	self.lastdiff = diff
	
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
	
	if diff.money > 0 and utils:tcount(positive) > 0 and utils:tcount(negative) == 0 then
		self:Debug("loot")
	elseif abs(diff.money) > 0 and utils:tcount(diff.items) == 1 then
		self:Debug("purchase or sale")
		
		for itemName, count in pairs(diff.items) do
			self:SaveValue(itemName, diff.money)
		end
	elseif utils:tcount(diff.items) > 1 then
		
		if utils:tcount(positive) > 0 and utils:tcount(negative) > 0 then
			-- we must have created/converted something
			self:Debug("conversion")
			local totalChange = 0
			for itemName, change in pairs(negative) do
				local _, itemCost, count = self:GetItemCost(itemName, change)
				self:SaveValue(itemName, abs(itemCost * change))
				
				totalChange = totalChange + abs(itemCost * change)
			end
			
			self:Debug("totalChange")
			self:Debug(totalChange)
			
			local valuePerItem = totalChange / positiveCount
			self:Debug(valuePerItem )
			for itemName, change in pairs(positive) do
				self:Debug(itemName)
				self:Debug(0-abs(valuePerItem * change))
				self:SaveValue(itemName, 0-abs(valuePerItem * change))
			end
		end
	end
	
	self.lastInventory = currentInventory
	addon:WatchBags()
end