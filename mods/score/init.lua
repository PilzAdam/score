
--
-- Player
--

local LEVEL_EXTENT = 100
local LEVEL_MAX = 100
local SPEED_MAX = 6

local INV_PICK_INDEX = 1
local INV_LIGHT_INDEX = 2
local INV_SIZE = 2

local HP_MAX = 20

local hud_ids = {
	--[[
		playername = {
			status_message = id,
			healthbar = id,
		},
	]]
}

local function get_pick_info(player)
	local hud_inv = player:get_inventory()
	local pick = hud_inv:get_stack("main", INV_PICK_INDEX)
	local level, speed = pick:get_name():match("^score:pick_([%d]+)_([%d]+)$")
	if not level or not tonumber(level) or not speed or not tonumber(speed) then
		level = 1
		speed = 1
	end
	return tonumber(level), tonumber(speed)
end

local function get_pick_name(level, speed)
	return "score:pick_" .. level .. "_" .. speed
end

local inventories = {
	--[[
	playername = {
		itemname = count,
	},
	]]
}

local function save_inventories()
	local file = io.open(minetest.get_worldpath() .. "/score_inventory", "w")
	if not file then
		minetest.log("error", "Can't save inventories")
		return
	end
	file:write(minetest.serialize(inventories))
	file:close()
end

local function load_inventories()
	local file = io.open(minetest.get_worldpath() .. "/score_inventory", "r")
	if not file then
		minetest.log("error", "Can't load inventories")
		return
	end
	inventories = minetest.deserialize(file:read("*all"))
	file:close()
end

local function get_pick_level_cost(level)
	local cost = {}
	cost["score:iron_" .. (level + 1)] = 30
	return cost
end

local function get_pick_speed_cost(level, speed)
	local cost = {}
	cost["score:iron_" .. level] = math.ceil(30 * 1.2 ^ (speed - 1))
	return cost
end

local function get_light_cost(level)
	local cost = {}
	cost["score:coal_" .. level] = 50
	if level > 1 then
		cost["score:coal_" .. (level - 1)] = 80
	end
	return cost
end

local function get_heal_cost(level)
	local cost = {}
	cost["score:turret_" .. level] = 10
	return cost
end

