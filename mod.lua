if not EWS then
	EWS = {
		mod_path = ModPath,
		_env = nil,
		state = {
			ducking = false,
			moving = false,
			underbarrel = false
		}
	}

	function EWS:log(msg)
		log("[EWS] " .. tostring(msg))
	end

	dofile(EWS.mod_path .. "lib/class_duping.lua")
	dofile(EWS.mod_path .. "lib/weapon_context.lua")
	dofile(EWS.mod_path .. "lib/falloff_chart.lua")
	dofile(EWS.mod_path .. "lua/blackmarketgui.lua")

	Hooks:Add("LocalizationManagerPostInit", "EWS_LocalizationManagerPostInit", function(loc_manager)
		loc_manager:load_localization_file(EWS.mod_path .. "loc/english.json")
	end)
end
