--[[
	@original dawid-script/Fluent/src/modules/Acrylic
]]

--// Imports
local services = require("@modules/services")
local creator = require("@modules/creator")

--// References
local workspace = services.Workspace
local lighting = services.Lighting

local create = creator.Create

--// Functions
local function map(value, inMin, inMax, outMin, outMax)
	return (value - inMin) * (outMax - outMin) / (inMax - inMin) + outMin
end

local function viewportPointToWorld(location, distance)
	local unitRay = workspace.CurrentCamera:ScreenPointToRay(location.X, location.Y)
	return unitRay.Origin + unitRay.Direction * distance
end

local function getOffset()
	local viewportSizeY = workspace.CurrentCamera.ViewportSize.Y
	return map(viewportSizeY, 0, 2560, 8, 56)
end

--// Initialize
local function createBlur(frame: GuiObject, distance: number?)
	local blurEffects = Instance.new("Folder", workspace.CurrentCamera)
	local connections = {}
	local cameraConnections = {}
	local disposed = false

	local triPositions = {
		topLeft = Vector2.new(),
		topRight = Vector2.new(),
		bottomRight = Vector2.new(),
	}
	local model = create("Part")({
		Color = Color3.new(0, 0, 0),
		Material = Enum.Material.Glass,
		Size = Vector3.new(1, 1, 0),
		Anchored = true,
		CanTouch = false,
		CanCollide = false,
		CanQuery = false,
		Locked = true,
		CastShadow = false,
		Transparency = 0.98,

		create("SpecialMesh")({
			MeshType = Enum.MeshType.Brick,
			Offset = Vector3.new(0, 0, -0.000001),
		}),
	}) :: Part
	local effect = create("DepthOfFieldEffect")({
		FarIntensity = 0,
		NearIntensity = 1,
		InFocusRadius = 0.1,
		Parent = lighting,
	})
	local mesh = model:FindFirstChildWhichIsA("SpecialMesh")

	distance = distance or 0.001

	local function updatePositions(size, position)
		triPositions.topLeft = position
		triPositions.topRight = position + Vector2.new(size.X, 0)
		triPositions.bottomRight = position + size
	end

	local function render()
		local camera = workspace.CurrentCamera
		if disposed or not camera then
			return
		end
		local cameraTransform = camera.CFrame

		local topLeft = triPositions.topLeft
		local topRight = triPositions.topRight
		local bottomRight = triPositions.bottomRight

		local topLeft3D = viewportPointToWorld(topLeft, distance)
		local topRight3D = viewportPointToWorld(topRight, distance)
		local bottomRight3D = viewportPointToWorld(bottomRight, distance)

		local width = (topRight3D - topLeft3D).Magnitude
		local height = (topRight3D - bottomRight3D).Magnitude

		model.CFrame = CFrame.fromMatrix(
			(topLeft3D + bottomRight3D) / 2,
			cameraTransform.XVector,
			cameraTransform.YVector,
			cameraTransform.ZVector
		)

		if mesh then
			mesh.Scale = Vector3.new(width, height, 0)
		end
	end

	local function onChange()
		if disposed or not workspace.CurrentCamera then
			return
		end
		local offset = getOffset()
		local size = frame.AbsoluteSize - Vector2.new(offset, offset)
		local position = frame.AbsolutePosition + Vector2.new(offset / 2, offset / 2)

		updatePositions(size, position)
		task.spawn(render)
	end

	local function bindCamera()
		if disposed then
			return
		end
		for _, connection in ipairs(cameraConnections) do
			connection:Disconnect()
		end
		table.clear(cameraConnections)
		local camera = workspace.CurrentCamera
		blurEffects.Parent = camera

		if not camera then
			return
		end

		cameraConnections[#cameraConnections + 1] = camera:GetPropertyChangedSignal("CFrame"):Connect(render)
		cameraConnections[#cameraConnections + 1] = camera:GetPropertyChangedSignal("ViewportSize"):Connect(onChange)
		cameraConnections[#cameraConnections + 1] = camera:GetPropertyChangedSignal("FieldOfView"):Connect(render)

		onChange()
	end

	model.Parent = blurEffects

	model.Destroying:Once(function()
		disposed = true
		for _, connection in ipairs(connections) do
			connection:Disconnect()
		end
		for _, connection in ipairs(cameraConnections) do
			connection:Disconnect()
		end
		table.clear(connections)
		table.clear(cameraConnections)
		effect:Destroy()
		-- The model is still locked inside Destroying; remove its folder afterward.
		task.defer(function()
			blurEffects:Destroy()
		end)
	end)

	connections[#connections + 1] = workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindCamera)
	bindCamera()

	return onChange, model, connections
end

return function(frame: GuiObject, distance: number?)
	local blur = {}
	local onChange, model, connections = createBlur(frame, distance)

	blur.SetVisibility = function(Value)
		if model.Parent then
			model.Transparency = Value and 0.98 or 1
		end
	end

	connections[#connections + 1] = frame:GetPropertyChangedSignal("AbsolutePosition"):Connect(onChange)

	connections[#connections + 1] = frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(onChange)

	connections[#connections + 1] = frame:GetPropertyChangedSignal("Visible"):Connect(function()
		blur.SetVisibility(frame.Visible)
	end)

	connections[#connections + 1] = frame.Destroying:Connect(function()
		model:Destroy()
	end)

	blur.Model = model

	return blur
end
