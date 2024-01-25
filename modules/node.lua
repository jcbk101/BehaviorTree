---------------------------------------------------
-- This module is a stand alone 'class'
-- All other modules are created from this
-- All functions and data are (mostly) stateless
---------------------------------------------------

local M = {}

-- Each instance should have all of the below
M.FAILURE = -1		
M.RUNNING = 1
M.SUCCESS = 2

-- A way to make dt global to all Nodes
M.dt = 0.0

-- Table containing a dictionary of actions in <KEY, OBJECT> format
-- This needs to be cleared per level, level reset
M.sharedData = {}

-- Need to init the random number generator
math.randomseed(os.clock())

----------------------------------------------------------------------
-- Node class constructor. This way is not memory friendly. Pass a
-- a table with { nodeType = "nodeType", evaluator = functionName, arg# = { name = "", value = ? } }
-- A string of node type requested IE: "selector, sequence, task, nil"
-- node type determines Evaluator used. Evaluator passed in the table
-- is ONLY for tasks created
----------------------------------------------------------------------
function M.new( nodeInfo )

	-- Create a new state each time and return to the requestor
	local Node = {}
	local nodeType = string.lower(nodeInfo.nodeType) or "task"
	local evaluator = nodeInfo.evaluator

	------------------------------------------------------------------------
	-- Selectors are like OR gates. If a task succeeds, it returns SUCCESS
	-- Immediately. If a task fails, it test all following tasks sequentially
	-- until one succeeds. If no child task succeeds, it returns FAIL back 
	-- to its parent node.
	------------------------------------------------------------------------
	if nodeType == "selector" then
		-- It would be a good idea to test for children to process
		Node.children = {}

		-- Recursively construct child nodes
		for i = 1, #nodeInfo.children do			
			Node.children[i] = M.new(nodeInfo.children[i])
		end

		--
		Node.type = hash("selector")

		function Node:Evaluate()

			-- Search the children and test the results of each action
			-- Requested. Return results based on the result from that node's Evaluate() function
			for node = 1, #self.children do
				local result = self.children[node]:Evaluate()

				-- Evaluate the node's test using it's own evaluator
				-- Default response is FAILURE, so test the next node
				if result == M.SUCCESS then
					return M.SUCCESS
				elseif result == M.RUNNING then
					return M.RUNNING
				end
			end

			-- All test failed. return failure by default
			return M.FAILURE
		end

		------------------------------------------------------------------------
		-- Sequencers are like AND gates. If a task succeeds, it returns SUCCESS
		-- Immediately, then proceeds to the next task. If it fails, then no
		-- further testing of the next tasks in line. When all test SUCCEED, then
		-- it returns SUCCEED to the parent for the next task.
		------------------------------------------------------------------------
	elseif nodeType == "sequence" then
		-- It would be a good idea to test for children to process
		Node.children = {}

		-- Recursively construct child nodes
		for i = 1, #nodeInfo.children do			
			Node.children[i] = M.new(nodeInfo.children[i])
		end

		Node.type = hash("sequence")

		function Node:Evaluate()

			local anyChildRunning = nil

			for node = 1, #self.children do
				local result = self.children[node]:Evaluate()

				if result == M.FAILURE then
					-- Exit sequencing with a failure code
					return M.FAILURE
				elseif result == M.SUCCESS then
					-- Continue testing nodes until all succeed or one fails
					result = nil
				elseif result == M.RUNNING then
					return M.RUNNING
				else
					-- Defaults to return SUCCESS
					return M.SUCCESS
				end 
			end

			-- All nodes succeeded
			return M.SUCCESS
		end	

		------------------------------------------------------------------------
		-- Limiter adds a limit on the amount of times the node can be called
		-- It tracks the called/tested amount
		-- Only a single child allowed
		------------------------------------------------------------------------				
	elseif nodeType == "limiter" then
		-- It would be a good idea to test for children to process
		Node.type = hash("limiter")
		-- Single child for this Evaluator node
		Node.children = { M.new(nodeInfo.children[1]) }

		-- Create and init the counter variable
		Node.key = "limit_" .. string.sub(tostring(Node), 8)

		-- Node expects a single value that will be used for the max_count test
		if nodeInfo["arg" ..1] ~= nil then
			Node.max_count = (nodeInfo["arg" ..1].value > 0 and nodeInfo["arg" ..1].value or 1)
		else
			-- Defaults to 1
			Node.max_count = 1
		end

		-------------------------------------------
		--
		-------------------------------------------		
		function Node:Evaluate()
			local count = self:getData(self.key)

			if count == nil then
				count = 0
			end

			if count < self.max_count then
				self:setData(self.key, count + 1)
				return self.children[1]:Evaluate()
			else
				-- Once failure is determined, the child node never runs again
				return M.FAILURE
			end
		end

		------------------------------------------------------------------------
		-- Random selection node. Leaf's return value is processed and 
		-- This node selects an action based on a random number dependent on
		-- The amount of children attachd to it.
		------------------------------------------------------------------------				
	elseif nodeType == "random" then
		-- It would be a good idea to test for children to process
		Node.type = hash("random")
		-- Single child for this Evaluator node
		Node.children = { M.new(nodeInfo.children[1]) }

		-- Recursively construct child nodes
		for i = 1, #nodeInfo.children do			
			Node.children[i] = M.new(nodeInfo.children[i])
		end			

		function Node:Evaluate()
			local node = math.random(#self.children)
			local result = self.children[node]:Evaluate()

			if result == M.SUCCESS then
				return M.SUCCESS
			elseif result == M.FAILURE then
				return M.FAILURE
			else
				return M.RUNNING
			end 
		end

		------------------------------------------------------------------------
		-- Negate nodes invert the result. If a task succeeds, it returns FAIL
		-- If it fails, it returns SUCCEED. Running stays the same.
		-- Only a single child allowed
		------------------------------------------------------------------------				
	elseif nodeType == "negate" then		
		-- It would be a good idea to test for children to process
		Node.type = hash("negate")
		-- Single child for this Evaluator node
		Node.children = { M.new(nodeInfo.children[1]) }

		function Node:Evaluate()
			local result = self.children[node]:Evaluate()

			if result == M.FAILURE then
				return M.SUCCESS
			elseif result == M.SUCCESS then
				return M.FAILURE
			else
				return M.RUNNING
			end 
		end

		------------------------------------------------------------------------
		-- Node always returns a constant state: SUCCESS or FAILURE 
		-- Only a single child allowed
		------------------------------------------------------------------------				
	elseif nodeType == "success" or nodeType == "failure" then
		-- It would be a good idea to test for children to process
		Node.children = {}

		-- Recursively construct child nodes
		for i = 1, #nodeInfo.children do			
			Node.children[i] = M.new(nodeInfo.children[i])
		end			

		----------------------------
		Node.type = hash(nodeType)
		if Node.type == hash("failure") then
			Node.STATE = M.FAILURE
		else
			Node.STATE = M.SUCCESS
		end

		function Node:Evaluate()
			for node = 1, #self.children do
				local result = self.children[node]:Evaluate()

				if result == M.RUNNING then
					return M.RUNNING
				else
					-- Defaults to return SUCCESS or FAILURE
					return self.STATE
				end 
			end
		end
	else
		------------------------------------------------------------------------
		--
		-- Default Evaluator. Replaced by a function used as an evaluator within
		-- The requestor's script file. 
		--
		------------------------------------------------------------------------				
		Node.type = hash("task")

		-------------------------------------
		-- Evaulator function		
		-------------------------------------
		Node.Evaluate = evaluator or function() 
			return M.SUCCESS
		end

		-------------------------------------------
		-- All arguments sent can be 
		-- added to the table by name & value
		-- As long as they are in numerical order
		-------------------------------------------
		local i = 1
		while nodeInfo["arg" ..i] ~= nil do 
			Node[nodeInfo["arg" ..i].name] = nodeInfo["arg" ..i].value
			i = i + 1
		end
	end


	----------------------------------------------
	-- Blackboard data access for:
	-- Set data
	----------------------------------------------			
	if nodeType == "task" or nodeType == "limiter" then
		function Node:setData(key, value)
			M.sharedData[key] = value
		end				

		-------------------------------------
		-- Get data
		-------------------------------------
		function Node:getData( key )
			-- Test to see if the value is at this level
			if M.sharedData[key] ~= nil then
				return M.sharedData[key]
			end
			-- Upon failure to locate a valid node, return nil
			return nil
		end

		------------------------------
		-- Clear data
		------------------------------
		function Node:clearData( key )
			-- Test to see if the value is at this level
			if M.sharedData[key] ~= nil then
				M.sharedData[key] = nil
				return true
			end
			-- Upon failure to locate a valid node, return nil
			return false		
		end		
	end

	-- Return the constructed Node
	return Node
end

return M