local function noop() end

-- fake weapon unit with necessary functions
local function make_unit()
	local unit = {}

	function unit:alive()
		return true
	end

	function unit:base()
		return self._ews_base
	end

	function unit:timer()
		return EWS.sim_timer
	end

	unit.set_extension_update_enabled = noop
	unit.get_object = noop
	unit.orientation_object = noop

	return unit
end

-- fake player standard
local function make_player_state(env, weapon)
	local state = setmetatable({
		_equipped_unit = weapon._unit,
		_state_data = {},
		_change_weapon_data = {},
		_ext_camera = { play_redirect = noop },
		_ext_network = { send = noop },
		_interupt_action_steelsight = noop,
		_interupt_action_running = noop,
		_interupt_action_charging_weapon = noop,
		set_animation_weapon_hold = noop
	}, env.PlayerStandard)

	state:set_animation_state("standard")

	return state
end

-- Class used as basis for fake weapons retrieving stats
local EWSWeaponContext = {}
EWSWeaponContext.__index = EWSWeaponContext

function EWSWeaponContext:weapon()
	if self._weapon == nil then
		self._weapon = self:_create_weapon() or false
	end

	return self._weapon or nil
end

-- refills main and underbarrel weapon
local function refill(weapon)
	local ammo = weapon:ammo_base()

	weapon:replenish()

	if ammo ~= weapon then
		ammo:replenish()
	end
end

local VISUAL_METHODS = {
	"tweak_data_anim_play",
	"tweak_data_anim_play_at_end",
	"tweak_data_anim_stop",
	"update_ammo_objects",
	"check_bullet_objects",
	"set_magazine_empty"
}

-- creates a stand in weapon base, as well as weapon unit
function EWSWeaponContext:_create_weapon()
	if self.underbarrel and not self:has_underbarrel() then
		-- empty return for when comparing underbarrels to a weapon without one
		return nil
	end

	local weapon_base_class = self._env[self.class_name]

	local unit = make_unit()

	local weapon = setmetatable({
		name_id = self.weapon_id
	}, weapon_base_class)

	unit._ews_base = weapon

	weapon:init(unit)
	weapon:set_factory_data(self.factory_id)

	weapon._blueprint = self.blueprint
	weapon._parts = {}
	weapon._assembly_complete = true

	for _, name in ipairs(VISUAL_METHODS) do
		weapon[name] = noop
	end

	weapon:_update_stats_values()

	if self.underbarrel then
		self._underbarrel = self:_attach_underbarrel(weapon)

		if not self._underbarrel then
			return nil
		end
	end

	return weapon
end

-- builds and enables underbarrel attachment
function EWSWeaponContext:_attach_underbarrel(weapon)
	local part = self:has_underbarrel() and self._underbarrel_part
	local gadget_class = part and self._env[part.class]

	if not gadget_class then
		return nil
	end

	local unit = make_unit()
	local gadget = setmetatable(
		clone(part.vars),
		gadget_class
	)

	unit._ews_base = gadget

	gadget:init(unit)

	for key, value in pairs(part.vars) do
		if gadget[key] == nil then
			gadget[key] = value
		end
	end

	for _, name in ipairs(VISUAL_METHODS) do
		gadget[name] = noop
	end

	gadget._on = true
	gadget:setup_data(
		{},
		1,
		managers.weapon_factory:get_underbarrel_ammo_data_from_weapon(
			self.factory_id,
			self.blueprint
		)
	)

	weapon._parts[part.id] = {
		unit = unit
	}

	weapon._cached_gadget = nil
	weapon._cached_gadgets = nil
	weapon:_update_stats_values(true)

	return gadget
end

function EWSWeaponContext:set_underbarrel(state)
	state = state or false

	if state ~= self.underbarrel then
		self.underbarrel = state
		self._weapon = nil
		self._underbarrel = nil
	end
end