local function update_formspec(player, not_enough_resources)
	local inv = inventories[player:get_player_name()]
	local hud_inv = player:get_inventory()

	local formspec = "size[9,4,true]"
	formspec = formspec .. "tableoptions[background=#00000000;border=false;highlight=#00000000]"
	formspec = formspec .. "tablecolumns[color;image,"
			.. "0=,"
			.. "1=" .. hud_inv:get_stack("main", INV_PICK_INDEX):get_definition().inventory_image .. ","
			.. "2=" .. minetest.registered_items["score:light"].tiles[1] .. ","
			.. "3=" .. minetest.registered_items["score:score_ore_1"].tiles[1] .. ","
			.. "4=" .. minetest.registered_items["score:stone_1"].tiles[1] .. ","
			.. "5=" .. minetest.registered_items["score:stone_2"].tiles[1] .. ","
			.. "6=" .. minetest.registered_items["score:stone_3"].tiles[1] .. ","
			.. "7=" .. minetest.registered_items["score:coal_1"].tiles[1] .. ","
			.. "8=" .. minetest.registered_items["score:coal_2"].tiles[1] .. ","
			.. "9=" .. minetest.registered_items["score:coal_3"].tiles[1] .. ","
			.. "10=" .. minetest.registered_items["score:iron_1"].tiles[1] .. ","
			.. "11=" .. minetest.registered_items["score:iron_2"].tiles[1] .. ","
			.. "12=" .. minetest.registered_items["score:iron_3"].tiles[1] .. ","
			.. "13=" .. minetest.registered_items["score:turret_1"].tiles[1] .. ","
			.. "14=" .. minetest.registered_items["score:turret_2"].tiles[1] .. ","
			.. "15=" .. minetest.registered_items["score:turret_3"].tiles[1] .. ""
			.. ";text;text]"
	formspec = formspec .. "table[0,0;3.9,4;;"

	local level, speed = get_pick_info(player)
	local light = hud_inv:get_stack("main", INV_LIGHT_INDEX)
	formspec = formspec .. "#FFFF00,0,Item,Amount,"
	formspec = formspec .. ",1,Pick Level " .. level .. " Speed " .. speed .. ",1,"
	formspec = formspec .. ",2," .. light:get_definition().description .. "," .. light:get_count() .. ","

	local lines = {}
	for itemname,count in pairs(inv) do
		table.insert(lines, {
			minetest.formspec_escape(minetest.registered_items[itemname].description),
			count,
		})
	end

	table.sort(lines, function(a, b)
		if b[1] == "Score" then
			return false
		end
		if a[1] == "Score" then
			return true
		end
		local a_level = tonumber(a[1]:match(".* Level ([%d]+)$"))
		local b_level = tonumber(b[1]:match(".* Level ([%d]+)$"))
		if not a_level or not b_level or a_level == b_level then
			return a[1] < b[1]
		end
		return a_level > b_level
	end)

	for _,line in ipairs(lines) do
		local image = 0
		if line[1] == "Score" then
			image = 3
		else
			local base = 0
			if line[1]:match("^Stone") then
				base = 4
			elseif line[1]:match("^Coal") then
				base = 7
			elseif line[1]:match("^Iron") then
				base = 10
			elseif line[1]:match("^Turret") then
				base = 13
			end
			local level = tonumber(line[1]:match("([%d]+)$"))
			if level and base ~= 0 then
				image = base + ((level - 1) % 3)
			end
		end
		formspec = formspec .. "," .. image .. "," .. line[1] .. "," .. line[2] .. ","
	end

	-- remove trailing comma
	if formspec:match(",$") then
		formspec = formspec:sub(1, -2)
	end

	formspec = formspec .. ";0]"

	formspec = formspec .. "button[4,0;2,1;btn_pick_level;Level Pick up]"
	formspec = formspec .. "tableoptions[background=#00000000;border=false;highlight=#00000000]"
	formspec = formspec .. "tablecolumns[color;text;text]"
	formspec = formspec .. "table[6,0;3,1.1;;"
	if level >= LEVEL_MAX then
		formspec = formspec .. ",Max. level,,"
	else
		if not_enough_resources == "pick_level" then
			formspec = formspec .. "#FF0000,Requires:,,"
		else
			formspec = formspec .. ",Requires:,,"
		end
		local pick_level_cost = get_pick_level_cost(level)
		for item, required in pairs(pick_level_cost) do
			local name = minetest.registered_items[item].description
			formspec = formspec .. ",  " .. name .. "," .. required .. ","
		end
		-- remove trailing comma
		if formspec:match(",$") then
			formspec = formspec:sub(1, -2)
		end
		formspec = formspec .. ";0]"
	end

	formspec = formspec .. "button[4,1;2,1;btn_pick_speed;Speed Pick up]"
	formspec = formspec .. "tableoptions[background=#00000000;border=false;highlight=#00000000]"
	formspec = formspec .. "tablecolumns[color;text;text]"
	formspec = formspec .. "table[6,1;3,1.1;;"
	if speed >= SPEED_MAX then
		formspec = formspec .. ",Max. speed for this level,,"
	else
		if not_enough_resources == "pick_speed" then
			formspec = formspec .. "#FF0000,Requires:,,"
		else
			formspec = formspec .. ",Requires:,,"
		end
		local pick_speed_cost = get_pick_speed_cost(level, speed)
		for item, required in pairs(pick_speed_cost) do
			local name = minetest.registered_items[item].description
			formspec = formspec .. ",  " .. name .. "," .. required .. ","
		end
		-- remove trailing comma
		if formspec:match(",$") then
			formspec = formspec:sub(1, -2)
		end
		formspec = formspec .. ";0]"
	end

	formspec = formspec .. "button[4,2;2,1;btn_light;Craft Light]"
	formspec = formspec .. "tableoptions[background=#00000000;border=false;highlight=#00000000]"
	formspec = formspec .. "tablecolumns[color;text;text]"
	formspec = formspec .. "table[6,2;3,1.1;;"
	if not_enough_resources == "light" then
		formspec = formspec .. "#FF0000,Requires:,,"
	else
		formspec = formspec .. ",Requires:,,"
	end
	local light_cost = get_light_cost(level)
	for item, required in pairs(light_cost) do
		local name = minetest.registered_items[item].description
		formspec = formspec .. ",  " .. name .. "," .. required .. ","
	end
	-- remove trailing comma
	if formspec:match(",$") then
		formspec = formspec:sub(1, -2)
	end
	formspec = formspec .. ";0]"

	if formspec ~= player:get_inventory_formspec() then
		player:set_inventory_formspec(formspec)
	end

	formspec = formspec .. "button[4,3;2,1;btn_heal;Heal]"
	formspec = formspec .. "tableoptions[background=#00000000;border=false;highlight=#00000000]"
	formspec = formspec .. "tablecolumns[color;text;text]"
	formspec = formspec .. "table[6,3;3,1.1;;"
	if not_enough_resources == "heal" then
		formspec = formspec .. "#FF0000,Requires:,,"
	else
		formspec = formspec .. ",Requires:,,"
	end
	local heal_cost = get_heal_cost(level)
	for item, required in pairs(heal_cost) do
		local name = minetest.registered_items[item].description
		formspec = formspec .. ",  " .. name .. "," .. required .. ","
	end
	-- remove trailing comma
	if formspec:match(",$") then
		formspec = formspec:sub(1, -2)
	end
	formspec = formspec .. ";0]"

	if formspec ~= player:get_inventory_formspec() then
		player:set_inventory_formspec(formspec)
	end
