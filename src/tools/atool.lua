--
-- Abstract tool
--  Defines a command line given a tool name and how to process inputs & flags
--  Override any part of this to define your own tool
--
--  Inputs are lists of strings, split in to categories, eg :
--	  Default input filenames : toolInputs['default']			(eg. source files for cc, obj files for linker)
--	  defines :					toolInputs['defines']
--	  includedirs :				toolInputs.includedirs
--	  libdirs :					toolInputs.libdirs
--	  staticlibs  				toolInputs.staticlibs
--	  sharedlibs  				toolInputs.sharedlibs
--	  frameworklibs				toolInputs.frameworklibs
--  Decorating these toolInputs is done via atool.prefixes[inputCategory] and suffixes[inputCategory]
--  eg. atool.prefixes.defines = '-D'
--  Alternatively, you can specify function atool.decorateFn.includedirs(cfg) to override this behaviour

premake.abstract.buildtool = {}
local atool = premake.abstract.buildtool
local config = premake5.config
local oven = premake5.oven

-- Tool name as it appears to premake. There can be several tools with the same tool name (eg. 'cc'),
--  but they must be unique within the same toolset
atool.toolName = 'unnamed-tool'

-- If specified, inherit values & function definitions from this table, unless overridden
atool.inheritFrom = nil

-- path to the tool binary. nil = search for it
atool.binaryDir = nil

-- Name of the binary to execute
atool.binaryName = nil

-- Cached result of getBinary
atool.binaryFullpath = nil

-- Fixed flags which always appear first in the command line
atool.fixedFlags = nil

-- Order of arguments in the command line. Arguments not specified in this list are appended (optional)
atool.argumentOrder = { 'fixedFlags', 'output', 'sysflags', 'cfgflags', 'input', 'linkAsStatic' }

-- Mapping from Premake 'flags' to compiler flags
atool.flagMap = {}

-- Prefix to decorate defines, include paths & include libs
atool.prefixes = {
-- defines = '-D',
-- depfileOutput = '-MF'
}
atool.suffixes = {
-- depfileOutput = '.d'
}
atool.decorateFn = {
-- input = function(inputList) return '-Wl,--start-group'..table.concat(inputList, ' ')..'-Wl,--end-group'; end
}

-- Default is for C++ source, override this for other tool types
--atool.extensionsForLinking = { '.o', '.a', '.so' }		-- possible inputs in to the linker
atool.objectFileExtension = '.o'		-- output file extension for the compiler

-- Extra cmdflags depending on the config & system
function atool:getsysflags(cfg)
	return ''
end

--
-- Construct a command line given the flags & input/output args.
--	toolCmd = atool:getBinary
--  cmdArgs = atool:decorateInputs
--
function atool:getCommandLine(cmdArgs)

	if #cmdArgs == 0 then
		error('#toolInputs == 0, did you forget to flatten it?')
	end

	-- Allow the tool to silence stderr. eg. The Intel ar tool outputs unwanted status information
	local redirectStderr = ""
	if(self.redirectStderr) then
		local hostIsWindows = os.is("windows")
		if( hostIsWindows ) then
			redirectStderr = '2> nul'
		else
			redirectStderr = '2> /dev/null'
		end
		table.insert(cmdArgs, redirectStderr)

		--[[elseif self.filterStderr then
		if not os.is("windows") then
		local grepFilter = "2>&1 | grep -v -e "
		for _,v in ipairs(self.filterStderr) do
		grepFilter = grepFilter .. "\'"..v.."\' "
		end
		table.insert(cmdArgs, grepFilter)
		end]]
	end

	local cmdParts = table.join(cmdArgs, self.endFlags)

	local cmd = table.concat(cmdParts, ' ')
	return cmd
end

----------------------------------------------
-- Functions which you shouldn't need to override
----------------------------------------------

