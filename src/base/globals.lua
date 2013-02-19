--
-- globals.lua
-- Global tables and variables, replacements and extensions to Lua's global functions.
-- Copyright (c) 2002-2011 Jason Perkins and the Premake project
--
	

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
	function dofile(fname, enableSpellCheck)
		local oldcwd, oldfile, dir
		
		local function setup()
			-- remember the current working directory and file; I'll restore it shortly
			oldcwd = _CWD
			oldfile = _SCRIPT
	
			-- if the file doesn't exist, check the search path
			if (not os.isfile(fname)) then
				local path = os.pathsearch(fname, _OPTIONS["scripts"], os.getenv("PREMAKE_PATH"))
				if (path) then
					fname = path.."/"..fname
				end
			end
	
			-- use the absolute path to the script file, to avoid any file name
			-- ambiguity if an error should arise
			fname = path.getabsolute(fname)
			dir = path.getdirectory(fname)

			if io.isExcludeDir(dir) then
				return false
			end			
			
			_SCRIPT = fname
			
			-- switch the working directory to the new script location
			os.chdir(dir)
			
			if enableSpellCheck then
				premake.spellCheckEnable(_G, "_G")
			end
			
			if premake.isLoaded then

				-- All files in subdirs of a premake solution will be included in that sln
				local d = path.getdirectory(dir)
				local sln
				while not sln do
					if io.slnScope[d] then 
						sln = io.slnScope[d]
						if premake.api.scope.solution ~= sln then
							premake.api.solution(sln.name)
						end 
					else
						d = path.getdirectory(d)
						if not d:startswith(repoRootPlain) then break end
					end
				end
				
				local slnNamespace
				if ptype(sln or {}) == 'solution' then 
					slnNamespace = sln.namespaces
				else
					slnNamespace = { '/' }
				end
				premake.api.namespace(slnNamespace)
			end
			
			return true
		end
		if not setup() then
		   return
		end
		
		--if premake.isLoaded then printDebug("Include : ".._SCRIPT.." solution "..tostring(premake.api.scope.solution.name)) end
		
		-- run the chunk. How can I catch variable return values?
		local a, b, c, d, e, f = builtin_dofile(_SCRIPT)


		if enableSpellCheck then
			premake.spellCheckDisable(_G)
		end
		
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
	io.slnScope = {}
	local helpMessageCount = 0
		
	function include(fileOrDir)

		local function includeFiles(files)
			local alreadyIncluded
            if type(files) == 'string' then files = { files } end
			for _,filename in ipairs(files) do
				filename = path.getabsolute(filename)
				if not io._includedFiles[filename] then
					io._includedFiles[filename] = true
					dofile(filename)
				else
					alreadyIncluded = filename 
				end
			end		
			return alreadyIncluded	
		end

		-- if a directory, recursively load all premake scripts inside it
		if os.isdir(fileOrDir) then
			
			premake.api.scopePush()
		
			local dir = fileOrDir
			local realDir = os.getSymlinkTarget(fileOrDir)
			local alreadyIncluded
			
			if realDir then
				realDir = path.getabsolute(realDir)
				if realDir:startswith(repoRoot) then
					-- dir is a symlink, pointing to a directory within repoRoot
					-- Ignore the symlink
					dir = realDir
				end
				-- else pretend it's a real directory 
			end
			
			if not io.isExcludeDir(dir) then
				local files = os.matchfiles(dir..'/premake*.lua')
				alreadyIncluded = includeFiles(files)
				local subdirFiles = os.matchfiles(dir..'/**/premake*.lua')
				alreadyIncluded = includeFiles(subdirFiles) or alreadyIncluded
			end

			if alreadyIncluded then
				if helpMessageCount < 3 then
					print("Note : Including a directory manually is now unnecessary : duplicate include \""..path.getname(dir).."\" in "..alreadyIncluded)
				elseif helpMessageCount == 3 then
					print(" etc...")
				end
				helpMessageCount = helpMessageCount + 1
			end
			
			premake.api.scopePop()
			
		elseif os.isfile(fileOrDir) then
			local filename = fileOrDir
					
			-- but only load each file once
			includeFiles(filename, true)
		else
			error('Could not find premake include "'..fileOrDir ..'" in file "'.._SCRIPT..'"')
		end
	end
	
