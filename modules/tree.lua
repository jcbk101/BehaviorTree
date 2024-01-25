local M = {}

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
		Tree = callback(self)
	end


	----------------------------------
	-- Tree update
	----------------------------------
	function Tree:update()

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
		Tree:Evaluate()

	end

	return Tree

end

return M