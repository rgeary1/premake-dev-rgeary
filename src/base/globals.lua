--
-- globals.lua
-- Global tables and variables, replacements and extensions to Lua's global functions.
-- Copyright (c) 2002-2011 Jason Perkins and the Premake project
--
	
--
-- Create a top-level namespace for Premake's own APIs. The premake5 namespace 
-- is a place to do next-gen (4.5) work without breaking the existing code (yet).
-- I think it will eventually go away.
--

	premake = { }
	premake5 = { }
	premake.tools = { }

-- Top level namespace for abstract base class definitions 
	premake.abstract = { }

	
-- The list of supported platforms; also update list in cmdline.lua

	premake.platforms = 
	{
		Native = 
		{ 
			cfgsuffix       = "",
		},
		x32 = 
		{ 
			cfgsuffix       = "32",
		},
		x64 = 
		{ 
			cfgsuffix       = "64",
		},
		Universal = 
		{ 
			cfgsuffix       = "univ",
		},
		Universal32 = 
		{ 
			cfgsuffix       = "univ32",
		},
		Universal64 = 
		{ 
			cfgsuffix       = "univ64",
		},
		PS3 = 
		{ 
			cfgsuffix       = "ps3",
			iscrosscompiler = true,
			nosharedlibs    = true,
			namestyle       = "PS3",
		},
		WiiDev =
		{
			cfgsuffix       = "wii",
			iscrosscompiler = true,
			namestyle       = "PS3",
		},
		Xbox360 = 
		{ 
			cfgsuffix       = "xbox360",
			iscrosscompiler = true,
			namestyle       = "windows",
		},
	}


--
-- A replacement for Lua's built-in dofile() function, this one sets the
-- current working directory to the script's location, enabling script-relative
-- referencing of other files and resources.
--

	local builtin_dofile = dofile
	function dofile(fname)
		-- remember the current working directory and file; I'll restore it shortly
		local oldcwd = os.getcwd()
		local oldfile = _SCRIPT

		-- if the file doesn't exist, check the search path
		if (not os.isfile(fname)) then
			local path = os.pathsearch(fname, _OPTIONS["scripts"], os.getenv("PREMAKE_PATH"))
			if (path) then
				fname = path.."/"..fname
			end
		end

		-- use the absolute path to the script file, to avoid any file name
		-- ambiguity if an error should arise
		_SCRIPT = path.getabsolute(fname)
		
		-- switch the working directory to the new script location
		local newcwd = path.getdirectory(_SCRIPT)
		os.chdir(newcwd)
		
		-- run the chunk. How can I catch variable return values?
		local a, b, c, d, e, f = builtin_dofile(_SCRIPT)
		
		-- restore the previous working directory when done
		_SCRIPT = oldfile
		os.chdir(oldcwd)
		return a, b, c, d, e, f
	end



--
-- "Immediate If" - returns one of the two values depending on the value of expr.
--

	function iif(expr, trueval, falseval)
		if (expr) then
			return trueval
		else
			return falseval
		end
	end
	
	
	
--
-- Load and run an external script file, with a bit of extra logic to make 
-- including projects easier. if "path" is a directory, will look for 
-- path/premake4.lua. And each file is tracked, and loaded only once.
--

	io._includedFiles = { }
	
	function include(filename)
		-- if a directory, load the premake script inside it
		if os.isdir(filename) then
			filename = path.join(filename, "premake4.lua")
		end
				
		-- but only load each file once
		filename = path.getabsolute(filename)
		if not io._includedFiles[filename] then
			io._includedFiles[filename] = true
			dofile(filename)
		end
	end



--
-- A shortcut for printing formatted output.
--

	function printf(msg, ...)
		print(string.format(msg, unpack(arg)))
	end

	
		
--
-- An extension to type() to identify project object types by reading the
-- "__type" field from the metatable.
--

	local builtin_type = type	
	function type(t)
		local mt = getmetatable(t)
		if (mt) then
			if (mt.__type) then
				return mt.__type
			end
		end
		return builtin_type(t)
	end
	
	
--
-- Count the number of elements in an associative table
--

	function count(t)
		local c = 0
		for _,_ in pairs(t) do
			c = c + 1
		end
		return c
	end
	
--
-- Map/Select function. Performs fn(key,value) on each element in a table, returns as a list 
--

	function map(t,fn)
	  rv = {}
	  for key,value in pairs(t) do
	  	table.insert(rv, fn(key,value))
	  end
	  return rv
	end

--
-- Map/Select function. Performs fn(value) for each numeric keyed element in a table, returns as a list 
--

	function imap(t,fn)
	  rv = {}
	  for _,value in ipairs(t) do
	  	table.insert(rv, fn(value))
	  end
	  return rv
	end

--
-- Returns the keys in a table. Or the sequence numbers if it's a sequence
--
  
	function getKeys(t)
		rv = {}
		for k,_ in pairs(t) do
			table.insert(rv, k)
		end
		return rv
	end
	

--
-- Returns the values in a table or sequence
--
  
	function getValues(t)
		rv = {}
		for _,v in pairs(t) do
			table.insert(rv, v)
		end
		return rv
	end
	
--
-- Returns the names of all the functions in the table
--

	function getFunctionNames(t)
		rv = {}
		for k,v in pairs(t) do
			if( type(v) == "function" ) then
				table.insert(rv, k)
			end
		end
		return rv
	end
	
--
-- Returns the names of all the tables in the table
--

	function getSubTableNames(t)
		rv = {}
		for k,v in pairs(t) do
			local typeV = builtin_type(v)
			if( typeV == "table" ) then
				table.insert(rv, k)
			end
		end
		return rv
	end
		
--
-- 'Inherit' functions & members from a base table. Performs a shallow copy of a table.
--
	function inheritFrom(t, derivedClassName)
		rv = {}
		for k,v in pairs(t) do
			rv[k] = v
		end
		-- Optional, but useful for error messages
		if( derivedClassName ) then
			setmetatable( rv, { __type = derivedClassName } ) 
		end
		return rv
	end
