 local addonName, addonTable = ...; 
local addon = _G[addonName]

local utils = addonTable.utils

local currentFaction = UnitFactionGroup("player")
local AHFactions = { currentFaction, 'Neutral' }

local options = {
	handler = addon,
	name = "ItemAuditor",
	type = 'group',
	args = {
		prices = {
			name = "Prices",
			desc = "Control how your minimum price is calculated.",
			type = 'group',
			args = {
				auction_house = {
					type = "select",
					name = "Auction House",
					desc = "",
					values = { currentFaction, 'Neutral' },
					get = 'GetAH',
					set = 'SetAH',
				},
			},
		},
		
		
		messages = {
			name = "Messages",
			desc = "Control which messages display in your chat window.",
			type = 'group',
			args = {
				dbg = {
					type = "toggle",
					name = "Debug",
					desc = "Toggles debug messages in chat",
					get = "GetDebug",
					set = "SetDebug",
					order = 100,
				},
				item_cost = {
					type = "toggle",
					name = "Item Cost",
					desc = "Shows a message every time an item's cost changes",
					get = function() return ItemAuditor.db.profile.messages.cost_updates end,
					set = function(info, value) ItemAuditor.db.profile.messages.cost_updates = value end,
					order = 0,
				},
			},
		},
		
		qa_options = {
			name = "QA Options",
			desc = "Control how ItemAuditor integrates with QuickAuctions",
			type = 'group',
			-- disabled = (not addon.QA_compatibile),
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
				--[[
				add_mail = {
					type = "toggle",
					name = "Add mail cost to QA Threshold",
					get = "IsQAEnabled",
					set = "SetQAEnabled",
					order = 1,
				},
				]]
				refresh_qa = {
					type = "execute",
					name = "Refresh QA Thresholds",
					desc = "Resets all Quick Auctions thresholds",
					func = "RefreshQAGroups",
					disabled = 'IsQADisabled',
				},
			}
		},
		options = {
			type = "execute",
			name = "options",
			desc = "Show Blizzard's options GUI",
			func = "ShowOptionsGUI",
			guiHidden = true,
		},
		queue = {
			type = "execute",
			name = "queue",
			desc = "Queue",
			func = "Queue",
			guiHidden = true,
		},
		
		
	},
}

function addon:RegisterOptions()
	self.optionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("ItemAuditor", "ItemAuditor")
	LibStub("AceConfig-3.0"):RegisterOptionsTable("ItemAuditor", options, {"ia"})
end

local function pairsByKeys (t, f)
	local a = {}
		for n in pairs(t) do table.insert(a, n) end
		table.sort(a, f)
		local i = 0      -- iterator variable
		local iter = function ()   -- iterator function
			i = i + 1
			if a[i] == nil then return nil
			else return a[i], t[a[i]]
			end
		end
	return iter
end

function addon:GetAH()
	return ItemAuditor.db.char.ah
end

function addon:SetAH(info, value)
	ItemAuditor.db.char.ah = value
end

function addon:GetAHCut()
	if ItemAuditor.db.char.ah == 1 then
		return 0.05
	end
	return 0.15
end

function addon:GetAHFaction()
	return AHFactions[ItemAuditor.db.char.ah]
end

function addon:DumpInfo()
	for itemName, value in pairsByKeys(self.db.factionrealm.item_account) do
		self:Print(itemName .. ": " .. self:FormatMoney(value))
	end
end


function addon:ShowOptionsGUI()
	InterfaceOptionsFrame_OpenToCategory(self.optionsFrame)
end


