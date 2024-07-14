if not CLIENT then return end

local MIN_FOV = 70
local MAX_FOV = 175
local DEFAUTL_VIEWMODEL_FOV = 54

local function getDefaultFov() return GetConVar("fov_desired"):GetInt() end

-- Create the console variables
CreateClientConVar("cfov_enable", 1, true, _, "Enable the Custom FOV mod", 0, 1)
CreateClientConVar("cfov", getDefaultFov(), true, _, "Set the value for custom fov", MIN_FOV, MAX_FOV)
CreateClientConVar("cfov_viewmodel_fixed", 0, true, _, "Locks the viewmodel in place", 0, 1)

-- Create Set FOV tab in the menu options
local function buildCustomFOVMenu()
	spawnmenu.AddToolMenuOption("Options", "Custom FOV", "CustomFOVMenu", "Set FOV", _, _, function(panel)
		panel:CheckBox('Enable', 'cfov_enable')
		panel:NumSlider("FOV", "cfov", MIN_FOV, MAX_FOV, 0)
		panel:CheckBox("Default viewmodel", "cfov_viewmodel_fixed")
	end)
end

local function CalcCustomFOV(ply, customFOV)
	local diff = customFOV - getDefaultFov()
	return ply:GetFOV() + diff
end

local function CalcFixedViewmodel(ply, customFOV)
	-- f(x) = ax + b
	-- f(fov) = -0.994 * fov + viewmodel_fov(=54 default)
	return -0.994 * (customFOV - ply:GetFOV()) + DEFAUTL_VIEWMODEL_FOV
end

local function HookCustomFOV(ply, pos, ang, _, znear, zfar)
	if (ply:InVehicle() and ply:GetVehicle():GetThirdPersonMode()) or 
		ply:ShouldDrawLocalPlayer() then return end -- Assume thirdperson is enabled

	return {
		origin = pos,
		angles = ang,
		fov = CalcCustomFOV(ply, GetConVarNumber("cfov")),
		znear = znear,
		zfar = zfar
	}
end

local function changeViewmodel(ply, fov)
	RunConsoleCommand("viewmodel_fov", CalcFixedViewmodel(ply, fov))
end

local function enableFixedViewmodel(switch)
	local ply = LocalPlayer()
	
	if switch and IsValid(ply) then
		changeViewmodel(ply, GetConVarNumber("cfov"))
		cvars.AddChangeCallback("cfov", function()
			changeViewmodel(ply, GetConVarNumber("cfov"))
		end, "changeViewmodel")
	else
		cvars.RemoveChangeCallback("cfov", "changeViewmodel")
		RunConsoleCommand("viewmodel_fov", DEFAUTL_VIEWMODEL_FOV)
	end
end

local function enableCustomFOV(switch)
	if switch then
		hook.Add("CalcView", "CalcCustomFOV", HookCustomFOV)
		enableFixedViewmodel(GetConVar("cfov_viewmodel_fixed"):GetBool())
	else
		hook.Remove("CalcView", "CalcCustomFOV")
		enableFixedViewmodel(false)
	end
end

-- Add the callbacks
cvars.AddChangeCallback("cfov_enable", function()
	enableCustomFOV(GetConVar("cfov_enable"):GetBool())
end)

cvars.AddChangeCallback("cfov_viewmodel_fixed", function()
	enableFixedViewmodel(GetConVar("cfov_enable"):GetBool()
	and GetConVar("cfov_viewmodel_fixed"):GetBool())
end)

-- Hook all the functions
hook.Add("AddToolMenuCategories", "CustomFOVMenu", buildCustomFOVMenu)
hook.Add("InitPostEntity", "InitCustomFOV", function()
	enableCustomFOV(GetConVar("cfov_enable"):GetBool())
end)
