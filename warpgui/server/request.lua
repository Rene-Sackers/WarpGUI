local textColor = Color(200, 50, 200)

Network:Subscribe("WarpRequestToServer", function(args)
	local requestingPlayer = args[1]
	local targetPlayer = args[2]
	
	Network:Send(targetPlayer, "WarpRequestToTarget", requestingPlayer)
end)

Network:Subscribe("WarpMessageTo", function(args)
	local player = args[1]
	local message = args[2]
	
	Chat:Send(player, message, textColor)
end)

Network:Subscribe("WarpTo", function(args)
	local requester = args[1]
	local target = args[2]
	
	Chat:Send(target, requester:GetName() .. " has warped to you.", textColor)
	Chat:Send(requester, "You have warped to " .. target:GetName() .. ".", textColor)
	
	local vector = target:GetPosition()
	vector.x = vector.x + 2
	requester:SetPosition(vector)
end)