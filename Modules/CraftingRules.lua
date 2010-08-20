local ItemAuditor = select(2, ...)
local CraftingRules = ItemAuditor:NewModule("CraftingRules")
print('CraftingRules')
local Crafting = ItemAuditor:GetModule("Crafting")
local Utils = ItemAuditor:GetModule("Utils")

ItemAuditor.DB_defaults.char.rules_default_veto = false
ItemAuditor.DB_defaults.char.rules = {
	
}

local print = function(message, ...)
	ItemAuditor:Print(message, ...)
end

local Options = {
	header_result = {
		type = 'header',
		name = 'Default Result',
		order = 9,
	},
	veto = {
		type = "toggle",
		name = "Veto unknown",
		desc = "Vetos any items you don't have a rule for",
		get = function() return ItemAuditor.db.char.rules_default_veto end,
		set = function(info, value) ItemAuditor.db.char.rules_default_veto = value end,
		order = 10,
	},
}

local function generateRuleOptions(name)
	local opt = {
		name = name,
		type = 'group',
		args = {
			items = {
				type = "input",
				name = "Item(s)",
				desc = "Items this rule should match. Separate items with commas.",
				multiline = true,
				get = function()
					return ItemAuditor.db.char.rules[name].search
				end,
				set = function(info, value)
					ItemAuditor.db.char.rules[name].search = value
				end,
				order = 0,
			},
			header_result = {
				type = 'header',
				name = 'Rule',
				order = 9,
			},
			veto = {
				type = "toggle",
				name = "Veto",
				desc = "Veto any item that matches this rule",
				get = function()
					return (ItemAuditor.db.char.rules[name].target == -1)
				end,
				set = function(info, value)
					if value then
						value = -1
					else
						value = 0
					end
					ItemAuditor.db.char.rules[name].target = value
				end,
				order = 10,
			},
			auction_threshold = {
				type = "range",
				name = "Number to craft",
				desc = "",
				min = 0,
				max = 1000,
				softMax = 50,
				step = 1,
				get = function() return max(0, ItemAuditor.db.char.rules[name].target) end,
				set = function(info, value)
					ItemAuditor.db.char.rules[name].target = value
				end,
				disabled = function() return ItemAuditor.db.char.rules[name].target == -1 end,
				order = 11,
			},
			header_delete = {
				type = 'header',
				name = '',
				order = 19,
			},
			header_delete = {
				type = 'execute',
				name = 'Delete Rule',
				func = function()
					ItemAuditor.db.char.rules[name] = nil
					Options['rule_'..name] = nil
				end,
				order = 20,
			},
		},
	}
	

	return opt
end

--[[
	This had to be separated because set refers to Options and generateRuleOptions
]]
Options.new = {
	type = "input",
	name = "Create New Rule",
	desc = "",
	get = function()
		return ""
	end,
	set = function(info, name)
		ItemAuditor.db.char.rules[name] = {
			search = name,
			target = 0,
		}
		Options['rule_'..name] = generateRuleOptions(name)
	end,
	order = 0,
}

local function generateDefaultGroups()
	local defaultGroups = {
		['Glyphs'] = {
			search = 'Glyph of',
			target = 0,
		},
		['Epic Gems'] = {
			search = "Cardinal Ruby, Ametrine, King's Amber, Eye of Zul, Majestic Zircon, Dreadstone",
			target = 0,
		},
		['Rare Gems'] = {
			search = "Scarlet Ruby, Monarch Topaz, Autumn's Glow, Forest Emerald, Sky Sapphire, Twilight Opal",
			target = 0,
		},
	}

	for name, rule in pairs(defaultGroups) do
		ItemAuditor.db.char.rules[name] = {
			search = rule.search,
			target = rule.target,
		}
		Options['rule_'..name] = generateRuleOptions(name)
	end
end

local rules
function CraftingRules:OnInitialize()
	rules = ItemAuditor.db.char.rules
	local count = 0
	for name, _ in pairs(rules) do
		Options['rule_'..name] = generateRuleOptions(name)
		count = count + 1
	end

	if count == 0 then
		generateDefaultGroups()
	end
end

local function runRule(rule, itemName, itemID)
	local searches = {strsplit(',', rule.search:upper())}

	for _, search in pairs(searches) do
		search = search:trim()
		
		if string.find(itemName, search) ~= nil or itemID == search then
			return rule.target
		end
	end
	return 0
end

local function Decide(data)

	local match_rule = nil
	local match_num = 0

	local itemName = data.name:upper()
	local itemID = tostring(Utils.GetItemID(data.link))
	for name, rule in pairs(rules) do
		local result = runRule(rule, itemName, itemID)
		if result == -1 then
			return result, name
		elseif result > match_num then
			match_rule = name
			match_num = result
		end
	end

	if match_rule == nil and ItemAuditor.db.char.rules_default_veto then
		return -1
	end
	return match_num, match_rule
end

Crafting.RegisterCraftingDecider('Crafting Rules', Decide, Options)
