if not CLIENT then return end

local MIN_FOV = 10
local MAX_FOV = 175
local MIN_VIEWMODEL_FOV = -30
local MAX_VIEWMODEL_FOV = 150

-- Create the console variables
CreateClientConVar("cfov_enable", 1, true, _, "Enable the Custom FOV mod", 0, 1)
CreateClientConVar("cfov", GetConVar("fov_desired"):GetInt(), true, _, "Set the value for custom fov", MIN_FOV, MAX_FOV)
CreateClientConVar("cfov_viewmodel_fixed", 0, true, _, "Fix the viewmodel in place", 0, 1)
CreateClientConVar("cfov_viewmodel_fov", GetConVar("viewmodel_fov"):GetInt(), true, _, "Base for viewmodel fov", MIN_VIEWMODEL_FOV, MAX_VIEWMODEL_FOV)

-- Create Set FOV tab in the menu options
local function buildCustomFOVMenu()
	spawnmenu.AddToolMenuOption("Options", "Custom FOV", "CustomFOVMenu", "Set FOV", _, _, function(panel)
		panel:CheckBox("Enable", "cfov_enable")
		panel:NumSlider("FOV", "cfov", MIN_FOV, MAX_FOV, 0)
		panel:Button("RESET FOV", "cfov", GetConVar("cfov"):GetDefault())
		panel:CheckBox("Proportional viewmodel", "cfov_viewmodel_fixed")
		panel:NumSlider("Viewmodel FOV", "cfov_viewmodel_fov", MIN_VIEWMODEL_FOV, MAX_VIEWMODEL_FOV, 0)
		panel:Button("RESET VIEWMODEL", "cfov_viewmodel_fov", 54)
	end)
end

-- https://github.com/Facepunch/garrysmod/blob/master/garrysmod/gamemodes/base/gamemode/cl_init.lua#L357
local function CalcCustomFOV(ply, pos, ang, fov)
	local view = {}

	-- Same verifications as the source function
	local vehicle = ply:GetVehicle()
	local weapon = ply:GetActiveWeapon()

	if (IsValid(weapon) and weapon.CalcView) then
		local origin, angles, weapon_fov = weapon.CalcView(weapon, ply, Vector(pos), Angle(ang), fov)
		pos, ang, fov = origin or pos, angles or ang, weapon_fov or fov
	end

	view.origin = pos
	view.angles = ang
	view.fov = fov + (GetConVar("cfov"):GetInt() - GetConVar("fov_desired"):GetInt())

	if (IsValid(vehicle)) then return hook.Run("CalcVehicleView", vehicle, ply, view) or view end

	return view
end

local function CalcFixedViewmodel(cfov, fov, base_viewmodel)
	-- f(x) = ax + b
	-- f(fov) = -0.994 * fov + viewmodel_fov(=54 default)
	return -0.994 * (cfov - fov) + base_viewmodel
end

local function updateViewmodel(ply, base_viewmodel)
	if GetConVar("cfov_viewmodel_fixed"):GetBool() then
		RunConsoleCommand("viewmodel_fov", CalcFixedViewmodel(
			GetConVar("cfov"):GetInt(), ply:GetFOV(), base_viewmodel))
	else
		RunConsoleCommand("viewmodel_fov", base_viewmodel)
	end
end

local function InitCustomFOV(switch)
	if !switch then
		hook.Remove("CalcView", "CalcView.CustomFOV")
		RunConsoleCommand("viewmodel_fov", GetConVar("cfov_viewmodel_fov"):GetDefault())
		cvars.RemoveChangeCallback("cfov", "callback.updateViewmodel")
		cvars.RemoveChangeCallback("cfov_viewmodel_fixed", "callback.updateViewmodel")
		cvars.RemoveChangeCallback("cfov_viewmodel_fov", "callback.updateViewmodel")
		return
	end

	local ply = LocalPlayer()
	local updateViewmodelFunc = function()
		updateViewmodel(ply, GetConVar("cfov_viewmodel_fov"):GetInt())
	end
	hook.Add("CalcView", "CalcView.CustomFOV", CalcCustomFOV)
	updateViewmodel(ply, GetConVar("cfov_viewmodel_fov"):GetInt())
	cvars.AddChangeCallback("cfov", updateViewmodelFunc, "callback.updateViewmodel")
	cvars.AddChangeCallback("cfov_viewmodel_fixed", updateViewmodelFunc, "callback.updateViewmodel")
	cvars.AddChangeCallback("cfov_viewmodel_fov", updateViewmodelFunc, "callback.updateViewmodel")
end

cvars.AddChangeCallback("cfov_enable", function(cvar_str)
	InitCustomFOV(GetConVar(cvar_str):GetBool())
end)

hook.Add("AddToolMenuCategories", "AddToolMenuCategories.Options.CustomFOV", buildCustomFOVMenu)
hook.Add("InitPostEntity", "InitPostEntity.CustomFOV", function()
	InitCustomFOV(GetConVar("cfov_enable"):GetBool())
end)
