--
-- Immutable table class
--

ITable = {}

local immutableMetatable = {
	__type = 'immutableTable',
	__index = function(self, key)
		local itable = rawget(self, '__itable')
		while itable do
			local v = rawget(itable, key)
			if v then return v end
			itable = rawget(itable, '__itable')
		end		
	end,
	__newindex = function(self, key, value)
		error("Use the .set function to mutate an immutable table")
	end,
	__call = function(self, func, ...)
		local fn = ITable[func]
		if fn then
			return fn(...)
		end
	end,
}

function ITable.new(input, parent)
	local data = {}
	data.__itable = parent 
	for k,v in pairs(input) do
		data[k] = v
	end
	setmetatable(data, immutableMetatable)
	local it = {}
	it.__itable = data
	setmetatable(it, immutableMetatable)
	return it
end

function ITable.set(self, t)
	return ITable.new(t, self)
end

function ITable.isITable(t)
	local mt = getmetatable(t)
	if mt and mt.__type == 'immutableTable' then
		return true
	end
	return false
end

function ITable.parent(it)
	if not it then return nil end
	if not ITable.isITable(it) then
		error("Not an ITable",2)
	end
	return rawget(it, "__itable")
end

--[[function ITable.next(it, k)
	local parent = ITable.parent(it)
	if parent then
		return ITable.next(
	return next(it, k)
end]]

function ITable.pairs(it)
	local k,v
	if not ITable.isITable(it) then
		error("Not an ITable")
	end
	local it = ITable.parent(it)
	return function(self)
		while (it) do
			k,v = next(it, k)
			if k ~= '__itable' then
				if k ~= nil then
					return k,v
				else
					it = ITable.parent(it)
				end
			end
		end
		return nil
	end
end

local builtin_pairs = pairs
function pairs(t)
	if not t then
		error("Cannot pass nil to pairs", 2)
	end 
	if ITable.isITable(t) then
		return ITable.pairs(t)
	else
		return builtin_pairs(t)
	end
end

function ITable.clone(t)
	return ITable.new(t)
end

function ITable.test()
	local function assert(cond) if not cond then error("Assert") end end
	local function assertEq(a,b) if a ~= b then error("Assert : \""..tostring(a).."\" ~= \""..tostring(b).."\"",2) end end
	local function assertError(test)
		local hasError = false
		local function errHandler(msg) hasError = true end  
		local rv = xpcall(test, errHandler)
		if not hasError then
			error("Assert : Expected error",2)
		end
	end
	local it = ITable.new({})
	assertEq( mkstring(it), "" )
	assertError(function() it.a = 2 end)
	assertError(function() it[1] = "foo" end)
	-- does nothing
	table.insert(it, "foo")
	assertEq( mkstring(it), "" )
	assertEq( it.a, nil )
	
	it = ITable.new({ a = "foo"})
	assertEq( mkstring(it), "a=foo" )
	assertError(function() it.a = 2 end)
	table.insert(it, "foo")
	assertEq( it.a, "foo" )

	it = ITable.new({ a = "bar", fruit = "orange"}, it)
	assertEq( mkstring(it), "a=bar, fruit=orange" )
	assertError(function() it.a = 2 end)
	table.insert(it, "foo")
	assertEq( it.a, "bar" )
end
--table.insert( premake.selfcheck, ITable.test )