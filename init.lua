--
-- A single, global function to help with registering auto-boxed meshes
--
autobox = {}

local function param2offset(pos, param2)
    local ret = {}
        local param2Table = {
		[0]={"x",1,"y",1,"z",1}, --0
        {"z",1,"y",1,"x",-1}, --1
        {"x",-1,"y",1,"z",-1}, --2
		{"z",-1,"y",1,"x",1}, --3
		
		{"x",1,"z",-1,"y",1}, --4
		{"z",1,"x",1,"y",1}, --5
		{"x",-1,"z",1,"y",1}, --6
		{"z",-1,"x",-1,"y",1}, --7
		
		{"x",1,"z",1,"y",-1}, --8
		{"z",1,"x",-1,"y",-1}, --9
		{"x",-1,"z",-1,"y",-1}, --10
		{"z",-1,"x",1,"y",-1}, --11
		
		{"y",1,"x",-1,"z",1}, --12
		{"y",1,"z",-1,"x",-1}, --13
		{"y",1,"x",1,"z",-1}, --14
		{"y",1,"z",1,"x",1}, --15
		
		{"y",-1,"x",1,"z",1}, --16
		{"y",-1,"z",1,"x",-1}, --17
		{"y",-1,"x",-1,"z",-1}, --18
		{"y",-1,"z",-1,"x",1}, --19
		
		{"x",-1,"y",-1,"z",1}, --20
		{"z",-1,"y",-1,"x",-1}, --21
		{"x",1,"y",-1,"z",-1}, --22
		{"z",1,"y",-1,"x",1}, --23   
        } --End all 24 directions
        ret.x = pos[param2Table[param2][1]] * param2Table[param2][2] --{x or y or z value} * {+1 or -1}
        ret.y = pos[param2Table[param2][3]] * param2Table[param2][4]
        ret.z = pos[param2Table[param2][5]] * param2Table[param2][6]
		if ret.x == -0 then
			ret.x = 0
		end
		if ret.y == -0 then
			ret.y = 0
		end
		if ret.z == -0 then
			ret.z = 0
		end
    return ret
end

local function copy(obj, seen)
  if type(obj) ~= 'table' then return obj end
  if seen and seen[obj] then return seen[obj] end
  local s = seen or {}
  local res = setmetatable({}, getmetatable(obj))
  s[obj] = res
  for k, v in pairs(obj) do res[copy(k, s)] = copy(v, s) end
  return res
end



--Place all ".box" files in your mod's "/data" folder
function autobox.register_node(name, data_filename, node_definition, respect_nodes)

-- Load the data
local modname = minetest.get_current_modname()
local path = minetest.get_modpath(modname)
minetest.log( path .. "/data/" .. data_filename )
local f = io.open(path .. "/data/" .. data_filename, "rb")
local data = minetest.deserialize(f:read("*all"))
io.close(f)




