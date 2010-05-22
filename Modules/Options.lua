 local addonName, addonTable = ...; 
local addon = _G[addonName]

local utils = addonTable.utils

local options = {
	name = "ItemAuditor",
	handler = addon,
	type = 'group',
	args = {
		debug = {
			type = "toggle",
			name = "Debug",
			desc = "Toggles debug messages in chat",
			handler = utils,
			get = "GetDebug",
			set = "SetDebug"
		},
		dump = {
			type = "execute",
			name = "dump",
			desc = "dumps IA database",
			func = "DumpInfo",
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

function addon:DumpInfo()
	self:Print("self.db.char")
	DevTools_Dump(self.db.char)
	self:Print("self.db.factionrealm")
	DevTools_Dump(self.db.factionrealm)
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
