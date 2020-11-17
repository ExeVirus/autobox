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
	
	----------------------------------------On Place-----------------------------------------------	
	placement_node.on_place = function(itemstack, placer, pointed_thing) --Mostly taken from core.item_place_node
		if pointed_thing.type ~= "node" then
			return itemstack, nil
		end
		local under = pointed_thing.under
		local oldnode_under = minetest.get_node_or_nil(under)
		local above = pointed_thing.above
		local oldnode_above = minetest.get_node_or_nil(above)
		local playername = user_name(placer)
		local log = make_log(playername)
	
		if not oldnode_under or not oldnode_above then
			log("info", playername .. " tried to place"
				.. " node in unloaded position " .. core.pos_to_string(above))
			return itemstack, nil
		end
		
		local olddef_under = core.registered_nodes[oldnode_under.name]
		olddef_under = olddef_under or core.nodedef_default
		local olddef_above = core.registered_nodes[oldnode_above.name]
		olddef_above = olddef_above or core.nodedef_default

		if not olddef_above.buildable_to and not olddef_under.buildable_to then
			log("info", playername .. " tried to place"
				.. " node in invalid position " .. core.pos_to_string(above)
				.. ", replacing " .. oldnode_above.name)
			return itemstack, nil
		end
		
		-- Place above pointed node
		local place_to = {x = above.x, y = above.y, z = above.z}
		
		-- If node under is buildable_to, place into it instead (eg. snow)
		if olddef_under.buildable_to then
			log("info", "node under is buildable to")
			place_to = {x = under.x, y = under.y, z = under.z}
		end
		
		if minetest.is_protected(place_to, playername) then
			log("action", playername
					.. " tried to place " .. def.name
					.. " at protected position "
					.. minetest.pos_to_string(place_to))
			minetest.record_protection_violation(place_to, playername)
			return itemstack, nil
		end
        
        --Get the param2 set before cycling through children nodes
        
        local oldnode = core.get_node(place_to)
		local newnode = {name = def.name, param1 = 0, param2 = param2 or 0}
		
		if def.place_param2 ~= nil then
			newnode.param2 = def.place_param2
		elseif (def.paramtype2 == "facedir" or
				def.paramtype2 == "colorfacedir") and not param2 then
			local placer_pos = placer and placer:get_pos()
			if placer_pos then
				local dir = {
					x = above.x - placer_pos.x,
					y = above.y - placer_pos.y,
					z = above.z - placer_pos.z
				}
				newnode.param2 = core.dir_to_facedir(dir)
				log("info", "facedir: " .. newnode.param2)
			end
		end
        
        --Now check protection for all the child nodes
        for i=2,data.numNodes do
            local child_pos = vector.add(place_to, param2offset(data.nodes[i].position, newnode.param2))
            if minetest.is_protected(child_pos, playername) then
                log("action", playername
                        .. " tried to place " .. def.name .. i-1
                        .. " at protected position "
                        .. minetest.pos_to_string(node_pos))
                minetest.record_protection_violation(place_to, playername)
                --Let the player know:
                minetest.chat_send_player(playername, "Unable to place object at ".. minetest.pos_to_string(place_to) .. " due to protection at: " .. minetest.pos_to_string(node_pos))
                return itemstack, nil
            end
        end
		
        --Now check if all spots besides the first is available
        --If not, let the player know where
		if respect_nodes == true then
            for i=2,data.numNodes do
            local child_pos = vector.add(place_to, param2offset(data.nodes[i].position, newnode.param2))
            local old_node = minetest.get_node_or_nil(child_pos)
            if old_node.name ~= "air" or old_node ~= nil or minetest.registered_nodes[old_node.name].draw_type == "liquid" or minetest.registered_nodes[old_node.name].draw_type == "flowingliquid" then
                log("action", playername
                        .. " tried to place " .. def.name
                        .. " (an autobox multi-node model) at inhabited position "
                        .. minetest.pos_to_string(node_pos))
                minetest.chat_send_player(playername, "Unable to place object at ".. minetest.pos_to_string(place_to) .. " due to " .. old_node.name .. " node at " .. minetest.pos_to_string(child_pos))
                return itemstack, nil
            end
        end

		log("action", playername .. " places node "
				.. def.name .. " at " .. core.pos_to_string(place_to))		
		
		-- Add node and update
		minetest.add_node(place_to, newnode)
        
        --Set up meta for finding the child nodes later
        local meta = minetest.get_meta(pos)
        meta:set_string("child_nodes", minetest.serialize(node_pos_list))
		meta:set_string("numNodes", tostring(data.numNodes-1))
		
		-- add the rest of the nodes, but without callbacks, since the parent handles all that :)
        for i=2,data.numNodes do
			local child_pos = vector.add(place_to, param2offset(data.nodes[i].position, newnode.param2)) --calculate node position
            minetest.swap_node(child_pos,{name=name..i-1, param2 = newnode.param2 }) --set the node
            local meta = minetest.get_meta(child_pos)
            meta:from_table(nil) --delete previous meta
			meta:set_string("parent_pos", minetest.serialize(place_to)) --set the child node's parent position
        end
			
		-- Play sound if it was done by a player
		if playername ~= "" and def.sounds and def.sounds.place then
			minetest.sound_play(def.sounds.place, {
				pos = place_to,
				exclude_player = playername,
			}, true)
		end
		
		local take_item = true
		
		-- Run callback
		if def.after_place_node and not prevent_after_place then
			-- Deepcopy place_to and pointed_thing because callback can modify it
			local place_to_copy = {x=place_to.x, y=place_to.y, z=place_to.z}
			local pointed_thing_copy = copy_pointed_thing(pointed_thing)
			if def.after_place_node(place_to_copy, placer, itemstack,
					pointed_thing_copy) then
				take_item = false
			end
		end
		
		-- Run script hook
		for _, callback in ipairs(core.registered_on_placenodes) do
			-- Deepcopy pos, node and pointed_thing because callback can modify them
			local place_to_copy = {x=place_to.x, y=place_to.y, z=place_to.z}
			local newnode_copy = {name=newnode.name, param1=newnode.param1, param2=newnode.param2}
			local oldnode_copy = {name=oldnode.name, param1=oldnode.param1, param2=oldnode.param2}
			local pointed_thing_copy = copy_pointed_thing(pointed_thing)
			if callback(place_to_copy, newnode_copy, placer, oldnode_copy, itemstack, pointed_thing_copy) then
				take_item = false
			end
		end
		
		if take_item then
			itemstack:take_item()
		end
		return itemstack, place_to
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
        --Get player name for protection checking and chat
        local playername = user and user:get_player_name() or ""
        
        --Get meta describing positioning
        local meta = minetest.get_meta(pos)
        local node_pos_list = minetest.deserialize(meta:get_string("child_nodes"))
		local numNodes =  tonumber(meta:get_string("numNodes"))
        
        --Check protection for children node destinations
        for i=1,numNodes do
            local child_pos = vector.add(pos, param2offset(node_pos_list[i], new_param2))
            if minetest.is_protected(child_pos, player_name) then
                --Let the player know:
                minetest.chat_send_player(playername, "Unable to rotate object at ".. minetest.pos_to_string(pos) .. " due to protection at: " .. minetest.pos_to_string(node_pos))
                return false --Fail to rotate
            end
        end
		
        --Now check if all spots, besides the first, are available
        --If not, let the player know where
		if respect_nodes == true then
            for i=1,numNodes do
                local child_pos = vector.add(pos, param2offset(node_pos_list[i], new_param2))
                local old_node = minetest.get_node_or_nil(child_pos)
                if old_node.name ~= "air" or old_node ~= nil or minetest.registered_nodes[old_node.name].draw_type == "liquid" or minetest.registered_nodes[old_node.name].draw_type == "flowingliquid" then
                    minetest.chat_send_player(playername, "Unable to place object at ".. minetest.pos_to_string(place_to) .. " due to " .. old_node.name .. " node at " .. minetest.pos_to_string(child_pos))
                    return false --Fail to rotate
                end
            end
        end
           
        --All spots are available, Delele old nodes, place the new nodes at correct locations. setting 'param2 = new_param2' (to get correct collision boxes)
		
        
        --table for storing node_param1 values
        local param1s = {}
        
        --Remove old child nodes
        local old_param2 = node.param2
        for i=1,numNodes do
			local child_pos = vector.add(pos, param2offset(node_pos_list[i], old_param2))
            param1s[i] = minetest.get_node(child_pos).param1
			minetest.swap_node(child_pos,{name="air"}) --Don't trigger the destructors
			minetest.get_meta(child_pos):from_table(nil) --delete the metadata
        end
		        
        --Place new child nodes
		for i=1,numNodes do
			local adjusted_offset = param2offset(node_pos_list[i], new_param2)
			local child_pos = vector.add(pos, adjusted_offset) --calculate node position
			minetest.swap_node(child_pos,{name=name..i, param1 = param1s[i], param2 = new_param2 }) --set the node
            local meta = minetest.get_meta(child_pos)
            meta:from_table(nil) --delete the metadata
			meta:set_string("parent_pos", minetest.serialize(pos)) --set that node's parent
        end
        
        --Don't forget the parent node itself :)
		local p_node = minetest.get_node(pos)
		minetest.swap_node(pos,{name=p_node.name, param1 = p_node.param1, param2 = new_param2})
		return true --rotate success
    end
    
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
			child_def.mesh = "" --Which ironically 
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
            
            --Call the parent for everything :)
            
			child_def.on_destruct = function(pos) --This will only occur on a dig
				local parent_pos = minetest.deserialize(minetest.get_meta(pos):get_string("parent_pos"))
                minetest.remove_node(parent_pos)
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
            
            child_def.on_punch = function(pos, node, puncher, pointed_thing)
                local parent_pos = minetest.deserialize(minetest.get_meta(pos):get_string("parent_pos"))
                return minetest.registered_nodes[name].on_punch(parent_pos, minetest.get_node(parent_pos), puncher, pointed_thing)
            end
            
            child_def.on_rightclick = function(pos, node, clicker, itemstack, pointed_thing)
                local parent_pos = minetest.deserialize(minetest.get_meta(pos):get_string("parent_pos"))
                return minetest.registered_nodes[name].on_rightclick(parent_pos, minetest.get_node(parent_pos), clicker, itemstack, pointed_thing)
            end
            
            child_def.on_blast = function(pos, intensity)
                local parent_pos = minetest.deserialize(minetest.get_meta(pos):get_string("parent_pos"))
                return minetest.registered_nodes[name].on_blast(parent_pos, intensity)
            end
			
            minetest.register_node(name..i-1, child_def)
	end  
    

else 
                                    -----------Single node representation----------------
	--Only need to overwrite the collision and selection boxes
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
end --end if single node represented object
end --End autobox function

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

node_definition ={
	description =  "Bridge",
	drawtype = "mesh",
        mesh = "bridge.obj",
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

        tiles = {"bridge.png"},

        
        groups = { cracky=2 },

}
autobox.register_node("autobox:bridge","bridge.box",node_definition,false)
