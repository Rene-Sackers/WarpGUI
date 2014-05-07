class 'WarpGui'

function WarpGui:__init()
	-- Local variables
	self.textColor = Color(200, 50, 200)
	self.storeInSql = true
	
	-- Set up SQL
	if self.storeInSql then self:InitializeDatabase() end
	
	-- Events
	Network:Subscribe("WarpRequestToServer", self, self.WarpRequestToServer)
	Network:Subscribe("WarpMessageTo", self, self.WarpMessageTo)
	Network:Subscribe("WarpTo", self, self.WarpTo)
	Network:Subscribe("WarpSetWhitelist", self, self.WarpSetWhitelist)
	Network:Subscribe("WarpGetWhitelists", self, self.WarpGetWhitelists)
end

-- ========================= Network request to target player =========================
function WarpGui:WarpRequestToServer(args)
	Network:Send(args.target, "WarpRequestToTarget", args.requester)
end

-- ========================= Send message to target player =========================
function WarpGui:WarpMessageTo(args)
	Chat:Send(args.target, args.message, self.textColor)
end

-- ========================= Warp requester to target =========================
function WarpGui:WarpTo(args)
	Chat:Send(args.target, args.requester:GetName() .. " has warped to you.", self.textColor)
	Chat:Send(args.requester, "You have warped to " .. args.target:GetName() .. ".", self.textColor)
	
	-- Poof
	Network:SendNearby(args.requester, "WarpDoPoof", args.requester:GetPosition())
	
	local vector = args.target:GetPosition()
	vector.x = vector.x + 2
	args.requester:SetPosition(vector)
	
	Network:SendNearby(args.target, "WarpDoPoof", vector)
	Network:Send(args.requester, "WarpDoPoof", args.requester:GetPosition())
end

-- ========================= Whitelist storing =========================
function WarpGui:InitializeDatabase() -- Create table if it doesn't exist
	--SQL:Execute("DROP TABLE IF EXISTS warp_whitelists")
	SQL:Execute("CREATE TABLE IF NOT EXISTS warp_whitelists (player_steam_id INT(20) NOT NULL, target_steam_id INT(20) NOT NULL, whitelist INT(1) NOT NULL DEFAULT 0, PRIMARY KEY (player_steam_id, target_steam_id))")
end

function WarpGui:WarpSetWhitelist(args)
	if not self.storeInSql then return end
	
	if args.whitelist == 0 then -- Remove from database
		SQL:Execute("DELETE FROM warp_whitelists WHERE player_steam_id = " .. args.playerSteamId .. " AND target_steam_id = " .. args.targetSteamId)
	else -- Update whitelist
		SQL:Execute("INSERT OR REPLACE INTO warp_whitelists (player_steam_id, target_steam_id, whitelist) VALUES (" .. args.playerSteamId .. ", " .. args.targetSteamId .. ", " .. args.whitelist .. ")")
	end
end

function WarpGui:WarpGetWhitelists(player)
	if not self.storeInSql or player == nil then return end
	
	local playerSteamId = player:GetSteamId().id

	local query = SQL:Query("SELECT target_steam_id, whitelist FROM warp_whitelists WHERE player_steam_id = " .. playerSteamId .. " AND whitelist != 0")
	local results = query:Execute()
	
	Network:Send(player, "WarpReturnWhitelists", results)
end

-- ========================= Initialize class =========================
local warpGui = WarpGui()