--@debug@
local ItemAuditor = select(2, ...)
local Utils= ItemAuditor:GetModule("Utils")

local function assertTable(tblA, tblB, msg)
   for key, value in pairs(tblA) do
      assert(tblA[key] == tblB[key], msg)
   end
   for key, value in pairs(tblB) do
      assert(tblA[key] == tblB[key], msg)
   end
end

local UnitTests = {};
local backups = {}

local FROSTWEAVE = "\124cffffffff\124Hitem:33470:0:0:0:0:0:0:0:0\124h[Frostweave Cloth]\124h\124r"
local RUNECLOTH = "\124cffffffff\124Hitem:14047:0:0:0:0:0:0:0:0\124h[Runecloth]\124h\124r"
local BOLT_FW = "\124cffffd000\124Henchant:55899\124h[Tailoring: Bolt of Frostweave]\124h\124r"

local fakeBags = {
	[0] = {
		size = 16,
		contents = {
			[0] = nil,
			[1] = {link = FROSTWEAVE, count=10},
		}
	},
	[1] = {
		size = 8,
		contents = {
			[0] = {link = RUNECLOTH, count=20},
		}
	},
}

local fakeMoney = 314159265

local fakeAlts = {
	[33470] = 10, -- Frostweave
}


UnitTests.Utils = {
	mocks = {
	};
	setUp = function()
		return {};
	end;
	tearDown = function()
	end;
	
	testGetItemID = function()
		local id = Utils.GetItemID(FROSTWEAVE)
		assert(id == 33470)
		
		-- This test doesn't work yet.
		-- local id = Utils:GetItemID('invalid link')
		-- assert(id == nil)
	end;
	
	testGetIDFromLink = function()
		-- This should be moved to Utils
		local id = ItemAuditor:GetIDFromLink(FROSTWEAVE)
		assert(id == 33470)
	end;
	
	testGetSafeLink = function()
		-- This should be moved to Utils
		local link = ItemAuditor:GetSafeLink(FROSTWEAVE)
		assert(link == 'item:33470')
	end;
}

UnitTests.Core = {
	mocks = {
		NUM_BAG_SLOTS = 1;
		GetContainerNumSlots = function(bagID)
			return (fakeBags[bagID] and fakeBags[bagID].size) or 0
		end;
		GetContainerItemLink = function(bagID, slotID)
			return fakeBags[bagID] and fakeBags[bagID].contents[slotID] and fakeBags[bagID].contents[slotID].link
		end;
		GetMoney = function()
			return fakeMoney
		end;
		GetItemCount = function(link)
			local total = 0
			local id = tonumber(link) or ItemAuditor:GetIDFromLink(link)
			
			for bagID, bag in pairs(fakeBags) do
				for slotID, contents in pairs(bag.contents) do
					if contents and ItemAuditor:GetIDFromLink(contents.link) == id then
						total = total + contents.count
					end
				end
			end
			return total
		end;
	};
	setUp = function()
		ItemAuditor:Print('Unit Test setUp')
		backups['ItemAuditor.db'] = ItemAuditor.db
		ItemAuditor.db = {
			char = {
				ah = 1,
				use_quick_auctions = false,
				crafting_threshold = 1,
				auction_threshold = 0.15,
				output_chat_frame = nil,
			},
			profile = {
				messages = {
					cost_updates = true,
					queue_skip = false,
				},
				ItemAuditor_enabled = true,
				-- This is for development, so I have no plans to turn it into an option.
				show_debug_frame_on_startup = false,
			},
			factionrealm = {
				items = {},
				item_account = {},
			},
		}
		
		backups['Altoholic.GetItemCount'] = Altoholic.GetItemCount
		Altoholic.GetItemCount = function(self, id) 
			local total = GetItemCount(id)
			total = total + (fakeAlts[id] or 0)
			
			return total
		end
		
		ItemAuditor:UpdateCurrentInventory()
		
		return {};
	end;
	tearDown = function()
		ItemAuditor:Print('Unit Test tearDown')
		ItemAuditor:UpdateCurrentInventory()
		ItemAuditor.db = backups['ItemAuditor.db']
		Altoholic.GetItemCount = backups['Altoholic.GetItemCount']		
	end;
	
	testMockGetContainerItemLink = function()
		assert(GetContainerItemLink(0, 1) == FROSTWEAVE)
	end;
	
	testGetItemCost = function(ia)
		local total, individual, count = ItemAuditor:GetItemCost(FROSTWEAVE)
		assert(total == 0, "total: "..total)
		assert(individual == 0, "individual: "..individual)
		assert(count == 20, "count: "..count)
		
		local total, individual, count = ItemAuditor:GetItemCost(BOLT_FW)
		assert(total == 0, "total: "..total)
		assert(individual == 0, "individual: "..individual)
		assert(count == 0, "count: "..count)
	end;
	
	testGetCurrentInventory = function()
		local inventory = ItemAuditor:GetCurrentInventory()
		assert(inventory.items['item:33470'] == 10)
		assert(inventory.items['item:14047'] == 20)
		assert(inventory.money == fakeMoney)
	end;
	
	testUpdateAuditPurchase = function()
		ItemAuditor:UpdateCurrentInventory()
		local backupSaveValue = ItemAuditor.SaveValue
		
		local price = 200000
		
		ItemAuditor.SaveValue = function(self, link, value, countChange)
			assertEquals({'item:33470', price, 20}, {link, value, countChange})
			return backupSaveValue(self, link, value, countChange)
		end
	
		ItemAuditor:UpdateAudit()
		
		assertEquals({0, 0, 20}, {ItemAuditor:GetItemCost(FROSTWEAVE)})
		
		-- buy 20 for 20g. Because I already had 20 frostweave, this will 
		-- be counted like I spent 40g on 40 frostweave
		fakeBags[1].contents[5] = {link = FROSTWEAVE, count=20}
		fakeMoney = fakeMoney - price
		ItemAuditor:UpdateAudit()
		
		assertEquals({400000, 10000, 40}, {ItemAuditor:GetItemCost(FROSTWEAVE)})
		
		ItemAuditor.SaveValue = function(self, link, value, countChange)
			assertEquals({'item:33470', 0-price, -10}, {link, value, countChange})
			return backupSaveValue(self, link, value, countChange)
		end
		
		-- Sell 10 frostweave for 20g.
		fakeBags[1].contents[5] = {link = FROSTWEAVE, count=10}
		fakeMoney = fakeMoney + price
		ItemAuditor:UpdateAudit()
		
		assertEquals({200000, 6667, 30}, {ItemAuditor:GetItemCost(FROSTWEAVE)})
		
		ItemAuditor.SaveValue = backupSaveValue
	end
}

if WoWUnit then
	WoWUnit:AddTestSuite("ItemAuditor", UnitTests);

	WoWUnitConsole:SlashCommand('ItemAuditor')
end
--@end-debug@