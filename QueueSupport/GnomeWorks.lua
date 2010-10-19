local function GnomeWorksQueue(data)
	if GnomeWorks then
		GnomeWorks:ShowQueueList()
		GnomeWorks:AddToQueue(GnomeWorks.player, data.tradeSkillIndex, data.recipeID, data.queue)
	else
		print("Unable to find GnomeWorks")
	end
end
IAapi.RegisterQueueDestination('GnomeWorks', GnomeWorksQueue)
