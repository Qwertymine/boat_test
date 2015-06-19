dofile(minetest.get_modpath("boat_test").."/waterlib.lua")
dofile(minetest.get_modpath("boat_test").."/complexphy.lua")
dofile(minetest.get_modpath("boat_test").."/infotools.lua")

--values for complex physics
local BOATRAD = 0.4
local COMPLEXPHYSICS = false

local function get_sign(i)
	if i == 0 then
		return 0
	else
		return i / math.abs(i)
	end
end

local function get_velocity_vector(v, yaw, y)
	local x = -math.sin(yaw) * v
	local z =  math.cos(yaw) * v
	return {x = x, y = y, z = z}
end

local function get_v(v)
	return math.sqrt(v.x ^ 2 + v.z ^ 2)
end

local boat_test = {
	physical = true,
	collisionbox = {-0.4, -0.4, -0.4, 0.4, 0.3, 0.4},
	visual = "mesh",
	mesh = "boat.obj",
	textures = {"default_wood.png"},
	automatic_face_movement_dir = -90.0,
	driver = nil,
	v = 0,
	last_v = 0,
	removed = false,
	in_water = false,
}

function boat_test.on_rightclick(self, clicker)
	if not clicker or not clicker:is_player() then
		return
	end
	local name = clicker:get_player_name()
	if self.driver and clicker == self.driver then
		self.driver = nil
		clicker:set_detach()
		default.player_attached[name] = false
		default.player_set_animation(clicker, "stand" , 30)
	elseif not self.driver then
		self.driver = clicker
		clicker:set_attach(self.object, "", {x = 0, y = 11, z = -3}, {x = 0, y = 0, z = 0})
		default.player_attached[name] = true
		minetest.after(0.2, function()
			default.player_set_animation(clicker, "sit" , 30)
		end)
		self.object:setyaw(clicker:get_look_yaw() - math.pi / 2)
	end
end

function boat_test.on_activate(self, staticdata, dtime_s)
	self.object:set_armor_groups({immortal = 1})
	if staticdata then
		self.v = tonumber(staticdata)
	end
	self.last_v = self.v
end

function boat_test.get_staticdata(self)
	return tostring(self.v)
end

function boat_test.on_punch(self, puncher, time_from_last_punch, tool_capabilities, direction)
	if not puncher or not puncher:is_player() or self.removed then
		return
	end
	if self.driver and puncher == self.driver then
		self.driver = nil
		puncher:set_detach()
		default.player_attached[puncher:get_player_name()] = false
	end
	if not self.driver then
		self.removed = true
		-- delay remove to ensure player is detached
		minetest.after(0.1, function()
			self.object:remove()
		end)
		if not minetest.setting_getbool("creative_mode") then
			puncher:get_inventory():add_item("main", "boat_test:boat")
		end
	end
end

