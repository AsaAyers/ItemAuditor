local ItemAuditor = select(2, ...)
local QuickAuctions= ItemAuditor:NewModule("QuickAuctions")
local Crafting = ItemAuditor:GetModule("Crafting")
local Utils = ItemAuditor:GetModule("Utils")
local AuctionHouse = ItemAuditor:GetModule("AuctionHouse")

local PT = LibStub("LibPeriodicTable-3.1")

--[[
	This is simply for compatibility while I change the QA API. Once
	my changes get merged into the main project, this can go away.
]]
if QAAPI ~= nil and QAAPI.GetGroupThreshold ~= nil and QAAPI.GetGroupConfig == nil then
	function QAAPI:GetGroupConfig(groupName)
		return QAAPI:GetGroupThreshold(groupName),
			QAAPI:GetGroupPostCap(groupName),
			QAAPI:GetGroupPerAuction(groupName)
	end
	
	function QAAPI:SetGroupConfig(groupName, key, value)
		if key == 'threshold' then
			return QAAPI:SetGroupThreshold(groupName, value)
		end
	end
end



function ItemAuditor:IsQACompatible()
	return (QAAPI ~= nil and QAAPI.GetGroupConfig ~= nil)
end

function ItemAuditor:IsQAEnabled()
	return ItemAuditor:IsQACompatible() and ItemAuditor.db.char.use_quick_auctions
end

function ItemAuditor:IsQADisabled()
	return not self:IsQAEnabled()
end

function ItemAuditor:SetQAEnabled(info, value)
	ItemAuditor.db.char.use_quick_auctions = value
end

function ItemAuditor:RefreshQAGroups()
	if not ItemAuditor.IsQAEnabled() then
		return
	end
	for groupName in pairs(QAAPI:GetGroups()) do
		self:UpdateQAGroup(groupName)
	end
end

function ItemAuditor:UpdateQAThreshold(link)
	if not ItemAuditor.IsQAEnabled() then
		return
	end
	_, link= GetItemInfo(link)
	
	self:UpdateQAGroup(QAAPI:GetItemGroup(link))
end

local function calculateQAThreshold(copper)
	if copper == 0 then
		copper = 1
	end
	
	-- add my minimum profit margin
	-- GetAuctionThreshold returns a percent as a whole number. This will convert 25 to 1.25
	copper = copper *  (1+ItemAuditor:GetAuctionThreshold())
	
	-- add AH Cut
	local keep = 1 - ItemAuditor:GetAHCut()
	return copper/keep
end

function ItemAuditor:UpdateQAGroup(groupName)
	if not ItemAuditor.IsQAEnabled() then
		return
	end
	if groupName then
		local threshold = 0
		
		for link in pairs(QAAPI:GetItemsInGroup(groupName)) do
			local _, itemCost= ItemAuditor:GetItemCost(link, 0)
			
			threshold = max(threshold, itemCost)
		end
		
		threshold = calculateQAThreshold(threshold)
		
		QAAPI:SetGroupConfig(groupName, 'threshold', ceil(threshold))
	end
end

local function isProfitable(data)
	if ItemAuditor.IsQAEnabled() then
		local QAGroup = QAAPI:GetItemGroup(data.link)
		if QAGroup ~= nil then
			local currentInvested, _, currentCount = ItemAuditor:GetItemCost(data.link)
			local threshold, postCap, perAuction = QAAPI:GetGroupConfig(QAGroup)
			local stackSize = postCap * perAuction
			
			-- bonus
			stackSize = ceil(stackSize * (1+ItemAuditor.db.char.qa_extra))
			local target = stackSize
			stackSize  = stackSize - currentCount
			
			local newThreshold = ((data.cost*stackSize) + currentInvested) / (currentCount + stackSize)
			newThreshold = calculateQAThreshold(newThreshold)
			
			if  newThreshold < data.price then
				return target
			end
			
			return -1
		end
	end
	return 0