function EWSWeaponContext:has_underbarrel()
	if self._underbarrel_part == nil then
		self._underbarrel_part = self:_find_underbarrel() or false
	end

	return self._underbarrel_part ~= false
end

-- gives underbarrel stats used to construct vanilla stat rows
-- things like damage, acc, stab, etc
function EWSWeaponContext:underbarrel_stats()
	local weapon = self:weapon()
	local gadget = self._underbarrel

	if not weapon or not gadget then
		return nil
	end

	local tweak = tweak_data.weapon[gadget.name_id]
	local ammo = weapon:ammo_base()
	local shooter = self:shooting_weapon()
	local fire_rate = tweak.fire_mode_data and tweak.fire_mode_data.fire_rate
	local damage

	if gadget._launcher_projectile then
		local projectile = tweak.projectile_types and tweak.projectile_types[gadget._launcher_projectile] or gadget._launcher_projectile
		local projectile_tweak = tweak_data.projectiles[projectile]
		local modifier = tweak.stats_modifiers and tweak.stats_modifiers.damage or 1

		damage = projectile_tweak and projectile_tweak.damage and projectile_tweak.damage * modifier
	else
		damage = shooter._damage * 10
	end

	return {
		name_id = gadget.name_id,
		categories = tweak.categories,
		fire_mode = tweak.FIRE_MODE or "single",
		magazine = ammo:get_ammo_max_per_clip(),
		totalammo = ammo:get_ammo_max(),
		fire_rate = fire_rate and fire_rate > 0 and 60 / fire_rate or nil,
		damage = damage,
		indices = shooter._current_stats_indices
	}
end

-- returns the acting weapon when shot
-- could be underbarrel if enabled otherwise base weapon
function EWSWeaponContext:shooting_weapon()
	local weapon = self:weapon()
	local gadget = self._underbarrel

	if weapon and gadget and gadget._get_spread then
		return gadget
	end

	return weapon
end

function EWSWeaponContext:max_clip()
	local weapon = self:weapon()

	return weapon and weapon:ammo_base():get_ammo_max_per_clip() or 0
end

function EWSWeaponContext:ammo_pickup()
	local weapon = self:weapon()

	if not weapon then
		return nil
	end

	local capture = {}
	local ammo = weapon:ammo_base()

	refill(weapon)
	ammo:set_ammo_total(0)

	EWS.lerp_capture = capture
	local ok = pcall(weapon.add_ammo, weapon, 1)
	EWS.lerp_capture = nil

	ammo:remove_pickup_ammo()
	refill(weapon)

	if not ok or not capture.min then
		return nil
	end

	return {
		main = capture.min,
		extra = capture.max
	}
end

function EWSWeaponContext:is_shell_reload()
	local weapon = self:weapon()

	return weapon and weapon:reload_interuptable() or false
end

local RELOAD_TIMERS = {
	"reload_enter_expire_t",
	"reload_expire_t",
	"reload_exit_expire_t"
}

local MAX_RELOAD_STEPS = 256

-- slight offset needed to handle actions happening on a next game tick
local EVENT_STEP = 1e-6