end

minetest.register_on_player_receive_fields(function(player, formname, fields)
	if fields["btn_pick_level"] then
		local inv = inventories[player:get_player_name()]
		local hud_inv = player:get_inventory()

		local level, speed = get_pick_info(player)

		if level >= LEVEL_MAX then
			return true
		end

		local pick_cost = get_pick_level_cost(level)
		for item, required in pairs(pick_cost) do
			if not inv[item] or inv[item] < required then
				update_formspec(player, "pick_level")
				return true
			end
		end
		for item, required in pairs(pick_cost) do
			inv[item] = inv[item] - required
		end

		hud_inv:set_stack("main", INV_PICK_INDEX, ItemStack(get_pick_name(level + 1, math.max(speed - 1, 1))))

		update_formspec(player)
		return true
	end

	if fields["btn_pick_speed"] then
		local inv = inventories[player:get_player_name()]
		local hud_inv = player:get_inventory()

		local level, speed = get_pick_info(player)

		if speed >= SPEED_MAX then
			return true
		end

		local pick_cost = get_pick_speed_cost(level, speed)
		for item, required in pairs(pick_cost) do
			if not inv[item] or inv[item] < required then
				update_formspec(player, "pick_speed")
				return true
			end
		end
		for item, required in pairs(pick_cost) do
			inv[item] = inv[item] - required
		end

		hud_inv:set_stack("main", INV_PICK_INDEX, ItemStack(get_pick_name(level, speed + 1)))

		update_formspec(player)
		return true
	end

	if fields["btn_light"] then
		local inv = inventories[player:get_player_name()]
		local hud_inv = player:get_inventory()

		local light_cost = get_light_cost(get_pick_info(player))
		for item, required in pairs(light_cost) do
			if not inv[item] or inv[item] < required then
				update_formspec(player, "light")
				return true
			end
		end
		for item, required in pairs(light_cost) do
			inv[item] = inv[item] - required
		end

		local light = hud_inv:get_stack("main", INV_LIGHT_INDEX)
		light:add_item(ItemStack("score:light"))
		hud_inv:set_stack("main", INV_LIGHT_INDEX, light)

		update_formspec(player)
		return true
	end

	if fields["btn_heal"] then
		local inv = inventories[player:get_player_name()]
		local hud_inv = player:get_inventory()

		if player:get_hp() >= HP_MAX then
			return
		end

		local heal_cost = get_heal_cost(get_pick_info(player))
		for item, required in pairs(heal_cost) do
			if not inv[item] or inv[item] < required then
				update_formspec(player, "heal")
				return true
			end
		end
		for item, required in pairs(heal_cost) do
			inv[item] = inv[item] - required
		end

		local new_health = math.min(player:get_hp() + 2, HP_MAX)
		player:set_hp(new_health)

		update_formspec(player)
		return true
	end

	if fields["quit"] then
		update_formspec(player)
	end
end)