end
Crafting.RegisterCraftingDecider('IA QuickAuctions', isProfitable)


function ItemAuditor:Queue()
	local dest, name = Crafting.GetQueueDestination()
	local function Export(data)
		ItemAuditor:Print(format("Adding %s x%s to %s queue. Profit: %s", 
			data.link, 
			data.queue, 
			name,
			Utils.FormatMoney(data.profit)
		))
		dest(data)
	end
	ItemAuditor:UpdateCraftingTable()
	Crafting.Export(Export)
end

function ItemAuditor:GetReagentCost(link, total)
	local totalCost = 0
	
	if PT:ItemInSet(link,"Tradeskill.Mat.BySource.Vendor") then
		local _, _, _, _, _, _, _, _, _, _, itemVendorPrice = GetItemInfo (link);
		totalCost = itemVendorPrice * total
		total = 0
	end

	
	local investedTotal, investedPerItem, count = ItemAuditor:GetItemCost(link)
	
	if count > 0 then
		if total <= count then
			totalCost = investedPerItem * total
			total = 0
		else
			totalCost = investedTotal
			total = total - count
		end
	end
	
	-- If there is none on the auction house, this uses a large enough number
	-- to prevent us from trying to make the item.
	local ahPrice = (self:GetAuctionPrice(link) or 99990000)
	-- local itemName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType, _, _, _, _, itemVendorPrice = GetItemInfo (link);
	
	return totalCost + (ahPrice * total)
end

function ItemAuditor:GetAuctionPrice(itemLink)
	return AuctionHouse:GetAuctionPrice(itemLink)
end

function ItemAuditor:AddToQueue(skillId,skillIndex, toQueue)
	if Skillet == nil then
		self:Print("Skillet not loaded")
		return
	end
	if Skillet.QueueCommandIterate ~= nil then
		local queueCommand = Skillet:QueueCommandIterate(tonumber(skillId), toQueue)
		Skillet:AddToQueue(queueCommand)
	else
		Skillet.stitch:AddToQueue(skillIndex, toQueue)
	end
end

ItemAuditor.Options.args.qa_options = {
	name = "QA Options",
	desc = "Control how ItemAuditor integrates with QuickAuctions",
	type = 'group',
	disabled = function() return not ItemAuditor:IsQACompatible() end,
	args = {
		toggle_qa = {
			type = "toggle",
			name = "Enable Quick Auctions",
			desc = "This will enable or disable Quick Auctions integration",
			get = "IsQAEnabled",
			set = "SetQAEnabled",
			order = 0,
		},
		auction_threshold = {
			type = "range",
			name = "Auction Threshold",
			desc = "Don't create items that will make less than this amount of profit",
			min = 0.0,
			max = 1.0,
			isPercent = true,
			get = function() return ItemAuditor.db.char.auction_threshold end,
			set = function(info, value)
				ItemAuditor.db.char.auction_threshold = value
				-- ItemAuditor:RefreshQAGroups()
			end,
			disabled = 'IsQADisabled',
			order = 1,
		},
		extra = {
			type = "range",
			name = "Create Extra",
			desc = "This is the amount of an item that should be created above what you sell in one post in QuickAuctions."..
				"If you sell 4 stacks of 5 of an item and your extra is 25%, it will queue enough for you to have 25 of that item.",
			min = 0.0,
			max = 1.0,
			isPercent = true,
			get = function() return ItemAuditor.db.char.qa_extra end,
			set = function(info, value)
				ItemAuditor.db.char.qa_extra = value
			end,
			disabled = 'IsQADisabled',
			order = 1,
		},
		refresh_qa = {
			type = "execute",
			name = "Refresh QA Thresholds",
			desc = "Resets all Quick Auctions thresholds",
			func = "RefreshQAGroups",
			disabled = 'IsQADisabled',
			order = 9,
		},
	}
}

ItemAuditor.Options.args.queue = {
	type = "execute",
	name = "queue",
	desc = "Queue",
	func = "Queue",
	guiHidden = true,
}