--
-- Decorates the tool inputs for the command line
-- Returns a table containing a sequence of command line arguments, and a hashtable of variable definitions
--
--  outputVar and inputVar are what you want to appear on the command line in the build file, eg. $out and $in
--	(optional) previousResult is the results of a previous run. If specified, only the changed inputs will be decorated & returned.
--
function atool:decorateInputs(cfg, outputVar, inputVar, previousResult)
	local rv = {}
	local tmr = timer.start('atool:decorateInputs')
	
	-- Construct the argument list from the inputs
	for _,category in ipairs(self.decorateArgs) do
		local inputList
		if category == 'output' then inputList = outputVar
		elseif category == 'input' then inputList = inputVar
		elseif category == 'sysflags' then inputList = self:getsysflags(cfg)
		elseif category == 'cfgflags' then inputList = table.translateV2(cfg.flags, self.flagMap)
		elseif category == 'toolbin' then inputList = self:getBinary()
		elseif category == 'fixedFlags' then inputList = { self.fixedFlags }
		elseif category == 'wrapper' then
			local wrapper
			if self.isCompiler and cfg.compilerwrapper then
				-- Insert or append original command
				wrapper = cfg.compilerwrapper
			elseif self.toolName == 'link' and cfg.linkerwrapper then
				wrapper = cfg.linkerwrapper
			end

			if wrapper then
				-- Try to find the wrapper
				local launcherPath = os.findbin(wrapper, self.binaryDir)
				if launcherPath then
					wrapper = path.join( launcherPath, wrapper )
				end

				inputList = { wrapper }
			end

		elseif category == 'depfileOutput' then
			if config.hasDependencyFileOutput(cfg) then
				inputList = outputVar
			end
		else
			inputList = cfg[category]
		end
		if inputList then
			local d = self:decorateInput(category, inputList, cfg, true)
			rv[category] = d
		end
	end
	
	-- ugly, need to add proper support for linker groups
	if (not _OPTIONS['disable-linker-groups']) and (not cfg.linkAsStatic) then
		rv.linkAsStatic = ' -Wl,--end-group'
	end

	if self.getDescription then
		rv.description = self:getDescription(cfg)
	end

	timer.stop(tmr)
	return rv
end

-- Returns true if the config requested a dependency file output and the tool supports it
function atool:hasDependencyFileOutput(cfg)
	return config.hasDependencyFileOutput(cfg) and (self.flagMap['CreateDependencyFile'])
end

