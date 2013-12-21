class 'WarpGui'

function WarpGui:__init()
	self.textColor = Color(200, 50, 200)
	self.admins = {}
	self.rows = {}
	self.acceptButtons = {}
	self.whitelist = {}
	self.whitelistAll = false
	self.warpRequests = {}
	self.windowShown = false
	
	-- Admins
	self:AddAdmin("STEAM_0:0:16870054")
	
	-- Create GUI
	self.window = Window.Create()
	self.window:SetVisible(self.windowShown)
	self.window:SetTitle("Warp GUI")
	self.window:SetSizeRel(Vector2(0.4, 0.7))
	self.window:SetPositionRel( Vector2(0.75, 0.5) - self.window:GetSizeRel()/2)
    self.window:Subscribe("WindowClosed", self, function (args) self:SetWindowVisible(false) end)
	
	-- Tabs
	local tabControl = TabControl.Create(self.window)
	tabControl:SetDock(GwenPosition.Left)
	tabControl:SetSizeRel(Vector2(0.98, 1))
	
	-- Pages
	local playersPage = tabControl:AddPage("Players"):GetPage()
	--local warpsPage = tabControl:AddPage("Warps"):GetPage()
	
	-- Player list
	self.playerList = SortedList.Create(playersPage)
	self.playerList:SetDock(GwenPosition.Fill)
	self.playerList:SetMargin(Vector2(0, 0), Vector2(0, 4))
	self.playerList:AddColumn("Name")
	self.playerList:AddColumn("Warp To", 90)
	self.playerList:AddColumn("Accept Warp", 90)
	self.playerList:AddColumn("Whitelist", 90)
	self.playerList:SetButtonsVisible(true)
	
	-- Player search box
	self.filter = TextBox.Create(playersPage)
	self.filter:SetDock(GwenPosition.Bottom)
	self.filter:SetSize(Vector2(self.window:GetSize().x, 32))
	self.filter:Subscribe("TextChanged", self, self.TextChanged)
	
	-- Whitelist all
	local whitelistAllCheckbox = LabeledCheckBox.Create(playersPage)
    whitelistAllCheckbox:SetSize(Vector2(300, 20))
    whitelistAllCheckbox:SetDock(GwenPosition.Top)
    whitelistAllCheckbox:GetLabel():SetText("Whitelist all")
    whitelistAllCheckbox:GetCheckBox():Subscribe("CheckChanged",
		function() self.whitelistAll = whitelistAllCheckbox:GetCheckBox():GetChecked() end)
	
	-- Add players
	for player in Client:GetPlayers() do
		self:AddPlayer(player)
	end
	
	-- Subscribe to events
	Events:Subscribe("LocalPlayerChat", self, self.LocalPlayerChat)
    Events:Subscribe("LocalPlayerInput", self, self.LocalPlayerInput)
	Events:Subscribe("PlayerJoin", self, self.PlayerJoin)
	Events:Subscribe("PlayerQuit", self, self.PlayerQuit)
    Events:Subscribe("KeyUp", self, self.KeyUp)
	Network:Subscribe("WarpRequestToTarget", self, self.WarpRequest)
	
	-- Debug
	--self:SetWindowVisible(true)
	--self:AddPlayer(LocalPlayer)
end

-- ========================= Admin check =========================
function WarpGui:AddAdmin(steamId)
	self.admins[steamId] = true
end

function WarpGui:IsAdmin(player)
	return self.admins[player:GetSteamId().string] ~= nil
end

-- ========================= Player adding =========================
function WarpGui:CreateListButton(text, enabled)
	local buttonBase = BaseWindow.Create(self.window)
	buttonBase:SetDock(GwenPosition.Fill)
	buttonBase:SetSize(Vector2(1, 23))
	
    local buttonBackground = Rectangle.Create(buttonBase)
    buttonBackground:SetSizeRel(Vector2(0.5, 1.0))
    buttonBackground:SetDock(GwenPosition.Fill)
    buttonBackground:SetColor(Color(0, 0, 0, 100))
	
	local button = Button.Create(buttonBase)
	button:SetText(text)
	button:SetDock(GwenPosition.Fill)
	button:SetEnabled(enabled)
	
	return buttonBase, button
end