function boat_test.on_step(self, dtime)
	
	local driver = self.driver
	local object = self.object
	local water_accel = 2
	local player_mass = 740 --N
	local boat_mass = 1000 --N
	local player_force = 3*1740 --N
	local water_force = 3*1000 --N
	local player_turn_force = 3*1000 --N
	local water_resistance = 100 --N
	local total_mass = boat_mass
	
	local flow = {}
	local water_force_total = {}
	local water_resistance_vector = {x=0,y=0,z=0}
	local velocity = object:getvelocity()
	local realpos = self.object:getpos()
	local pos = {x=math.floor(realpos.x+0.5),y=math.floor(realpos.y+0.5),z=math.floor(realpos.z+0.5)}
	local node   = minetest.get_node({x=pos.x,y=pos.y,z=pos.z})
	local param2 = node.param2
	
	--setup physics variables
	local yaw = object:getyaw()
	--setup self.v and any dependant variables
	self.v = math.abs(get_v(velocity))
	
	player_turn_force = player_turn_force * math.sqrt(self.v)
	water_resistance_vector = get_velocity_vector(water_resistance*self.v*self.v,yaw,water_resistance_vector.y)
	
	
	
	if COMPLEXPHYSICS and minetest.get_item_group(node.name, "water") == 0 then
		pos,node = move_centre(pos,realpos,node,BOATRAD)
	end
	
	--get initial water direction
	flow = quick_water_flow(pos,node)
	
	water_force_total = {x=flow.x*water_force,y=0,z=flow.z*water_force}
	
	
	--make it float
	if node_is_water(node) and flow.y == 0 then
		if COMPLEXPHYSICS then
			boat_particles(object,velocity,realpos)
		end
		object:get_luaentity().in_water = true
		--slow down boats that fall into water smoothly
		if velocity.y < 0 then
			flow.y = 10
		else
			flow.y = 4
		end
	end
	
	--make it fall when not in water
	if not node_is_water(node) then
		--beach it
		if minetest.registered_nodes[minetest.get_node({x=pos.x,y=pos.y-1,z=pos.z}).name].walkable == true then
			object:get_luaentity().in_water = false
			flow.y = -10
			velocity.x = 0
			velocity.z = 0
		else
			object:get_luaentity().in_water = false
			flow.y = -10
		end
	end
	
	local player_force_total = {x=0,y=0,z=0}
	if driver then
		total_mass = boat_mass + player_mass
		local player_force_vector = {x=0,y=0,z=0}
		local turn_force_vector = {x=0,y=0,z=0}
		local ctrl = self.driver:get_player_control()
		if ctrl.up then
			player_force_vector = get_velocity_vector(player_force,yaw,player_force_vector.y)
		elseif ctrl.down then
			player_force_vector = get_velocity_vector(-player_force,yaw,player_force_vector.y)
		end
		if ctrl.left then
			if self.v < 0 then
				turn_force_vector = get_velocity_vector(-player_turn_force,yaw+90,turn_force_vector.y)
			else
				turn_force_vector = get_velocity_vector(player_turn_force,yaw+90,turn_force_vector.y)
			end
		elseif ctrl.right then
		--correct yaw change to turn right is 89 for some reason...
			if self.v < 0 then
				turn_force_vector = get_velocity_vector(player_turn_force,yaw+89,turn_force_vector.y)
			else
				turn_force_vector = get_velocity_vector(-player_turn_force,yaw+89,turn_force_vector.y)
			end
		end
		player_force_total = { x=player_force_vector.x+turn_force_vector.x,y=player_force_vector.y+turn_force_vector.y,z=player_force_vector.z+turn_force_vector.z}
	end
	--add any more functionality before this block
	object:setvelocity({x=velocity.x,y=velocity.y,z=velocity.z})
	object:setacceleration({x=(water_force_total.x+player_force_total.x-water_resistance_vector.x)/total_mass,y=flow.y,z=(water_force_total.z+player_force_total.z-water_resistance_vector.z)/total_mass})
end

minetest.register_entity("boat_test:boat", boat_test)

minetest.register_craftitem("boat_test:boat", {
	description = "boat_test boat boat",
	inventory_image = "boat_inventory.png",
	wield_image = "boat_wield.png",
	wield_scale = {x = 2, y = 2, z = 1},
	liquids_pointable = true,

	on_place = function(itemstack, placer, pointed_thing)
		if pointed_thing.type ~= "node" then
			return
		end
		--if not is_water(pointed_thing.under) then
		--	return
		--end
		pointed_thing.under.y = pointed_thing.under.y + 1.0
		pointed_thing.under.y = pointed_thing.under.y
		minetest.add_entity(pointed_thing.under, "boat_test:boat")
		if not minetest.setting_getbool("creative_mode") then
			itemstack:take_item()
		end
		return itemstack
	end,
})







