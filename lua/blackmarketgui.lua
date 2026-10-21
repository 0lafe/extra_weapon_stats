-- Flag set when gui is of a type that should move dlc
local dlc_info_moved = false

-- Inventories that want rich weapon stats
local function moves_dlc_info(component_data)
	if not component_data then
		return false
	end

	local category = component_data.category

	return category == "primaries"
		or category == "secondaries"
		or component_data.topic_id == "bm_menu_melee_weapons"
		or component_data.topic_id == "bm_menu_buy_weapon_title"
end

local function tab_identifier(self)
	local tab = self._tabs and self._tabs[self._selected]

	return tab and tab._data.identifier
end

local function is_weapon_mod_tab(self)
	return tab_identifier(self) == self.identifiers.weapon_mod
end

local function is_ews_identifier(self, identifier)
	return identifier == self.identifiers.weapon
		or identifier == self.identifiers.weapon_mod
		or identifier == self.identifiers.weapon_cosmetic
end

function BlackMarketGuiSlotItem:ews_set_top_texts_visible(state)
	for _, name in ipairs({ "equipped_text", "custom_name_text" }) do
		local text = self._panel:child(name)

		if alive(text) then
			text:set_visible(state)
		end
	end
end

Hooks:PreHook(BlackMarketGuiSlotItem, "select", "EWS_BlackMarketGuiSlotItem_select", function(self)
	if dlc_info_moved then
		self:ews_set_top_texts_visible(false)
	end
end)

Hooks:PostHook(BlackMarketGuiSlotItem, "deselect", "EWS_BlackMarketGuiSlotItem_deselect", function(self)
	self:ews_set_top_texts_visible(true)
end)

Hooks:PreHook(BlackMarketGui, "_setup", "EWS_BlackMarketGui_setup_pre", function(self, is_start_page, component_data)
	dlc_info_moved = moves_dlc_info(component_data)

	self._ews_dlc_info_text = nil
	self._ews_mod_dlc_text = nil
	self._ews_screen = nil
	self._ews_stat_texts = nil
	self._ews_melee_texts = nil
	self._ews_stance_buttons = nil
	self._ews_underbarrel_available = nil
	self._ews_underbarrel_active = nil
	self._ews_vanilla_shown = nil
	self._ews_falloff = nil
end)

-- Runs once when menu is opened
Hooks:PostHook(BlackMarketGui, "_setup", "EWS_BlackMarketGui_setup_post", function(self, is_start_page, component_data)
	self:ews_setup()
end)

-- Puts back a global value hidden by hide_mod_dlc
local function restore_mod_global_value(self)
	local hidden = self._ews_hidden_global_value

	if hidden then
		hidden.slot_data.global_value = hidden.global_value
		self._ews_hidden_global_value = nil
	end
end

-- The DLC line and color vanilla would show for a weapon mod's global value
local function mod_dlc_line(global_value)
	if not global_value or global_value == "normal" then
		return nil
	end

	local global_value_data = tweak_data.lootdrop.global_values[global_value]

	if not global_value_data or not global_value_data.desc_id then
		return nil
	end

	return managers.localization:to_upper_text(global_value_data.desc_id), global_value_data.color
end

-- Replaces vanilla's side panel DLC info text with one on our panel, once
local function move_dlc_info(self)
	if not dlc_info_moved or alive(self._ews_dlc_info_text) then
		return
	end

	local dlc_info_text_index = 4
	local dlc_text = self._info_texts and self._info_texts[dlc_info_text_index]

	if not alive(dlc_text) then
		return
	end

	self._ews_dlc_info_text = self._panel:text({
		text = dlc_text:text(),
		wrap = dlc_text:wrap(),
		name = dlc_text:name(),
		word_wrap = dlc_text:word_wrap(),
		layer = 10,
		font_size = tweak_data.menu.pd2_tiny_font_size - 3,
		font = tweak_data.menu.pd2_small_font,
		color = dlc_text:color(),
		width = dlc_text:w(),
		align = "center"
	})

	self._info_texts[dlc_info_text_index] = self._ews_dlc_info_text

	dlc_text:parent():remove(dlc_text)
end

local function hide_mod_dlc(self)
	restore_mod_global_value(self)

	local slot_data = self._slot_data

	if is_weapon_mod_tab(self) and slot_data and slot_data.global_value then
		self._ews_hidden_global_value = {
			slot_data = slot_data,
			global_value = slot_data.global_value
		}

		slot_data.global_value = nil
	end
end

-- Puts the moved DLC info text onto the selected slot
local function place_dlc_info(self)
	local text = self._ews_dlc_info_text
	local slot = self._selected_slot

	if not alive(text) or not slot or not alive(slot._panel) then
		return
	end

	local slot_panel = slot._panel

	text:set_w(slot_panel:w())
	text:set_world_x(slot_panel:world_left())
	text:set_font_size(tweak_data.menu.pd2_tiny_font_size - 3)

	if slot._data.empty_slot then
		text:set_world_bottom(slot_panel:world_bottom())
	else
		text:set_world_top(slot_panel:world_top() + 6)
	end

	local tab = self._tabs[self._selected]
	local scroll_bar = tab and alive(tab._scroll_bar_panel) and tab._scroll_bar_panel:child("scroll_bar")

	if alive(scroll_bar) then
		text:set_visible(slot_panel:center_y() > scroll_bar:y())
	end