local function show_status_message(player, message)
	local left, right = message:match("(.+)\n(.+)")
	if left and right then
		show_status_message(player, left)
		show_status_message(player, right)
		return
	end

	local id = hud_ids[player:get_player_name()].status_message
	local previous = player:hud_get(id).text
	if previous ~= "" then
		player:hud_change(id, "text", previous .. "\n" .. message)
	else
		player:hud_change(id, "text", message)
	end
	minetest.after(5, function(player, id)
		local previous = player:hud_get(id).text
		local pos = previous:find("\n")
		if pos then
			player:hud_change(id, "text", previous:sub(pos + 1))
		else
			player:hud_change(id, "text", "")
		end
	end, player, id)
end

minetest.register_on_joinplayer(function(player)
	player:set_properties({ textures = {} })
	player:set_sky("0x000000", "plain", {})
	player:set_physics_override({ sneak_glitch = false })

	player:hud_set_hotbar_itemcount(INV_SIZE)
	player:hud_set_flags({
		hotbar = true,
		healthbar = false,
		crosshair = true,
		wielditem = true,
		minimap = false,
	})
	
	hud_ids[player:get_player_name()] = {}
	hud_ids[player:get_player_name()].status_message = player:hud_add({
		hud_elem_type = "text",
		position = { x = 1.0, y = 1.0 },
		text = "",
		number = "0xFFFFFF",
		offset = { x = -10, y = -10 },
		alignment = { x = -1, y = -1 },
	})
	player:hud_add({
		hud_elem_type = "statbar",
		position = { x = 0.5, y = 1 },
		text = "score_heart_empty.png",
		number = HP_MAX,
		direction = 0,
		size = { x = 20, y = 20 },
		offset = { x = -5 * HP_MAX, y = -(48 + 20 + 16) },
	})
	hud_ids[player:get_player_name()].healthbar = player:hud_add({
		hud_elem_type = "statbar",
		position = { x = 0.5, y = 1 },
		text = "score_heart.png",
		number = player:get_hp(),
		direction = 0,
		size = { x = 20, y = 20 },
		offset = { x = -5 * HP_MAX, y = -(48 + 20 + 16) },
	})

	minetest.sound_play("score_background", {
		to_player = player:get_player_name(),
		loop = true,
	})

	local hud_inv = player:get_inventory()
	hud_inv:set_size("main", INV_SIZE)
	if not hud_inv:get_stack("main", INV_PICK_INDEX):get_name():match("^score:pick_") then
		hud_inv:set_stack("main", INV_PICK_INDEX, ItemStack(get_pick_name(1, 1)))
		hud_inv:set_stack("main", INV_LIGHT_INDEX, ItemStack("score:light 10"))
	end

	local inv = inventories[player:get_player_name()]
	if not inv then
		inventories[player:get_player_name()] = {
			["score:score"] = 0
		}
	end

	update_formspec(player)
end)

minetest.register_on_respawnplayer(function(player)
	local level, speed = get_pick_info(player)
	local hud_inv = player:get_inventory()
	local inv = inventories[player:get_player_name()]

	local score_penalty = 5 + level * 5

	show_status_message(player, "Death Penalty:\n* Score -" .. score_penalty .. "\n* Speed -1")
	speed = math.max(speed - 1, 1)
	hud_inv:set_stack("main", INV_PICK_INDEX, ItemStack(get_pick_name(level, speed)))
	inv["score:score"] = math.max(inv["score:score"] - score_penalty, 0)
	update_formspec(player)

	local pos = player:getpos()
	pos = { x = pos.x + math.random(-50, 50), y = -50, z = pos.z + math.random(-50, 50) }
	player:setpos(pos)

	return true
end)