--
-- Never include premake files in this directory
--
	io.excludedirs = {}
	function excludedir(d)
		if type(d) ~= 'string' then
			error("excludedir expected string, found "..type(d),2)
		end
		d = path.getabsolute(d)
		table.insert( io.excludedirs, d )
	end
	
	function io.isExcludeDir(d)
		for _,v in ipairs(io.excludedirs) do
			if d:startswith(v) then
				return true
			end
		end
		return false	
	end

--
-- A shortcut for printing formatted output.
--

	function printf(msg, ...)
		print(string.format(msg, unpack(arg)))
	end

	
		
--
-- Premake type. An extension to type() to identify project object types by reading the
-- "__type" field from the metatable.
--

	function ptype(t)
		local mt = getmetatable(t)
		if (mt) then
			if (mt.__type) then
				return mt.__type
			end
		end
		return type(t)
	end
	
	function ptypeSet(t, name)
		local mt = getmetatable(t) or {}
		mt.__type = name
		return setmetatable(t, mt)
	end
	
	
--
-- Count the number of elements in an associative table
--

	function count(t)
		local c = 0
		if t then
			for _,_ in pairs(t) do
				c = c + 1
			end
		end
		return c
	end
	
--
-- Map/Select function. Performs fn(key,value) on each element in a table, returns as a list 
--

	function map(t,fn)
	  local rv = {}
	  if t then
		  for key,value in pairs(t) do
		  	table.insert(rv, fn(key,value))
		  end
	  end
	  return rv
	end

--
-- Map/Select function. Performs fn(value) for each numeric keyed element in a table, returns as a list 
--

	function imap(t,fn)
	  local rv = {}
	  if( t ) then
		  for _,value in ipairs(t) do
		  	table.insert(rv, fn(value))
		  end
	  end
	  return rv
	end

--
-- Returns the keys in a table. Or the sequence numbers if it's a sequence
--
  
	function getKeys(t)
		local rv = {}
		if t then
			for k,_ in pairs(t) do
				table.insert(rv, k)
			end
		end
		return rv
	end
	

--
-- Returns the values in a table or sequence
--
  
	function getValues(t)
		local rv = {}
		if t then
			for _,v in pairs(t) do
				table.insert(rv, v)
			end
		end
		return rv
	end
	
--
-- Returns the values for integer keyed entries in a table
--
  
	function getIValues(t)
		local rv = {}
		if t then
			for _,v in ipairs(t) do
				table.insert(rv, v)
			end
		end
		return rv
	end
--
-- Returns the names of all the functions in the table
--

	function getFunctionNames(t)
		local rv = {}
		if t then
			for k,v in pairs(t) do
				if( type(v) == "function" ) then
					table.insert(rv, k)
				end
			end
		end
		return rv
	end
	
--
-- Returns the names of all the tables in the table
--

	function getSubTableNames(t)
		local rv = {}
		if t then
			for k,v in pairs(t) do
				local typeV = type(v)
				if( typeV == "table" ) then
					table.insert(rv, k)
				end
			end
		end
		return rv
	end
	
