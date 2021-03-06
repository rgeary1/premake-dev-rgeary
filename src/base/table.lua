--
-- table.lua
-- Additions to Lua's built-in table functions.
-- Copyright (c) 2002-2008 Jason Perkins and the Premake project
--
	

--
-- Returns true if the table contains the specified value.
--

	function table.contains(t, value)
		for _,v in pairs(t) do
			if (v == value) then
				return true
			end
		end
		return false
	end
	

--
-- Make a copy of the indexed elements of the table.
--

	function table.arraycopy(object)
		local result = {}
		for i, value in ipairs(object) do
			result[i] = value
		end
		return result
	end

--
-- Make a shallow 1 level copy of a table
--
	function table.shallowcopy(t)
		local dest = {}
		for k,v in pairs(t) do
			dest[k] = v
		end
		return dest
	end

--
-- Make a complete copy of a table, including any child tables it contains.
--

	function table.deepcopy(object)
		-- keep track of already seen objects to avoid loops
		local seen = {}
		
		local function copy(object)
			if type(object) ~= "table" then
				return object
			elseif seen[object] then
				return seen[object]
			end
			
			local clone = {}
			seen[object] = clone
			for key, value in pairs(object) do
				clone[key] = copy(value)
			end
			
			return clone
		end
		
		return copy(object)
	end


--
-- Enumerates an array of objects and returns a new table containing
-- only the value of one particular field.
--

	function table.extract(arr, fname)
		local result = { }
		for _,v in ipairs(arr) do
			table.insert(result, v[fname])
		end
		return result
	end
	
	

--
-- Flattens a hierarchy of tables into a single array containing all
-- of the values.
--

	function table.flatten(arr)
		local result = { }
		
		local function flatten(arr)
			for _, v in ipairs(arr) do
				if type(v) == "table" then
					flatten(v)
				else
					table.insert(result, v)
				end
			end
		end
		
		flatten(arr)
		return result
	end

--
-- Returns true if two tables contain the same elements (first level compare)
--
	function table.equals(t1, t2)
		for k,v in pairs(t1) do
			local v2 = t2[k] 
			if v2 ~= v then
				if type(v) == 'table' and type(v2) == 'table' then
					return table.equals(v, v2)
				else
					return false
				end
			end
		end
		return true
	end

--
-- Merge two lists into an array of objects, containing pairs
-- of values, one from each list.
--

	function table.fold(list1, list2)
		local result = {}
		for _, item1 in ipairs(list1 or {}) do
			if list2 and #list2 > 0 then
				for _, item2 in ipairs(list2) do
					table.insert(result, { item1, item2 })
				end
			else
				table.insert(result, { item1 })
			end
		end
		return result
	end


--
-- Merges an array of items into a string.
--

	function table.implode(arr, before, after, between)
		local result = ""
		for _,v in ipairs(arr) do
			if (result ~= "" and between) then
				result = result .. between
			end
			result = result .. before .. v .. after
		end
		return result
	end


--
-- Inserts a value of array of values into a table. If the value is
-- itself a table, its contents are enumerated and added instead. So 
-- these inputs give these outputs:
--
--   "x" -> { "x" }
--   { "x", "y" } -> { "x", "y" }
--   { "x", { "y" }} -> { "x", "y" }
--

	function table.insertflat(tbl, values)
		if values == nil then
			return
		elseif type(values) == "table" then
			for _, value in ipairs(values) do
				table.insertflat(tbl, value)
			end
		else
			table.insert(tbl, values)
		end
	end


--
-- Returns true if the table is empty, and contains no indexed or keyed values.
--

	function table.isempty(t)
		if t and type(t) == 'table' then 
			return not next(t)
		end
	end

--
-- Returns the size of the table including keyed values
--
	function table.size(t)
		if t and type(t) == 'table' then
			local i = 0
			for k,v in pairs(t) do
				i = i + 1
			end
			return i
		end
		return 0
	end

--
-- Adds the values from one array to the end of another and
-- returns the result.
--

	function table.join(...)
		local result = { }
		for _,t in ipairs(arg) do
			if type(t) == "table" then
				for _,v in ipairs(t) do
					table.insert(result, v)
				end
			else
				table.insert(result, t)
			end
		end
		return result
	end


--
-- Return a list of all keys used in a table.
--

	function table.keys(tbl)
		local keys = {}
		for k, _ in pairs(tbl) do
			table.insert(keys, k)
		end
		return keys
	end


--
-- Adds the key-value associations from one table into another
-- and returns the resulting merged table.
--

	function table.merge(...)
		local result = { }
		for _,t in ipairs(arg) do
			if type(t) == "table" then
				for k,v in pairs(t) do
					result[k] = v
				end
			else
				error("invalid value")
			end
		end
		return result
	end

--
-- Returns a copy of table t without the keys in list removeKeys
-- 
	function table.exceptKeys(t, removeKeys)
		local rv = {}
		local i = 0
		removeKeys = toSet(removeKeys)
		for k,v in pairs(t) do
			if not removeKeys[k] then
				rv[k] = v
			end
		end
		return rv
	end

--
-- Returns a copy of table t without the values in list removeValues
-- 
	function table.exceptValues(t, removeValues)
		local rv = {}
		local i = 0
		removeValues = toSet(removeValues)
		for k,v in pairs(t) do
			if not removeValues[v] then
				if type(k) == 'number' then
					i = i + 1
					k = i
				end
				rv[k] = v
			end
		end
		return rv
	end

--
-- Looks for an object within an array. Returns its index if found,
-- or nil if the object could not be found.
--

	function table.indexof(tbl, obj)
		local count = #tbl
		for i = 1, count do
			if tbl[i] == obj then
				return i
			end
		end		
	end


--
-- Translates the values contained in array, using the specified
-- translation table, and returns the results in a new array.
--

	function table.translate(arr, translation)
		local result = { }
		if( translation ~= nil ) then
			for _, value in ipairs(arr) do
				local tvalue
				if type(translation) == "function" then
					tvalue = translation(value)
				else
					tvalue = translation[value]
				end
				if (tvalue) then
					table.insert(result, tvalue)
				end
			end
		end
		return result
	end

--
-- Translates the values contained in a keyed table. Used for flags
--
	function table.translateV2(t, translation)
		local result = { }
		if( translation ~= nil ) then
			for k,v in pairs(t) do
				local tvalue
				if type(translation) == "function" then
					tvalue = translation(value)
				elseif translation[k] then
					if type(translation[k]) == 'string' then
						tvalue = translation[k]
					else
						tvalue = translation[k][v]
					end
				end
				if (tvalue) then
					table.insert(result, tvalue)
				end
			end
		end
		return result
	end	
		
	function table.mergeRecursive(src, dest)	
		dest = dest or {}
		for k,v in pairs(src) do
			if dest[k] and type(v) == 'table' then
				dest[k] = table.mergeRecursive(v, dest[k])
			else
				dest[k] = table.deepcopy(v)
			end
		end
		return dest
	end