 local addonName, addonTable = ...; 
local addon = _G[addonName]

local utils = addonTable.utils

local options = {
	name = "ItemAuditor",
	handler = addon,
	type = 'group',
	args = {
		dbg = {
			type = "toggle",
			name = "Debug",
			desc = "Toggles debug messages in chat",
			get = "GetDebug",
			set = "SetDebug"
		},
		dump = {
			type = "execute",
			name = "dump",
			desc = "dumps IA database",
			func = "DumpInfo",
		},
		refresh_qa = {
			type = "execute",
			name = "Refresh QA Thresholds",
			desc = "Resets all Quick Auctions thresholds",
			func = "RefreshQAGroups",
		},
		options = {
			type = "execute",
			name = "options",
			desc = "Show Blizzard's options GUI",
			func = "ShowOptionsGUI",
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

function addon:DumpInfo()
	for itemName, value in pairsByKeys(self.db.factionrealm.item_account) do
		self:Print(itemName .. ": " .. utils:FormatMoney(value))
	end
end


function addon:ShowOptionsGUI()
	InterfaceOptionsFrame_OpenToCategory(self.optionsFrame)
end

function addon:GetDebug(info)
       return self.db.char.debug
end

function addon:SetDebug(info, input)
       self.db.char.debug = input
       local value = "off"
       if input then
               value = "on"
       end
       self:Print("Debugging is now: " .. value)
end
