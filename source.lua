if not game:IsLoaded() then
	game.Loaded:Wait()
end
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local owner = Players.LocalPlayer
while not owner do
	Players.PlayerAdded:Wait()
	owner = Players.LocalPlayer
end
local character = owner.Character or owner.CharacterAdded:Wait()
local humanoid = character:FindFirstChildOfClass("Humanoid")
while not humanoid or humanoid.ClassName ~= "Humanoid" do
	humanoid = character.ChildAdded:Wait()
end
for _, connectionInfo in getconnections(owner.Idled) do
	for _, name in { "Disable", "Disconnect" } do
		if connectionInfo[name] then
			connectionInfo[name](connectionInfo)
			break
		end
	end
end
local function getPath(object, ...)
	for index = 1, select("#", ...) do
		object = object:WaitForChild(tostring((select(index, ...))))
	end
	return object
end
local currentRooms = getPath(workspace, "CurrentRooms")
local gameData = getPath(ReplicatedStorage, "GameData")
local latestRoom = getPath(gameData, "LatestRoom")
local mainUI = getPath(owner, "PlayerGui", "MainUI")
local function pressButton(button)
	local mousePosition = button.AbsolutePosition + button.AbsoluteSize / 2
	firesignal(button.MouseButton1Down, mousePosition.X, mousePosition.Y)
end
local canCollide = true
local function slideTo(position)
	local currentPosition = character:GetPivot().Position
	local lastFrame = os.clock()
	while task.wait() do
		local delta = os.clock() - lastFrame
		lastFrame = os.clock()
		if (character:GetPivot().Position - currentPosition).Magnitude > 3 then
			currentPosition = character:GetPivot().Position
		end
		if (currentPosition - position).Magnitude > 1e-3 then
			currentPosition = (CFrame.lookAt(currentPosition, position) * CFrame.new(
				0,
				0,
				-math.min(100 * math.min(delta, 1 / 15), (currentPosition - position).Magnitude)
			)).Position
		end
		character:PivotTo(CFrame.new(currentPosition))
		for _, object in character:GetChildren() do
			if object:IsA("BasePart") then
				object.AssemblyLinearVelocity, object.CanCollide = Vector3.zero, false
				object.CanQuery, object.CanTouch = canCollide, canCollide
				object.Anchored = false
			end
		end
		if (currentPosition - position).Magnitude < 1e-3 then
			break
		end
	end
end
task.defer(game.Destroy, getPath(game:GetService("ReplicatedStorage"), "ClientModules", "EntityModules", "Void"))
local xzAxis = Vector3.new(1, 0, 1)
local bases = {}
for room = 0, 100 do
	bases[room] = {}
end
local pathfindingBases = {}
local function check(object)
	if table.find(pathfindingBases, object) then
		return
	end
	if object.Name == "Base" and object.Parent:GetAttribute("Floor") then
		local roomName = object.Parent.Name
		local currentBases = bases[tonumber(roomName)]
		table.insert(currentBases, object)
		local pathfindingBase = object:Clone()
		pathfindingBase:PivotTo(CFrame.new(0, -pathfindingBase.CFrame.Y, 0) * pathfindingBase.CFrame)
		table.insert(pathfindingBases, pathfindingBase)
		pathfindingBase.Parent = workspace
		local ancestryChanged
		ancestryChanged = object.AncestryChanged:Connect(function()
			if object:IsDescendantOf(workspace) then
				return
			end
			ancestryChanged:Disconnect()
			table.remove(currentBases, table.find(currentBases, object))
			table.remove(pathfindingBases, table.find(pathfindingBases, pathfindingBase))
			pathfindingBase:Destroy()
		end)
	end
	if object:IsA("BasePart") then
		object.CanCollide, object.CanQuery, object.CanTouch = false, false, false
	end
end
workspace.DescendantAdded:Connect(check)
for _, object in workspace:GetDescendants() do
	check(object)
end
local path = game:GetService("PathfindingService"):CreatePath({
	AgentCanJump = false,
	WaypointSpacing = math.huge,
})
local startPosition = character:GetPivot().Position
pcall(
	queueonteleport or queue_on_teleport,
	"loadstring(game:HttpGet('https://raw.githubusercontent.com/Amourousity/WALLS/main/source.lua'), 'WALLS')()"
)
while workspace.DistributedGameTime < 30 do
	slideTo(startPosition)