local enable_damage = false

minetest.register_on_player_hpchange(function(player, hp_change)
	if not enable_damage and hp_change < 0 then
		return 0
	end
	player:hud_change(hud_ids[player:get_player_name()].healthbar, number, player:get_hp() + hp_change)
	return hp_change
end, true)

minetest.handle_node_drops = function(pos, drops, player)
	for _, dropped_item in ipairs(drops) do
		dropped_item = ItemStack(dropped_item)
		local item_name = dropped_item:get_name()
		if item_name == "score:light" then
			local hud_inv = player:get_inventory()
			local light = hud_inv:get_stack("main", INV_LIGHT_INDEX)
			light:add_item(dropped_item)
			hud_inv:set_stack("main", INV_LIGHT_INDEX, light)
		else
			local inv = inventories[player:get_player_name()]
			if not inv[item_name] then
				inv[item_name] = dropped_item:get_count()
			else
				inv[item_name] = inv[item_name] + dropped_item:get_count()
			end
			local status_message = "Mined " .. dropped_item:get_count() .. " "
					.. dropped_item:get_definition().description .. " (total: "
					.. inv[item_name] .. ")"
			show_status_message(player, status_message)
		end
	end
	update_formspec(player)
end

local save_interval = tonumber(minetest.setting_get("server_map_save_interval")) or 5.3
local timer = 0
minetest.register_globalstep(function(dtime)
	timer = timer + dtime
	if timer > save_interval then
		timer = 0
		save_inventories()
	end
end)


load_inventories()
minetest.setting_set("static_spawnpoint", "0,-50,0")
minetest.setting_set("enable_damage", "true")

--
-- Content
--

for level = 1, LEVEL_MAX do

	local image = (level - 1) % 3 + 1

	minetest.register_node("score:stone_" .. level, {
		description = "Stone Level " .. level,
		tiles = { "score_stone_" .. image .. ".png" },
		groups = { stone = level },
		light_source = 1,
		sounds = {
			footstep = { name = "score_footstep", gain = 1.0 },
			place = { name=" score_place ", gain = 1.0 },
			dig = { name="score_dig", gain = 0.5 },
		},
	})

	minetest.register_node("score:iron_" .. level, {
		description = "Iron Level " .. level,
		tiles = { "score_stone_" .. image .. ".png^score_iron.png" },
		groups = { stone = level },
		light_source = 1,
		sounds = {
			footstep = { name = "score_footstep", gain = 1.0 },
			place = { name=" score_place ", gain = 1.0 },
			dig = { name="score_dig", gain = 0.5 },
		},
	})

	minetest.register_ore({
		ore_type = "scatter",
		ore = "score:iron_" .. level,
		wherein = "score:stone_" .. level,
		clust_scarcity = 8 * 8 * 8,
		clust_num_ores = 5,
		clust_size = 3,
	})

	minetest.register_node("score:coal_" .. level, {
		description = "Coal Level " .. level,
		tiles = { "score_stone_" .. image .. ".png^score_coal.png" },
		groups = { stone = level },
		light_source = 1,
		sounds = {
			footstep = { name = "score_footstep", gain = 1.0 },
			place = { name=" score_place ", gain = 1.0 },
			dig = { name="score_dig", gain = 0.5 },
		},
	})

	minetest.register_ore({
		ore_type = "scatter",
		ore = "score:coal_" .. level,
		wherein = "score:stone_" .. level,
		clust_scarcity = 8 * 8 * 8,
		clust_num_ores = 8,
		clust_size = 4,
	})

	minetest.register_node("score:turret_" .. level, {
		description = "Turret Level " .. level,
		tiles = { "score_stone_" .. image .. ".png^score_turret.png" },
		groups = { stone = level, turret = 1 },
		light_source = 1,
		sounds = {
			footstep = { name = "score_footstep", gain = 1.0 },
			place = { name=" score_place ", gain = 1.0 },
			dig = { name="score_dig", gain = 0.5 },
		},
	})

	minetest.register_node("score:score_ore_" .. level, {
		tiles = { "score_stone_" .. image .. ".png^score_score.png" },
		groups = { stone = level + 1 },
		drop = "score:score " .. level,
		light_source = 1,
		sounds = {
			footstep = { name = "score_footstep", gain = 1.0 },
			place = { name=" score_place ", gain = 1.0 },
			dig = { name="score_dig", gain = 0.5 },
		},
	})

	minetest.register_ore({
		ore_type = "scatter",
		ore = "score:score_ore_" .. level,
		wherein = "score:stone_" .. level,
		clust_scarcity = 12 * 12 * 12,
		clust_num_ores = 1,
		clust_size = 1,
	})

	for speed = 1, SPEED_MAX do
		local pick_capabilities = {
			groupcaps = {
				stone = { times = {}, uses = 0 },
			},
		}

		for i = 1, level do
			pick_capabilities.groupcaps.stone.times[i] = math.max(1.1 - (0.1 * speed) * 0.8 ^ (level - i), 0.2)
		end
		pick_capabilities.groupcaps.stone.times[level + 1] = 1.5 - (0.1 * speed)

		minetest.register_tool(get_pick_name(level, speed), {
			description = "Pick Level " .. level,
			inventory_image = "score_pick_" .. image .. ".png",
			tool_capabilities = pick_capabilities,
			on_drop = function(itemstack, dropper, pos)
				return itemstack
			end,
		})
	end

