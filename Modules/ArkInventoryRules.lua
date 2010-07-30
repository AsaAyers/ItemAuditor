

local ItemAuditor = select(2, ...)
local ArkInventory = ItemAuditor:NewModule("ArkInventory")

function ArkInventory:OnEnable( )
	if ArkInventoryRules then
		ItemAuditor:Print('Registering with ArkInventory')
		ArkInventoryRules.Register(self, "itemauditor", ArkInventory.Execute)
	end
end

function ArkInventory.Execute( ... )

	-- always check for the hyperlink and that it's an actual item, not a spell (pet/mount)
	if not ArkInventoryRules.Item.h or ArkInventoryRules.Item.class ~= "item" then
		return false
	end
	
	local fn = "test" -- your rule name, needs to be set so that error messages are readable
	
	local ac = select( '#', ... )
	
	-- if you need at least 1 argument, this is how you check, if you dont need or care then you can remove this part
	if ac == 0 then
		error( string.format( ArkInventory.Localise["RULE_FAILED_ARGUMENT_NONE_SPECIFIED"], fn ), 0 )
	end
	
	for ax = 1, ac do -- loop through the supplied ... arguments
		
		local arg = select( ax, ... ) -- select the argument were going to work with
		
		-- this code checks item quality, either as text or as a number
		-- your best bet is to check the existing system rules to find one thats close to what you need an modify it to suit your needs
		-- all you have to do is ensure that you return true (matched your criteria) or false (failed to match)
		
		if type( arg ) == "string" then
			local link = ArkInventoryRules.Item.h
			
			local itemName = GetItemInfo(link)
			
			if string.lower( strtrim( arg ) ) == 'profitable' then
				
				local investedTotal, investedPerItem, count = ItemAuditor:GetItemCost(link)
				
				if investedTotal > 0 then
					local ap = ItemAuditor:GetAuctionPrice(link)
					local keep = 1 - ItemAuditor:GetAHCut()
					
					if ap ~= nil then
						
						if ap > ceil(investedPerItem/keep) then
							return true
						end
					end
				end
				return false
			elseif string.lower( strtrim( arg ) ) == 'qa' then
				if ItemAuditor:IsQAEnabled() then
					local groupName = QAAPI:GetItemGroup(link)
					if groupName then
						return true
					end
				end
				return false
			end
			
		else
			
			error( string.format( ArkInventory.Localise["RULE_FAILED_ARGUMENT_IS_INVALID"], fn, ax, string.format( "%s or %s", ArkInventory.Localise["STRING"], ArkInventory.Localise["NUMBER"] ) ), 0 )
			
		end
		
	end
	
	return false
	
end