end
getPath(mainUI, "ItemShop").Visible = false
task.spawn(function()
	local lastRoom = 0
	local lastEntered = os.clock()
	while task.wait(1) do
		if lastRoom ~= latestRoom.Value then
			lastEntered = os.clock()
			lastRoom = latestRoom.Value
		elseif os.clock() - lastEntered > 15 then
			pressButton(getPath(mainUI, "ItemShop", "Confirm"))
			getPath(ReplicatedStorage, "EntityInfo", "PlayAgain"):FireServer()
			break
		end
	end
end)
for roomNumber = 0, 50 do
	local room = getPath(currentRooms, roomNumber)
	local ceiling = getPath(room, "LightBase").Position * Vector3.yAxis
	canCollide = false
	slideTo(character:GetPivot().Position * xzAxis + ceiling)
	canCollide = true
	local door = getPath(room, "Door")
	local doorPart = getPath(door, "Door")
	local doorCFrame = getPath(doorPart, "OriginalCFrameValue").Value
	local doorOpen = math.abs(doorCFrame.X - doorPart.CFrame.X) > 1e-3
	local lock = door:FindFirstChild("Lock")
	if roomNumber ~= 50 and lock and not doorOpen then
		local key = room:FindFirstChild("KeyObtain", true)
		while not key do
			room.DescendantAdded:Wait()
			key = room:FindFirstChild("KeyObtain", true)
		end
		local done
		task.spawn(function()
			repeat
				slideTo(character:GetPivot().Position * xzAxis + ceiling)
			until done
		end)
		repeat
			path:ComputeAsync(
				character:GetPivot().Position * xzAxis + Vector3.yAxis * 4,
				key:GetPivot().Position * xzAxis + Vector3.yAxis * 4
			)
		until path.Status.Name == "Success"
		done = true
		local waypoints = path:GetWaypoints()
		table.remove(waypoints, 1)
		for _, waypoint in waypoints do
			slideTo(waypoint.Position * xzAxis + ceiling)
		end
		slideTo(key:GetPivot().Position * xzAxis + ceiling)
		slideTo(key:GetPivot().Position)
		repeat
			slideTo(key:GetPivot().Position)
			fireproximityprompt(getPath(key, "ModulePrompt"))
		until owner.Character:FindFirstChild("Key")
		slideTo(key:GetPivot().Position * xzAxis + ceiling)
		done = false
		task.spawn(function()
			repeat
				slideTo(character:GetPivot().Position * xzAxis + ceiling)
			until done
		end)
		repeat
			path:ComputeAsync(
				key:GetPivot().Position * xzAxis + Vector3.yAxis * 4,
				(doorCFrame * CFrame.new(0, 0, 5)).Position * xzAxis + Vector3.yAxis * 4
			)
		until path.Status.Name == "Success"
		done = true
		waypoints = path:GetWaypoints()
		table.remove(waypoints, 1)
		for _, waypoint in waypoints do
			slideTo(waypoint.Position * xzAxis + ceiling)
		end
		slideTo((doorCFrame * CFrame.new(0, 0, 5)).Position * xzAxis + ceiling)
		slideTo((doorCFrame * CFrame.new(0, 0, 5)).Position)
		repeat
			slideTo((doorCFrame * CFrame.new(0, 0, 5)).Position)
			fireproximityprompt(getPath(lock, "UnlockPrompt"))
		until roomNumber < latestRoom.Value
		slideTo((doorCFrame * CFrame.new(0, 0, -5)).Position)
	else
		local done
		task.spawn(function()
			repeat
				slideTo(character:GetPivot().Position * xzAxis + ceiling)
			until done
		end)
		repeat
			path:ComputeAsync(
				character:GetPivot().Position * xzAxis + Vector3.yAxis * 4,
				(doorCFrame * CFrame.new(0, 0, 5)).Position * xzAxis + Vector3.yAxis * 4
			)
		until path.Status.Name == "Success"
		done = true
		local waypoints = path:GetWaypoints()
		table.remove(waypoints, 1)
		for _, waypoint in waypoints do
			slideTo(waypoint.Position * xzAxis + ceiling)
		end
		slideTo((doorCFrame * CFrame.new(0, 0, 5)).Position * xzAxis + ceiling)
		slideTo((doorCFrame * CFrame.new(0, 0, 5)).Position)
		repeat
			slideTo((doorCFrame * CFrame.new(0, 0, math.random(0, 5))).Position)
		until roomNumber < latestRoom.Value or doorOpen or roomNumber == 50
		slideTo((doorCFrame * CFrame.new(0, 0, -5)).Position)
	end
	owner:SetAttribute("CurrentRoom", latestRoom.Value)
end
pressButton(getPath(mainUI, "ItemShop", "Confirm"))
