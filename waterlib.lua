	--this code is extremely inefficient
	--check for flowing water (This is insane)

--calculate correct water height
local function get_mod_node_param2(pos)
	local node = minetest.get_node({x=pos.x,y=pos.y,z=pos.z})
	local param2 = node.param2
	-- 8 = water above or source, 8 > flowing, negative = flowing down
	if node.name == "default:water_source" then
		param2 = 8
	elseif node.name == "default:water_flowing" then
	--water above
		if minetest.get_item_group(minetest.get_node({x=pos.x,y=pos.y+1,z=pos.z}).name, "water") ~= 0 then
			param2 = 8
		--water below 	--MODIFY THE PARAM2 IF NODE IS FLOWING WATER WITH FLOWING WATER BELOW IT (NEEDS TO SUBTRACT 8)
		elseif minetest.get_item_group(minetest.get_node({x=pos.x,y=pos.y-1,z=pos.z}).name, "water") ~= 0  then
			param2 = param2 - 8
		-- else keep default
		end
	else
	--if not water
	param2 = nil
	end
	return param2
end

-- direction should be 1 or -1
-- returns axis aligned direction the boat would flow based on the single node
local function water_flow_logic(param2,pos_testing,direction)
	local param2_testing = get_mod_node_param2(pos_testing)
	if param2_testing and param2 then
		if param2_testing < param2 then
			return direction
		elseif param2_testing > param2 then
			return (0 - direction)
		else
			return 0
		end
	else
		return 0
	end
end

--sum of directions must be less than 5
function to_unit_vector(dir_vector)
	--(sum,root)
	-- (0,1), (1,1+0=1), (2,1+1=2), (3,1+2^2=5), (4,2^2+2^2=8)
	local roots = {[0] = 1, [1] = 1, [2] = 1.414213562373095, [4] = 2, [5] = 2.236067977499789, [8] = 2.828427124746190}
	local sum = math.abs(dir_vector.x)^2 + math.abs(dir_vector.z)^2
	local vector_out = {x=dir_vector.x/roots[sum],y=dir_vector.y,z=dir_vector.z/roots[sum]}
	return vector_out
end

--8 directions only + 0
--returns values between -1 and 1
function 8d_water_flow(pos)
	local node = minetest.get_node({x=pos.x,y=pos.y,z=pos.z})
	local param2 = get_mod_node_param2(pos)
	local param2_testing = nil
	local is_source = false
	local x = 0
	local z = 0
	
	-- water flow logic
	x = x + water_flow_logic(param2,{x=pos.x-1,y=pos.y,z=pos.z},-1)
	x = x + water_flow_logic(param2,{x=pos.x+1,y=pos.y,z=pos.z}, 1)
	z = z + water_flow_logic(param2,{x=pos.x,y=pos.y,z=pos.z-1},-1)
	z = z + water_flow_logic(param2,{x=pos.x,y=pos.y,z=pos.z+1}, 1)
	
	--reduce to 8 directions
	if x ~= 0 then
		x = x / math.abs(x)
	end
	
	if z ~= 0 then
		z = z / math.abs(z)
	end
	
	return to_unit_vector({x=x,y=0,z=z})
end

--full 16 directions + 0 --matches rendered directions
--returns values between -2 and 2
function water_flow(pos)
	local node = minetest.get_node({x=pos.x,y=pos.y,z=pos.z})
	local param2 = get_mod_node_param2(pos)
	local param2_testing = nil
	local is_source = false
	local x = 0
	local z = 0
	
	-- water flow logic
	x = x + water_flow_logic(param2,{x=pos.x-1,y=pos.y,z=pos.z},-1)
	x = x + water_flow_logic(param2,{x=pos.x+1,y=pos.y,z=pos.z}, 1)
	z = z + water_flow_logic(param2,{x=pos.x,y=pos.y,z=pos.z-1},-1)
	z = z + water_flow_logic(param2,{x=pos.x,y=pos.y,z=pos.z+1}, 1)
	
	return to_unit_vector({x=x,y=0,z=z})
end

function is_touching_water(realpos,nodepos,radius)
	local boarder = 0.5 - radius
	return (math.abs(realpos - nodepos) > (boarder))
end

function is_water(pos)
	return (minetest.get_item_group(minetest.get_node({x=pos.x,y=pos.y,z=pos.z}).name, "water") ~= 0)
end


--[[
function get_quick_mod_node_param2(pos)
	local node = minetest.get_node({x=pos.x,y=pos.y,z=pos.z})
	local param2 = node.param2
	-- 9 = water above 8 = source 8 > flowing
	--water source or water source with water above
	if node.name == "default:water_source" then
		if minetest.get_item_group(minetest.get_node({x=pos.x,y=pos.y+1,z=pos.z}).name, "water") ~= 0 then
			param2 = 9
		else
			param2 = 8
		end
	--flowing or flowing with water above
	elseif node.name == "default:water_flowing" then
		if param2 == 7 then
			if minetest.get_item_group(minetest.get_node({x=pos.x,y=pos.y+1,z=pos.z}).name, "water") ~= 0 then
				param2 = 9
			end
		-- else
		-- keep default
		end
	end
	return param2
end

local function get_quick_mod_node_param2(pos)
	local node = minetest.get_node({x=pos.x,y=pos.y,z=pos.z})
	local param2 = node.param2
	-- 9 = water above, 8 = source, 8 > flowing
	if minetest.get_item_group(node.name,"water") ~= 0 then
		--water above
		if minetest.get_item_group(minetest.get_node({x=pos.x,y=pos.y+1,z=pos.z}).name, "water") ~= 0 then
			param2 = 9
		--water source
		elseif node.name == "default:water_source" then
			param2 = 8
		-- else keep default
		end
	else
	--if not water
	param2 = nil
	end
	return param2
end

--]]
