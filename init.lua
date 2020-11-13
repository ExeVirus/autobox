--
-- A single, global function to help with registering auto-boxed meshes
--
autobox = {}
--------------------------------------DELETE ME LATER-------------------------------------------
-- local export = require "export"
-- local vector = require "vector"
-- local minetest = {}
-- function minetest.register_node(name, node_def)
-- end
-- function minetest.get_meta(pos)
-- end
-- function minetest.chat_send_player(name, message)
-- end
-- function minetest.get_objects_inside_radius(pos, range)
-- end
-- function minetest.remove_node(pos)
-- end
-- function minetest.place_node(pos, node)
-- end
---------------------------------------END DELETEME---------------------------------------------

--Place all ".box" files in your mod's "/data" folder
function autobox.register_node(name, data_filename, node_definition, respect_nodes)

-- Load the data
local f = io.open("data/" .. data_filename, "rb")
local data = export.deserialize(f:read("*all"))
io.close(f)


local function param2offset(pos, param2)
    local ret = {}
        local param2Table = {
        [0]={"x",1,"y",1,"z",1},
        {"y",1,"x",1,"z",1},
        
        
        
        
        
        
        } --End all 24 directions
        ret.x = pos[param2Table[param2][1]] * param2Table[param2][2] --{x or y or z} * {+1 or -1}
        ret.y = pos[param2Table[param2][3]] * param2Table[param2][4]
        ret.z = pos[param2Table[param2][5]] * param2Table[param2][6]
    return ret
end



if data.numNodes > 1 then
    local placement_node = node_definition
    
    --Get list of child node positions
    local node_pos_list = {}
    for i=2,data.numNodes do 
        node_pos_list[i-1] = data.nodes[1].position    
    end
    
    ----------------------------------------On Construct-----------------------------------------------
    placement_node.on_construct = function(pos)
        --Check if placement can occur:
        if respect_nodes then
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
        meta:set_string("child_nodes", export.serialize(node_pos_list))
        
        --then place all the child nodes
        for i=2,data.numNodes do
            minetest.place_node(vector.add(pos, data.nodes[i].position), name .. (i-1)
        end          
    end
    
    ----------------------------------------On Destruct----------------------------------------
    placement_node.on_destruct = function(pos)
        local meta = minetest.get_meta(pos)
        --First remove the nodes
        local node_pos_list = minetest.deserialize(meta:get_string("child_nodes"))
        local param2 = minetest.get_node(pos).param2
        --param 2 is between 0-23, need to properly change directions of the node position offsets based on this value
        
        --First we need to specify the order ( xyz , xzy , yxz , yzx , zxy, zyx )
        --Then specify the direction. Maybe I should just do a lookup table.........
        --Z direction is always facedir_to_dir, that is accurate for Z only.
        local adjusted_offset = param2offset(child_node_pos, param2)
        for _,child_node_pos in ipairs(node_pos_list) do
            minetest.remove_node(vector.add(pos, adjusted_offset)) --Child Node destructors will clean up the meta
        end
        meta:set_string("child_nodes", nil)
    end
    
    ----------------------------------------On Rotate-----------------------------------------------
    placement_node.on_rotate = function(pos, node, user, mode, new_param2) --ignore new_param2 and just use the mode and a lookup table
        --Check for protection
            --if protected return false
        
        if respect_nodes then
            --Check for availability at new param2 for each child node (ignore any nodes with a name starting with this node's name)
                --If even one is not available, return false and alert nearby players where it's not available
        end
           
        --All spots are available, Delele old nodes, place the new nodes at correct locations. setting 'param2 = new_param2' (to get correct collision boxes)
        local node_pos_list = minetest.deserialize(meta:get_string("child_nodes"))
        
        --table for storing node_param1 values
        local param1s = {}
        
        --Remove old nodes
        local old_param2 = node.param2
        local adjusted_offset = param2offset(child_node_pos, old_param2)
        for i,child_node_pos in ipairs(node_pos_list) do
            local child_pos = vector.add(pos, adjusted_offset)
            param1s[i] = minetest.get_node(child_pos).param1
            minetest.remove_node(child_pos) --Child Node destructors will clean up the meta
        end
        
        --Place new nodes
        adjusted_offset = param2offset(child_node_pos, new_param2)
        for i,child_node_pos in ipairs(node_pos_list) do
            minetest.set_node(vector.add(pos, adjusted_offset), {name=name..i, param1 = param1s[i], param2 = new_param2 })
        end
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
	node_definition.draw_type = "mesh" --Just in case, maybe you forget ;)
	node_definition.collision_box = {
										type = "fixed",
										fixed = data.nodes[1].boxList
									}
	node_definition.selection_box = {
										type = "fixed",
										fixed = data.nodes[1].boxList
									}
									
	--Just register the node like normal. Nothing that special is required here, just autoboxing a single node							
	minetest.register_node(name, node_definition)
end
end