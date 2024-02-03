---------------------------------------------------
-- This module is a stand alone 'class'
-- All other modules are created from this
-- All functions and data are (mostly) stateless
---------------------------------------------------

local M = {}

-- Each instance should have all of the below
M.RUNNING = 1
M.SUCCESS = 2
M.FAILURE = 3
M.CONTINUE = 4
M.TERMINATE = -1

-- Need to init the random number generator
math.randomseed(os.clock())

-------------------------------------
-- Load children per Node
-------------------------------------
local function loadChildren( Node, children, size )

	-- Construct child nodes
	if size and type(size) == "number" then
		for i = 1, size do
			if children[i] then
				Node.children[i] = M.new(children[i])
			end
		end
	else		
		for i = 1, #children do			
			Node.children[i] = M.new(children[i])
		end	
	end			
end


-------------------------------------
-- Load children per Node
-------------------------------------
local function loadArguments( Node, nodeInfo )
	local i = 1
	while nodeInfo["arg" ..i] ~= nil do 
		Node[nodeInfo["arg" ..i].name] = nodeInfo["arg" ..i].value
		i = i + 1
	end
end


----------------------------------------------------------------------
-- Node class constructor. This way is not memory friendly. Pass a
-- a table with { nodeType = "nodeType", evaluator = functionName, arg# = { name = "", value = ? } }
-- A string of node type requested IE: "selector, sequence, task, nil"
-- node type determines Evaluator used. Evaluator passed in the table
-- is ONLY for tasks created
----------------------------------------------------------------------
function M.new( nodeInfo )

	--print(nodeInfo.nodeType)

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
		loadChildren(Node, nodeInfo.children)
		--
		Node.type = hash("selector")

		function Node:Evaluate(parent, dt)

			-- Search the children and test the results of each action
			-- Requested. Return results based on the result from that node's Evaluate() function
			for node = 1, #self.children do
				local result = self.children[node]:Evaluate(parent, dt)

				-- Evaluate the node's test using it's own evaluator
				-- Default response is FAILURE, so test the next node
				if result == M.SUCCESS then
					return M.SUCCESS
				elseif result == M.RUNNING then
					return M.RUNNING
				elseif result == M.TERMINATE then
					return M.TERMINATE			
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
		loadChildren(Node, nodeInfo.children)

		Node.type = hash("sequence")

		function Node:Evaluate(parent, dt)

			local anyChildRunning = nil
			local result = nil

			for node = 1, #self.children do
				local result = self.children[node]:Evaluate(parent, dt)

				if result == M.FAILURE then
					-- Exit sequencing with a failure code
					return M.FAILURE
				elseif result == M.SUCCESS then
					-- Continue testing nodes until all succeed or one fails
				elseif result == M.RUNNING then
					return M.RUNNING
				elseif result == M.TERMINATE then
					return M.TERMINATE
				elseif result == M.CONTINUE then
					-- Continue testing nodes until all succeed or one fails					
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
		Node.child = M.new(nodeInfo.child)

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
		function Node:Evaluate(parent, dt)
			local count = self:getData(self.key)

			if count == nil then
				count = 0
			end

			if count < self.max_count then
				self:setData(self.key, count + 1)
				return self.child:Evaluate(parent, dt)
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
		Node.children = {}
		Node.type = hash("random")

		-- Recursively construct child nodes
		loadChildren(Node, nodeInfo.children)

		function Node:Evaluate(parent, dt)
			local node = math.random(#self.children)
			local result = self.children[node]:Evaluate(parent, dt)

			if result == M.SUCCESS then
				return M.SUCCESS
			elseif result == M.FAILURE then
				return M.FAILURE
			elseif result == M.TERMINATE then
				return M.TERMINATE			
			elseif result == M.CONTINUE then
				return M.CONTINUE				
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
		Node.child = M.new(nodeInfo.child)

		function Node:Evaluate(parent, dt)
			local result = self.child:Evaluate(parent, dt)

			if result == M.FAILURE then
				return M.SUCCESS
			elseif result == M.SUCCESS then
				return M.FAILURE
			elseif result == M.TERMINATE then
				return M.TERMINATE
			elseif result == M.CONTINUE then
				return M.CONTINUE
			else
				return M.RUNNING
			end 
		end

		------------------------------------------------------------------------
		-- Node always returns a constant state: SUCCESS or FAILURE 
		-- Only a single child allowed
		------------------------------------------------------------------------				
	elseif nodeType == "success" or nodeType == "failure" or nodeType == "continue" then
		-- It would be a good idea to test for children to process
		-- Single child for this Evaluator node
		Node.child = M.new(nodeInfo.child)		
		--
		Node.type = hash(nodeType)

		if Node.type == hash("failure") then
			Node.STATE = M.FAILURE
		elseif Node.type == hash("continue") then
			Node.STATE = M.CONTINUE
		else
			Node.STATE = M.SUCCESS
		end

		function Node:Evaluate(parent, dt)
			local result = self.child:Evaluate(parent, dt)

			if result == M.RUNNING then
				return M.RUNNING
			elseif result == M.TERMINATE then
				return M.TERMINATE	
			else
				-- Defaults to return SUCCESS or FAILURE
				return self.STATE
			end 
		end
	elseif nodeType == "task" then
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
		Node.Evaluate = evaluator or function(parent, dt) 
			return M.SUCCESS
		end

		-------------------------------------------
		-- All arguments sent can be 
		-- added to the table by name & value
		-- As long as they are in numerical order
		-------------------------------------------
		loadArguments(Node, nodeInfo)
	else
		-- Node not supported. report error
		assert(nil, "Error: '" .. nodeType .. "' is not supported")
	end

	-- Return the constructed Node
	return Node
end


----------------------------------
-- Node clean up
----------------------------------
function M.final(self)
	-- Test to see if the value is at this level
	for key, obj in pairs(self.root.sharedData) do
		self.root.sharedData[key] = nil
	end
	-- Other cleanup done here
end

return M