end

local function place_mod_dlc_text(self)
	local hidden = self._ews_hidden_global_value
	local line, color = mod_dlc_line(hidden and hidden.global_value)

	restore_mod_global_value(self)

	local text = self._ews_mod_dlc_text
	local slot = self._selected_slot
	local slot_panel = slot and slot._panel

	if not line or not alive(slot_panel) then
		if alive(text) then
			text:hide()
		end

		return
	end

	if not alive(text) then
		text = self._panel:text({
			text = "",
			layer = 10,
			wrap = true,
			word_wrap = true,
			align = "center",
			font_size = tweak_data.menu.pd2_tiny_font_size - 3,
			font = tweak_data.menu.pd2_small_font
		})

		self._ews_mod_dlc_text = text
	end

	text:set_text(line)
	text:set_color(color or tweak_data.screen_colors.text)
	text:set_w(slot_panel:w())

	local _, _, _, h = text:text_rect()

	text:set_h(h)
	text:set_world_x(slot_panel:world_left())

	local bottom = slot_panel:world_bottom() - 2
	local corner_text = slot_panel:child("corner_text")

	if alive(corner_text) and corner_text:visible() and corner_text:text() ~= "" then
		local _, _, _, corner_h = corner_text:text_rect()

		bottom = bottom - corner_h
	end

	text:set_world_bottom(bottom)
	text:show()
end

local function hides_weapon_value(self)
	return self._ews_screen and tab_identifier(self) == self.identifiers.weapon and not self._data.buying_weapon
end

local function restore_weapon_value(self)
	local hidden = self._ews_hidden_price

	if hidden then
		hidden.slot_data.price = hidden.price
		self._ews_hidden_price = nil
	end
end

-- remove weapon value to increase space in stat menu
local function hide_weapon_value(self)
	restore_weapon_value(self)

	local slot_data = self._slot_data

	if hides_weapon_value(self) and slot_data and slot_data.price then
		self._ews_hidden_price = {
			slot_data = slot_data,
			price = slot_data.price
		}

		slot_data.price = 0
	end
end

Hooks:PreHook(BlackMarketGui, "update_info_text", "EWS_BlackMarketGui_move_dlc_info", function(self)
	move_dlc_info(self)
	hide_mod_dlc(self)
	hide_weapon_value(self)
end)

Hooks:PostHook(BlackMarketGui, "update_info_text", "EWS_BlackMarketGui_update_info_text", function(self)
	place_dlc_info(self)
	place_mod_dlc_text(self)
	restore_weapon_value(self)
end)

-- Runs on tab switch
Hooks:PostHook(BlackMarketGui, "_update_borders", "EWS_BlackMarketGui_update_borders", function(self)
	self:ews_apply_layout()
end)

local VANILLA_STAT_SKILLS = {
	spread = function(stats, index, present)
		return managers.blackmarket:accuracy_multiplier(stats.name_id, stats.categories, false, nil, nil, stats
				.fire_mode),
			managers.blackmarket:accuracy_addend(stats.name_id, stats.categories, index, false, nil, stats.fire_mode) *
			present
	end,
	recoil = function(stats, index, present)
		return managers.blackmarket:recoil_multiplier(stats.name_id, stats.categories, false),
			managers.blackmarket:recoil_addend(stats.name_id, stats.categories, index, false) * present
	end,
	suppression = function(stats)
		return managers.blackmarket:threat_multiplier(stats.name_id, stats.categories, false), 0
	end
}