--[[
--
-- Helper functions
--

local function is_water(pos)
	local nn = minetest.get_node(pos).name
	return minetest.get_item_group(nn, "water") ~= 0
end

local function get_sign(i)
	if i == 0 then
		return 0
	else
		return i / math.abs(i)
	end
end

local function get_velocity(v, yaw, y)
	local x = -math.sin(yaw) * v
	local z =  math.cos(yaw) * v
	return {x = x, y = y, z = z}
end

local function get_v(v)
	return math.sqrt(v.x ^ 2 + v.z ^ 2)
end

--
-- Boat entity
--

local boat = {
	physical = true,
	collisionbox = {-0.5, -0.4, -0.5, 0.5, 0.3, 0.5},
	visual = "mesh",
	mesh = "boat.obj",
	textures = {"default_wood.png"},

	driver = nil,
	v = 0,
	last_v = 0,
	removed = false
}


function boat.on_step(self, dtime)
	self.v = get_v(self.object:getvelocity()) * get_sign(self.v)
	if self.driver then
		local ctrl = self.driver:get_player_control()
		local yaw = self.object:getyaw()
		if ctrl.up then
			self.v = self.v + 0.1
		elseif ctrl.down then
			self.v = self.v - 0.1
		end
		if ctrl.left then
			if self.v < 0 then
				self.object:setyaw(yaw - (1 + dtime) * 0.03)
			else
				self.object:setyaw(yaw + (1 + dtime) * 0.03)
			end
		elseif ctrl.right then
			if self.v < 0 then
				self.object:setyaw(yaw + (1 + dtime) * 0.03)
			else
				self.object:setyaw(yaw - (1 + dtime) * 0.03)
			end
		end
	end
	local velo = self.object:getvelocity()
	if self.v == 0 and velo.x == 0 and velo.y == 0 and velo.z == 0 then
		self.object:setpos(self.object:getpos())
		return
	end
	local s = get_sign(self.v)
	self.v = self.v - 0.02 * s
	if s ~= get_sign(self.v) then
		self.object:setvelocity({x = 0, y = 0, z = 0})
		self.v = 0
		return
	end
	if math.abs(self.v) > 4.5 then
		self.v = 4.5 * get_sign(self.v)
	end

	local p = self.object:getpos()
	p.y = p.y - 0.5
	local new_velo = {x = 0, y = 0, z = 0}
	local new_acce = {x = 0, y = 0, z = 0}
	if not is_water(p) then
		local nodedef = minetest.registered_nodes[minetest.get_node(p).name]
		if (not nodedef) or nodedef.walkable then
			self.v = 0
			new_acce = {x = 0, y = 1, z = 0}
		else
			new_acce = {x = 0, y = -9.8, z = 0}
		end
		new_velo = get_velocity(self.v, self.object:getyaw(), self.object:getvelocity().y)
		self.object:setpos(self.object:getpos())
	else
		p.y = p.y + 1
		if is_water(p) then
			local y = self.object:getvelocity().y
			if y >= 4.5 then
				y = 4.5
			elseif y < 0 then
				new_acce = {x = 0, y = 20, z = 0}
			else
				new_acce = {x = 0, y = 5, z = 0}
			end
			new_velo = get_velocity(self.v, self.object:getyaw(), y)
			self.object:setpos(self.object:getpos())
		else
			new_acce = {x = 0, y = 0, z = 0}
			if math.abs(self.object:getvelocity().y) < 1 then
				local pos = self.object:getpos()
				pos.y = math.floor(pos.y) + 0.5
				self.object:setpos(pos)
				new_velo = get_velocity(self.v, self.object:getyaw(), 0)
			else
				new_velo = get_velocity(self.v, self.object:getyaw(), self.object:getvelocity().y)
				self.object:setpos(self.object:getpos())
			end
		end
	end
	self.object:setvelocity(new_velo)
	self.object:setacceleration(new_acce)
end

minetest.register_entity("boats:boat", boat)

minetest.register_craft({
	output = "boats:boat",
	recipe = {
		{"",           "",           ""          },
		{"group:wood", "",           "group:wood"},
		{"group:wood", "group:wood", "group:wood"},
	},
})
]]--