end

minetest.register_node("score:light", {
	description = "Light",
	tiles = { "score_light.png" },
	groups = { dig_immediate = 3 },
	light_source = 14,
	sounds = {
		footstep = { name = "score_footstep", gain = 1.0 },
		place = { name=" score_dig ", gain = 0.5 },
		dug = { name="score_dig", gain = 0.5 },
	},
	on_drop = function(itemstack, dropper, pos)
		return itemstack
	end,
})

minetest.register_craftitem("score:score", {
	description = "Score",
})

minetest.register_tool(":", {
	type = "none",
	wield_image = "score_hand.png",
	wield_scale = { x = 1, y = 1, z = 1.5 },
	range = 4,
})

--
-- Turret
--

local TURRET_RANGE = 8

minetest.register_entity("score:turret_flash", {
	initial_properties = {
		physical = false,
		visual = "sprite",
		visual_size = { x = 0.5, y = 0.5 },
		textures = { "score_flash.png" },
		collisionbox = { 0, 0, 0, 0, 0, 0, },
	},

	on_activate = function(self, staticdata, dtime_s)
		if staticdata and staticdata ~= "" then
			local data = minetest.deserialize(staticdata)
			self.base_pos = data.base_pos
			self.level = data.level
		end
		self.level = self.level or 1
		self.sound_handle = minetest.sound_play("score_flash", {
			object = self.object,
			loop = true,
			max_hear_distance = TURRET_RANGE,
		})
	end,

	on_step = function(self, dtime)
		if not self.base_pos or vector.distance(self.base_pos, self.object:getpos()) > TURRET_RANGE + 3 then
			self.object:remove()
			minetest.sound_stop(self.sound_handle)
		end
		local mypos = self.object:getpos()
		for _, player in ipairs(minetest.get_objects_inside_radius(mypos, 2.5)) do
			if player:is_player() then
				local playerpos = player:getpos()
				local diff = vector.subtract(mypos, playerpos)
				local hit = true
				if hit and (diff.x > 0.6 or diff.x < -0.6) then
					hit = false
				end
				if hit and (diff.z > 0.6 or diff.z < -0.6) then
					hit = false
				end
				if hit and (diff.y > 2.1 or diff.y < -0.3) then
					hit = false
				end
				if hit then
					local level = get_pick_info(player)
					local damage = 1
					if self.level - level >= 0 then
						damage = damage + 1 + (self.level - level)
					end
					enable_damage = true
					player:punch(self.object, 1.0, {
						full_punch_interval = 1.0,
						damage_groups = { fleshy = damage },
					}, vector.multiply(diff, -1))
					enable_damage = false
					minetest.sound_stop(self.sound_handle)
					self.object:remove()
				end
			end
		end
	end,

	get_staticdata = function(self)
		return minetest.serialize({
			base_pos = self.base_pos,
			level = self.level,
		})
	end,
})

