--require "init"

local node_def = {


}

local pos = {x=1,y=2,z=3}
print(pos.x)
local var = "z"
print(pos[var])

--autobox.register_node("test:test", "data.box", node_definition, true)