--
-- Returns true if the object contains a list of strings
--
	function isStringSeq(t)
		local rv = false
		if( #t>0 ) then
			rv = true
			for _,v in ipairs(t) do
				if type(v) ~= 'string' then
					rv = false
					break
				end
			end
		else
			rv = false
		end
		return rv
	end
		
--
-- 'Inherit' functions & members from a base table. Performs a shallow copy of a table.
--
	function inheritFrom(t, derivedClassName)
		local rv = {}
		for k,v in pairs(t) do
			rv[k] = v
		end
		if rv.super == nil then
			rv.super = t
		end
		-- Optional, but useful for error messages
		if( derivedClassName ) then
			ptypeSet( rv, derivedClassName )
		end
		return rv
	end

	function prepend(a,b)
		return concat(b,a)
	end

	-- str(a, b, c) == a..b..c
	function str(...)
		return table.concat(arg, '')
	end
	
	function concat(a,b)
		local atype = type(a)
		local btype = type(b)
		local rv = {}
		
		if a == nil then
			rv = b
		elseif b == nil then
			rv = a
		elseif atype == "table" then
			if btype == "string" then
				-- Concatenate b on to each element of a
				for k,v in pairs(a) do
					if( type(v) == "string" ) then
						rv[k] = v .. b
					end
				end
			elseif btype == "table" then
				-- Concatenate b on to a, ie. Assuming no overwrites, #(a++b) == #a + #b
				for k,v in pairs(a) do
					rv[k] = v
				end
				local offset = #a
				for k,v in pairs(b) do
					if type(k) == 'number' then
						rv[k+offset] = v
					else
						rv[k] = v
					end
				end
			end
		elseif( btype == "table" ) then
			if atype == "string" then
				-- Prepend a on to each element of b
				for k,v in pairs(b) do
					if( type(v) == "string" ) then
						rv[k] = a ..v
					end
				end
			end
		end
		return rv
	end
	
	function mkstring(t, delimiter, seen)
		delimiter = delimiter or ' '
		seen = seen or {}
		if t == nil then
			return 'nil'
		end
		if seen[t] then
			return seen[t]
		end
		seen[t] = ''
		
		local rv
		if t == nil then
			rv = ''
		elseif type(t) == 'string' then
			rv = t
		elseif type(t) == 'table' then
			local s = ''
			for k,v in pairs(t) do
				if #s > 0 then s = s .. delimiter end
				if type(k) == 'number' then
					s = s .. mkstring(v, delimiter, seen)
				else
					s = s .. mkstring(k, delimiter, seen) ..'='..mkstring(v, delimiter, seen)
				end
			end
			rv = s
		else
			rv = tostring(t)
		end
		seen[t] = rv
		return rv
	end
	
	function toSet(vs, toLower)
		if not vs then return {} end
		if type(vs) == 'string' then
			-- Convert string to hashset
			local t = {}
			if toLower then 
				t[vs:lower()] = vs
			else
				t[vs] = vs
			end
			return t
		elseif type(vs) == 'function' then
			-- assume it's an iterator function
			kvs = {}
			for k,v in vs do
				if toLower then 
					kvs[v:lower()] = v
				else
					kvs[v] = v
				end
			end
			return kvs
		end
		if #vs > 0 then
			-- Convert sequence to hashset
			kvs = {}
			for _,v in ipairs(vs) do
				if toLower then 
					kvs[v:lower()] = v
				else
					kvs[v] = v
				end
			end
			return kvs
		else
			local t = {}
			if toLower then
				for k,v in pairs(vs) do
					if type(k) == 'string' then
						t[k:lower()] = v
					else
						t[k] = v
					end
				end
				return t
			else
				return vs
			end
		end
	end
	
	-- Return only unique values in the list
	function unique(list)
		if not list then return nil end
		
		local set = {}
		local newList = {}
		for _,v in ipairs(list) do
			if not set[v] then
				table.insert(newList, v)
				set[v] = v
			end
		end
		return newList
	end
	
	function toList(vs)
		if type(vs) == 'function' then
			-- assume it's an iterator function
			rv = {}
			for k,v in vs do
				table.insert(rv, v)
			end
			return rv
		elseif type(vs) == 'table' then
			return vs
		else
			-- Convert to sequence
			return { vs }
		end		
	end
	
	function printDebug(msg, ...)
		if _OPTIONS['debug'] then
			printf(msg, unpack(arg))
		end
	end
	
	-- Pad msg with spaces
	function padSpaces(msg, length)
		local rv = msg
		if #rv < length then
			for i=#rv,length-1 do
				rv = rv..' '
			end
		end
		return rv
	end

	local builtin_loadstring = loadstring
	local loadstringCache = {} 
	function loadstring(str)
		if loadstringCache[str] then
			return loadstringCache[str]
		else
			local l = builtin_loadstring(str)
			loadstringCache[str] = l
			return l
		end
	end