local placement_node = copy(node_definition)
if data.numNodes > 1 then
    
    
    --Get list of child node positions
    local node_pos_list = {}
    for i=2,data.numNodes do 
        node_pos_list[i-1] = data.nodes[i].position    
    end
    
    ----------------------------------------On Construct-----------------------------------------------
    placement_node.on_construct = function(pos)
        --Check if placement can occur:
        if respect_nodes == true then
            for i=2,data.numNodes do
                local node_pos = vector.add(pos, data.nodes[i].position)
                local node_name = minetest.get_node_or_nil(node_pos).name
                if node_name ~= "air" and node_name ~= nil then
                    
                    minetest.remove_node(pos) --Placement Won't work
                    
                    --Let the nearby players know why it didn't work
                    local all_objects = minetest.get_objects_inside_radius(pos, 15)
                    for _,obj in ipairs(all_objects) do
                        if obj:is_player() then
                            minetest.chat_send_player(obj,"Unable to place " .. name .. " due to node already at: (" .. node_pos.x .. ", " .. node_pos.y .. ", " .. node_pos.z .. ")")
                        end
                    end
                    return false --hopefully this is allowed :)
                end
            end
        end
        
        --Okay we will be able to place our object without any issues, let's do so
  
        --First save the positions of all the child nodes
        local meta = minetest.get_meta(pos)
        meta:set_string("child_nodes", minetest.serialize(node_pos_list))
		meta:set_string("numNodes", tostring(data.numNodes-1))
		local parent_param2 = minetest.get_node(pos).param2
        
        --then place all the child nodes
        for i=2,data.numNodes do
			local child_pos = vector.add(pos, param2offset(data.nodes[i].position, parent_param2)) --calculate node position
            minetest.set_node(child_pos,{name=name..i-1, param1 = 0, param2 = parent_param2 }) --set the node
			minetest.get_meta(child_pos):set_string("parent_pos", minetest.serialize(pos)) --set that node's parent
        end
    end
    
    ----------------------------------------On Destruct----------------------------------------
    placement_node.on_destruct = function(pos)
        local meta = minetest.get_meta(pos)
        --First remove the nodes
        local node_pos_list = minetest.deserialize(meta:get_string("child_nodes"))
		if node_pos_list ~= nil then
			local parent_param2 = minetest.get_node(pos).param2
			--param 2 is between 0-23, need to properly change directions of the node position offsets based on this value
			
			--First we need to specify the order ( xyz , xzy , yxz , yzx , zxy, zyx )
			--Then specify the direction. Maybe I should just do a lookup table.........
			--Z direction is always facedir_to_dir, that is accurate for Z only.
			local numNodes = tonumber(meta:get_string("numNodes"))
			for i=1,numNodes do
				local adjusted_offset = param2offset(node_pos_list[i], parent_param2)
				minetest.swap_node(vector.add(pos, adjusted_offset),{name="air"}) --Don't trigger the destructors
				minetest.get_meta(vector.add(pos, adjusted_offset)):from_table(nil) --delete the metadata
			end
		end
    end
    
    ----------------------------------------On Rotate-----------------------------------------------
    placement_node.on_rotate = function(pos, node, user, mode, new_param2) --ignore new_param2 and just use the mode and a lookup table
        --Check for protection
            --if protected return false
        
        if respect_nodes == true then
            --Check for availability at new param2 for each child node (ignore any nodes with a name starting with this node's name)
                --If even one is not available, return false and alert nearby players where it's not available
        end
           
        --All spots are available, Delele old nodes, place the new nodes at correct locations. setting 'param2 = new_param2' (to get correct collision boxes)
		local meta = minetest.get_meta(pos)
        local node_pos_list = minetest.deserialize(meta:get_string("child_nodes"))
		local numNodes =  tonumber(meta:get_string("numNodes"))
        
        --table for storing node_param1 values
        local param1s = {}
        
        --Remove old nodes
        local old_param2 = node.param2
        for i=1,numNodes do
			local adjusted_offset = param2offset(node_pos_list[i], old_param2) --YOU ARE HERE
            local child_pos = vector.add(pos, adjusted_offset)
            param1s[i] = minetest.get_node(child_pos).param1
			minetest.swap_node(child_pos,{name="air"}) --Don't trigger the destructors
			minetest.get_meta(child_pos):from_table(nil) --delete the metadata
        end
		        
        --Place new nodes
		for i=1,numNodes do
			local adjusted_offset = param2offset(node_pos_list[i], new_param2)
			local child_pos = vector.add(pos, adjusted_offset) --calculate node position
			minetest.set_node(child_pos,{name=name..i, param1 = 0, param2 = new_param2 }) --set the node
			minetest.get_meta(child_pos):set_string("parent_pos", minetest.serialize(pos)) --set that node's parent
        end
		local p_node = minetest.get_node(pos)
		minetest.swap_node(pos,{name=p_node.name, param1 = p_node.param1, param2 = new_param2})
		return true
    end
	
	placement_node.draw_type = "mesh" --Just in case, maybe you forget ;)
	placement_node.collision_box =  {
										type = "fixed",
										fixed = data.nodes[1].boxTable
									}
	placement_node.selection_box =  {
										type = "fixed",
										fixed = data.nodes[1].boxTable
									}
	
	--Register Placement Node
	minetest.register_node(name, placement_node)
	
	for i=2,data.numNodes do
			local child_def = copy(node_definition)
			child_def.draw_type = "airlike" --Gotta be invisible
			child_def.mesh = ""
			child_def.collision_box =  	{
											type = "fixed",
											fixed = data.nodes[i].boxTable
										}
			child_def.selection_box =  	{
											type = "fixed",
											fixed = data.nodes[i].boxTable
										}
			child_def.drop = ""
			child_def.groups.not_in_creative_inventory = 1
			---------------------------------------------------Child Destruct---------------------------------
			child_def.on_destruct = function(pos) --This will only occur on a dig
				local parent_pos = minetest.deserialize(minetest.get_meta(pos):get_string("parent_pos"))
				if parent_pos ~= nil then
				--call the parent's destructor. 
					minetest.remove_node(parent_pos)
				--remove the parent by digging (yielding a drop)
				end
			end
			
			child_def.on_dig = function(pos, node, digger)
				local parent_pos = minetest.deserialize(minetest.get_meta(pos):get_string("parent_pos"))
				minetest.node_dig(parent_pos, {name=name}, digger)
			end
			
			child_def.on_rotate = function(pos, node, user, mode, new_param2)
				local parent_pos = minetest.deserialize(minetest.get_meta(pos):get_string("parent_pos"))
				return minetest.registered_nodes[name].on_rotate(parent_pos, minetest.get_node(parent_pos), user, mode, new_param2)	
			end
			
            minetest.register_node(name..i-1, child_def)
	end  
    
	--register first node based on first set of boxes, change it's on_place, on_rotate, on_dig, etc. to pull up the other nodes
	--Register the dependent nodes, and have them call the parent node's on_place, on_rotate, etc. when interacted with
	--If the user provides a special on_place or on_rotate, then we will have to tack it on at the end of ours. 
	
	--[[
		on_construct = function(pos),
		on_destruct = function(pos),
		on_punch = function(pos, node, puncher, pointed_thing),
		on_rightclick = function(pos, node, clicker, itemstack, pointed_thing),
		on_rotate = fuunction(vector.new(pos),
				{name = node.name, param1 = node.param1, param2 = node.param2},
				user, mode, new_param2) --Should return false, and handle all rotation inside .on_rotate
		https://github.com/minetest/minetest_game/blob/master/mods/screwdriver/init.lua
		on_dig = function(pos, node, digger),
	]]