function WarpGui:AddPlayer(player)
	local playerId = tostring(player:GetId())
	local playerName = player:GetName()
	
	-- Warp to button
	local warpToButtonBase, warpToButton = self:CreateListButton("Warp to", true)
	warpToButton:Subscribe("Press", function() self:WarpToPlayerClick(player) end)
	
	-- Accept 
	local acceptButtonBase, acceptButton = self:CreateListButton("Accept", false)
	acceptButton:Subscribe("Press", function() self:AcceptWarpClick(player) end)
	self.acceptButtons[playerId] = acceptButton
	
	-- Whitelist
	local whitelistButtonBase, whitelistButton = self:CreateListButton("None", true)
	whitelistButton:Subscribe("Press", function() self:WhitelistClick(playerId, whitelistButton) end)
	
	-- List item
	local item = self.playerList:AddItem(playerId)
	item:SetCellText(0, playerName)
	item:SetCellContents(1, warpToButtonBase)
	item:SetCellContents(2, acceptButtonBase)
	item:SetCellContents(3, whitelistButton)
	
	self.rows[playerId] = item
	
	-- Add is serch filter matches
	local filter = self.filter:GetText():lower()
	if filter:len() > 0 then
		item:SetVisible(true)
	end
end

-- ========================= Player search =========================
function WarpGui:TextChanged()
	local filter = self.filter:GetText()

	if filter:len() > 0 then
		for k, v in pairs(self.rows) do
			v:SetVisible(self:PlayerNameContains(v:GetCellText(0), filter))
		end
	else
		for k, v in pairs(self.rows) do
			v:SetVisible(true)
		end
	end
end

function WarpGui:PlayerNameContains(name, filter)
	return string.match(name:lower(), filter:lower()) ~= nil
end

-- ========================= Warp to/Warp accept =========================
function WarpGui:WarpToPlayerClick(player)
	self.filter:SetText("")
	Network:Send("WarpRequestToServer", {LocalPlayer, player})
	self:SetWindowVisible(false)
end

function WarpGui:AcceptWarpClick(player)
	local playerId = tostring(player:GetId())
	
	if self.warpRequests[playerId] == nil then
		Chat:Print(player:GetName() .. " has not requested to warp to you.", self.textColor)
		return
	else
		local acceptButton = self.acceptButtons[playerId]
		if acceptButton == nil then return end
		self.warpRequests[playerId] = nil
		acceptButton:SetEnabled(false)
		
		Network:Send("WarpTo", {player, LocalPlayer})
		self:SetWindowVisible(false)
	end
end

-- ========================= White/black -list click =========================
function WarpGui:WhitelistClick(playerId, button)
	local currentWhiteList = self.whitelist[playerId]
	
	if currentWhiteList == nil then -- Currently none, set whitelisted
		self:SetWhitelist(playerId, true)
		button:SetText("Whitelisted")
	elseif currentWhiteList == true then -- Currently whitelisted, blacklisted
		self:SetWhitelist(playerId, false)
		button:SetText("Blacklisted")
	elseif currentWhiteList == false then -- Currently blacklisted, set none
		self:SetWhitelist(playerId, nil)
		button:SetText("None")
	end
end

function WarpGui:SetWhitelist(playerId, whitelisted)
	if self.whitelist[playerId] ~= whitelisted then self.whitelist[playerId] = whitelisted end
end

-- ========================= Warp request =========================
function WarpGui:WarpRequest(args)
	local requestingPlayer = args
	local playerId = tostring(requestingPlayer:GetId())
	local whitelist = self.whitelist[playerId]
	
	if whitelist == true or self.whitelistAll or self:IsAdmin(requestingPlayer) then -- In whitelist
		Network:Send("WarpTo", {requestingPlayer, LocalPlayer})
	elseif whitelist == nil then -- Not in whitelist
		local acceptButton = self.acceptButtons[playerId]
		if acceptButton == nil then return end
		
		acceptButton:SetEnabled(true)
		self.warpRequests[playerId] = true
		Network:Send("WarpMessageTo", {requestingPlayer, "Please wait for " .. LocalPlayer:GetName() .. " to accept."})
		Chat:Print(requestingPlayer:GetName() .. " would like to warp to you. Type /warp or press V to accept.", self.textColor)
	end -- Blacklist
end

-- ========================= Chat command =========================
function WarpGui:LocalPlayerChat(args)
	local player = args.player
	local message = args.text
	
	if message ~= "/warp" then return true end
	
	self:SetWindowVisible(not self.windowShown)
	
	return false
end

-- ========================= Window management =========================
function WarpGui:LocalPlayerInput(args) -- Prevent mouse from moving & buttons being pressed
    return not (self.windowShown and Game:GetState() == GUIState.Game)
end

function WarpGui:KeyUp( args )
    if args.key == string.byte('V') then
        self:SetWindowVisible(not self.windowShown)
    end
end

function WarpGui:PlayerJoin(args)
	local player = args.player
	
	self:AddPlayer(player)
end

function WarpGui:PlayerQuit(args)
	local player = args.player
	local playerId = tostring(player:GetId())
	
	if self.rows[playerId] == nil then return end

	self.playerList:RemoveItem(self.rows[playerId])
	self.rows[playerId] = nil
end

function WarpGui:SetWindowVisible(visible)
	self.windowShown = visible
	self.window:SetVisible(visible)
	Mouse:SetVisible(visible)
end

warpGui = WarpGui()