minetest.register_abm({
	nodenames = { "group:turret" },
	interval = 2,
	chance = 1,
	catch_up = false,
	action = function(pos, node)
		local level = tonumber(node.name:match("([%d]+)$")) or 1
		for _, player in ipairs(minetest.get_objects_inside_radius(pos, TURRET_RANGE)) do
			if player:is_player() then
				local playerpos = vector.add(player:getpos(), { x = 0, y = 1.4, z = 0 })
				local direction = vector.direction(pos, playerpos)
				if minetest.line_of_sight(vector.add(pos, direction), playerpos, 0.01) then
					local flash = minetest.add_entity(pos, "score:turret_flash")
					if flash then
						flash:get_luaentity().level = level
						flash:get_luaentity().base_pos = pos
						flash:setvelocity(vector.multiply(direction, 5))
					end
				end
			end
		end
	end,
})

--
-- Mapgen
--

local mg_params = minetest.get_mapgen_params()
local mg_noise_params = {
	offset = 0.0,
	scale = 1.0,
	spread = { x = 25, y = 25, z = 25 },
	seed = 4,
	octaves = 4,
	persistence = 0.5,
}

minetest.set_mapgen_params({
	mgname = "singlenode",
	flags = "nolight",
})


local c_air
local c_stones = {}
local c_turrets = {}
local noise_map

minetest.register_on_generated(function(minp, maxp, seed)
	local c_air = c_air or minetest.get_content_id("air")

	local vox_manip, vox_minp, vox_maxp = minetest.get_mapgen_object("voxelmanip")
	local vox_data = vox_manip:get_data()
	local vox_area = VoxelArea:new({ MinEdge = vox_minp, MaxEdge = vox_maxp })

	if not noise_map then
		noise_map = minetest.get_perlin_map(mg_noise_params,
				{ x = maxp.x - minp.x + 1, y = maxp.y - minp.y + 1, z = maxp.z - minp.z + 1 })
	end
	local noise_table = noise_map:get3dMap_flat(minp)
	local noise_index = 0

	local pr_gen = PseudoRandom(seed)

	for z = minp.z, maxp.z do
	for y = minp.y, maxp.y do
	for x = minp.x, maxp.x do
		local vox_index = vox_area:index(x, y, z)
		noise_index = noise_index + 1
		
		local radius = math.sqrt(x * x + z * z)
		local level = math.max(math.min(math.ceil(radius / LEVEL_EXTENT), LEVEL_MAX), 1)

		local noise = noise_table[noise_index] + math.abs((y + 50) / 32.0) - 0.8

		if noise > 0.0 then
			if not c_stones[level] then
				c_stones[level] = minetest.get_content_id("score:stone_" .. level)
			end
			vox_data[vox_index] = c_stones[level]
		else
			if vox_data[vox_area:index(x, y - 1, z)] ~= c_air and pr_gen:next(1, 400) == 1 then
				if not c_turrets[level] then
					c_turrets[level] = minetest.get_content_id("score:turret_" .. level)
				end
				vox_data[vox_index] = c_turrets[level]
			else
				vox_data[vox_index] = c_air
			end
		end
	end
	end
	end

	vox_manip:set_data(vox_data)
	minetest.generate_ores(vox_manip, minp, maxp)
	vox_manip:calc_lighting()
	vox_manip:write_to_map()
end)

-- Some aliases to supress error messages
minetest.register_alias("mapgen_stone", "air")
minetest.register_alias("mapgen_", "air")
minetest.register_alias("mapgen_water_source", "air")
minetest.register_alias("mapgen_river_water_source", "air")
