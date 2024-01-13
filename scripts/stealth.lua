

local function get_config(name)
	return settings.startup["stealth_" .. name].value
end

local stealth_radius = get_config("radius")
local stealth_duration =  get_config("duration") * 60
local stealth_cooldown = get_config("cooldown") * 60
local gun_threat = get_config("gun_threat")
local threat_decrease = get_config("threat_decrease")
local threat_upperbound = get_config("threat_upperbound")
local timebomb_delay = get_config("timebomb_delay") * 60
local timebomb_dist = get_config("timebomb_dist")
local smokecloud_threat = get_config("smokecloud_threat")

local protection_threat = get_config("protection_threat")
local protection_radius = get_config("protection_radius")
local died_bonus = 60 * get_config("died_bonus")
local exit_stealth_speed_modifier = get_config("exit_stealth_speed_modifier")

local refresh_rate = 5

local pfx = "stealth_"
local center_flow_name = pfx .. "center"
local left_frame_name = pfx .. "left"
local threat_name = pfx .. "threat"
local time_name = pfx .. "time"
local timebomb_name = pfx .. "timebomb"
local lure_name = pfx .. "lure"

local show_protection

local stealth_weapons = {
	[pfx .. "walther_ppk"] = true
}

local command_names = {
	[defines.command.attack] = "attack",
	[defines.command.go_to_location] = "go_to_location",
	[defines.command.compound] = "compound",
	[defines.command.group] = "group",
	[defines.command.attack_area] = "attack_area",
	[defines.command.wander] = "wander",
	[defines.command.flee] = "flee",
	[defines.command.stop] = "stop",
	[defines.command.build_base] = "build_base"
}

---------------------------------------------------------------------------------------------------------------

local show_log = true
local show_log_screen = true

local function base_print(msg)
	for _, player in pairs(game.players) do
		player.print(msg)
	end
end

local function debug(msg)
	if not show_log then
		return
	end
	msg = "[" .. game.tick .. "]:" .. msg
	log(msg)
	if not show_log_screen then
		return
	end
	base_print(msg)
end

--------------------------------------------------------

local exit_stealth_mode

---@param player LuaPlayer
---@return table<string, any>
local function get_vars(player)
	local players = global.players
	if not players then
		players = {}
		global.players = players
	end
	local vars = players[player.index]
	if not vars then
		vars = {}
		players[player.index] = vars
	end
	return vars
end

---@param p1 MapPosition
---@param p2 MapPosition
---@return number
local vect_distance = function(p1, p2)
	local dx = p2.x - p1.x
	local dy = p2.y - p1.y
	return math.sqrt(dx * dx + dy * dy)
end

---@param player LuaPlayer
local function create_center_flow(player)
	local panel = player.gui.center[center_flow_name]
	if panel then panel.destroy() end

	panel = player.gui.center.add { type = "flow", name = center_flow_name, direction = "vertical" }
	local element
	local style

	element = panel.add { type = "empty-widget" }
	style = element.style
	style.height = 50

	element = panel.add { type = "progressbar", name = threat_name, style = pfx .. "progress-action" }
	style = element.style
	style.color = { 1, 0, 0 }

	element = panel.add { type = "progressbar", name = time_name, style = pfx .. "progress-action" }
	style = element.style
	style.color = { 0, 0, 1 }
end

---@param player LuaPlayer
local function get_center(player)
	local frame = player.gui.center[center_flow_name]
	if frame then return frame end
	create_center_flow(player)
	return player.gui.center[center_flow_name]
end

---@param player LuaPlayer
local function remove_center(player)
	local frame = player.gui.center[center_flow_name]
	if frame then
		frame.destroy()
	end
end

---@param player LuaPlayer
local function create_left_frame(player)
	local panel = player.gui.center[left_frame_name]
	if panel then panel.destroy() end

	panel = player.gui.left.add { type = "frame", name = left_frame_name, direction = "vertical" }
	local element
	local style

	element = panel.add { type = "progressbar", name = threat_name, caption = { "labels.stealth_cooldown" }, style = pfx .. "progress-cooldown" }
	style = element.style
	style.width = 200
	style.color = { 1, 0, 0 }
end

---@param player LuaPlayer
local function get_left(player)
	local frame = player.gui.left[left_frame_name]
	if frame then return frame end
	create_left_frame(player)
	return player.gui.left[left_frame_name]
end

---@param player LuaPlayer
local function remove_left(player)
	local frame = player.gui.left[left_frame_name]
	if frame then
		frame.destroy()
	end
end

---@param vars table<string, any>
---@param amount integer
local function add_threat(vars, amount)
	local threat = vars.threat or 0
	threat = threat + amount
	if threat < 0 then threat = 0 end
	vars.threat = threat
end

---@param vars table<string, any>
---@param amount integer
local function add_cooldown(vars, amount)
	local stealth_start = vars.stealth_start + amount
	local tick = game.tick
	if stealth_start > tick then stealth_start = tick end
	vars.stealth_start = stealth_start
end