function atool:decorateInput(category, input, cfg, alwaysReturnString)
	local str
	local inputList = toList(input)

	--[[if self.cache[input] then
	timer.start('cache.hit')
	timer.stop('cache.hit')
	return self.cache[input]
	end]]
	--timer.start('decorateInput')

	-- consistent sort order to prevent ninja rebuilding needlessly
	table.sort(inputList)

	if self.decorateFn[category] then

		-- Override prefix/suffix behaviour
		str = self.decorateFn[category](inputList, cfg)

	elseif self.prefixes[category] or self.suffixes[category] then
		-- Decorate each entry with prefix/suffix
		local prefix = self.prefixes[category] or ''
		local suffix = self.suffixes[category]

		local rv = {}
		for _,v in ipairs(inputList) do
			if prefix then
				rv[#rv+1] = prefix
			end
			rv[#rv+1] = v
			if suffix then
				rv[#rv+1] = suffix
			end
			rv[#rv+1] = ' '
		end
		str = table.concat(rv)
	elseif alwaysReturnString then
		str = table.concat(inputList, ' ')
	else
		str = nil
	end

	--self.cache[input] = str
	--timer.stop('decorateInput')

	return str
end

-- Return the full path of the binary
function atool:getBinary()
	if self.binaryFullpath then
		return self.binaryFullpath
	end

	if not self.binaryName then
		error('binaryName is not specified for tool ' .. self.toolName)
	end

	-- Find the binary
	local binpath = os.findbin(self.binaryName, self.binaryDir)
	local fullpath = ''
	if binpath then
		fullpath = binpath .. '/' .. self.binaryName
	else
		-- Just assume it's there
		if self.binaryDir then
			fullpath = self.binaryDir .. '/'
		end
		fullpath = fullpath .. self.binaryName
	end
	self.binaryDir = binpath

	self.binaryFullpath = fullpath

	return fullpath
end


--
-- Get the build tool & output filename given the source filename. Returns null if it's not a recognised source file
-- eg. .cpp -> .o
--
function atool:getCompileOutput(cfg, fileName, uniqueSet)
	local outputFilename
	local fileExt = path.getextension(fileName):lower()

	if (self.extensionsForCompiling and self.extensionsForCompiling[fileExt]) then

		local baseName, objName
		
		if cfg.kind == premake.OBJECTFILE then
			baseName = cfg.project.shortname
		else
			baseName = path.getbasename(fileName)
		end
		objName = baseName .. self.objectFileExtension

		-- Make sure the object file name is unique to avoid name collisions if two source files
		--  in different paths have the same filename

		if uniqueSet then
			for i=2,99999 do
				if not uniqueSet[objName] then break end
				objName = baseName .. tostring(i) .. self.objectFileExtension
			end
			uniqueSet[objName] = 1
		end

		return objName
	else
		return nil		-- don't process
	end
end

--
-- Returns true if this is an object file for the toolset
--
function atool:isLinkInput(cfg, fileExt)
	return (not self.extensionsForLinking) or (self.extensionsForLinking[fileExt] ~= nil)
end

--
-- API callbacks
--

function premake.tools.newtool(toolDef)
	if not toolDef or type(toolDef) ~= 'table' then
		error('Expected tool definition table')
	end

	local t = inheritFrom(premake.abstract.buildtool, 'tool')

	-- Aliases
	if toolDef.inheritfrom then
		toolDef.inheritFrom = toolDef.inheritfrom
	end
	if toolDef.inherit_from then
		toolDef.inheritFrom = toolDef.inherit_from
	end

	-- Apply inherited tool
	if toolDef.inheritFrom then
		for k,v in pairs(toolDef.inheritFrom) do
			if type(v) == 'table' then
				t[k] = table.deepcopy(v)
			else
				t[k] = v
			end
		end
	end

	-- Apply specified values/functions
	for k,v in pairs(toolDef) do
		t[k] = v
	end

	if (not t.toolName) or #t.toolName < 1 then
		error('toolName not specified')
	end
	
	if t.toolName == atool.toolName then
		t.toolName = t.binaryName
	end

	-- Categorise the tool
	if (not t.isCompiler) and (not t.isLinker) then
		if t.toolName == 'cc' or t.toolName == 'cxx' then
			t.isCompiler = true
		else
			t.isLinker = true
		end
	end

	-- Set up a list of arguments to decorate
	t.decorateArgs = {}

	-- extraArgs are arguments we always insert at the end
	local extraArgs = {}
	if t.fixedFlags then table.insert(extraArgs, 'fixedFlags') end
	table.insert(extraArgs, 'cfgflags')
	if t.getsysflags ~= atool.getsysflags then
		table.insert(extraArgs, 'sysflags')
	else
		t.argumentOrder = table.exceptValues(t.argumentOrder, 'sysflags')
	end
	table.insertflat(extraArgs, { 'input', 'output' } )

	if t.isCompiler then
		table.insert( extraArgs, 'buildoptions' )
	end
	if t.toolName == 'link' then
		table.insert( extraArgs, 'ldflags' )
	end

	local args = Seq:new(t.prefixes):concat(t.suffixes):concat(t.decorateFn):getKeys():concat(extraArgs):toSet()
	-- First add any arguments specified in the argumentOrder variable
	for _,argName in ipairs(t.argumentOrder or {}) do
		if args[argName] then
			if not t.decorateArgs[argName] then
				t.decorateArgs[argName] = argName
				table.insert(t.decorateArgs, argName)
			end
		else
			--printf("Warning : Could not find a decorator for argument '%s' listed in argumentOrder for tool %s", argName, t.toolName)
		end
	end
	-- Then add any others
	for category,_ in pairs(args) do
		if not t.decorateArgs[category] then
			t.decorateArgs[category] = category
			table.insert(t.decorateArgs, category)
		end
	end

	-- Make sure the toolbin (and wrapper) is at the front
	table.insert( t.decorateArgs, 1, 'wrapper' )
	table.insert( t.decorateArgs, 2, 'toolbin' )

	t.cache = {}

	return t
end

function atool.decorateStaticLibList(list, cfg)
	if not list or #list == 0 then
		return iif( _OPTIONS['disable-linker-groups'], "", ' -Wl,--end-group' )
	else
		local s = { '-Wl,-Bstatic ' }
		local binaryDir = cfg.linktarget.directory
		for _,lib in ipairs(list) do
			if path.containsSlash(lib) then
				s[#s+1] = lib
			else
				-- Target is a system lib
				s[#s+1] = '-l'
				s[#s+1] = lib
			end
			s[#s+1] = ' '
		end
		if not _OPTIONS['disable-linker-groups'] then
			s[#s+1] = ' -Wl,--end-group'
		end
		return table.concat(s)
	end
end

function atool.decorateSharedLibList(list, cfg)
	if not list or #list == 0 then
		return ''
	else
		local s = { '-Wl,-Bdynamic ' }
		local rpaths = {}
		for _,lib in ipairs(list) do
			if path.containsSlash(lib) then
			
				local dir = path.getdirectory(lib)
				local libName = path.getname(lib)
				if libName:contains('.so') then
					s[#s+1] = path.join(dir, libName)

					-- add -lmylib
					--s[#s+1] = ' '
					--s[#s+1] = '-l:'
					--s[#s+1] = libName
					
					-- add -Ldir
					--s[#s+1] = ' '
					--s[#s+1] = '-L'
					--s[#s+1] = dir

					-- add -Wl,-rpath=dir
					local finalRpath = atool.getRpath(dir, cfg)
					if not rpaths[finalRpath] then
						rpaths[dir] = dir
						s[#s+1] = ' '
						s[#s+1] = "-Wl,-rpath="
						s[#s+1] = finalRpath
					end
				else
					-- Target is a specific version of an .so
					s[#s+1] = lib
				end
			else
				-- Target is a system lib
				s[#s+1] = '-l'
				s[#s+1] = lib
			end
			s[#s+1] = ' '
		end
		return table.concat(s)
	end
end

function atool.decorateRPath(list, cfg)
	local rv = {}
	local binaryDir = cfg.linktarget.directory
	local set = toSet(list)
	for rpath,_ in pairs(set) do

		local finalRpath = atool.getRpath(rpath, cfg)
		rv[#rv+1] = '-Wl,-rpath='..finalRpath

	end
	return table.concat(rv, " ")
end

function atool.getRpath(rpath, cfg)

	if (not cfg.linktarget) or (not cfg.linktarget.directory) then
		return ''
	end

	-- rpath should either be absolute (relative to /)
	--  or relative to the final binary location, specified $ORIGIN
	local binaryDir = path.getabsolute(cfg.linktarget.directory)
	
	if rpath:startswith("$ORIGIN") then
		return "'"..rpath.."'"
	end
	
	local builddir = _OPTIONS['targetdir'] or _OPTIONS['objdir'] 
		
	if rpath:startswith("/") then
		return path.getabsolute(rpath)
	elseif path.isSystemDir(rpath) then
		return path.getabsolute(rpath)
	elseif rpath:startswith("$root") or (builddir and rpath:startswith(builddir)) then
		local relPath = path.getrelative(binaryDir, rpath)
		return "'$ORIGIN/"..relPath.."'"
	else
		return "'"..rpath.."'"
	end
end

function atool.generateDepfileOutput(list, cfg)
	if #list == 0 then return end
	local buildpaths = _OPTIONS['buildpaths']
	local str = '.d'
	if buildpaths and buildpaths ~= 'root' then
		str = str .. buildpaths
	end
	return '-MF'..list[1]..str
end