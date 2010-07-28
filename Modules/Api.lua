local ItemAuditor = select(2, ...)

local Crafting = ItemAuditor:GetModule("Crafting")

IAapi = {}

--[[
	You can register a callback here to influence which items will get crafted and how many.
	The decider function needs to return the number of items the user should have in their
	inventory. If the number owned is less than the highest decided number, that item will
	be queued to be crafted unless any decider vetos the item.
	
	There is no way to unregister your decider but it can be overwritten with a function that simply returns 0.
	
	Please make sure your decider runs as fast as possible, It will be called at least once
	for every tradeskill being considered.
	
	I find the (non) word "Decider" to be amusing, so I used it.
	
	ItemAuditor will veto any item that costs more to create than it will sell for, It will also
	queue one of every item that is profitable. If you simply wanted to increase that to 5 of every
	profitable item you could use this:
	
	IAapi.RegisterCraftingDecider('Five', function() return 5 end)
]]
function IAapi.RegisterCraftingDecider(name, decider)
	Crafting.RegisterCraftingDecider(name, decider)
end


