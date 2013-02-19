--
-- Timing functions to help improve performance
--

local enabled = {}
local disabled = {}
timer = disabled

enabled.order = {}				-- print the timers in the same order of the timer.start() calls
enabled.totals = {}				-- { allTime, childTime, numCalls }
enabled.startTime = {}
enabled.stackName = {}
enabled.stackChildTime = {}
enabled.onPrintCallbacks = {}

function timer.enable()
	timer = enabled
end

function timer.disable()
	timer = disabled
end

function enabled.start(name)
	table.insert( timer.stackName, name )
	table.insert( timer.stackChildTime, 0.0 )
	if not enabled.order[name] then
		table.insert(enabled.order, name)
		enabled.order[name] = 1
		enabled.totals[name] = { 0.0, 0.0, 0 }
	end
	local t = os.clock()
	table.insert( timer.startTime, t )
	return name
end

function enabled.stop(name_, iters)
	local endTime = os.clock()
	iters = iters or 1
	
	if #enabled.stackName == 0 then
		timer.print()
		error('Called timer.stop() with nothing on the timer stack')
	end
	
	local name = table.remove( enabled.stackName )
	if name ~= name_ then
		error('Mismatched timer.stop. Expected '..name..' got '.. (name_ or '(nil)'))
	end
	local startTime = table.remove( enabled.startTime )
	local childTime = table.remove( enabled.stackChildTime )

	local diff = endTime - startTime
	local totals = enabled.totals[name]
	enabled.totals[name] = { totals[1] + diff, totals[2] + childTime, totals[3] + iters }
	if #enabled.stackChildTime > 0 then
		-- add the time to the parent's child time
		local i = #enabled.stackChildTime
		enabled.stackChildTime[i] = enabled.stackChildTime[i] + diff
	end 
end

function enabled.print(tmr)
	local totalTime = 0.0
	local maxLen = Seq:new(enabled.totals):getKeys():max()
	local sName = '%'..maxLen..'s'
	for _,name in ipairs(enabled.order) do
		local timeT = enabled.totals[name]
		local selfTime = timeT[1]-timeT[2]
		totalTime = totalTime + selfTime
	end	
	for _,name in ipairs(enabled.order) do
		if (not tmr) or tmr == name then
			local timeT = enabled.totals[name]
			local selfTime = timeT[1]-timeT[2]
			local selfPct = selfTime/totalTime * 100.0 
			local totalPct = timeT[1]/totalTime * 100.0
			printf(sName.." : self %.4f (%2.f%%)   total %.4f (%2.f%%)  child %.4f   calls %d", name, selfTime, selfPct, timeT[1], totalPct, timeT[2], timeT[3])
		end
	end
	if not tmr then
		printf(sName.." : %.4f", 'Total', totalTime)
	end
	
	for _,func in ipairs(enabled.onPrintCallbacks) do
		func()
	end
end

function enabled.onPrint(func)
	if not enabled.onPrintCallbacks then
		enabled.onPrintCallbacks[func] = func
		table.insert( enabled.onPrintCallbacks, func)
	end
end


function disabled.start(name) end
function disabled.stop() end
function disabled.print() end
function disabled.onPrint(func) end

function enabled.runTests()
	local function test(name, func, args, prepareFunc)
		local count = 10000
		if prepareFunc then
			for i = 1,count do
				prepareFunc(args)
				local tmr = timer.start(name)
				func(args)
				timer.stop(tmr)
			end
		else
			local tmr = timer.start(name)
			for i = 1,count do
				func(args)
			end
			timer.stop(tmr, count)
		end
	end
	
	local function addItems(num)
		local rv = {}
		for i = 1,num do
			table.insert(rv, i)
		end
		return rv
	end

	local presizedTables = {}
	local function createPresizeTable(num)
		-- create pst
		local t = presizedTables[num]
		if not presizedTables[num] then
			presizedTables[num] = {}
			t = presizedTables[num]
			for i=1,num do
				table.insert(t, true)
			end
		end
		local lent = #t
		for i=lent,1,-1 do
			t[i] = nil
		end
	end

	local function addItemsPresize(num)
		local t = presizedTables[num]
		
		for i = 1,num do
			table.insert(t, i)
		end
		return t
	end
	
	local function testMathSin()
		local x = 0
		for i = 1,100 do
			x = x + math.sin(i)
		end
	end

	local function testMathSinLocal()
		local x = 0
		local sin = math.sin
		for i = 1,100 do
			x = x + sin(i)
		end
	end

	local globalSin = math.sin
	local function testMathSinOuter()
		local x = 0
		for i = 1,100 do
			x = x + globalSin(i)
		end
	end
	
	local function addItemsT1(num)
		local rv = {}
		for i = 1,num do
			rv[#rv+1] = i
		end
		return rv
	end
	
	-- Test os.getcwd()
	test("os.getcwd", os.getcwd)
	
	-- Test inserting items
	local maxAdd = 10000
	test("Add 5 items", addItems, 5)
	test("Add 5 items (#t+1)", addItemsT1, 5)
	--test("Add 5 items (pst)", addItemsPresize, 5, createPresizeTable)
	test("Add 10 items", addItems, 10)
	test("Add 10 items (#t+1)", addItemsT1, 10)
	--test("Add 10 items (pst)", addItemsPresize, 10, createPresizeTable)
	test("Add 100 items", addItems, 100)
	test("Add 100 items (#t+1)", addItemsT1, 100)
	if maxAdd > 100 then 
		--test("Add 100 items (pst)", addItemsPresize, 100, createPresizeTable)
		test("Add 1000 items", addItems, 1000)
		test("Add 1000 items (#t+1)", addItemsT1, 1000)
	end
	--test("Add 1000 items (pst)", addItemsPresize, 1000, createPresizeTable)
	test("Test math.sin", testMathSin)
	test("Test math.sin local", testMathSinLocal)
	test("Test math.sin outer", testMathSinOuter)
end