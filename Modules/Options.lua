local addonName, addonTable = ...; 
local addon = _G[addonName]

local currentFaction = UnitFactionGroup("player")
local AHFactions = { currentFaction, 'Neutral' }

local craftingThresholds = {5000, 10000, 50000}
local craftingThresholdsDisplay = {}

local currentVersion = "@project-version@"

for key, value in pairs(craftingThresholds) do
	craftingThresholdsDisplay[key] = addon:FormatMoney(value, '', true)
	-- craftingThresholdsDisplay[key] = value
end

local windowIndex = nil
function addon:GetChatWindowList()
	local windows = {}
	for i=1, NUM_CHAT_WINDOWS do
		local name, _, _, _, _, _, shown, locked, docked = GetChatWindowInfo(i)
		if (name ~= "") and (docked or shown) then
			windows[i] = name
		end
	end
	return windows
end

function addon:GetChatWindowIndex()
	local cf = self.db.char.output_chat_frame
	if not windowIndex then
		for i=1, NUM_CHAT_WINDOWS do
			local name, _, _, _, _, _, shown, locked, docked = GetChatWindowInfo(i)
			if name ~= "" and cf ~= nil and cf == name then
				self:SetChatWindow(nil, i)
			end
		end
	end
	return windowIndex 
end


local selectedWindow = nil

function addon:SetChatWindow(info, index)
	windowIndex = index
	local name = GetChatWindowInfo(windowIndex)
	
	self.db.char.output_chat_frame = name
	selectedWindow = nil
end

function addon:GetSelectedChatWindow()
	if not selectedWindow then
		local index = self:GetChatWindowIndex()
		if index then
			selectedWindow = _G["ChatFrame"..index]
		end
	end
	if (selectedWindow) then
		return selectedWindow
	end
	return DEFAULT_CHAT_FRAME
end

local options = {
	handler = addon,
	name = "ItemAuditor "..currentVersion,
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
				
				item_cost = {
					type = "toggle",
					name = "Item Cost",
					desc = "Shows a message every time an item's cost changes",
					get = function() return ItemAuditor.db.profile.messages.cost_updates end,
					set = function(info, value) ItemAuditor.db.profile.messages.cost_updates = value end,
					order = 0,
				},
				queue_skip = {
					type = "toggle",
					name = "Queue Skip",
					desc = "Displays a message when an item is excluded from the queue.",
					get = function() return ItemAuditor.db.profile.messages.queue_skip end,
					set = function(info, value) ItemAuditor.db.profile.messages.queue_skip = value end,
					disabled = 'IsQADisabled',
					order = 1,
				},
				output = {
					type = "select",
					name = "Output",
					desc = "",
					values = 'GetChatWindowList',
					get = 'GetChatWindowIndex',
					set = 'SetChatWindow',
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
						ItemAuditor:RefreshQAGroups()
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
		},
		crafting_options = {
			name = "Crafting with Skillet",
			desc = "/ia queue",
			type = 'group',
			disabled = function() return Skillet == nil end,
			args = {
				crafting_threshold = {
					type = "select",
					name = "Crafting Threshold",
					desc = "Don't create items that will make less than this amount of profit",
					values = craftingThresholdsDisplay,
					get = function() return ItemAuditor.db.char.crafting_threshold end,
					set = function(info, value) ItemAuditor.db.char.crafting_threshold = value end,
					order = 11,
				},
			},
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
		debug = {
			type = "execute",
			name = "debug",
			desc = "Shows the debug frame",
			func = function() ItemAuditor_DebugFrame:Show() end,
			guiHidden = true,
		},
		invested = {
			type = "execute",
			name = "invested",
			desc = "Shows what you have invested in",
			func = "DisplayInvested",
			guiHidden = false,
		},
		crafting = {
			type = "execute",
			name = "crafting",
			desc = "<description goes here>",
			func = "DisplayCrafting",
			guiHidden = false,
		},
		
		suspend = {
			type = "toggle",
			name = "suspend",
			desc = "Suspends ItemAuditor",
			get = "IsEnabled",
			set = "SetEnabled",
			guiHidden = true,
		},
	},
}

function addon:SetEnabled(info, enable)
	self.db.profile.addon_enabled = enable
	if enable == self:IsEnabled() then
		-- do nothing
	elseif enable then
		self:Enable()
		self:Print('ItemAuditor is enabled.')
	else
		self:Disable()
		self:Print('ItemAuditor is supended and will not watch for any events. Use "/ia suspend" to turn it back on.')
	end
end

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

function addon:GetCraftingThreshold()
	local key = ItemAuditor.db.char.crafting_threshold
	return craftingThresholds[key]
end

function addon:GetAuctionThreshold()
	return ItemAuditor.db.char.auction_threshold
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

function addon:ShowOptionsGUI()
	InterfaceOptionsFrame_OpenToCategory(self.optionsFrame)
end