-- simulates reloading weapon to get accurate reload timers
function EWSWeaponContext:reload(rounds_missing, interrupt)
	local weapon = self:weapon()

	if not weapon then
		return nil
	end

	local ammo = weapon:ammo_base()

	refill(weapon)
	weapon._current_reload_speed_multiplier = nil

	local max_clip = ammo:get_ammo_max_per_clip()
	local in_clip = rounds_missing and math.max(max_clip - rounds_missing, 0) or 0

	ammo:set_ammo_remaining_in_clip(in_clip)

	local clock = EWS.sim_timer
	local state = make_player_state(self._env, weapon)
	local timers = state._state_data
	local rounds = {}
	local last_ammo = in_clip
	local t = 0

	clock.t = t

	state:_start_action_reload_enter(t)

	if interrupt and weapon:reload_interuptable() then
		state._queue_reload_interupt = true
	end

	for _ = 1, MAX_RELOAD_STEPS do
		local event_t

		for _, name in ipairs(RELOAD_TIMERS) do
			local expire_t = timers[name]

			if expire_t and (not event_t or expire_t < event_t) then
				event_t = expire_t
			end
		end

		local shell_t = timers.reload_expire_t and weapon._next_shell_reloded_t

		if shell_t and (not event_t or shell_t < event_t) then
			event_t = shell_t
		end

		if not event_t then
			if t == 0 then
				return nil
			end

			return {
				total = t,
				rounds = rounds
			}
		end

		t = event_t
		clock.t = t + EVENT_STEP

		state:_update_reload_timers(clock.t, 0, {})

		local in_clip_now = ammo:get_ammo_remaining_in_clip()

		if in_clip_now ~= last_ammo then
			table.insert(rounds, {
				t = t,
				ammo = in_clip_now
			})

			last_ammo = in_clip_now
		end
	end

	error("reload did not finish in " .. MAX_RELOAD_STEPS .. " steps")
end