else --Single node representation
	--Only need to overwrite the collision and selection boxes
	placement_node.draw_type = "mesh" --Just in case, maybe you forget ;)
	placement_node.collision_box = {
										type = "fixed",
										fixed = data.nodes[1].boxTable
									}
	placement_node.selection_box = {
										type = "fixed",
										fixed = data.nodes[1].boxTable
									}
									
	--Just register the node like normal. Nothing that special is required here, just autoboxing a single node							
	minetest.register_node(name, placement_node)
	minetest.log("Only one node")
end --end if else
end  --End autobox function




--Example
node_definition ={
	description =  "Glove",
	drawtype = "mesh",
        mesh = "glove.obj",
        sunlight_propagates = true,
        paramtype2 = "facedir",
        collision_box = {
            type = "fixed",
            fixed = {{0.95, -1.55, -0.55, -0.25, -0.65, 0.55}}
        },
        selection_box = {
            type = "fixed",
            fixed = {{0.95, -1.55, -0.55, -0.25, -0.65, 0.55}}
        },

        tiles = {"stone.png"},

        
        groups = { cracky=2 },

}
autobox.register_node("autobox:glove","glove.box",node_definition,false)

node_definition ={
	description =  "Spike",
	drawtype = "mesh",
        mesh = "spike.obj",
        sunlight_propagates = true,
        paramtype2 = "facedir",
        collision_box = {
            type = "fixed",
            fixed = {{0.95, -1.55, -0.55, -0.25, -0.65, 0.55}}
        },
        selection_box = {
            type = "fixed",
            fixed = {{0.95, -1.55, -0.55, -0.25, -0.65, 0.55}}
        },

        tiles = {"stone.png"},

        
        groups = { cracky=2 },

}
autobox.register_node("autobox:spike","spike.box",node_definition,false)

node_definition ={
	description =  "Spike2",
	drawtype = "mesh",
        mesh = "spike2.obj",
        sunlight_propagates = true,
        paramtype2 = "facedir",
        collision_box = {
            type = "fixed",
            fixed = {{0.95, -1.55, -0.55, -0.25, -0.65, 0.55}}
        },
        selection_box = {
            type = "fixed",
            fixed = {{0.95, -1.55, -0.55, -0.25, -0.65, 0.55}}
        },

        tiles = {"stone.png"},

        
        groups = { cracky=2 },

}
autobox.register_node("autobox:spike2","spike2.box",node_definition,false)

node_definition ={
	description =  "Spike2-Relo",
	drawtype = "mesh",
        mesh = "spike2-relo.obj",
        sunlight_propagates = true,
        paramtype2 = "facedir",
        collision_box = {
            type = "fixed",
            fixed = {{0.95, -1.55, -0.55, -0.25, -0.65, 0.55}}
        },
        selection_box = {
            type = "fixed",
            fixed = {{0.95, -1.55, -0.55, -0.25, -0.65, 0.55}}
        },

        tiles = {"stone.png"},

        
        groups = { cracky=2 },

}
autobox.register_node("autobox:spike2_relo","spike2-relo.box",node_definition,false)

node_definition ={
	description =  "Wagon",
	drawtype = "mesh",
        mesh = "wagon.obj",
        sunlight_propagates = true,
        paramtype2 = "facedir",
        collision_box = {
            type = "fixed",
            fixed = {{0.95, -1.55, -0.55, -0.25, -0.65, 0.55}}
        },
        selection_box = {
            type = "fixed",
            fixed = {{0.95, -1.55, -0.55, -0.25, -0.65, 0.55}}
        },

        tiles = {"wagon.png"},

        
        groups = { cracky=2 },

}
autobox.register_node("autobox:wagon","wagon.box",node_definition,false)