-- convert stats to vanilla stat display values
-- logic is close to what vanilla does
local function vanilla_index_stat(stats, shown)
	local name = shown.name
	local tweak_stats = tweak_data.weapon.stats[name]
	local index = stats.indices and stats.indices[name]

	if not tweak_stats or not index then
		return nil
	end

	local present = tweak_data.gui.stats_present_multiplier
	local low = math.min(tweak_stats[1], tweak_stats[#tweak_stats]) * present
	local high = math.max(tweak_stats[1], tweak_stats[#tweak_stats]) * present
	local offset = shown.offset and low or 0
	local percent_max = (shown.index and #tweak_stats or high) - offset

	index = math.clamp(index, 1, #tweak_stats)

	local value = (shown.index and index or tweak_stats[index] * present) - offset

	if shown.revert then
		value = high - offset - value
	end

	if shown.percent then
		value = value / percent_max * 100
	end

	local multiplier, modifier = VANILLA_STAT_SKILLS[name](stats, index, present)

	if modifier ~= 0 then
		if shown.revert then
			modifier = -modifier
		end

		if shown.percent then
			modifier = modifier / percent_max * 100
		end
	end

	if shown.revert then
		multiplier = 1 / math.max(multiplier, 0.01)
	end

	return math.max(modifier + value * multiplier, 0)
end

-- simple underbarrel lookup stats
local function underbarrel_stat(key)
	return function(context)
		local stats = context:underbarrel_stats()

		return stats and stats[key]
	end
end

-- weird underbarrel stats needing translation
local function underbarrel_index_stat(context, shown)
	local stats = context:underbarrel_stats()

	return stats and vanilla_index_stat(stats, shown)
end

-- ALL stats shown
local WEAPON_STATS = {
	{ name = "magazine",    vanilla = true, value = underbarrel_stat("magazine") },
	{ name = "totalammo",   vanilla = true, value = underbarrel_stat("totalammo") },
	{ name = "fire_rate",   vanilla = true, value = underbarrel_stat("fire_rate") },
	{ name = "damage",      vanilla = true, value = underbarrel_stat("damage") },
	{ name = "spread",      vanilla = true, value = underbarrel_index_stat },
	{ name = "recoil",      vanilla = true, value = underbarrel_index_stat },
	{ name = "concealment", vanilla = true },
	{ name = "suppression", vanilla = true, value = underbarrel_index_stat },
	{
		name = "ews_reload_tactical",
		value = function(context)
			local max_clip = context:max_clip()

			if max_clip <= 1 then
				return nil
			end

			return context:reload_stats(context:is_shell_reload() and max_clip - 1 or 1)
		end,
		format_type = "seconds",
		better = "lower"
	},
	{
		name = "ews_reload_empty",
		value = function(context)
			return context:reload_stats()
		end,
		format_type = "seconds",
		better = "lower"
	},
	{
		name = "ews_equip_delay",
		value = function(context)
			return context:equip_stats()
		end,
		format_type = "seconds",
		better = "lower"
	},
	{
		name = "ews_ammo_pickup",
		value = function(context)
			return context:ammo_pickup()
		end,
		format_type = "decimal",
		better = "higher"
	},
	{
		name = "ews_spread_hor",
		value = function(context)
			return context:spread(
				EWS.state.ducking,
				EWS.state.moving,
				"horizontal"
			)
		end,
		format_type = "degrees",
		better = "lower"
	},
	{
		name = "ews_spread_vert",
		value = function(context)
			return context:spread(
				EWS.state.ducking,
				EWS.state.moving,
				"vertical"
			)
		end,
		format_type = "degrees",
		better = "lower"
	},
	{
		name = "ews_pellets",
		value = function(context)
			return context:pellets()
		end,
		format_type = "integer",
		better = "higher"
	},
	{
		name = "ews_charge_time",
		value = function(context)
			return context:charge_stats()
		end,
		format_type = "seconds",
		better = "lower"
	}
}

local function melee_tweak(melee_id)
	return tweak_data.blackmarket.melee_weapons[melee_id]
end

local function melee_timer(get)
	return function(melee_id)
		local melee = melee_tweak(melee_id)

		return melee and {
			main = get(melee)
		}
	end
end

local function melee_dot(melee)
	return not melee.random_special_effects and melee.dot_data_name and tweak_data.dot:get_dot_data(melee.dot_data_name)
end

local function melee_dot_stat(get)
	return function(melee_id)
		local melee = melee_tweak(melee_id)
		local dot = melee and melee_dot(melee)

		return dot and get(dot)
	end
end

local function melee_effect(melee_id)
	local melee = melee_tweak(melee_id)

	if not melee then
		return nil
	end

	-- one picked by weight on each hit (Piggy Hammer)
	if melee.random_special_effects then
		return {
			main = managers.localization:text("ews_melee_effect_random")
		}
	end

	if melee.tase_data then
		return {
			main = managers.localization:text("ews_melee_effect_tase")
		}
	end

	local dot = melee_dot(melee)

	if dot then
		local effects = {
			poison = "ews_melee_effect_poison",
			fire = "ews_melee_effect_fire"
		}

		local text_id = effects[dot.variant]

		return {
			main = text_id and managers.localization:text(text_id) or tostring(dot.variant)
		}
	end

	return nil
end

local function melee_effect_chance(melee_id)
	local melee = melee_tweak(melee_id)

	if not melee or melee.random_special_effects then
		return nil
	end

	if melee.tase_data then
		return {
			main = 1
		}
	end

	local dot = melee_dot(melee)

	return dot and {
		main = dot.dot_trigger_chance or 1
	}
end

local MELEE_STATS = {
	{
		name = "ews_melee_attack_delay",
		value = melee_timer(function(melee)
			if melee.instant then
				return 0
			end

			return math.min(melee.melee_damage_delay or 0, melee.repeat_expire_t)
		end),
		format_type = "seconds",
		better = "lower"
	},
	{
		name = "ews_melee_cooldown",
		value = melee_timer(function(melee)
			return math.min(melee.repeat_expire_t, melee.expire_t)
		end),
		format_type = "seconds",
		better = "lower"
	},
	{
		name = "ews_melee_recovery",
		value = melee_timer(function(melee)
			return melee.expire_t
		end),
		format_type = "seconds",
		better = "lower"
	},
	{
		name = "ews_melee_effect",
		value = melee_effect,
		format_type = "text"
	},
	{
		name = "ews_melee_effect_chance",
		value = melee_effect_chance,
		format_type = "percent",
		better = "higher"
	},
	{
		name = "ews_melee_effect_duration",
		value = melee_dot_stat(function(dot)
			return {
				main = dot.dot_length
			}
		end),
		format_type = "seconds",
		better = "higher"
	},
	{
		name = "ews_melee_effect_damage",
		value = melee_dot_stat(function(dot)
			local present = tweak_data.gui.stats_present_multiplier
			local ticks = math.max(1, math.floor(dot.dot_length / dot.dot_tick_period))

			return {
				main = ticks * dot.dot_damage * present,
				extra = dot.dot_damage * present
			}
		end),
		format_type = "number",
		better = "higher"
	}
}

local MELEE_STAT_COLUMNS = {
	{ name = "name", x = 2,   size = 100 },
	{ name = "a1",   x = 102, size = 55, align = "right" },
	{ name = "b1",   x = 157, size = 33, align = "left" },
	{ name = "a2",   x = 190, size = 55, align = "right" },
	{ name = "b2",   x = 245, size = 33, align = "left" }
}

local EXTRA_STAT_COLUMNS = {
	{ name = "name", size = 100 },
	{ name = "a1",   size = 50, align = "right" },
	{ name = "b1",   size = 50, align = "left" },
	{ name = "a2",   size = 50, align = "right" },
	{ name = "b2",   size = 50, align = "left" }
}

local STAT_ROW_HEIGHT = 20

-- Row panel holding a vanilla weapon stat
local function weapon_stat_row(self, stat_name)
	local texts = self._stats_texts and self._stats_texts[stat_name]
	local name_text = texts and texts.name

	return alive(name_text) and name_text:parent():parent() or nil
end

function BlackMarketGui:ews_setup()
	-- melee only adds rows, it keeps vanilla's layout
	if tab_identifier(self) == self.identifiers.melee_weapon then
		if alive(self._mweapon_stats_panel) then
			self:ews_build_melee_rows()
			self:ews_refresh_info()
		end

		return
	end

	if not is_ews_identifier(self, tab_identifier(self)) or not alive(self._weapon_info_panel) then
		return
	end

	self._ews_screen = true

	-- remove bg on mod menu detection
	if self._data.use_bgs then
		local detection_children = self._detection_panel:children()

		for i = 1, 2 do
			if alive(detection_children[i]) then
				detection_children[i]:hide()
			end
		end
	end

	self._panel:child("back_button"):set_right(self._box_panel:right())

	if alive(self._rweapon_stats_panel) then
		-- take the space of the hidden value line
		if hides_weapon_value(self) then
			self._stats_panel:move(0, -tweak_data.menu.pd2_small_font_size)
		end

		self:ews_build_stat_rows()
	end

	self:ews_apply_layout()
	self:ews_refresh_info()
end

function BlackMarketGui:ews_refresh_info()
	self:show_stats()

	if self._slot_data then
		self:update_info_text()
	end
end

-- The parts of the layout vanilla's _update_borders resets
function BlackMarketGui:ews_apply_layout()
	if not self._ews_screen then
		return
	end

	local back_button = self._panel:child("back_button")

	if self._detection_panel:visible() then
		self._detection_panel:set_right(back_button:left() - 8)
		self._detection_panel:set_center_y(back_button:center_y())
		self._detection_border:hide()
	end

	self._btn_panel:set_bottom(self._panel:bottom())

	local old_h = self._weapon_info_panel:h()
	local weapon_info_height = self._panel:bottom()
		- (self._button_count > 0 and self._btn_panel:h() + 8 or 0)
		- self._weapon_info_panel:top()

	self._weapon_info_panel:set_h(weapon_info_height)
	self._info_texts_panel:set_h(weapon_info_height - 20)

	if alive(self._stats_panel) then
		self._stats_panel:set_h(weapon_info_height - self._stats_panel:top())
	end

	if alive(self._rweapon_stats_panel) then
		self._rweapon_stats_panel:set_h(weapon_info_height)
	end

	if old_h ~= self._weapon_info_panel:h() then
		self._weapon_info_border:create_sides(self._weapon_info_panel, {
			sides = { 1, 1, 1, 1 }
		})
	end
end

function BlackMarketGui:ews_build_stat_rows()
	local first_stat = self._stats_shown and self._stats_shown[1]
	local first_row = first_stat and weapon_stat_row(self, first_stat.name)
	local y = first_row and first_row:y() or STAT_ROW_HEIGHT
	local count = 0

	self:ews_add_stance_buttons()

	y = y + STAT_ROW_HEIGHT

	local function place(row)
		count = count + 1

		row:set_y(y)
		y = y + row:h()

		return count % 2 == 0
	end

	local shown_index = {}
	self._ews_vanilla_shown = {}

	for i, stat in ipairs(self._stats_shown or {}) do
		shown_index[stat.name] = i
		self._ews_vanilla_shown[stat.name] = stat

		local row = weapon_stat_row(self, stat.name)

		if row then
			row:hide()
		end
	end

	self._ews_stat_texts = {}

	for _, stat in ipairs(WEAPON_STATS) do
		if stat.vanilla then
			self:ews_place_vanilla_row(stat.name, shown_index[stat.name], place)
		else
			self._ews_stat_texts[stat.name] = self:ews_add_stat_row(self._rweapon_stats_panel, EXTRA_STAT_COLUMNS, stat, place)
		end
	end

	self:ews_add_falloff_charts(y)
end

function BlackMarketGui:ews_place_vanilla_row(name, index, place)
	local row = weapon_stat_row(self, name)

	if not row or not self._ews_vanilla_shown[name] then
		return
	end

	row:show()

	local striped = place(row)
	local stripe = row:child(tostring(index)) or row:child("ews_stripe")

	if not stripe and striped then
		stripe = row:rect({
			name = "ews_stripe",
			color = Color.black:with_alpha(0.3)
		})
	end

	if stripe then
		stripe:set_visible(striped)
	end
end

function BlackMarketGui:ews_add_stat_row(panel, columns, stat, place)
	local font_size = tweak_data.menu.pd2_small_font_size
	local row = panel:panel({
		name = "ews_stat_row",
		layer = 1,
		h = STAT_ROW_HEIGHT,
		w = panel:w()
	})

	local texts = {}
	local x = 2

	for _, column in ipairs(columns) do
		x = column.x or x

		local text_panel = row:panel({
			layer = 0,
			x = x,
			w = column.size,
			h = row:h()
		})

		texts[column.name] = text_panel:text({
			text = column.name == "name" and managers.localization:to_upper_text(stat.name) or "",
			layer = 1,
			font_size = font_size,
			font = tweak_data.menu.pd2_small_font,
			align = column.align,
			blend_mode = column.name ~= "name" and "add" or nil,
			color = tweak_data.screen_colors.text,
			y = row:h() - font_size
		})

		x = x + column.size
	end

	if place(row) then
		row:rect({
			name = "ews_stripe",
			color = Color.black:with_alpha(0.3)
		})
	end

	return texts
end

function BlackMarketGui:ews_build_melee_rows()
	local panel = self._mweapon_stats_panel
	local shown = self._mweapon_stats_shown or {}
	local count = #shown
	local last = shown[count]
	local last_texts = last and self._mweapon_stats_texts and self._mweapon_stats_texts[last.name]
	local last_name = last_texts and last_texts.name
	local y = alive(last_name) and last_name:parent():parent():bottom() or STAT_ROW_HEIGHT * (count + 1)

	local function place(row)
		count = count + 1

		row:set_y(y)
		y = y + row:h()

		return count % 2 == 0
	end

	self._ews_melee_texts = {}

	for _, stat in ipairs(MELEE_STATS) do
		self._ews_melee_texts[stat.name] = self:ews_add_stat_row(panel, MELEE_STAT_COLUMNS, stat, place)
	end
end

function BlackMarketGui:ews_add_falloff_charts(y)
	local panel = self._rweapon_stats_panel:panel({
		name = "ews_falloff",
		layer = 1,
		y = y,
		h = 64,
		w = self._rweapon_stats_panel:w()
	})

	local name_w = EXTRA_STAT_COLUMNS[1].size
	local column_w = EXTRA_STAT_COLUMNS[2].size + EXTRA_STAT_COLUMNS[3].size
	local x = 2

	panel:text({
		text = managers.localization:to_upper_text("ews_falloff"),
		layer = 1,
		x = x,
		w = name_w,
		h = panel:h(),
		vertical = "center",
		font_size = tweak_data.menu.pd2_small_font_size,
		font = tweak_data.menu.pd2_small_font,
		color = tweak_data.screen_colors.text
	})

	x = x + name_w

	self._ews_falloff = {
		panel = panel,
		charts = {
			EWS.FalloffChart:new(panel, x + 1, 0, column_w - 2, panel:h()),
			EWS.FalloffChart:new(panel, x + column_w + 1, 0, column_w - 2, panel:h())
		},
		tooltip_bg = self._panel:rect({
			visible = false,
			layer = 1000,
			color = Color.black:with_alpha(0.8)
		}),
		tooltip = self._panel:text({
			visible = false,
			layer = 1001,
			text = "",
			align = "right",
			font_size = tweak_data.menu.pd2_small_font_size,
			font = tweak_data.menu.pd2_small_font,
			color = tweak_data.screen_colors.text
		})
	}
end

local function hide_falloff_tooltip(falloff)
	falloff.tooltip:hide()
	falloff.tooltip_bg:hide()
end

local function update_falloff_chart(chart, context)
	local falloff = context and context:damage_falloff(true, 50, chart:columns())

	if not falloff then
		chart:set_visible(false)

		return false
	end

	for i, multiplier in ipairs(falloff.multipliers) do
		chart:set_column(i, multiplier, managers.localization:text("ews_falloff_chart_text", {
			DMG = string.format("%.1f", falloff.damage * multiplier),
			DIS = string.format("%.1f", (i - 1) * 50 / 100)
		}))
	end

	chart:set_visible(true)

	return true
end

function BlackMarketGui:ews_update_falloff_charts(first, second)
	local falloff = self._ews_falloff

	if not falloff then
		return
	end

	hide_falloff_tooltip(falloff)

	local shown = update_falloff_chart(falloff.charts[1], first)

	shown = update_falloff_chart(falloff.charts[2], second) or shown

	falloff.panel:set_visible(shown)
end

Hooks:PostHook(BlackMarketGui, "mouse_moved", "EWS_BlackMarketGui_mouse_moved", function(self, o, x, y)
	local falloff = self._ews_falloff

	if not falloff or not alive(falloff.tooltip) then
		return
	end

	hide_falloff_tooltip(falloff)

	if not self._enabled or self._renaming_item or alive(self._context_panel) then
		return
	end

	if not self._rweapon_stats_panel:visible() or not falloff.panel:visible() then
		return
	end

	for _, chart in ipairs(falloff.charts) do
		local text = chart:text_at(x, y)

		if text then
			local tooltip = falloff.tooltip

			tooltip:set_text(text)

			local _, _, w, h = tooltip:text_rect()

			tooltip:set_size(w, h)
			tooltip:set_world_right(x)
			tooltip:set_world_top(y + 15)
			tooltip:show()

			falloff.tooltip_bg:set_shape(tooltip:x() - 4, tooltip:y() - 2, w + 8, h + 4)
			falloff.tooltip_bg:show()

			return true, "arrow"
		end
	end
end)

function BlackMarketGui:ews_add_stance_buttons()
	local stats_panel = self._rweapon_stats_panel

	local title_bar = self._stats_panel:children()[1]

	if alive(title_bar) then
		title_bar:move(0, STAT_ROW_HEIGHT)
	end

	for _, title in pairs(self._stats_titles or {}) do
		title:move(0, STAT_ROW_HEIGHT)
	end

	local row = self._stats_panel:panel({
		name = "ews_stance_buttons",
		layer = 1,
		h = STAT_ROW_HEIGHT,
		w = self._stats_panel:w()
	})

	self._ews_stance_buttons = {}

	local stance_buttons = {
		{ key = "ducking",     on = "ews_stance_crouching",   off = "ews_stance_standing" },
		{ key = "moving",      on = "ews_stance_moving",      off = "ews_stance_still" },
		{ key = "underbarrel", on = "ews_weapon_underbarrel", off = "ews_weapon_main",    underbarrel_only = true }
	}

	for _, stance in ipairs(stance_buttons) do
		local btn = BlackMarketGuiButtonItem:new(row, {
			name = stance.off,
			prio = 1,
			callback = function()
				EWS.state[stance.key] = not EWS.state[stance.key]

				self:ews_update_stance_buttons()
				self:show_stats()
			end
		}, 0)

		-- something about double clicking from MWS, idk
		btn._data.prio = 5
		btn._ews_stance = stance

		function btn:visible()
			return self._panel:visible() and stats_panel:visible()
		end

		self._btns["ews_stance_" .. stance.key] = btn

		table.insert(self._ews_stance_buttons, btn)
	end

	self:ews_update_stance_buttons()
end

function BlackMarketGui:ews_update_stance_buttons()
	local x = 0

	for _, btn in ipairs(self._ews_stance_buttons or {}) do
		local stance = btn._ews_stance

		btn._ews_hidden = stance.underbarrel_only and not self._ews_underbarrel_available

		if btn._ews_hidden then
			btn:hide()
		else
			btn._btn_text_id = EWS.state[stance.key] and stance.on or stance.off
			btn:set_text_params()

			local _, _, w = btn._btn_text:text_rect()

			btn._panel:set_w(w + 8)
			btn._panel:set_x(x)
			btn._btn_text:set_center_x(btn._panel:w() / 2)
			btn:show()

			x = btn._panel:right() + 8
		end
	end
end

-- show_btns hides every button in self._btns before showing the slot's own
Hooks:PostHook(BlackMarketGui, "show_btns", "EWS_BlackMarketGui_show_btns", function(self)
	for _, btn in ipairs(self._ews_stance_buttons or {}) do
		if not btn._ews_hidden then
			btn:show()
		end
	end
end)

function BlackMarketGui:ews_apply_underbarrel(viewed, compared)
	local available = viewed and viewed:has_underbarrel() or false

	self._ews_underbarrel_active = available and EWS.state.underbarrel

	for _, context in pairs({ viewed, compared }) do
		context:set_underbarrel(self._ews_underbarrel_active)
	end

	if available ~= self._ews_underbarrel_available then
		self._ews_underbarrel_available = available

		self:ews_update_stance_buttons()
	end
end

local function seconds(value)
	return string.format("%.2f%s", value, managers.localization:text("menu_seconds_suffix_short"))
end

local function format_value(value, format_type)
	if format_type == "seconds" then
		return seconds(value)
	elseif format_type == "decimal" then
		return string.format("%.2f", value)
	elseif format_type == "degrees" then
		return string.format("%.2f°", value)
	elseif format_type == "integer" then
		return string.format("%d", value)
	elseif format_type == "percent" then
		return string.format("%d%%", math.round(value * 100))
	elseif format_type == "number" then
		return (string.format("%.1f", value):gsub("%.?0+$", ""))
	else
		return tostring(value)
	end
end

local EXTRA_DIVIDER = " | "

local function stat_values(stat, context)
	if not context then
		return nil, "", ""
	end

	local stats
	local ok = pcall(function()
		stats = stat.value(context)
	end)

	if not ok then
		return nil, "?", ""
	elseif not stats then
		return nil, "-", ""
	end

	return stats,
		format_value(stats.main, stat.format_type),
		stats.extra and EXTRA_DIVIDER .. format_value(stats.extra, stat.format_type) or ""
end

local function stat_change(stat, new, old)
	if not new or not old or not stat.better then
		return nil
	end

	local new_text = format_value(new, stat.format_type)

	if new_text == format_value(old, stat.format_type) then
		return nil
	end

	local diff = tonumber(string.format("%.2f", new)) - tonumber(string.format("%.2f", old))
	local improved = (diff < 0) == (stat.better == "lower")
	local color = improved and tweak_data.screen_colors.stats_positive or tweak_data.screen_colors.stats_negative

	return color, (diff > 0 and "+" or "-") .. format_value(math.abs(diff), stat.format_type)
end

function BlackMarketGui:ews_weapon_mod_contexts()
	local slot_data = self._slot_data
	local part_id = slot_data.name
	local crafted = managers.blackmarket:get_crafted_category_slot(slot_data.category, slot_data.slot)

	if not crafted or not tweak_data.weapon.factory.parts[part_id] then
		return nil
	end

	local current = managers.blackmarket:get_weapon_blueprint(slot_data.category, slot_data.slot)
	local current_context = EWS:weapon_context(crafted.weapon_id, crafted.factory_id, deep_clone(current))

	if table.contains(current, part_id) then
		return current_context
	end

	local modded = deep_clone(current)

	managers.weapon_factory:change_part_blueprint_only(crafted.factory_id, part_id, modded, false)

	return EWS:weapon_context(crafted.weapon_id, crafted.factory_id, modded), current_context
end

function BlackMarketGui:ews_weapon_contexts()
	local slot_data = self._slot_data

	-- Route for skins with attachments
	if slot_data.default_blueprint then
		local crafted = managers.blackmarket:get_crafted_category_slot(slot_data.category, slot_data.slot)

		if not crafted then
			return nil
		end

		return EWS:weapon_context(crafted.weapon_id, crafted.factory_id, deep_clone(slot_data.default_blueprint))
	end

	local selected = EWS:weapon_context_for_slot(slot_data)
	local category = slot_data.category
	local equipped_slot = slot_data.equipped_slot or managers.blackmarket:equipped_weapon_slot(category)

	if not equipped_slot or equipped_slot == slot_data.slot then
		return selected
	end

	local equipped_item = managers.blackmarket:equipped_item(category)

	return selected, EWS:weapon_context_for_slot({
		category = category,
		slot = equipped_slot,
		name = slot_data.equipped_name or equipped_item and equipped_item.weapon_id
	})
end

local function set_texts(texts, index, a, b, alpha)
	for key, text in pairs({ a = a, b = b }) do
		local object = texts[key .. index]

		object:set_text(text)
		object:set_alpha(alpha)
		object:set_color(tweak_data.screen_colors.text)
		object:clear_range_color(0, utf8.len(text))
	end
end

local function color_after_divider(object, color)
	object:set_range_color(utf8.len(EXTRA_DIVIDER), utf8.len(object:text()), color)
end

local function color_changes(texts, stat, new, old, index, diff_index)
	if not new or not old then
		return false
	end

	local main_color, main_diff = stat_change(stat, new.main, old.main)
	local extra_color, extra_diff = stat_change(stat, new.extra, old.extra)

	if main_color then
		texts["a" .. index]:set_color(main_color)

		if diff_index then
			texts["a" .. diff_index]:set_color(main_color)
			texts["a" .. diff_index]:set_text(main_diff)
		end
	end

	if extra_color then
		color_after_divider(texts["b" .. index], extra_color)

		if diff_index then
			texts["b" .. diff_index]:set_text(EXTRA_DIVIDER .. extra_diff)
			color_after_divider(texts["b" .. diff_index], extra_color)
		end
	end

	return main_color ~= nil or extra_color ~= nil
end

local function set_mod_texts(texts, stat, modded, current)
	local new, a, b = stat_values(stat, modded)
	local old = current and stat_values(stat, current)

	set_texts(texts, 1, a, b, 1)
	set_texts(texts, 2, "", "", 1)

	local changed = color_changes(texts, stat, new, old, 1, 2)

	texts.name:set_alpha(changed and 1 or 0.5)
end

local function set_inventory_texts(texts, stat, selected, equipped)
	texts.name:set_alpha(1)

	if not equipped then
		local _, a, b = stat_values(stat, selected)

		set_texts(texts, 1, a, b, 1)
		set_texts(texts, 2, "", "", 1)

		return
	end

	local old, old_a, old_b = stat_values(stat, equipped)
	local new, new_a, new_b = stat_values(stat, selected)

	set_texts(texts, 1, old_a, old_b, 0.75)
	set_texts(texts, 2, new_a, new_b, 1)
	color_changes(texts, stat, new, old, 2)
end

-- vanilla's format_round
local function format_vanilla(value, shown)
	if shown.round_value then
		return tostring(math.round(value))
	end

	return (string.format("%.1f", value):gsub("%.?0+$", ""))
end

local function vanilla_stat_text(stat, shown, context)
	if not context then
		return nil, ""
	end

	local ok, value = pcall(stat.value, context, shown)

	if not ok then
		return nil, "?"
	elseif not value then
		return nil, "-"
	end

	return value, format_vanilla(value, shown)
end

local function vanilla_change(shown, new, old)
	if not new or not old or format_vanilla(new, shown) == format_vanilla(old, shown) then
		return nil
	end

	local diff = new - old
	local improved = (diff > 0) ~= (shown.inverted == true)

	local color = improved and tweak_data.screen_colors.stats_positive or tweak_data.screen_colors.stats_negative
	local diff = (diff > 0 and "+" or "-") .. format_vanilla(math.abs(diff), shown)

	return color, diff
		
end

local function reset_vanilla_texts(texts, alpha)
	for name, text in pairs(texts) do
		if name ~= "name" then
			text:set_text("")
			text:set_color(tweak_data.screen_colors.text)
		end

		text:set_alpha(alpha)
	end
end

local function set_vanilla_mod_texts(texts, stat, shown, modded, current)
	local new, new_text = vanilla_stat_text(stat, shown, modded)
	local old = current and vanilla_stat_text(stat, shown, current)
	local color, diff = vanilla_change(shown, new, old)

	reset_vanilla_texts(texts, color and 1 or 0.5)

	texts.equip:set_text(new_text)

	if color then
		texts.equip:set_color(color)
		texts.skill:set_text(diff)
		texts.skill:set_color(color)
	end
end

local function set_vanilla_inventory_texts(texts, stat, shown, selected, equipped)
	local new, new_text = vanilla_stat_text(stat, shown, selected)

	reset_vanilla_texts(texts, 1)

	if not equipped then
		texts.equip:set_text(new_text)

		return
	end

	local old, old_text = vanilla_stat_text(stat, shown, equipped)
	local color = vanilla_change(shown, new, old)

	texts.equip:set_text(old_text)
	texts.equip:set_alpha(0.75)
	texts.total:set_text(new_text)

	if color then
		texts.total:set_color(color)
	end
end

local function hide_stat_titles(self, names)
	for _, name in ipairs(names) do
		local title = self._stats_titles and self._stats_titles[name]

		if alive(title) then
			title:hide()
		end
	end
end

function BlackMarketGui:ews_fill_stats(set_ews_texts, set_vanilla_texts, viewed, compared)
	for _, stat in ipairs(WEAPON_STATS) do
		if not stat.vanilla then
			set_ews_texts(self._ews_stat_texts[stat.name], stat, viewed, compared)
		elseif self._ews_underbarrel_active and stat.value then
			local texts = self._stats_texts[stat.name]
			local shown = self._ews_vanilla_shown[stat.name]

			if texts and shown then
				set_vanilla_texts(texts, stat, shown, viewed, compared)
			end
		end
	end
end

function BlackMarketGui:ews_melee_ids()
	local selected = self._slot_data and self._slot_data.name

	if not melee_tweak(selected) then
		return nil
	end

	local equipped = managers.blackmarket:equipped_item(self._slot_data.category)

	if equipped == selected or not melee_tweak(equipped) then
		return selected
	end

	return selected, equipped
end

Hooks:PostHook(BlackMarketGui, "show_stats", "EWS_BlackMarketGui_show_stats", function(self)
	if self._ews_melee_texts and alive(self._mweapon_stats_panel) and self._mweapon_stats_panel:visible() then
		local selected, equipped = self:ews_melee_ids()

		for _, stat in ipairs(MELEE_STATS) do
			set_inventory_texts(self._ews_melee_texts[stat.name], stat, selected, equipped)
		end

		return
	end

	if not self._ews_stat_texts or not alive(self._rweapon_stats_panel) or not self._rweapon_stats_panel:visible() then
		return
	end

	if is_weapon_mod_tab(self) then
		local modded, current = self:ews_weapon_mod_contexts()

		self:ews_apply_underbarrel(modded, current)
		self:ews_fill_stats(set_mod_texts, set_vanilla_mod_texts, modded, current)

		if self._ews_underbarrel_active then
			hide_stat_titles(self, { "equip", "removed" })
		end

		self:ews_update_falloff_charts(modded, current)

		return
	end

	local selected, equipped = self:ews_weapon_contexts()

	self:ews_apply_underbarrel(selected, equipped)
	self:ews_fill_stats(set_inventory_texts, set_vanilla_inventory_texts, selected, equipped)

	if self._ews_underbarrel_active and not equipped then
		hide_stat_titles(self, { "base", "mod", "skill" })
	end

	-- Same columns as the texts: equipped then selected, or selected alone
	if equipped then
		self:ews_update_falloff_charts(equipped, selected)
	else
		self:ews_update_falloff_charts(selected, nil)
	end
end)
