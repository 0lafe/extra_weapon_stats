if not EWS then
	EWS = {
		mod_path = ModPath,
		required = {},
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

	Hooks:Add("LocalizationManagerPostInit", "EWS_LocalizationManagerPostInit", function(loc_manager)
		loc_manager:load_localization_file(EWS.mod_path .. "loc/english.json")
	end)
end

if RequiredScript and not EWS.required[RequiredScript] then
	local fname = EWS.mod_path .. RequiredScript:gsub(".+/(.+)", "lua/%1.lua")

	if io.file_is_readable(fname) then
		dofile(fname)
	end

	EWS.required[RequiredScript] = true
end
