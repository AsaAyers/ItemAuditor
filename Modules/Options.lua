local ItemAuditor = select(2, ...)
local Options = ItemAuditor:NewModule("Options")

local currentFaction = UnitFactionGroup("player")
local AHFactions = { currentFaction, 'Neutral' }

local windowIndex = nil
function Options.GetChatWindowList()
	local windows = {}
	for i=1, NUM_CHAT_WINDOWS do
		local name, _, _, _, _, _, shown, locked, docked = GetChatWindowInfo(i)
		if (name ~= "") and (docked or shown) then
			windows[i] = name
		end
	end
	return windows
end

function Options:GetChatWindowIndex()
	local cf = ItemAuditor.db.char.output_chat_frame
	if not windowIndex then
		for i=1, NUM_CHAT_WINDOWS do
			local name, _, _, _, _, _, shown, locked, docked = GetChatWindowInfo(i)
			if name ~= "" and cf ~= nil and cf == name then
				Options.SetChatWindow(nil, i)
			end
		end
	end
	return windowIndex 
end


local selectedWindow = nil

function Options.SetChatWindow(info, index)
	windowIndex = index
	local name = GetChatWindowInfo(windowIndex)
	
	ItemAuditor.db.char.output_chat_frame = name
	selectedWindow = nil
end

function Options.GetSelectedChatWindow()
	if not selectedWindow then
		local index = Options.GetChatWindowIndex()
		if index then
			selectedWindow = _G["ChatFrame"..index]
		end
	end
	if (selectedWindow) then
		return selectedWindow
	end
	return DEFAULT_CHAT_FRAME
end


function ItemAuditor:SetEnabled(info, enable)
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



function ItemAuditor:GetAuctionThreshold()
	return ItemAuditor.db.char.auction_threshold
end

function ItemAuditor:GetAH()
	return ItemAuditor.db.char.ah
end

function ItemAuditor:SetAH(info, value)
	ItemAuditor.db.char.ah = value
end

function ItemAuditor:GetAHCut()
	if ItemAuditor.db.char.ah == 1 then
		return 0.05
	end
	return 0.15
end

function ItemAuditor:GetAHFaction()
	return AHFactions[ItemAuditor.db.char.ah]
end

function ItemAuditor:ShowOptionsGUI()
	InterfaceOptionsFrame_OpenToCategory(self.optionsFrame)
end


ItemAuditor.Options.args.messages = {
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
		cod_warning = {
			type = "toggle",
			name = "COD Warning",
			desc = "This will warn you to attach the correct COD amount if you are mailing items to another account",
			get = function() return ItemAuditor.db.char.cod_warnings end,
			set = function(info, value) ItemAuditor.db.char.cod_warnings = value end,
			disabled = 'IsQADisabled',
			order = 1,
		},
		output = {
			type = "select",
			name = "Output",
			desc = "",
			values = Options.GetChatWindowList,
			get = Options.GetChatWindowIndex,
			set = Options.SetChatWindow,
		},
	},
}

ItemAuditor.Options.args.prices = {
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
}