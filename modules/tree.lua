local M = {}


local function linkMetaTables( tbls, Tree )
	-- Loop through table and assign metatable to all nested tables
	for i, tbl in pairs(tbls) do
		if type(tbl) == "table" then
			if (tbl.type == hash("task") or tbl.type == hash("limiter")) then
				setmetatable(tbl, Tree)
			elseif i == "child" or i == "children" or type(i) == "number" then
				linkMetaTables(tbl, Tree)
			end
		end
	end
end

----------------------------------
-- Main tree
----------------------------------
function M.start( self, callback )

	local Tree = nil

	-- Which ever script inits this Behavior Tree instance
	-- Should have it's own 'SetupTree' function that gets called 
	if type(callback) == "function" then
		-- This callback should call 'SetupTree' from the behavior initializer
		-- IE: Boss creates a Behavior tree. That source needs to send the reference to 'SetupTree'
		-- 'SetupTree' will then return the 'Root Node' code initialized and attached
		-- For function calls and data requested per that node.
		-- Actual tree instance to use		
		Tree = callback(self)
		Tree.sharedData = {}
		Tree.__index = Tree
		linkMetaTables(Tree, Tree)
	end


	----------------------------------------------
	-- Blackboard data access for:
	-- Set data
	----------------------------------------------			
	function Tree:setData(key, value)
		self.sharedData[key] = value
	end				

	-------------------------------------
	-- Get data
	-------------------------------------
	function Tree:getData( key )
		-- Test to see if the value is at this level
		if self.sharedData[key] ~= nil then
			return self.sharedData[key]
		end
		-- Upon failure to locate a valid node, return nil
		return nil
	end

	------------------------------
	-- Clear data
	------------------------------
	function Tree:clearData( key )
		-- Test to see if the value is at this level
		if self.sharedData[key] ~= nil then
			self.sharedData[key] = nil
			return true
		end
		-- Upon failure to locate a valid node, return nil
		return false		
	end		

	----------------------------------
	-- Tree update
	----------------------------------
	function Tree:update(parent, dt)

		-- This should be placed in the controller script's update function
		-- This will allow the tree to be constantly monitored
		--[[ IE: 
		function update(self, dt)
			if self.root then
				-- node is the master class accessible in all node instances. 
				-- Use it for dt access as a global variable
				node.dt = dt 
				self.root:update() -- [ Tree:update() ]
			end
		end
		--]]
		return Tree:Evaluate(parent, dt)
	end

	return Tree
end

return M