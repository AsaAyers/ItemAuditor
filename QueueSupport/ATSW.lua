local function ATSWQueue(data)
	if ATSW_AddJobLL then
		ATSW_AddJobLL(data.skillName, data.queue)
	else
		print("Unable to find ATSW")
	end
end
IAapi.RegisterQueueDestination('ATSW', ATSWQueue)
