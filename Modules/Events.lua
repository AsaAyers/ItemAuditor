local addonName, addonTable = ...; 
local addon = _G[addonName]

local utils = addonTable.utils

function addon:PLAYER_ENTERING_WORLD()
	self:RegisterEvent("MAIL_SHOW")
	self:RegisterEvent("UNIT_SPELLCAST_START")
	addon:UpdateCurrentInventory()
	self:WatchBags()
	
	-- addon:ConvertItems()
end
 
 function addon:MAIL_SHOW()
	self:Debug("MAIL_SHOW")
	addon:UpdateCurrentInventory()
	self.lastMailScan = self:ScanMail()
	
	self:UnregisterEvent("MAIL_SHOW")
	self:RegisterEvent("MAIL_CLOSED")
	self:RegisterEvent("MAIL_INBOX_UPDATE")
end

function addon:MAIL_CLOSED()
	self:Debug("MAIL_CLOSED")
	addon:UnregisterEvent("MAIL_CLOSED")
	self:MAIL_INBOX_UPDATE()
	self:UnregisterEvent("MAIL_INBOX_UPDATE")
	self:RegisterEvent("MAIL_SHOW")
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
		return
	end
	
	if diff.money > 0 and self:tcount(positive) > 0 and self:tcount(negative) == 0 then
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