--
-- A single, global function to help with registering auto-boxed meshes
--
autobox = {}

--Place all ".box" files in your mod's "/data" folder
function autobox.register_node(name, data_filename, node_definition, respect_nodes)

-- Load the data
local f = io.open("data/" .. data_filename, "rb")
local data = minetest.deserialize(f:read("*all"))
io.close(f)

if data.numNodes > 1 then
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