function EWSWeaponContext:reload_stats(rounds_missing)
	if not self:is_shell_reload() then
		local result = self:reload(rounds_missing)

		return result and result.total and {
			main = result.total
		}
	end

	local interrupted = self:reload(rounds_missing, true)

	if not interrupted then
		return nil
	end

	local stats = {
		main = interrupted.total
	}

	local rounds = self:reload(rounds_missing).rounds
	local first, last = rounds[1], rounds[#rounds]

	-- Average reload times for reload queue weapons
	if #rounds > 1 then
		stats.extra = (last.t - first.t) / (#rounds - 1)
	end

	return stats
end

-- simulates swapping to and then away from the weapon to get swap timers
function EWSWeaponContext:equip_stats()
	local weapon = self:weapon()

	if not weapon then
		return nil
	end

	if self._underbarrel then
		local timers = tweak_data.weapon[self._underbarrel.name_id].timers or {}

		return {
			main = timers.equip_underbarrel or 0,
			extra = timers.unequip_underbarrel or 0
		}
	end

	local state = make_player_state(self._env, weapon)

	state:_start_action_equip_weapon(0)
	state:_start_action_unequip_weapon(0, {})

	local equip = state._equip_weapon_expire_t
	local unequip = state._unequip_weapon_expire_t

	return equip and unequip and {
		main = equip,
		extra = unequip
	}
end

local function make_user_unit(state)
	local unit = {
		_movement = { _current_state = state }
	}

	function unit:alive()
		return true
	end

	function unit:movement()
		return self._movement
	end

	return unit
end

function EWSWeaponContext:spread(ducking, moving, direction)
	local weapon = self:shooting_weapon()

	if not weapon or weapon:is_category("saw") then
		return nil
	end

	local state = make_player_state(self._env, weapon)
	local user_unit = make_user_unit(state)

	state._moving = moving
	state._state_data.ducking = ducking

	state._state_data.in_steelsight = false
	local hipfire_x, hipfire_y = weapon:_get_spread(user_unit)

	state._state_data.in_steelsight = true
	local ads_x, ads_y = weapon:_get_spread(user_unit)

	if direction == "horizontal" then
		return {
			main = hipfire_x,
			extra = ads_x
		}
	else
		return {
			main = hipfire_y,
			extra = ads_y
		}
	end
end

-- not super ideal way to get pellet count
-- idk a better option
function EWSWeaponContext:pellets()
	local weapon = self:shooting_weapon()

	if not weapon then
		return nil
	end

	return {
		main = not weapon.flamethrower and weapon._rays or 1
	}
end

-- max and min charge times for bows
function EWSWeaponContext:charge_stats()
	local weapon = self:shooting_weapon()

	if not weapon or not weapon.charge_multiplier then
		return nil
	end

	local max_t = weapon:charge_max_t()
	-- min charge is 1/5 max charge
	-- not in the tweak data, just in bowbase
	-- could be weird at some point
	local min_t = max_t * 0.2

	return {
		main = max_t,
		extra = min_t
	}
end

function EWSWeaponContext:damage_falloff(steelsight, step, count)
	local weapon = self:weapon() and (self._underbarrel or self:weapon())

	if not weapon or not weapon._optimal_distance or weapon._optimal_distance + weapon._optimal_range == 0 then
		return nil
	end

	local state = make_player_state(self._env, weapon)
	local user_unit = make_user_unit(state)
	local col_ray = {}
	local multipliers = {}

	state._state_data.in_steelsight = steelsight

	for i = 1, count do
		col_ray.distance = (i - 1) * step
		multipliers[i] = weapon:get_damage_falloff(1, col_ray, user_unit)
	end

	return {
		damage = weapon._damage * 10,
		multipliers = multipliers
	}
end

-- Ugly but idk how else to grab the specific base class otherwise
local unit_extension_cache = {}
local function unit_base_extension(unit_path)
	local cached = unit_extension_cache[unit_path]

	if cached ~= nil then
		return cached or nil
	end

	local base

	pcall(function()
		local ids_path = Idstring(unit_path)

		if not DB:has(Idstring("unit"), ids_path) then
			return
		end

		local data = ScriptSerializer:from_custom_xml(DB:open(Idstring("unit"), ids_path):read())

		for _, extension in ipairs(data and data.extensions or {}) do
			if extension.name == "base" then
				local vars = {}

				for _, var in ipairs(extension) do
					if type(var) == "table" and var.name ~= nil then
						vars[var.name] = var.value
					end
				end

				base = {
					class = extension.class,
					vars = vars
				}

				break
			end
		end
	end)

	unit_extension_cache[unit_path] = base or false

	return base
end

local function unit_base_class(factory_id, blueprint)
	local unit_path = managers.weapon_factory:get_weapon_unit(factory_id, blueprint)
	local base = unit_path and unit_base_extension(unit_path)

	return base and base.class
end

function EWSWeaponContext:_find_underbarrel()
	local weapon_factory = managers.weapon_factory
	local part_id = weapon_factory:get_parts_from_weapon_by_type_or_perk("underbarrel", self.factory_id, self.blueprint)[1]

	if not part_id then
		return nil
	end

	local override = weapon_factory:_get_override_parts(self.factory_id, self.blueprint)
	local part = weapon_factory:_part_data(part_id, self.factory_id, override)
	local base = part.unit and unit_base_extension(part.unit)

	return base and base.class and {
		id = part_id,
		class = base.class,
		vars = base.vars
	}
end

function EWS:weapon_context(weapon_id, factory_id, blueprint)
	local env = self:get_classes()

	if not env or not tweak_data.weapon[weapon_id] then
		return nil
	end

	return setmetatable({
		_env = env,
		weapon_id = weapon_id,
		factory_id = factory_id,
		blueprint = blueprint,
		class_name = unit_base_class(factory_id, blueprint)
	}, EWSWeaponContext)
end

function EWS:weapon_context_for_slot(slot_data)
	if not slot_data or slot_data.empty_slot or not tweak_data.weapon[slot_data.name or ""] then
		return nil
	end

	local category = slot_data.category
	local slot = slot_data.slot
	local crafted = category and slot and managers.blackmarket:get_crafted_category_slot(category, slot)
	local weapon_id = crafted and crafted.weapon_id or slot_data.name
	local factory_id = managers.weapon_factory:get_factory_id_by_weapon_id(weapon_id)
	local blueprint = crafted and managers.blackmarket:get_weapon_blueprint(category, slot) or managers.weapon_factory:get_default_blueprint_by_factory_id(factory_id)

	return self:weapon_context(weapon_id, factory_id, deep_clone(blueprint))
end