---@param e EventData.on_entity_damaged
local function on_entity_damaged(e)
	local cause = e.cause
	local entity = e.entity
	if not entity.valid or entity.force.name ~= "enemy" then return end
	if not cause or cause.name ~= "character" then return end
	local character = cause
	local player = character.player
	if not player then return end
	local vars = get_vars(player)
	if not vars or not vars.stealthy then return end

	local guns = character.get_inventory(defines.inventory.character_guns)
	---@cast guns -nil
	local gun = guns[character.selected_gun_index]

	if not stealth_weapons[gun.name] then
		exit_stealth_mode(player, vars)
		return
	end

	if e.entity.type ~= "unit" then
		exit_stealth_mode(player, vars)
		return
	end

	add_threat(vars, gun_threat)
end

---@param character LuaEntity
---@param vars table<string, any>
local function clear_speed_modifier(character, vars)
	character.character_running_speed_modifier = character.character_running_speed_modifier - (vars.speed_modifier or 0)
	vars.speed_modifier = 0
end

---@param player LuaPlayer
---@param vars table<string, any>
exit_stealth_mode = function(player, vars)
	player.print { "message.exit_stealth_mode" }
	player.force = vars.force
	vars.stealthy = false
	vars.stealth_end = game.tick
	local frame = get_center(player)
	frame[time_name].style.color = { 1, 1, 0 }
	frame[time_name].value = 0
	frame[threat_name].value = 0
	if vars.marker_id then
		rendering.destroy(vars.marker_id)
		vars.marker_id = nil
	end
	if vars.circle_id then
		rendering.destroy(vars.circle_id)
		vars.circle_id = nil
	end
	remove_center(player)
	local character = player.character
	if character then
		vars.speed_modifier = exit_stealth_speed_modifier
		character.character_running_speed_modifier = character.character_running_speed_modifier + exit_stealth_speed_modifier
	end
end

---@param player LuaPlayer
---@param vars table<string, any>
local function enter_stealth_mode(player, vars)
	player.print { "message.enter_stealth_mode" }
	vars.force = player.force.name
	player.force = "enemy"
	vars.stealthy = true
	vars.stealth_start = game.tick
	vars.threat = 0

	local character = player.character
	if character then
		vars.marker_id = rendering.draw_sprite { sprite = "stealth_marker",
			target = player.character, surface = character.surface, target_offset = { x = 0, y = -2 }, render_layer = "entity-info-icon" }
		vars.circle_id = rendering.draw_circle { target = player.character, surface = character.surface, radius = stealth_radius, color = { 1, 0.84, 0 } }

		clear_speed_modifier(character, vars)

		local surface = player.surface
		local enemies = surface.find_entities_filtered { type = "unit", force = "enemy", position = player.position, radius = 3 * stealth_radius }

		local function check_targeting(c)
			if c == nil then return false end
			local type = c.type
			if type == defines.command.attack and c.target == character then
				return true
			elseif type == defines.command.compound then
				for _, ic in pairs(c.commands) do
					if check_targeting(ic) then return true end
				end
			end
			return false
		end

		for _, enemy in ipairs(enemies) do
			if check_targeting(enemy.command) or check_targeting(enemy.distraction_command) then
				enemy.set_command { type = defines.command.wander }
			end
		end
	end
end

---@param player LuaPlayer
---@param vars table<string, any>
local function update_timer(player, vars)
	if vars.stealthy then
		local tick = game.tick
		local duration = tick - vars.stealth_start
		if duration > stealth_duration then
			exit_stealth_mode(player, vars)
			return
		end
		local frame = get_center(player)
		frame[time_name].value = duration / stealth_duration

		local threat = vars.threat or 0
		threat = threat - threat_decrease
		if threat < 0 then
			threat = 0
		end

		local character = player.character
		if character then
			local surface = character.surface

			local player_pos = character.position

			local total = 0
			local function process_enemies(enemies, weight)
				for _, enemy in pairs(enemies) do
					local position = enemy.position
					local dist = vect_distance(position, player_pos) / stealth_radius
					dist = 1 - dist
					if dist < 0 then dist = 0 end
					local coef = math.pow(dist, 1.7)

					total = total + weight * coef
				end
			end

			local enemies = surface.find_entities_filtered { position = player_pos, force = "enemy", radius = stealth_radius, type = "unit" }
			process_enemies(enemies, 1)
			enemies = surface.find_entities_filtered { position = player_pos, force = "enemy", radius = stealth_radius, type = "unit-spawner" }
			process_enemies(enemies, 1.5)
			enemies = surface.find_entities_filtered { position = player_pos, force = "enemy", radius = stealth_radius, type = "turret" }
			process_enemies(enemies, 2)

			if total > threat_upperbound then total = threat_upperbound end
			threat = threat + total

			local function process_protections(protections)
				for _, protection in pairs(protections) do
					threat = threat - protection_threat
					rendering.draw_circle({ target = protection, color = { 0, 1, 0 }, radius = 0.2, filled = true, time_to_live = refresh_rate + 1, surface = protection.surface })
				end
			end

			process_protections(surface.find_entities_filtered { position = player_pos, radius = protection_radius, type = { "tree", "cliff" } })
			process_protections(surface.find_entities_filtered { position = player_pos, radius = protection_radius, name = { "rock-big", "rock-huge", "sand-rock-big" } })
		end

		if threat > 100 then
			exit_stealth_mode(player, vars)
			return
		end

		if threat < 0 then threat = 0 end

		vars.threat = threat
		frame[threat_name].value = threat / 100
	else
		local used = false
		if vars.stealth_end then
			local duration = vars.stealth_end + stealth_cooldown - game.tick
			if duration < 0 then
				vars.stealth_end = nil
				local character = player.character
				if character then
					clear_speed_modifier(character, vars)
				end
			else
				get_left(player)[threat_name].value = duration / stealth_cooldown
				used = true
			end
		end
		if not used then
			remove_left(player)
		end
	end
