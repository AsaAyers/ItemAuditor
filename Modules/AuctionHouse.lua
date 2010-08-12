local ItemAuditor = select(2, ...)
local AuctionHouse = ItemAuditor:NewModule("AuctionHouse")

local Utils = ItemAuditor:GetModule("Utils")

local addon_options
local function getAddons()
	-- this will ensure that the addons are only scanned once per session.
	if not addon_options then
		addon_options = {}
		local total = 0
		local lastKey
		if AucAdvanced and AucAdvanced.Version then
			addon_options['auctioneer'] = 'Auctioneer'
			total = total + 1
			lastKey = 'auctioneer'
		end
		if GetAuctionBuyout ~= nil then
			addon_options['other'] = 'Other (GetAuctionBuyout compatibile)'
			total = total + 1
			lastKey = 'other'
		end

		if total == 1 or not ItemAuditor.db.profile.auction_addon then
			ItemAuditor.db.profile.auction_addon = lastKey
		end
	end

	return addon_options
end

local function getSelected()
	-- just making sure ItemAuditor.db.profile.auction_addon is set if there is only one addon
	if not addon_options then
		getAddons()
	end

	return ItemAuditor.db.profile.auction_addon
end

local function setAddon(info, value)
	ItemAuditor.db.profile.auction_addon = value
end

local function getPricingMethods()
	if ItemAuditor.db.profile.auction_addon == 'other' then
		return {
			low = 'Lowest Price',
		}
	else
		return {
			low = 'Lowest Price',
			market = 'Market Price',
		}
	end
end

ItemAuditor.Options.args.auction_house = {
	name = "Auction House",
	type = 'group',
	args = {
		ah_addon = {
			type = "select",
			name = "Addon",
			desc = "",
			values = getAddons,
			get = getSelected,
			set = setAddon,
			order = 0,
		},
		pricingMethod = {
			type = "select",
			name = "Pricing Method",
			desc = "",
			values = getPricingMethods,
			get = function() return ItemAuditor.db.profile.pricing_method end,
			set = function(info, value) ItemAuditor.db.profile.pricing_method = value end,
			order = 1,
		}
		
	},
}

local function clearSnatch()
	ItemAuditor:Print('clearing snatch')
	local Snatch = AucAdvanced.Modules.Util.SearchUI.Searchers.Snatch
	local snatchList = Snatch.Private.snatchList

	for itemLink in pairs(snatchList) do
		local link = select(2, GetItemInfo('item:'..itemLink))
		Snatch.RemoveSnatch(link)
	end
end

function AuctionHouse.Snatch()
	if not AucAdvanced or not AucAdvanced.Version then
		ItemAuditor:Print("The snatch command requires Auctioneer.")
		return
	end
	
	local Snatch = AucAdvanced.Modules.Util.SearchUI.Searchers.Snatch
	if not Snatch.Private.frame then
		ItemAuditor:Print("You must visit the Auction House before you can update Auctioneer's snatch list.")
		return
	end
	clearSnatch()

	local function Export(data)
		for id, reagent in pairs(data.reagents) do
			ItemAuditor:Print("Adding %s for %s", reagent.link, Utils.FormatMoney(reagent.price))
			Snatch.AddSnatch(reagent.link, reagent.price)
		end
	end
	ItemAuditor:UpdateCraftingTable()
	ItemAuditor:GetModule("Crafting").Export(Export)
end

ItemAuditor.Options.args.snatch = {
	type = "execute",
	handler = AuctionHouse,
	name = "snatch",
	desc = "Replace Auctioner's snatch list with all the reagents you need for crafting.",
	func = "Snatch",
	guiHidden = true,
}

function AuctionHouse:GetAuctionPrice(itemLink)
	local link = select(2, GetItemInfo(itemLink))
	assert(link, 'Invalid item link: '..itemLink)
	local addon = getSelected()
	local prices = ItemAuditor.db.profile.pricing_method or 'low'
	if GetAuctionBuyout ~= nil and addon == 'other' then
		return GetAuctionBuyout(link)
	elseif AucAdvanced and AucAdvanced.Version and addon == 'auctioneer' then
		if prices == 'low' then
			local _, _, _, _, _, lowBuy= AucAdvanced.Modules.Util.SimpleAuction.Private.GetItems(link)
			return lowBuy
		else
			return AucAdvanced.API.GetMarketValue(link)
		end
	end
	return nil
end