end

local function on_nth_tick()
	local players = global.players
	if not players then return end
	for index, vars in pairs(players) do
		local player = game.players[index]
		if not player then
			players[index] = nil
		else
			update_timer(player, vars)
		end
	end
	if global.timebombs then
		local tick = game.tick
		local exploded = false
		for index, bomb_info in ipairs(global.timebombs) do
			local bomb = bomb_info.entity
			local remain = (bomb_info.start + bomb_info.delay) - tick
			if remain <= 0 then
				if bomb.valid then
					bomb.force = "player"
					bomb.surface.create_entity({ name = pfx .. "bomb_trigger", position = bomb.position, force = "enemy" })
				end
				bomb_info.exploded = true
				exploded = true
			elseif bomb.valid then
				rendering.draw_text { target = bomb, text = tostring(math.floor(remain / 60)), time_to_live = refresh_rate + 1, surface = bomb.surface, color = { 1, 0, 0 } }
			end
		end

		if exploded then
			local new_timebombs = {}
			for index, bomb_info in ipairs(global.timebombs) do
				if not bomb_info.exploded then
					table.insert(new_timebombs, bomb_info)
				end
			end
			global.timebombs = new_timebombs
		end
	end
end

local function on_init()
	for _, player in pairs(game.players) do
		local t = {}
		for _, element in pairs(player.gui.center.children) do
			element.destroy()
		end
	end
	on_nth_tick()
end

local function on_stealth_toggle(e)
	local player = game.players[e.player_index]
	local vars = get_vars(player)

	if player.force.name == "enemy" then
		exit_stealth_mode(player, vars)
	else
		if vars.stealth_end and (game.tick - vars.stealth_end) < stealth_cooldown then
			player.print { "message.stealth_cooldown" }
			return
		end
		enter_stealth_mode(player, vars)
	end
end

---@param e EventData.on_built_entity
local function on_build(e)
	local entity = e.created_entity
	if entity.name ~= timebomb_name then return end

	local player = game.players[e.player_index]
	local vars = get_vars(player)

	local function abort()
		local inv = player.get_inventory(defines.inventory.character_main)
		local stack = { name = entity.name, count = 1 }
		---@cast inv -nil
		inv.insert(stack)
		entity.destroy()
	end

	if not vars.stealthy then
		abort()
		player.print { "message.only_usable_in_stealth_mode" }
		return
	end

	local dist = vect_distance(player.position, entity.position)
	if dist > timebomb_dist then
		abort()
		player.print { "message.you_must_be_nearer" }
		return
	end

	local timebombs = global.timebombs
	if not timebombs then
		timebombs = {}
		global.timebombs = timebombs
	end
	table.insert(timebombs,
		{
			delay = timebomb_delay,
			start = game.tick,
			entity = entity
		})
end

---@param e EventData.on_script_trigger_effect
local function on_script_trigger_effect(e)
	local entity = e.target_entity
	if e.effect_id == "smokecloud" and entity and entity.valid and entity.name == "character" then
		local player = entity.player
		if not player then return end
		local vars = get_vars(player)
		if not vars.stealthy then return end

		add_threat(vars, -smokecloud_threat)
	end
end

---@param e EventData.on_entity_died
local function on_entity_died(e)
	local entity = e.entity
	local cause = e.cause

	if not cause then return end
	if cause.name == "character" and entity.type == "unit" then
		local character = cause
		local player = character.player
		if not player then return end
		local vars = get_vars(player)
		if not vars or not vars.stealthy then return end
		add_cooldown(vars, died_bonus)
	end
end

---@param e EventData.on_trigger_created_entity
local function on_trigger_created_entity(e)
	local entity = e.entity
	if entity.name ~= lure_name then return end
	entity.force = "player"
end

script.on_init(on_init)
script.on_event("stealth_key_toggle", on_stealth_toggle)
script.on_nth_tick(refresh_rate, on_nth_tick)
script.on_event(defines.events.on_entity_damaged, on_entity_damaged)
script.on_event(defines.events.on_entity_died, on_entity_died)
script.on_event(defines.events.on_built_entity, on_build)
script.on_event(defines.events.on_script_trigger_effect, on_script_trigger_effect)
script.on_event(defines.events.on_trigger_created_entity, on_trigger_created_entity)
